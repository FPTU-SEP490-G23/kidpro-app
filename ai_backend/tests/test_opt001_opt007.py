import io
import json
import os
import pickle
import sys
import tempfile
import unittest
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

if __name__ == "__main__":
    unittest.main()
