#!/usr/bin/env python3
"""
KIDPRO - Vector Embedding Batch Recalculation Tool (OPT-007)
Upgrades all registered student embeddings to pipeline_version='v2_umeyama_align'.
Supports --dry-run, creates automatic backups, and writes atomically.
"""

import argparse
import datetime
import glob
import json
import os
import shutil
import sqlite3
import sys
from typing import Dict, List, Optional, Tuple

import cv2
import numpy as np

# Ensure ai_backend is on path for runtime execution
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
AI_BACKEND_DIR = os.path.join(SCRIPT_DIR, "..", "kidpro_app", "ai_backend")
if os.path.exists(AI_BACKEND_DIR):
    sys.path.insert(0, os.path.abspath(AI_BACKEND_DIR))

try:
    from kidpro_app.ai_backend.face_detector import align_face, YOLOFaceDetector  # type: ignore
except (ImportError, ModuleNotFoundError):
    try:
        from face_detector import align_face, YOLOFaceDetector  # type: ignore
    except (ImportError, ModuleNotFoundError) as e:
        print(f"❌ Missing face_detector: {e}")
        sys.exit(1)

try:
    from ultralytics import YOLO
    import onnxruntime as ort
except ImportError as e:
    print(f"❌ Missing dependencies: {e}")
    sys.exit(1)

PIPELINE_VERSION = "v2_umeyama_align"
MODEL_NAME = "arcface_w600k_r50"
EMBEDDING_DIM = 512


def extract_features(img: np.ndarray, face_detector, arcface_session, arc_inp: str, arc_out: str) -> Optional[np.ndarray]:
    det = face_detector.detect(img, conf=0.35)
    if det is None or det.landmarks is None:
        return None

    aligned = align_face(img, det.landmarks, size=112)
    face_rgb = cv2.cvtColor(aligned, cv2.COLOR_BGR2RGB)
    face_norm = (face_rgb.astype(np.float32) - 127.5) / 128.0
    blob = np.transpose(face_norm, (2, 0, 1))
    blob = np.expand_dims(blob, axis=0)

    raw_emb1 = arcface_session.run([arc_out], {arc_inp: blob})[0][0]

    # TTA Flip
    flip_rgb = cv2.flip(face_rgb, 1)
    flip_norm = (flip_rgb.astype(np.float32) - 127.5) / 128.0
    flip_blob = np.transpose(flip_norm, (2, 0, 1))
    flip_blob = np.expand_dims(flip_blob, axis=0)
    raw_emb2 = arcface_session.run([arc_out], {arc_inp: flip_blob})[0][0]

    comb = raw_emb1 + raw_emb2
    norm = np.linalg.norm(comb)
    return (comb / norm) if norm > 0 else comb


def save_npz_atomic(filepath: str, embeddings: np.ndarray, student_ids: List[str], metadata: dict):
    tmp_path = f"{filepath}.tmp.npz"
    meta_json = json.dumps(metadata)
    np.savez(
        tmp_path,
        embeddings=embeddings.astype(np.float32),
        student_ids=np.array([str(s) for s in student_ids], dtype=str),
        metadata=np.array([meta_json], dtype=str)
    )
    if os.path.exists(filepath):
        try:
            os.replace(tmp_path, filepath)
        except Exception:
            try:
                os.remove(filepath)
            except Exception:
                pass
            os.rename(tmp_path, filepath)
    else:
        os.rename(tmp_path, filepath)


def recalculate(
    source_dirs: List[str],
    sqlite_db: Optional[str],
    output_npz: str,
    yolo_model_path: str,
    arcface_model_path: str,
    dry_run: bool = False
):
    print("=" * 70)
    print("🔄 KIDPRO RECALCULATE EMBEDDINGS (OPT-007)")
    print(f"Target Pipeline Version: {PIPELINE_VERSION}")
    print(f"Target Model:            {MODEL_NAME}")
    print(f"Output File:             {output_npz}")
    print(f"Dry Run Mode:            {'YES (no files will be written)' if dry_run else 'NO (live update)'}")
    print("=" * 70)

    # 1. Load models
    print("Loading models...")
    yolo = YOLO(yolo_model_path)
    detector = YOLOFaceDetector(yolo, simulate_landmarks_if_missing=True)
    sess_opts = ort.SessionOptions()
    sess_opts.intra_op_num_threads = 2
    session = ort.InferenceSession(arcface_model_path, sess_options=sess_opts, providers=["CPUExecutionProvider"])
    arc_inp = session.get_inputs()[0].name
    arc_out = session.get_outputs()[0].name

    # 2. Gather student images
    # Map student_id -> image_path
    student_photos: Dict[str, str] = {}

    for s_dir in source_dirs:
        if not os.path.exists(s_dir):
            continue
        for ext in ("*.jpg", "*.jpeg", "*.png"):
            for fpath in glob.glob(os.path.join(s_dir, ext)):
                fname = os.path.basename(fpath)
                # Matches student_<uuid>_timestamp.jpg
                if fname.startswith("student_"):
                    parts = fname.split("_")
                    if len(parts) >= 2:
                        sid = parts[1]
                        student_photos[sid] = fpath
                elif fname.startswith("sample_"):
                    student_photos["SAMPLE_STUDENT"] = fpath

    # Also check sqlite if provided
    if sqlite_db and os.path.exists(sqlite_db):
        try:
            conn = sqlite3.connect(sqlite_db)
            c = conn.cursor()
            c.execute("SELECT student_id, name FROM students")
            for sid, sname in c.fetchall():
                if sid not in student_photos:
                    # check if any file in source dirs matches sid
                    found = False
                    for s_dir in source_dirs:
                        cand = os.path.join(s_dir, f"{sid}.jpg")
                        if os.path.exists(cand):
                            student_photos[sid] = cand
                            found = True
                            break
                    if not found and "SAMPLE_STUDENT" in student_photos:
                        # Fallback for dev demo
                        pass
            conn.close()
        except Exception as e:
            print(f"Notice reading sqlite: {e}")

    print(f"Found {len(student_photos)} registered students to recalculate.")

    succeeded_ids = []
    succeeded_vectors = []
    failed_reports = []

    for sid, img_path in student_photos.items():
        img = cv2.imread(img_path)
        if img is None:
            failed_reports.append((sid, img_path, "CANNOT_DECODE_IMAGE"))
            continue

        emb = extract_features(img, detector, session, arc_inp, arc_out)
        if emb is None:
            failed_reports.append((sid, img_path, "NO_FACE_OR_LANDMARKS_DETECTED"))
            continue

        succeeded_ids.append(sid)
        succeeded_vectors.append(emb)
        print(f"  ✅ Recalculated {sid}: vector norm={np.linalg.norm(emb):.4f}")

    print("\n" + "=" * 70)
    print("📊 BATCH RECALCULATION REPORT")
    print(f"Total processed : {len(student_photos)}")
    print(f"Successful      : {len(succeeded_ids)}")
    print(f"Failed          : {len(failed_reports)}")

    if failed_reports:
        print("\n❌ Failed students detail:")
        for fid, fpath, reason in failed_reports:
            print(f"  - Student: {fid} | Path: {fpath} | Reason: {reason}")

    if dry_run:
        print("\n[DRY RUN] Completed without modifying vector store.")
        return len(succeeded_ids), len(failed_reports)

    # 3. Create backup if file exists
    if os.path.exists(output_npz):
        ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_path = f"{output_npz}.bak_{ts}"
        shutil.copy2(output_npz, backup_path)
        print(f"📦 Backup created at: {backup_path}")

    # Also backup legacy .pkl if present
    legacy_pkl = os.path.join(os.path.dirname(output_npz), "embeddings.pkl")
    if os.path.exists(legacy_pkl):
        ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_pkl = f"{legacy_pkl}.bak_{ts}"
        shutil.copy2(legacy_pkl, backup_pkl)
        print(f"📦 Legacy pickle backup created at: {backup_pkl}")

    # 4. Save new vectors atomically
    if succeeded_vectors:
        vecs_arr = np.vstack(succeeded_vectors)
        meta = {
            "model_name": MODEL_NAME,
            "pipeline_version": PIPELINE_VERSION,
            "dim": EMBEDDING_DIM,
            "recalculated_at": datetime.datetime.now().isoformat(),
            "total_vectors": len(succeeded_ids)
        }
        save_npz_atomic(output_npz, vecs_arr, succeeded_ids, meta)
        print(f"✅ Atomically saved {len(succeeded_ids)} v2 vectors to {output_npz}")
    else:
        print("⚠️ No vectors to save.")

    print("=" * 70)
    return len(succeeded_ids), len(failed_reports)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="KIDPRO Recalculate Face Embeddings to v2 Umeyama Alignment")
    parser.add_argument("--source-dirs", nargs="+", default=[
        "KidPro-be/uploads/faces",
        "kidpro_app/ai_backend"
    ], help="Directories holding student photos")
    parser.add_argument("--sqlite", default="kidpro_app/ai_backend/attendance.db", help="Path to SQLite attendance.db")
    parser.add_argument("--output", default="kidpro_app/ai_backend/embeddings.npz", help="Output .npz path")
    parser.add_argument("--yolo", default="kidpro_app/ai_backend/face_yolov8n.pt", help="YOLO model path")
    parser.add_argument("--arcface", default="kidpro_app/ai_backend/arcface_w600k_r50.onnx", help="ArcFace ONNX model path")
    parser.add_argument("--dry-run", action="store_true", help="Perform dry-run without modifying files")

    args = parser.parse_args()
    recalculate(
        source_dirs=args.source_dirs,
        sqlite_db=args.sqlite,
        output_npz=args.output,
        yolo_model_path=args.yolo,
        arcface_model_path=args.arcface,
        dry_run=args.dry_run
    )
