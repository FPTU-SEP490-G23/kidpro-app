from abc import ABC, abstractmethod
from typing import Optional, Tuple
import numpy as np
import cv2

class FaceDetectionResult:
    def __init__(self, box: np.ndarray, landmarks: Optional[np.ndarray], confidence: float):
        self.box = box.astype(int)  # [x1, y1, x2, y2]
        self.landmarks = landmarks.astype(np.float32) if landmarks is not None else None  # (5, 2)
        self.confidence = float(confidence)

    @property
    def area(self) -> float:
        w = max(0, self.box[2] - self.box[0])
        h = max(0, self.box[3] - self.box[1])
        return float(w * h)

class BaseFaceDetector(ABC):
    @abstractmethod
    def detect(self, img: np.ndarray, conf: float = 0.35) -> Optional[FaceDetectionResult]:
        """Detect the largest face in the image and return bounding box + 5 landmarks."""
        pass

class YOLOFaceDetector(BaseFaceDetector):
    def __init__(self, model_or_path, simulate_landmarks_if_missing: bool = False):
        from ultralytics import YOLO
        if isinstance(model_or_path, str):
            self.model = YOLO(model_or_path)
        else:
            self.model = model_or_path
        self.simulate_landmarks_if_missing = simulate_landmarks_if_missing

    def detect(self, img: np.ndarray, conf: float = 0.35) -> Optional[FaceDetectionResult]:
        if img is None or img.size == 0:
            return None

        # Two-stage confidence detection: conf -> fallback to 0.12
        results = self.model(img, conf=conf, verbose=False)
        boxes = results[0].boxes
        if len(boxes) == 0:
            results = self.model(img, conf=0.12, verbose=False)
            boxes = results[0].boxes

        if len(boxes) == 0:
            return None

        # Pick largest face
        best_idx = int(np.argmax([
            float((b.xyxy[0][2] - b.xyxy[0][0]) * (b.xyxy[0][3] - b.xyxy[0][1]))
            for b in boxes
        ]))

        best_box = boxes[best_idx]
        xyxy = best_box.xyxy[0].cpu().numpy().astype(int)
        score = float(best_box.conf[0].cpu().item()) if hasattr(best_box, "conf") and len(best_box.conf) > 0 else 1.0

        # Extract 5 landmarks if model has keypoints (YOLO-Face pose)
        landmarks = None
        if hasattr(results[0], "keypoints") and results[0].keypoints is not None:
            kpts_data = results[0].keypoints
            if len(kpts_data) > best_idx:
                kpts = kpts_data.xy[best_idx].cpu().numpy()  # (N_kpts, 2)
                if kpts.shape[0] >= 5:
                    landmarks = kpts[:5, :2].astype(np.float32)

        if landmarks is None and self.simulate_landmarks_if_missing:
            # Fallback geometric simulation of 5 landmarks for detection-only weights (e.g. testing)
            x1, y1, x2, y2 = xyxy
            cx = (x1 + x2) / 2.0
            cy = (y1 + y2) / 2.0
            bw = x2 - x1
            bh = y2 - y1
            landmarks = np.array([
                [cx - bw * 0.20, cy - bh * 0.12],  # Left eye
                [cx + bw * 0.20, cy - bh * 0.12],  # Right eye
                [cx,             cy + bh * 0.05],  # Nose tip
                [cx - bw * 0.15, cy + bh * 0.25],  # Left mouth corner
                [cx + bw * 0.15, cy + bh * 0.25]   # Right mouth corner
            ], dtype=np.float32)

        return FaceDetectionResult(xyxy, landmarks, score)

# ArcFace Standard Template on 112x112
ARCFACE_STANDARD_TEMPLATE_112 = np.array([
    [38.2946, 51.6963],  # Left eye
    [73.5318, 51.5014],  # Right eye
    [56.0252, 71.7366],  # Nose tip
    [41.5493, 92.3655],  # Left mouth corner
    [70.7299, 92.2041]   # Right mouth corner
], dtype=np.float32)

def align_face(img: np.ndarray, landmarks5: np.ndarray, size: int = 112) -> np.ndarray:
    """
    Umeyama similarity transform (rotation + scaling + translation, strictly preserving aspect ratio).
    Aligns 5 landmarks [left_eye, right_eye, nose, left_mouth, right_mouth] to the standard ArcFace template.
    """
    if landmarks5 is None or landmarks5.shape != (5, 2):
        raise ValueError("NO_LANDMARKS")

    src_pts = landmarks5.astype(np.float32)
    dst_pts = ARCFACE_STANDARD_TEMPLATE_112.astype(np.float32)
    if size != 112:
        dst_pts = dst_pts * (size / 112.0)

    # estimateAffinePartial2D finds similarity transform (4 degrees of freedom: rotation, scale, translation x, translation y)
    M, _ = cv2.estimateAffinePartial2D(src_pts, dst_pts, method=cv2.LMEDS)
    if M is None:
        raise ValueError("ALIGNMENT_FAILED")

    aligned = cv2.warpAffine(img, M, (size, size), borderMode=cv2.BORDER_CONSTANT, borderValue=0)
    return aligned
