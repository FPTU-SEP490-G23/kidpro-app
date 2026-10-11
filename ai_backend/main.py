import io
import os
import pickle
import sqlite3
from datetime import datetime
from typing import List, Optional

import cv2
import numpy as np
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# InsightFace
from insightface.app import FaceAnalysis

# ==========================================
# CONFIGURATION & INITIALIZATION
# ==========================================
DB_PATH = "attendance.db"
EMBEDDINGS_FILE = "embeddings.pkl"
SIMILARITY_THRESHOLD = 0.65

app = FastAPI(
    title="KIDPRO - Face Attendance AI Engine",
    description="PoC AI Facial Recognition Service using YOLOv8-Face & InsightFace buffalo_sc",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global in-memory cache for fast vector dot-product matching
# registered_embeddings: np.ndarray shape (N, 512)
# registered_student_ids: list of student_id strings
registered_embeddings: Optional[np.ndarray] = None
registered_student_ids: List[str] = []

# Initialize InsightFace model
print("🔄 Loading InsightFace model 'buffalo_sc' with CPUExecutionProvider...")
face_app = FaceAnalysis(name="buffalo_sc", providers=["CPUExecutionProvider"])
face_app.prepare(ctx_id=0, det_size=(640, 640))
print("✅ InsightFace model ready!")


# ==========================================
# DATABASE & STORAGE HELPERS
# ==========================================
def init_db():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS students (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id TEXT UNIQUE NOT NULL,
            name TEXT NOT NULL,
            class_name TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS attendance_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            student_id TEXT,
            status TEXT NOT NULL,
            confidence_score REAL,
            checkin_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()
    conn.close()


def load_embeddings_cache():
    global registered_embeddings, registered_student_ids
    if os.path.exists(EMBEDDINGS_FILE):
        try:
            with open(EMBEDDINGS_FILE, "rb") as f:
                data = pickle.load(f)
                registered_embeddings = data.get("embeddings")
                registered_student_ids = data.get("student_ids", [])
                print(f"📦 Loaded {len(registered_student_ids)} face embeddings from {EMBEDDINGS_FILE}")
        except Exception as e:
            print(f"⚠️ Failed to load embeddings cache: {e}")
            registered_embeddings = None
            registered_student_ids = []
    else:
        registered_embeddings = None
        registered_student_ids = []


def save_embeddings_cache():
    global registered_embeddings, registered_student_ids
    with open(EMBEDDINGS_FILE, "wb") as f:
        pickle.dump({
            "embeddings": registered_embeddings,
            "student_ids": registered_student_ids
        }, f)


@app.on_event("startup")
def startup_event():
    init_db()
    load_embeddings_cache()


# ==========================================
# HELPER FUNCTIONS
# ==========================================
def read_image_from_upload(upload_file: UploadFile) -> np.ndarray:
    contents = upload_file.file.read()
    nparr = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(status_code=400, detail="Không thể giải mã tệp ảnh.")
    return img


def extract_l2_normalized_embedding(img: np.ndarray) -> np.ndarray:
    faces = face_app.get(img)
    if not faces:
        return None
    # Pick the largest detected face by bounding box area
    largest_face = max(faces, key=lambda f: (f.bbox[2] - f.bbox[0]) * (f.bbox[3] - f.bbox[1]))
    embedding = largest_face.embedding.astype(np.float32)
    norm = np.linalg.norm(embedding)
    if norm > 0:
        embedding = embedding / norm
    return embedding


# ==========================================
# API ENDPOINTS
# ==========================================
@app.get("/")
def root():
    return {
        "service": "KidPro Face Attendance AI",
        "status": "ONLINE",
        "registered_students_count": len(registered_student_ids),
        "similarity_threshold": SIMILARITY_THRESHOLD,
        "model": "buffalo_sc (InsightFace / ONNX Runtime CPU)",
    }


@app.post("/api/v1/register")
async def register_student(
    student_id: str = Form(..., description="Mã số học sinh"),
    name: str = Form(..., description="Họ và tên học sinh"),
    class_name: str = Form(..., description="Tên lớp học"),
    file: UploadFile = File(..., description="Ảnh chân dung học sinh"),
):
    global registered_embeddings, registered_student_ids

    # 1. Decode & Extract Face Embedding
    img = read_image_from_upload(file)
    embedding = extract_l2_normalized_embedding(img)
    if embedding is None:
        raise HTTPException(status_code=400, detail="Không tìm thấy khuôn mặt trong ảnh chân dung.")

    # 2. Save/Update in SQLite
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    try:
        cursor.execute(
            "INSERT OR REPLACE INTO students (student_id, name, class_name) VALUES (?, ?, ?)",
            (student_id, name, class_name),
        )
        conn.commit()
    finally:
        conn.close()

    # 3. Update Vector Cache in RAM
    if student_id in registered_student_ids:
        # Update existing
        idx = registered_student_ids.index(student_id)
        registered_embeddings[idx] = embedding
    else:
        registered_student_ids.append(student_id)
        if registered_embeddings is None or len(registered_embeddings) == 0:
            registered_embeddings = np.expand_dims(embedding, axis=0)
        else:
            registered_embeddings = np.vstack([registered_embeddings, embedding])

    # 4. Persist to disk
    save_embeddings_cache()

    return {
        "success": True,
        "student_id": student_id,
        "name": name,
        "class_name": class_name,
        "message": f"Đã đăng ký thành công học sinh {name} (Vector 512 chiều)",
    }


@app.post("/api/v1/check-in")
async def check_in_face(
    file: UploadFile = File(..., description="Ảnh chụp khuôn mặt từ camera client"),
):
    global registered_embeddings, registered_student_ids

    # 1. Decode Image
    img = read_image_from_upload(file)

    # 2. Extract Embedding
    target_embedding = extract_l2_normalized_embedding(img)
    if target_embedding is None:
        # Log UNKNOWN
        _log_attendance(None, "UNKNOWN", 0.0)
        return {
            "status": "UNKNOWN",
            "confidence_score": 0.0,
            "message": "Không phát hiện khuôn mặt trong khung hình",
        }

    # 3. Check if registered database has any students
    if registered_embeddings is None or len(registered_student_ids) == 0:
        _log_attendance(None, "UNKNOWN", 0.0)
        return {
            "status": "UNKNOWN",
            "confidence_score": 0.0,
            "message": "Chưa có học sinh nào được đăng ký trong hệ thống",
        }

    # 4. Fast Vector Cosine Similarity (np.dot)
    # Because embeddings are L2 normalized, np.dot directly yields Cosine Similarity
    scores = np.dot(registered_embeddings, target_embedding)
    best_idx = int(np.argmax(scores))
    best_score = float(scores[best_idx])
    matched_student_id = registered_student_ids[best_idx]

    # 5. Threshold Evaluation
    if best_score >= SIMILARITY_THRESHOLD:
        # Query student information
        student = _get_student(matched_student_id)
        _log_attendance(matched_student_id, "PRESENT", best_score)
        return {
            "status": "PRESENT",
            "student_id": matched_student_id,
            "name": student["name"] if student else "Học sinh",
            "class_name": student["class_name"] if student else "",
            "confidence_score": round(best_score, 4),
            "checkin_time": datetime.now().strftime("%H:%M:%S - %d/%m/%Y"),
        }
    else:
        # Stranger / unregistered face
        _log_attendance(None, "UNKNOWN", best_score)
        return {
            "status": "UNKNOWN",
            "confidence_score": round(best_score, 4),
            "message": "Không nhận diện được học sinh (Độ khớp thấp hơn ngưỡng 0.65)",
        }


@app.get("/api/v1/students")
def list_students():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("SELECT student_id, name, class_name, created_at FROM students ORDER BY id DESC")
    rows = cursor.fetchall()
    conn.close()
    return [dict(r) for r in rows]


@app.get("/api/v1/logs")
def list_logs(limit: int = 20):
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("""
        SELECT a.id, a.student_id, s.name, s.class_name, a.status, a.confidence_score, a.checkin_time
        FROM attendance_logs a
        LEFT JOIN students s ON a.student_id = s.student_id
        ORDER BY a.id DESC LIMIT ?
    """, (limit,))
    rows = cursor.fetchall()
    conn.close()
    return [dict(r) for r in rows]


# ==========================================
# INTERNAL DB UTILS
# ==========================================
def _get_student(student_id: str) -> Optional[dict]:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("SELECT student_id, name, class_name FROM students WHERE student_id = ?", (student_id,))
    row = cursor.fetchone()
    conn.close()
    return dict(row) if row else None


def _log_attendance(student_id: Optional[str], status: str, score: float):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO attendance_logs (student_id, status, confidence_score) VALUES (?, ?, ?)",
        (student_id, status, score),
    )
    conn.commit()
    conn.close()


if __name__ == "__main__":
    import uvicorn
    # Bind to 0.0.0.0 so devices on same LAN Wi-Fi can access
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
