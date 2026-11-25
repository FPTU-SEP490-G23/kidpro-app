import io
import json
import os
import pickle
import sys
import tempfile
import unittest
from unittest.mock import patch
import numpy as np

# Add paths
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from face_detector import align_face, ARCFACE_STANDARD_TEMPLATE_112, FaceDetectionResult

class TestOPT001Alignment(unittest.TestCase):
    def test_align_face_shape_and_landmarks(self):
        # Create dummy 200x200 image
        dummy_img = np.zeros((200, 200, 3), dtype=np.uint8)
        # 5 landmarks around center
        landmarks = np.array([
            [80, 80],   # left eye
            [120, 80],  # right eye
            [100, 100], # nose
            [85, 120],  # left mouth
            [115, 120]  # right mouth
        ], dtype=np.float32)

        aligned = align_face(dummy_img, landmarks, size=112)
        self.assertEqual(aligned.shape, (112, 112, 3))

    def test_align_face_no_landmarks_raises_error(self):
        dummy_img = np.zeros((200, 200, 3), dtype=np.uint8)
        with self.assertRaises(ValueError) as ctx:
            align_face(dummy_img, None, size=112)
        self.assertIn("NO_LANDMARKS", str(ctx.exception))

        with self.assertRaises(ValueError) as ctx:
            align_face(dummy_img, np.zeros((4, 2)), size=112)
        self.assertIn("NO_LANDMARKS", str(ctx.exception))


class TestOPT007VersioningAndGuard(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.temp_dir.cleanup()

    def test_save_and_load_npz_with_metadata(self):
        from main import save_embeddings_to_npz, load_embeddings_from_file

        npz_path = os.path.join(self.temp_dir.name, "test_emb.npz")
        vectors = np.random.randn(5, 512).astype(np.float32)
        student_ids = [f"ST_{i}" for i in range(5)]
        meta = {
            "model_name": "arcface_w600k_r50",
            "pipeline_version": "v2_umeyama_align",
            "dim": 512
        }

        save_embeddings_to_npz(npz_path, vectors, student_ids, meta)
        self.assertTrue(os.path.exists(npz_path))

        loaded_vecs, loaded_ids, loaded_meta = load_embeddings_from_file(npz_path)
        np.testing.assert_allclose(loaded_vecs, vectors, rtol=1e-5)
        self.assertEqual(loaded_ids, student_ids)
        self.assertEqual(loaded_meta.get("pipeline_version"), "v2_umeyama_align")
        self.assertEqual(loaded_meta.get("model_name"), "arcface_w600k_r50")

    def test_legacy_pickle_fallback(self):
        from main import load_embeddings_from_file

        pkl_path = os.path.join(self.temp_dir.name, "legacy.pkl")
        vectors = np.random.randn(3, 512).astype(np.float32)
        student_ids = ["HS1", "HS2", "HS3"]
        with open(pkl_path, "wb") as f:
            pickle.dump({"embeddings": vectors, "student_ids": student_ids}, f)

        loaded_vecs, loaded_ids, loaded_meta = load_embeddings_from_file(pkl_path)
        self.assertEqual(loaded_ids, student_ids)
        self.assertEqual(loaded_meta.get("pipeline_version"), "v1_raw_crop")


class TestDatabaseVectorStore(unittest.TestCase):
    def test_embedding_parser_requires_512_finite_values(self):
        from main import _parse_face_embedding

        vector = np.zeros(512, dtype=np.float32)
        vector[0] = 1.0
        np.testing.assert_array_equal(_parse_face_embedding(vector.tolist()), vector)
        self.assertIsNone(_parse_face_embedding([1.0] * 511))
        self.assertIsNone(_parse_face_embedding([float("nan")] + [0.0] * 511))

    def test_internal_image_fetch_rejects_cross_origin_redirects(self):
        import main
        from urllib.request import Request

        request = Request(
            "http://backend/uploads/face.jpg",
            headers={"X-Internal-Service-Key": "internal-test-key"},
        )
        handler = main._SameOriginRedirectHandler()

        self.assertIsNone(handler.redirect_request(
            request, None, 302, "Found", {}, "https://images.example/face.jpg"
        ))

    def test_external_image_request_does_not_include_internal_key(self):
        import main

        class FakeResponse:
            def __enter__(self):
                return self

            def __exit__(self, exc_type, exc_value, traceback):
                return False

            def read(self):
                return b"image"

        captured_requests = []

        class FakeOpener:
            def open(self, request, timeout):
                captured_requests.append(request)
                return FakeResponse()

        expected_embedding = np.zeros(512, dtype=np.float32)
        expected_embedding[0] = 1.0
        with patch("main.urllib.request.build_opener", return_value=FakeOpener()), \
                patch("main.cv2.imdecode", return_value=np.zeros((1, 1, 3), dtype=np.uint8)), \
                patch("main.extract_l2_normalized_embedding", return_value=expected_embedding):
            main._download_face_embedding("http://backend", "https://images.example/face.jpg")

        self.assertNotIn(
            "x-internal-service-key",
            {name.lower() for name, _ in captured_requests[0].header_items()},
        )

    def test_database_mode_does_not_write_local_vector_caches(self):
        import main

        embeddings = np.ones((1, 512), dtype=np.float32)
        with patch.object(main, "BACKEND_URL", "http://backend"), \
                patch.object(main, "DATABASE_VECTOR_STORE", True), \
                patch.object(main, "save_embeddings_to_npz") as save_npz:
            main.update_embeddings_atomic(embeddings, ["student-1"])
            main.save_embeddings_cache()
            save_npz.assert_not_called()

        with patch.object(main, "BACKEND_URL", "http://backend"), \
                patch.object(main, "DATABASE_VECTOR_STORE", True), \
                patch("builtins.open", side_effect=AssertionError("unexpected file write")):
            main.update_pickup_cache_atomic({"photo": embeddings[0]})
            main.save_pickup_cache()

        main.update_embeddings_atomic(None, [])
        main.update_pickup_cache_atomic({})

    def test_database_sync_migrates_legacy_vector_through_internal_api(self):
        import main

        student_id = "student-legacy-1"
        vector = np.zeros(512, dtype=np.float32)
        vector[0] = 1.0
        face_file = {
            "faceFileId": 15,
            "studentId": student_id,
            "studentName": "Student",
            "classId": None,
            "className": "Class",
            "photoUrl": "https://images.example/face.jpg",
            "faceEmbedding": None,
            "modelName": "arcface_w600k_r50",
            "pipelineVersion": "v1_raw_crop",
        }

        class FakeResponse:
            def __init__(self, body=b""):
                self.body = body

            def __enter__(self):
                return self

            def __exit__(self, exc_type, exc_value, traceback):
                return False

            def read(self):
                return self.body

        opened_requests = []
        responses = iter([
            FakeResponse(json.dumps([face_file]).encode("utf-8")),
            FakeResponse(),
        ])

        class FakeOpener:
            def open(self, request, timeout):
                opened_requests.append(request)
                return next(responses)

        with tempfile.TemporaryDirectory() as temp_dir:
            db_path = os.path.join(temp_dir, "attendance.db")
            with patch.object(main, "DB_PATH", db_path), \
                    patch.object(main, "cached_pipeline_version", "v1_raw_crop"), \
                    patch.object(main, "_load_legacy_student_embeddings", return_value={student_id: vector}), \
                    patch("main.urllib.request.build_opener", return_value=FakeOpener()):
                main.init_db()
                result = main.sync_embeddings_from_backend("http://backend")

                self.assertEqual(result, {"synced_count": 1, "migrated_count": 1})
                put_request = opened_requests[1]
                self.assertEqual(put_request.get_method(), "PUT")
                update_payload = json.loads(put_request.data.decode("utf-8"))
                self.assertEqual(len(update_payload["faceEmbedding"]), 512)
                self.assertEqual(update_payload["pipelineVersion"], main.PIPELINE_VERSION)
                self.assertEqual(main.get_embeddings_snapshot()[1], [student_id])
                np.testing.assert_array_equal(main.get_embeddings_snapshot()[0][0], vector)

        main.update_embeddings_atomic(None, [])

    def test_database_sync_fills_missing_pickup_vector(self):
        import main

        face_file = {
            "faceFileId": 27,
            "photoUrl": "https://images.example/pickup.jpg",
            "faceEmbedding": None,
        }
        vector = np.zeros(512, dtype=np.float32)
        vector[0] = 1.0
        opened_requests = []

        class FakeResponse:
            def __init__(self, body=b""):
                self.body = body

            def __enter__(self):
                return self

            def __exit__(self, exc_type, exc_value, traceback):
                return False

            def read(self):
                return self.body

        responses = iter([
            FakeResponse(json.dumps([face_file]).encode("utf-8")),
            FakeResponse(),
        ])

        class FakeOpener:
            def open(self, request, timeout):
                opened_requests.append(request)
                return next(responses)

        with patch("main.urllib.request.build_opener", return_value=FakeOpener()), \
                patch("main._download_face_embedding", return_value=vector):
            result = main.sync_pickup_encodings_from_backend("http://backend")

        self.assertEqual(result, {"synced_count": 1, "migrated_count": 1})
        self.assertEqual(opened_requests[1].get_method(), "PUT")
        self.assertEqual(len(json.loads(opened_requests[1].data)["faceEmbedding"]), 512)

if __name__ == "__main__":
    unittest.main()
