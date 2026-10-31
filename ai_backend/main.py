import io
import os
import pickle
import sqlite3
from datetime import datetime
from typing import List, Optional

import cv2
import numpy as np
import onnxruntime as ort
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from ultralytics import YOLO

# ==========================================
# CONFIGURATION & INITIALIZATION
# ==========================================
DB_PATH = "attendance.db"
EMBEDDINGS_FILE = "embeddings.pkl"
SIMILARITY_THRESHOLD = 0.60
YOLO_MODEL_PATH = "face_yolov8n.pt"
ARCFACE_MODEL_PATH = "arcface_w600k_r50.onnx"

app = FastAPI(
    title="KIDPRO - Face Attendance AI Engine (YOLOv8 + ArcFace)",
    description="Lightweight Face Attendance AI Service combining YOLOv8n-Face and ArcFace ONNX (512-dim)",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global in-memory cache for fast vector dot-product matching
registered_embeddings: Optional[np.ndarray] = None
registered_student_ids: List[str] = []

def ensure_model_file(path: str, url: str, fallback_path: Optional[str] = None):
    import shutil
    import urllib.request
    if not os.path.exists(path):
        if fallback_path and os.path.exists(fallback_path):
            print(f"📦 Đang sao chép {path} từ cache {fallback_path}...")
            shutil.copy(fallback_path, path)
            return
        print(f"📥 Đang tự động tải mô hình {path}...")
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as resp, open(path, "wb") as f:
            f.write(resp.read())
        print(f"✅ Đã tải xong {path} ({os.path.getsize(path)/(1024*1024):.2f} MB)")

# 1. Load YOLOv8n-Face detector
ensure_model_file(
    YOLO_MODEL_PATH,
    "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8n.pt"
)
print(f"🔄 Đang tải mô hình YOLOv8n-Face detector từ {YOLO_MODEL_PATH}...")
yolo_detector = YOLO(YOLO_MODEL_PATH)
print("✅ YOLOv8n-Face detector đã sẵn sàng!")

# 2. Load ArcFace ONNX feature extractor
ensure_model_file(
    ARCFACE_MODEL_PATH,
    "https://huggingface.co/maze/faceX/resolve/main/w600k_r50.onnx",
    fallback_path=os.path.expanduser("~/.insightface/models/buffalo_l/w600k_r50.onnx")
)
print(f"🔄 Đang tải ArcFace ONNX feature extractor từ {ARCFACE_MODEL_PATH}...")
arcface_session = ort.InferenceSession(ARCFACE_MODEL_PATH, providers=["CPUExecutionProvider"])
arcface_input_name = arcface_session.get_inputs()[0].name
arcface_output_name = arcface_session.get_outputs()[0].name
print("✅ ArcFace ONNX feature extractor đã sẵn sàng!")


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
                print(f"📦 Đã nạp {len(registered_student_ids)} vector khuôn mặt từ cache {EMBEDDINGS_FILE}")
        except Exception as e:
            print(f"⚠️ Không thể đọc cache: {e}")
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
# FACE EXTRACTION PIPELINE (YOLOv8 + ArcFace)
# ==========================================
async def read_image_from_upload(upload_file: UploadFile) -> np.ndarray:
    contents = await upload_file.read()
    nparr = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(status_code=400, detail="Không thể giải mã tệp ảnh.")
    return img


def extract_l2_normalized_embedding(img: np.ndarray) -> Optional[np.ndarray]:
    """
    Pipeline 2 giai đoạn:
    1. YOLOv8n-Face phát hiện khuôn mặt & chọn khuôn mặt có diện tích lớn nhất.
    2. Cắt khuôn mặt, tiền xử lý và đưa vào ArcFace trích xuất vector 512 chiều chuẩn hóa L2.
    """
    # 1. Phát hiện khuôn mặt bằng YOLOv8
    results = yolo_detector(img, conf=0.35, verbose=False)
    boxes = results[0].boxes
    if len(boxes) == 0:
        return None

    # Chọn khuôn mặt lớn nhất trong khung hình (trọng tâm bức ảnh)
    best_box = max(boxes, key=lambda b: (b.xyxy[0][2] - b.xyxy[0][0]) * (b.xyxy[0][3] - b.xyxy[0][1]))
    xyxy = best_box.xyxy[0].cpu().numpy().astype(int)

    h, w = img.shape[:2]
    # Mở rộng bounding box thêm 10% lề để bao trọn cằm và trán
    box_w = xyxy[2] - xyxy[0]
    box_h = xyxy[3] - xyxy[1]
    margin_x = int(box_w * 0.10)
    margin_y = int(box_h * 0.10)

    x1 = max(0, xyxy[0] - margin_x)
    y1 = max(0, xyxy[1] - margin_y)
    x2 = min(w, xyxy[2] + margin_x)
    y2 = min(h, xyxy[3] + margin_y)

    if x2 <= x1 or y2 <= y1:
        return None

    face_crop = img[y1:y2, x1:x2]
    if face_crop.size == 0:
        return None

    # 2. Tiền xử lý đưa vào ArcFace ONNX
    face_resized = cv2.resize(face_crop, (112, 112))
    face_rgb = cv2.cvtColor(face_resized, cv2.COLOR_BGR2RGB)
    face_norm = (face_rgb.astype(np.float32) - 127.5) / 128.0
    face_blob = np.transpose(face_norm, (2, 0, 1))  # (3, 112, 112)
    face_blob = np.expand_dims(face_blob, axis=0)   # (1, 3, 112, 112)

    # 3. Chạy suy luận trích xuất đặc trưng
    raw_emb = arcface_session.run([arcface_output_name], {arcface_input_name: face_blob})[0][0]

    # Chuẩn hóa L2 norm = 1.0 (cho phép so khớp Cosine Similarity bằng tích vô hướng np.dot)
    norm = np.linalg.norm(raw_emb)
    if norm > 0:
        raw_emb = raw_emb / norm

    return raw_emb


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
        "model": "YOLOv8n-Face (Detection ~6MB) + ArcFace ONNX (Embedding 512-dim)",
        "network": "Listening on 0.0.0.0:8000 (Supports Wi-Fi LAN & USB Reverse simultaneously)",
    }


@app.post("/api/v1/register")
async def register_student(
    student_id: str = Form(..., description="Mã số học sinh"),
    name: str = Form(..., description="Họ và tên học sinh"),
    class_name: str = Form(..., description="Tên lớp học"),
    file: UploadFile = File(..., description="Ảnh chân dung học sinh"),
):
    global registered_embeddings, registered_student_ids

    # 1. Giải mã và trích xuất vector đặc trưng
    img = await read_image_from_upload(file)
    embedding = extract_l2_normalized_embedding(img)
    if embedding is None:
        raise HTTPException(status_code=400, detail="Không tìm thấy khuôn mặt trong ảnh chân dung.")

    # 2. Lưu thông tin vào SQLite
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

    # 3. Cập nhật Vector Cache trong RAM
    if student_id in registered_student_ids:
        idx = registered_student_ids.index(student_id)
        registered_embeddings[idx] = embedding
    else:
        registered_student_ids.append(student_id)
        if registered_embeddings is None or len(registered_embeddings) == 0:
            registered_embeddings = np.expand_dims(embedding, axis=0)
        else:
            registered_embeddings = np.vstack([registered_embeddings, embedding])

    # 4. Lưu ra đĩa
    save_embeddings_cache()

    return {
        "success": True,
        "student_id": student_id,
        "name": name,
        "class_name": class_name,
        "message": f"Đã đăng ký thành công học sinh {name} (YOLOv8 + ArcFace 512-dim)",
    }


@app.post("/api/v1/check-in")
async def check_in_face(
    file: UploadFile = File(..., description="Ảnh chụp khuôn mặt từ camera mobile"),
):
    global registered_embeddings, registered_student_ids

    try:
        # 1. Giải mã ảnh
        img = await read_image_from_upload(file)

        # 2. Trích xuất embedding bằng YOLOv8n + ArcFace
        target_embedding = extract_l2_normalized_embedding(img)
        if target_embedding is None:
            _log_attendance(None, "UNKNOWN", 0.0)
            return {
                "status": "UNKNOWN",
                "confidence_score": 0.0,
                "message": "Không phát hiện khuôn mặt trong khung hình",
            }

        # 3. Kiểm tra danh sách học sinh đã đăng ký
        if registered_embeddings is None or len(registered_student_ids) == 0:
            _log_attendance(None, "UNKNOWN", 0.0)
            return {
                "status": "UNKNOWN",
                "confidence_score": 0.0,
                "message": "Chưa có học sinh nào được đăng ký trong hệ thống",
            }

        # 4. So khớp nhanh Cosine Similarity (np.dot)
        scores = np.dot(registered_embeddings, target_embedding)
        best_idx = int(np.argmax(scores))
        best_score = float(scores[best_idx])
        matched_student_id = registered_student_ids[best_idx]

        # 5. Đánh giá ngưỡng nhận diện
        if best_score >= SIMILARITY_THRESHOLD:
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
            # Cảnh báo người lạ / chưa đăng ký
            _log_attendance(None, "UNKNOWN", best_score)
            return {
                "status": "UNKNOWN",
                "confidence_score": round(best_score, 4),
                "message": f"Không nhận diện được học sinh (Độ khớp {int(best_score * 100)}% thấp hơn ngưỡng {int(SIMILARITY_THRESHOLD * 100)}%)",
            }
    except Exception as e:
        print(f"Lỗi xử lý check-in: {e}")
        return {
            "status": "UNKNOWN",
            "confidence_score": 0.0,
            "message": f"Lỗi xử lý AI: {str(e)}",
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
    # Bind to 0.0.0.0 so devices on same LAN Wi-Fi or USB reverse can access concurrently
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
