import io
import json
import os
import pickle
import sqlite3
import urllib.request
from datetime import datetime
from typing import List, Optional

import cv2
import numpy as np
from contextlib import asynccontextmanager
import onnxruntime as ort
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from ultralytics import YOLO

# ==========================================
# CONFIGURATION & INITIALIZATION (WARN-01, WARN-02, WARN-06)
# ==========================================
DB_PATH = os.getenv("DB_PATH", "attendance.db")
EMBEDDINGS_FILE = os.getenv("EMBEDDINGS_FILE", "embeddings.pkl")
PICKUP_CACHE_FILE = os.getenv("PICKUP_CACHE_FILE", "pickup_embeddings.pkl")
SIMILARITY_THRESHOLD = float(os.getenv("SIMILARITY_THRESHOLD", "0.60"))
BLUR_THRESHOLD = float(os.getenv("BLUR_THRESHOLD", "60.0"))
INTERNAL_SERVICE_KEY = os.getenv("INTERNAL_SERVICE_KEY", "kidpro_internal_secret_key_2026")
YOLO_MODEL_PATH = os.getenv("YOLO_MODEL_PATH", "face_yolov8n.pt")
ARCFACE_MODEL_PATH = os.getenv("ARCFACE_MODEL_PATH", "arcface_w600k_r50.onnx")

# Global in-memory cache for fast vector dot-product matching
registered_embeddings: Optional[np.ndarray] = None
registered_student_ids: List[str] = []
pickup_face_cache: dict = {}

# Model references initialized via FastAPI lifespan (WARN-01)
yolo_detector = None
arcface_session = None
arcface_input_name = None
arcface_output_name = None

def ensure_model_file(path: str, url: str, fallback_path: Optional[str] = None):
    """
    WARN-01: Kiểm tra và đảm bảo file model weights đã tồn tại.
    Ưu tiên weights đóng gói sẵn (baked in container), chống treo container khi không có mạng ngoài.
    """
    import shutil
    if os.path.exists(path):
        return

    # Kiểm tra đường dẫn dự phòng cục bộ
    local_candidates = [
        fallback_path,
        os.path.join(os.path.dirname(__file__), os.path.basename(path)),
        os.path.join(os.getcwd(), os.path.basename(path))
    ]
    for cand in local_candidates:
        if cand and os.path.exists(cand) and cand != path:
            print(f"📦 Đang sao chép {path} từ weights có sẵn {cand}...")
            shutil.copy(cand, path)
            return

    # Nếu không có file cục bộ, thử tải về với timeout chặt chẽ (tránh treo container vô hạn)
    print(f"📥 Đang tải mô hình {path} từ kho lưu trữ...")
    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=30) as resp, open(path, "wb") as f:
            f.write(resp.read())
        print(f"✅ Đã tải xong {path} ({os.path.getsize(path)/(1024*1024):.2f} MB)")
    except Exception as e:
        print(f"⚠️ Không thể tải {path} qua mạng: {e}")
        if not os.path.exists(path):
            raise RuntimeError(
                f"Lỗi khởi động AI Engine: Thiếu file weights '{path}'. "
                f"Vui lòng đóng gói sẵn file model vào thư mục hoặc mount volume khi triển khai Docker."
            )

def check_image_blur(img: np.ndarray, threshold: float = BLUR_THRESHOLD) -> tuple[bool, float]:
    """
    WARN-02: Kiểm tra độ nhòe/rung lắc bằng Laplacian Variance (cv2.Laplacian.var()).
    Nếu score < threshold, ảnh bị nhòe và có nguy cơ nhận diện sai.
    """
    if img is None or img.size == 0:
        return True, 0.0
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY) if len(img.shape) == 3 else img
    score = float(cv2.Laplacian(gray, cv2.CV_64F).var())
    return score < threshold, score

@asynccontextmanager
async def lifespan(app: FastAPI):
    global yolo_detector, arcface_session, arcface_input_name, arcface_output_name
    print("🚀 [Lifespan] Khởi tạo AI Engine và nạp weights mô hình...")
    init_db()
    load_embeddings_cache()
    load_pickup_cache()

    # 1. Load YOLOv8n-Face detector
    ensure_model_file(
        YOLO_MODEL_PATH,
        "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8n.pt"
    )
    print(f"🔄 Đang nạp mô hình YOLOv8n-Face detector từ {YOLO_MODEL_PATH}...")
    yolo_detector = YOLO(YOLO_MODEL_PATH)
    app.state.yolo_detector = yolo_detector
    print("✅ YOLOv8n-Face detector đã sẵn sàng!")

    # 2. Load ArcFace ONNX feature extractor
    ensure_model_file(
        ARCFACE_MODEL_PATH,
        "https://huggingface.co/maze/faceX/resolve/main/w600k_r50.onnx",
        fallback_path=os.path.expanduser("~/.insightface/models/buffalo_l/w600k_r50.onnx")
    )
    print(f"🔄 Đang nạp ArcFace ONNX feature extractor từ {ARCFACE_MODEL_PATH}...")
    arcface_session = ort.InferenceSession(ARCFACE_MODEL_PATH, providers=["CPUExecutionProvider"])
    arcface_input_name = arcface_session.get_inputs()[0].name
    arcface_output_name = arcface_session.get_outputs()[0].name
    app.state.arcface_session = arcface_session
    print("✅ ArcFace ONNX feature extractor đã sẵn sàng!")

    yield

    print("🛑 [Lifespan] Dọn dẹp tài nguyên AI Engine khi tắt ứng dụng.")

app = FastAPI(
    title="KIDPRO - Face Attendance AI Engine (YOLOv8 + ArcFace)",
    description="Lightweight Face Attendance AI Service combining YOLOv8n-Face and ArcFace ONNX (512-dim)",
    version="2.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


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
            class_id TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    # Thêm cột class_id nếu bảng đã tồn tại từ phiên bản trước
    try:
        cursor.execute("ALTER TABLE students ADD COLUMN class_id TEXT")
    except Exception:
        pass

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


def load_pickup_cache():
    global pickup_face_cache
    if os.path.exists(PICKUP_CACHE_FILE):
        try:
            with open(PICKUP_CACHE_FILE, "rb") as f:
                pickup_face_cache = pickle.load(f)
                print(f"📦 Đã nạp {len(pickup_face_cache)} vector khuôn mặt người đón từ cache {PICKUP_CACHE_FILE}")
        except Exception as e:
            print(f"⚠️ Không thể đọc cache người đón: {e}")
            pickup_face_cache = {}
    else:
        pickup_face_cache = {}


def save_pickup_cache():
    global pickup_face_cache
    try:
        with open(PICKUP_CACHE_FILE, "wb") as f:
            pickle.dump(pickup_face_cache, f)
    except Exception as e:
        print(f"⚠️ Không thể ghi cache người đón: {e}")


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


def extract_l2_normalized_embedding(img: np.ndarray, require_face: bool = False) -> Optional[np.ndarray]:
    """
    Pipeline 2 giai đoạn cải tiến (Khả năng chịu góc nghiêng & TTA):
    1. YOLOv8n-Face phát hiện khuôn mặt & cắt theo tỉ lệ vuông 1:1 quanh tâm mặt.
    2. Mở rộng lề 25% chống mất trán/tai khi nghiêng góc.
    3. Đưa vào ArcFace trích xuất vector 512-dim kết hợp ảnh gốc + ảnh lật ngang (TTA - Test-Time Augmentation).
    require_face=True: trả về None nếu không phát hiện khuôn mặt (dùng cho API so khớp 1-1 compare).
    """
    if img is None or img.size == 0:
        return None

    # 1. Phát hiện khuôn mặt bằng YOLOv8 (conf 0.35 -> fallback 0.12)
    results = yolo_detector(img, conf=0.35, verbose=False)
    boxes = results[0].boxes
    if len(boxes) == 0:
        results = yolo_detector(img, conf=0.12, verbose=False)
        boxes = results[0].boxes

    h, w = img.shape[:2]

    if len(boxes) > 0:
        # Chọn khuôn mặt lớn nhất trong khung hình (trọng tâm bức ảnh)
        best_box = max(boxes, key=lambda b: (b.xyxy[0][2] - b.xyxy[0][0]) * (b.xyxy[0][3] - b.xyxy[0][1]))
        xyxy = best_box.xyxy[0].cpu().numpy().astype(int)

        # Cắt theo hình vuông quanh tâm mặt (Square Crop 1:1) để không bị kéo méo khi nghiêng góc
        cx = (xyxy[0] + xyxy[2]) / 2.0
        cy = (xyxy[1] + xyxy[3]) / 2.0
        box_w = xyxy[2] - xyxy[0]
        box_h = xyxy[3] - xyxy[1]
        max_side = max(box_w, box_h)
        # Mở rộng 25% lề an toàn
        side = int(max_side * 1.25)

        x1 = max(0, int(cx - side / 2.0))
        y1 = max(0, int(cy - side / 2.0))
        x2 = min(w, int(cx + side / 2.0))
        y2 = min(h, int(cy + side / 2.0))
        face_crop = img[y1:y2, x1:x2]
    elif require_face:
        return None
    else:
        # Fallback ảnh chân dung tự động cắt trung tâm
        margin_x = int(w * 0.10)
        margin_y = int(h * 0.10)
        face_crop = img[margin_y:h-margin_y, margin_x:w-margin_x]

    if face_crop is None or face_crop.size == 0:
        face_crop = img

    # 2. Tiền xử lý ảnh gốc đưa vào ArcFace ONNX
    face_resized = cv2.resize(face_crop, (112, 112))
    face_rgb = cv2.cvtColor(face_resized, cv2.COLOR_BGR2RGB)
    face_norm = (face_rgb.astype(np.float32) - 127.5) / 128.0
    face_blob = np.transpose(face_norm, (2, 0, 1))
    face_blob = np.expand_dims(face_blob, axis=0)

    # 3. Trích xuất đặc trưng ảnh gốc
    raw_emb1 = arcface_session.run([arcface_output_name], {arcface_input_name: face_blob})[0][0]

    # 4. Kỹ thuật TTA (Test-Time Augmentation): trích xuất thêm ảnh lật ngang để chống sai lệch góc nghiêng
    face_flip = cv2.flip(face_rgb, 1)
    face_flip_norm = (face_flip.astype(np.float32) - 127.5) / 128.0
    face_flip_blob = np.transpose(face_flip_norm, (2, 0, 1))
    face_flip_blob = np.expand_dims(face_flip_blob, axis=0)
    raw_emb2 = arcface_session.run([arcface_output_name], {arcface_input_name: face_flip_blob})[0][0]

    # 5. Kết hợp 2 vector và chuẩn hóa L2 (tối ưu hóa độ tương đồng góc nghiêng)
    combined_emb = raw_emb1 + raw_emb2
    norm = np.linalg.norm(combined_emb)
    if norm > 0:
        combined_emb = combined_emb / norm

    return combined_emb


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
    class_id: Optional[str] = Form(None, description="Mã ID lớp học"),
    file: UploadFile = File(..., description="Ảnh chân dung học sinh"),
):
    global registered_embeddings, registered_student_ids

    # 1. Giải mã và trích xuất vector đặc trưng
    img = await read_image_from_upload(file)

    # 1b. Kiểm tra ảnh mờ (WARN-02)
    is_blurred, blur_score = check_image_blur(img, BLUR_THRESHOLD)
    if is_blurred:
        raise HTTPException(
            status_code=400,
            detail=f"Ảnh chân dung quá mờ hoặc rung lắc (độ nét {blur_score:.1f} < {BLUR_THRESHOLD}). Vui lòng chọn ảnh chụp rõ nét hơn."
        )
    embedding = extract_l2_normalized_embedding(img)
    if embedding is None:
        raise HTTPException(status_code=400, detail="Không tìm thấy khuôn mặt trong ảnh chân dung.")

    # 2. Lưu thông tin vào SQLite
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    try:
        cursor.execute(
            "INSERT OR REPLACE INTO students (student_id, name, class_name, class_id) VALUES (?, ?, ?, ?)",
            (student_id, name, class_name, class_id),
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
        "class_id": class_id,
        "message": f"Đã đăng ký thành công học sinh {name} (YOLOv8 + ArcFace 512-dim)",
    }


@app.post("/api/v1/sync")
def sync_from_backend(backend_url: str = "http://127.0.0.1:8080", class_id: Optional[str] = None):
    """Đồng bộ ảnh khuôn mặt học sinh (hỗ trợ lọc phạm vi lớp học class_id) từ Spring Boot Backend vào AI Engine"""
    global registered_embeddings, registered_student_ids
    try:
        url = f"{backend_url}/api/attendance/face-logs/registered-faces"
        if class_id:
            url += f"?classId={class_id}"

        headers = {
            'User-Agent': 'KidPro-AI-Engine',
            'X-Internal-Service-Key': INTERNAL_SERVICE_KEY
        }
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode('utf-8'))

        synced_count = 0
        for item in data:
            sid = str(item.get("studentId"))
            sname = item.get("studentName", "Học sinh")
            cname = item.get("className", "")
            cid = item.get("classId") or class_id or ""
            photo_url = item.get("photoUrl", "")
            if not photo_url:
                continue

            # Tải ảnh từ backend URL
            full_img_url = photo_url if photo_url.startswith("http") else f"{backend_url}{photo_url}"
            try:
                img_req = urllib.request.Request(full_img_url, headers={'User-Agent': 'KidPro-AI-Engine'})
                with urllib.request.urlopen(img_req, timeout=5) as img_resp:
                    img_bytes = img_resp.read()
                nparr = np.frombuffer(img_bytes, np.uint8)
                img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
                if img is None:
                    continue
                emb = extract_l2_normalized_embedding(img)
                if emb is None:
                    continue

                if sid in registered_student_ids:
                    idx = registered_student_ids.index(sid)
                    registered_embeddings[idx] = emb
                else:
                    registered_student_ids.append(sid)
                    if registered_embeddings is None or len(registered_embeddings) == 0:
                        registered_embeddings = np.expand_dims(emb, axis=0)
                    else:
                        registered_embeddings = np.vstack([registered_embeddings, emb])

                conn = sqlite3.connect(DB_PATH)
                cursor = conn.cursor()
                cursor.execute(
                    "INSERT OR REPLACE INTO students (student_id, name, class_name, class_id) VALUES (?, ?, ?, ?)",
                    (sid, sname, cname, cid),
                )
                conn.commit()
                conn.close()
                synced_count += 1
            except Exception as e:
                print(f"Lỗi tải ảnh bé {sid}: {e}")

        save_embeddings_cache()
        return {
            "success": True,
            "synced_count": synced_count,
            "total_registered": len(registered_student_ids),
        }
    except Exception as e:
        return {"success": False, "error": str(e)}


@app.post("/api/v1/check-in")
async def check_in_face(
    file: UploadFile = File(..., description="Ảnh chụp khuôn mặt từ camera mobile"),
    class_id: Optional[str] = Form(None, description="Chỉ đối chiếu học sinh thuộc lớp này"),
):
    global registered_embeddings, registered_student_ids

    try:
        # 1. Giải mã ảnh
        img = await read_image_from_upload(file)

        # 1b. Kiểm tra ảnh mờ / rung lắc trước khi nhận diện (WARN-02)
        is_blurred, blur_score = check_image_blur(img, BLUR_THRESHOLD)
        if is_blurred:
            return {
                "status": "BLURRED",
                "confidence_score": 0.0,
                "blur_score": round(blur_score, 2),
                "message": f"Ảnh quá nhòe hoặc rung lắc (độ nét {blur_score:.1f} < {BLUR_THRESHOLD}). Vui lòng giữ yên điện thoại để nhận diện chính xác.",
            }

        # 2. Trích xuất embedding bằng YOLOv8n + ArcFace
        target_embedding = extract_l2_normalized_embedding(img)
        if target_embedding is None:
            _log_attendance(None, "UNKNOWN", 0.0)
            return {
                "status": "UNKNOWN",
                "confidence_score": 0.0,
                "message": "Không phát hiện khuôn mặt trong khung hình",
            }

        # 3. Kiểm tra danh sách học sinh đã đăng ký (hỗ trợ lọc theo lớp class_id)
        if registered_embeddings is None or len(registered_student_ids) == 0:
            _log_attendance(None, "UNKNOWN", 0.0)
            return {
                "status": "UNKNOWN",
                "confidence_score": 0.0,
                "message": "Chưa có học sinh nào được đăng ký trong hệ thống",
            }

        if class_id:
            allowed_ids = set(_get_student_ids_by_class(class_id))
            class_indices = [i for i, sid in enumerate(registered_student_ids) if sid in allowed_ids]
            if not class_indices:
                _log_attendance(None, "UNKNOWN", 0.0)
                return {
                    "status": "UNKNOWN",
                    "confidence_score": 0.0,
                    "message": "Chưa có học sinh nào trong lớp này được đăng ký trong hệ thống",
                }
            active_embeddings = registered_embeddings[class_indices]
            active_student_ids = [registered_student_ids[i] for i in class_indices]
        else:
            active_embeddings = registered_embeddings
            active_student_ids = registered_student_ids

        # 4. So khớp nhanh Cosine Similarity (np.dot) trong phạm vi lớp
        scores = np.dot(active_embeddings, target_embedding)
        best_idx = int(np.argmax(scores))
        best_score = float(scores[best_idx])
        matched_student_id = active_student_ids[best_idx]

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


@app.post("/api/v1/register-pickup")
async def register_pickup_face(
    photo_url: str = Form(""),
    file: UploadFile = File(..., description="Ảnh chân dung người đón"),
):
    """
    Trích xuất và lưu trước vector ArcFace embedding (512-dim) của phụ huynh/người giám hộ.
    Giúp việc quét mặt khi đón trẻ đạt tốc độ thời gian thực (< 30ms).
    """
    global pickup_face_cache
    img = await read_image_from_upload(file)

    # 1. Kiểm tra ảnh mờ
    is_blurred, blur_score = check_image_blur(img, BLUR_THRESHOLD)
    if is_blurred:
        raise HTTPException(
            status_code=400,
            detail=f"Ảnh quá mờ hoặc rung lắc (độ nét {blur_score:.1f} < {BLUR_THRESHOLD}). Vui lòng chọn ảnh chụp rõ nét hơn."
        )

    # 2. Trích xuất embedding
    embedding = extract_l2_normalized_embedding(img, require_face=True)
    if embedding is None:
        raise HTTPException(status_code=400, detail="Không phát hiện khuôn mặt rõ ràng trong ảnh.")

    # 3. Lưu vào RAM cache và đĩa
    if photo_url:
        pickup_face_cache[photo_url] = embedding
        save_pickup_cache()

    return {
        "status": "SUCCESS",
        "embedding": embedding.tolist(),
        "photo_url": photo_url,
        "message": "Đã trích xuất và nạp cache vector đặc trưng người đón thành công."
    }


@app.post("/api/v1/recognize-pickup")
async def recognize_pickup(
    file: UploadFile = File(..., description="Ảnh chụp khuôn mặt người đến đón"),
    class_id: Optional[str] = Form(None, description="Mã lớp học"),
    candidates_json: str = Form("[]", description="Danh sách JSON các phụ huynh/người đón hợp lệ của lớp"),
):
    """
    Quét mặt phụ huynh đón trẻ: so khớp trực tiếp ảnh chụp với danh sách phụ huynh/người giám hộ có con trong lớp.
    Tối ưu tốc độ cực nhanh (~25-30ms) nhờ ma trận vector dot-product trên cache RAM.
    """
    global pickup_face_cache
    try:
        probe_img = await read_image_from_upload(file)

        # 1. Kiểm tra mờ rung lắc
        is_blurred, blur_score = check_image_blur(probe_img, BLUR_THRESHOLD)
        if is_blurred:
            return {
                "matched": False,
                "status": "BLURRED",
                "similarity": 0.0,
                "message": f"Ảnh quá nhòe hoặc rung lắc ({blur_score:.1f} < {BLUR_THRESHOLD}). Vui lòng giữ yên điện thoại.",
            }

        # 2. Trích xuất embedding người đón (1 lần duy nhất ~20ms)
        probe_emb = extract_l2_normalized_embedding(probe_img, require_face=True)
        if probe_emb is None:
            return {
                "matched": False,
                "status": "NO_FACE",
                "similarity": 0.0,
                "message": "Không tìm thấy khuôn mặt rõ ràng trong khung hình.",
            }

        candidates = json.loads(candidates_json) if candidates_json else []
        if not candidates:
            return {
                "matched": False,
                "status": "NO_CANDIDATES",
                "similarity": 0.0,
                "message": "Lớp học chưa có phụ huynh nào đăng ký nhận diện khuôn mặt.",
            }

        valid_candidates = []
        candidate_embeddings = []
        cache_updated = False

        # 3. Thu thập vector đặc trưng từ candidates (ưu tiên vector truyền sẵn hoặc cache RAM)
        for cand in candidates:
            photo_url = cand.get("photoUrl") or cand.get("photo_url")
            raw_emb = cand.get("faceEmbedding") or cand.get("face_embedding")

            ref_emb = None
            if raw_emb:
                try:
                    if isinstance(raw_emb, str):
                        ref_emb = np.array(json.loads(raw_emb), dtype=np.float32)
                    elif isinstance(raw_emb, list):
                        ref_emb = np.array(raw_emb, dtype=np.float32)
                    if photo_url and photo_url not in pickup_face_cache:
                        pickup_face_cache[photo_url] = ref_emb
                        cache_updated = True
                except Exception:
                    ref_emb = None

            if ref_emb is None and photo_url:
                ref_emb = pickup_face_cache.get(photo_url)

            if ref_emb is None and photo_url:
                try:
                    ref_bytes = None
                    if photo_url.startswith("http"):
                        headers = {'User-Agent': 'KidPro-AI-Engine', 'X-Internal-Service-Key': INTERNAL_SERVICE_KEY}
                        req = urllib.request.Request(photo_url, headers=headers)
                        with urllib.request.urlopen(req, timeout=4) as resp:
                            ref_bytes = resp.read()
                    elif os.path.exists(photo_url.lstrip("/")):
                        with open(photo_url.lstrip("/"), "rb") as f:
                            ref_bytes = f.read()

                    if ref_bytes:
                        nparr = np.frombuffer(ref_bytes, np.uint8)
                        ref_img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
                        if ref_img is not None:
                            ref_emb = extract_l2_normalized_embedding(ref_img)
                            if ref_emb is not None:
                                pickup_face_cache[photo_url] = ref_emb
                                cache_updated = True
                except Exception as ex:
                    print(f"⚠️ Lỗi nạp ảnh phụ huynh {photo_url}: {ex}")

            if ref_emb is not None:
                valid_candidates.append(cand)
                candidate_embeddings.append(ref_emb)

        if cache_updated:
            save_pickup_cache()

        if not candidate_embeddings:
            return {
                "matched": False,
                "status": "NO_EMBEDDINGS",
                "similarity": 0.0,
                "message": "Không thể trích xuất vector khuôn mặt của danh sách phụ huynh trong lớp.",
            }

        # 4. So khớp ma trận Cosine Similarity siêu tốc (np.dot trong < 0.1ms)
        embs_matrix = np.vstack(candidate_embeddings)
        scores = np.dot(embs_matrix, probe_emb)
        best_idx = int(np.argmax(scores))
        best_score = float(scores[best_idx])
        best_candidate = valid_candidates[best_idx]

        matched = best_score >= SIMILARITY_THRESHOLD
        return {
            "matched": matched,
            "similarity": round(best_score, 4),
            "threshold": SIMILARITY_THRESHOLD,
            "best_candidate": best_candidate if matched else None,
            "message": "Khớp phụ huynh thành công" if matched else "Không tìm thấy phụ huynh phù hợp trong lớp",
        }
    except Exception as e:
        print(f"Lỗi recognize-pickup: {e}")
        return {
            "matched": False,
            "similarity": 0.0,
            "error": str(e),
            "message": f"Lỗi xử lý AI: {str(e)}",
        }


@app.post("/api/v1/detect")
async def detect_face(
    file: UploadFile = File(..., description="Ảnh cần kiểm tra có khuôn mặt hay không"),
):
    """Kiểm tra ảnh chân dung người đón có khuôn mặt rõ ràng trước khi lưu làm ảnh tham chiếu."""
    img = await read_image_from_upload(file)
    embedding = extract_l2_normalized_embedding(img, require_face=True)
    return {"face_detected": embedding is not None}


@app.post("/api/v1/compare")
async def compare_faces(
    reference: UploadFile = File(..., description="Ảnh khuôn mặt người đón đã đăng ký"),
    probe: UploadFile = File(..., description="Ảnh giáo viên chụp người đến đón"),
):
    """So khớp 1-1 khuôn mặt người đến đón với ảnh đã đăng ký (BR-022). Ngưỡng do backend quyết định."""
    reference_img = await read_image_from_upload(reference)
    probe_img = await read_image_from_upload(probe)

    probe_emb = extract_l2_normalized_embedding(probe_img, require_face=True)
    if probe_emb is None:
        raise HTTPException(status_code=422, detail="PROBE_NO_FACE")

    # Ảnh tham chiếu đã được kiểm tra lúc đăng ký nên cho phép fallback cắt trung tâm
    reference_emb = extract_l2_normalized_embedding(reference_img)
    if reference_emb is None:
        raise HTTPException(status_code=422, detail="REFERENCE_NO_FACE")

    similarity = float(np.dot(reference_emb, probe_emb))
    return {"similarity": round(similarity, 4)}


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
def _get_student_ids_by_class(class_id: str) -> List[str]:
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT student_id FROM students WHERE class_id = ?", (class_id,))
    rows = cursor.fetchall()
    conn.close()
    return [r[0] for r in rows]


def _get_student(student_id: str) -> Optional[dict]:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("SELECT student_id, name, class_name, class_id FROM students WHERE student_id = ?", (student_id,))
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
