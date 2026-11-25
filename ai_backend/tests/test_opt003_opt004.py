import os
import unittest
from unittest.mock import patch
import numpy as np
import cv2
from fastapi.testclient import TestClient
import sys

os.environ.setdefault("INTERNAL_SERVICE_KEY", "test-internal-key")
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from main import (
    app,
    INTERNAL_SERVICE_KEY,
    PIPELINE_VERSION,
    MODEL_NAME,
    update_embeddings_atomic,
    cached_pipeline_version,
)
from face_detector import FaceDetectionResult
import main


class TestOPT003OPT004(unittest.TestCase):
    def setUp(self):
        self.client = TestClient(app)
        # Create synthetic registered embeddings with distinct students
        emb1 = np.zeros(512, dtype=np.float32)
        emb1[0] = 1.0

        emb2 = np.zeros(512, dtype=np.float32)
        emb2[1] = 1.0

        emb3 = np.zeros(512, dtype=np.float32)
        emb3[2] = 1.0

        embeddings = np.vstack([emb1, emb2, emb3])
        student_ids = ["student-001", "student-002", "student-003"]
        update_embeddings_atomic(embeddings, student_ids)
        main.cached_pipeline_version = PIPELINE_VERSION

        # Dummy face image (112x112)
        self.dummy_img = np.zeros((112, 112, 3), dtype=np.uint8)
        cv2.circle(self.dummy_img, (56, 56), 40, (200, 200, 200), -1)
        _, self.img_encoded = cv2.imencode(".jpg", self.dummy_img)
        self.img_bytes = self.img_encoded.tobytes()

        # Mock detection result with landmarks
        landmarks = np.array([
            [40, 50],
            [70, 50],
            [55, 70],
            [45, 90],
            [65, 90]
        ], dtype=np.float32)
        self.mock_det = FaceDetectionResult(np.array([20, 20, 90, 90]), landmarks, 0.95)

    def test_unauthorized_when_missing_or_invalid_internal_key(self):
        # Missing key
        res = self.client.post(
            "/api/v1/check-in",
            files={"file": ("test.jpg", self.img_bytes, "image/jpeg")}
        )
        self.assertEqual(res.status_code, 401)
        self.assertIn("UNAUTHORIZED", res.json()["detail"])

        # Invalid key
        res = self.client.post(
            "/api/v1/check-in",
            headers={"X-Internal-Service-Key": "wrong-secret-key"},
            files={"file": ("test.jpg", self.img_bytes, "image/jpeg")}
        )
        self.assertEqual(res.status_code, 401)

    @patch("main.extract_l2_normalized_embedding")
    @patch("main.check_image_blur", return_value=(False, 120.0))
    def test_feature_extractor_contract_authorized(self, mock_blur, mock_extract):
        # Query vector close to student-001
        q_emb = np.zeros(512, dtype=np.float32)
        q_emb[0] = 0.95
        q_emb[1] = 0.31
        q_emb = q_emb / np.linalg.norm(q_emb)
        mock_extract.return_value = q_emb

        res = self.client.post(
            "/api/v1/check-in",
            headers={"X-Internal-Service-Key": INTERNAL_SERVICE_KEY},
            files={"file": ("test.jpg", self.img_bytes, "image/jpeg")}
        )
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data["face_found"])
        self.assertEqual(data["pipeline_version"], PIPELINE_VERSION)
        self.assertEqual(data["model_name"], MODEL_NAME)
        self.assertEqual(data["top1_student_id"], "student-001")
        self.assertGreater(data["top1_score"], 0.90)
        self.assertEqual(data["top2_student_id"], "student-002")
        self.assertGreater(data["margin"], 0.0)
        # Verify no PRESENT/UNKNOWN decision is made by FastAPI
        self.assertNotIn("status", data)

    @patch("main.estimate_head_yaw", return_value=12.5)
    def test_estimate_yaw_endpoint(self, mock_yaw):
        with patch.object(main, "face_detector") as mock_fd:
            mock_fd.detect.return_value = self.mock_det
            res = self.client.post(
                "/api/v1/estimate-yaw",
                headers={"X-Internal-Service-Key": INTERNAL_SERVICE_KEY},
                files={"file": ("test.jpg", self.img_bytes, "image/jpeg")}
            )
            self.assertEqual(res.status_code, 200)
            data = res.json()
            self.assertTrue(data["face_found"])
            self.assertEqual(data["yaw_estimate"], 12.5)

    @patch("main.check_image_blur", return_value=(False, 120.0))
    def test_liveness_turn_intra_identity_check(self, mock_blur):
        # Front embedding and turn embedding of the same person
        emb_front = np.zeros(512, dtype=np.float32)
        emb_front[0] = 1.0

        emb_turn = np.zeros(512, dtype=np.float32)
        emb_turn[0] = 0.90
        emb_turn[1] = 0.43
        emb_turn = emb_turn / np.linalg.norm(emb_turn)

        turn_img = np.zeros((112, 112, 3), dtype=np.uint8)
        _, turn_encoded = cv2.imencode(".jpg", turn_img)
        turn_bytes = turn_encoded.tobytes()

        # Side effects for front then turn
        turned_landmarks = np.array([
            [30, 50],
            [60, 50],
            [65, 70],
            [35, 90],
            [55, 90]
        ], dtype=np.float32)
        mock_turn_det = FaceDetectionResult(np.array([20, 20, 90, 90]), turned_landmarks, 0.95)

        with patch("main.extract_l2_normalized_embedding", side_effect=[emb_front, emb_turn]):
            with patch.object(main, "face_detector") as mock_fd:
                mock_fd.detect.return_value = mock_turn_det
                res = self.client.post(
                    "/api/v1/check-in",
                    headers={"X-Internal-Service-Key": INTERNAL_SERVICE_KEY},
                    files={
                        "file": ("front.jpg", self.img_bytes, "image/jpeg"),
                        "turn_file": ("turn.jpg", turn_bytes, "image/jpeg")
                    },
                    data={"expected_action": "TURN_LEFT"}
                )
                self.assertEqual(res.status_code, 200)
                data = res.json()
                self.assertTrue(data["face_found"])
                self.assertTrue(data["turn_valid"])
                self.assertGreater(data["intra_similarity"], 0.70)


if __name__ == "__main__":
    unittest.main()
