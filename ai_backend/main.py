import asyncio
import io
import json
import os
import pickle
import sqlite3
import threading
import urllib.request
from datetime import datetime
from typing import List, Optional

import cv2
import numpy as np
from contextlib import asynccontextmanager
import hmac
import onnxruntime as ort
from fastapi import FastAPI, File, Form, HTTPException, UploadFile, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from ultralytics import YOLO

# Limit PyTorch CPU threads to avoid CPU oversubscription
TORCH_NUM_THREADS = int(os.getenv("TORCH_NUM_THREADS", "2"))
try:
    import torch
    torch.set_num_threads(TORCH_NUM_THREADS)
except Exception:
    pass

ONNX_INTRA_THREADS = int(os.getenv("ONNX_INTRA_THREADS", "2"))
ONNX_INTER_THREADS = int(os.getenv("ONNX_INTER_THREADS", "1"))

# ==========================================
# CONFIGURATION & INITIALIZATION (WARN-01, WARN-02, WARN-06)
# ==========================================
DB_PATH = os.getenv("DB_PATH", "attendance.db")
EMBEDDINGS_FILE = os.getenv("EMBEDDINGS_FILE", "embeddings.npz")
PICKUP_CACHE_FILE = os.getenv("PICKUP_CACHE_FILE", "pickup_embeddings.pkl")
# SIMILARITY_THRESHOLD removed in OPT-002: Single Source of Truth on Spring Boot
SIMILARITY_THRESHOLD = float(os.getenv("SIMILARITY_THRESHOLD", "0.60"))
PICKUP_FACE_THRESHOLD = float(os.getenv("PICKUP_FACE_THRESHOLD", "0.60"))
BLUR_THRESHOLD = float(os.getenv("BLUR_THRESHOLD", "50.0"))
INTERNAL_SERVICE_KEY = os.getenv("INTERNAL_SERVICE_KEY", "kidpro_internal_secret_key_2026")
YOLO_MODEL_PATH = os.getenv("YOLO_MODEL_PATH", "face_yolov8n.pt")
YOLO_FACE_MODEL_PATH = os.getenv("YOLO_FACE_MODEL_PATH", YOLO_MODEL_PATH)
ARCFACE_MODEL_PATH = os.getenv("ARCFACE_MODEL_PATH", "arcface_w600k_r50.onnx")

# Pipeline and Model Versioning Constants (OPT-001, OPT-007)
PIPELINE_VERSION = "v2_umeyama_align"
MODEL_NAME = "arcface_w600k_r50"
EMBEDDING_DIM = 512

def verify_internal_key(x_internal_service_key: Optional[str] = Header(None, alias="X-Internal-Service-Key")):
    """
    OPT-003: Constant-time authentication for internal server-to-server calls.
    Rejects unauthenticated direct client access.
    """
    if not x_internal_service_key or not hmac.compare_digest(x_internal_service_key, INTERNAL_SERVICE_KEY):
        raise HTTPException(
            status_code=401,
            detail="UNAUTHORIZED: Missing or invalid X-Internal-Service-Key"
        )

try:
    from face_detector import (
        align_face,
        ARCFACE_STANDARD_TEMPLATE_112,
        YOLOFaceDetector,
        BaseFaceDetector,
        estimate_head_yaw,
        MockAntiSpoofDetector,
        BaseAntiSpoofDetector,
        AntiSpoofResult
    )
except (ImportError, ModuleNotFoundError):
    from kidpro_app.ai_backend.face_detector import (
        align_face,
        ARCFACE_STANDARD_TEMPLATE_112,
        YOLOFaceDetector,
        BaseFaceDetector,
        estimate_head_yaw,
        MockAntiSpoofDetector,
        BaseAntiSpoofDetector,
        AntiSpoofResult
    )

ANTI_SPOOF_ENABLED = os.getenv("ANTI_SPOOF_ENABLED", "false").lower() in ("true", "1", "yes")
anti_spoof_detector: BaseAntiSpoofDetector = MockAntiSpoofDetector(passthrough=True)

# Global in-memory cache for fast vector dot-product matching (thread-safe protected)
embeddings_lock = threading.RLock()
pickup_lock = threading.RLock()

registered_embeddings: Optional[np.ndarray] = None
registered_student_ids: List[str] = []
cached_pipeline_version: str = "v1_raw_crop"
pickup_face_cache: dict = {}

def get_embeddings_snapshot():
    with embeddings_lock:
        return registered_embeddings, list(registered_student_ids)

def update_embeddings_atomic(new_embeddings: Optional[np.ndarray], new_student_ids: List[str]):
    global registered_embeddings, registered_student_ids
    with embeddings_lock:
        registered_embeddings = new_embeddings
        registered_student_ids = list(new_student_ids)

def get_pickup_cache_snapshot():
    with pickup_lock:
        return dict(pickup_face_cache)

def update_pickup_cache_atomic(new_cache: dict):
    global pickup_face_cache
    with pickup_lock:
        pickup_face_cache = dict(new_cache)

def save_embeddings_to_npz(path: str, embeddings: np.ndarray, student_ids: List[str], metadata: dict):
    tmp_path = f"{path}.tmp.npz"
    meta_json = json.dumps(metadata)
    np.savez(
        tmp_path,
        embeddings=embeddings.astype(np.float32),
        student_ids=np.array([str(s) for s in student_ids], dtype=str),
        metadata=np.array([meta_json], dtype=str)
    )
    if os.path.exists(path):
        try:
            os.replace(tmp_path, path)
        except Exception:
            try:
                os.remove(path)
            except Exception:
                pass
            os.rename(tmp_path, path)
    else:
        os.rename(tmp_path, path)

def load_embeddings_from_file(path: str):
    # Try .npz first
    npz_candidates = [path] if path.endswith(".npz") else [f"{os.path.splitext(path)[0]}.npz", path]
    for npz_path in npz_candidates:
        if os.path.exists(npz_path) and not npz_path.endswith(".pkl"):
            try:
                with np.load(npz_path, allow_pickle=False) as data:
                    embeddings = data["embeddings"]
                    student_ids = [str(s) for s in data["student_ids"]]
                    meta_raw = data.get("metadata")
                    if meta_raw is not None and len(meta_raw) > 0:
                        metadata = json.loads(str(meta_raw[0]))
                    else:
                        metadata = {}
                    return embeddings, student_ids, metadata
            except Exception as e:
                print(f"⚠️ Error reading npz vector store {npz_path}: {e}")

    # Fallback to legacy .pkl
    pkl_candidates = [path] if path.endswith(".pkl") else [f"{os.path.splitext(path)[0]}.pkl", "embeddings.pkl"]
    for pkl_path in pkl_candidates:
        if os.path.exists(pkl_path):
            try:
                with open(pkl_path, "rb") as f:
                    data = pickle.load(f)
                    embeddings = data.get("embeddings")
                    student_ids = list(data.get("student_ids", []))
                    metadata = {
                        "model_name": MODEL_NAME,
                        "pipeline_version": "v1_raw_crop",
                        "dim": EMBEDDING_DIM,
                        "created_at": "legacy_pickle"
                    }
                    print(f"⚠️ Đã nạp kho vector cũ (Pickle) từ {pkl_path}: gán mặc định pipeline_version='v1_raw_crop'")
                    return embeddings, student_ids, metadata
            except Exception as e:
                print(f"⚠️ Error reading legacy pickle file {pkl_path}: {e}")

    return None, [], {}

# Model references initialized via FastAPI lifespan (WARN-01)
yolo_detector = None
face_detector: Optional[BaseFaceDetector] = None
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
    global yolo_detector, face_detector, arcface_session, arcface_input_name, arcface_output_name
    print("🚀 [Lifespan] Khởi tạo AI Engine và nạp weights mô hình...")
    init_db()
    load_embeddings_cache()
    load_pickup_cache()

    # 1. Load YOLOv8-Face detector (OPT-001)
    model_path_to_use = YOLO_FACE_MODEL_PATH if os.path.exists(YOLO_FACE_MODEL_PATH) else YOLO_MODEL_PATH
    ensure_model_file(
        model_path_to_use,
        "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8n.pt"
    )
    print(f"🔄 Đang nạp mô hình YOLOv8-Face detector từ {model_path_to_use}...")
    yolo_detector = YOLO(model_path_to_use)
    face_detector = YOLOFaceDetector(
        yolo_detector,
        simulate_landmarks_if_missing=bool(os.getenv("SIMULATE_LANDMARKS_IF_MISSING", "true").lower() in ("true", "1"))
    )
    app.state.yolo_detector = yolo_detector
    app.state.face_detector = face_detector
    print("✅ YOLOv8-Face detector đã sẵn sàng!")

    # 2. Load ArcFace ONNX feature extractor
    ensure_model_file(
        ARCFACE_MODEL_PATH,
        "https://huggingface.co/maze/faceX/resolve/main/w600k_r50.onnx",
        fallback_path=os.path.expanduser("~/.insightface/models/buffalo_l/w600k_r50.onnx")
    )
    print(f"🔄 Đang nạp ArcFace ONNX feature extractor từ {ARCFACE_MODEL_PATH} (intra_threads={ONNX_INTRA_THREADS}, inter_threads={ONNX_INTER_THREADS})...")
    sess_options = ort.SessionOptions()
    sess_options.intra_op_num_threads = ONNX_INTRA_THREADS
    sess_options.inter_op_num_threads = ONNX_INTER_THREADS
    arcface_session = ort.InferenceSession(ARCFACE_MODEL_PATH, sess_options=sess_options, providers=["CPUExecutionProvider"])
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
    global cached_pipeline_version
    emb, ids, meta = load_embeddings_from_file(EMBEDDINGS_FILE)
    cached_pipeline_version = meta.get("pipeline_version", "v1_raw_crop")
    update_embeddings_atomic(emb, ids)
    if emb is not None and len(ids) > 0:
        if cached_pipeline_version != PIPELINE_VERSION:
            print(f"⚠️ CẢNH BÁO OPT-007: Kho vector đang ở phiên bản '{cached_pipeline_version}', khác với pipeline hiện tại '{PIPELINE_VERSION}'!")
        else:
            print(f"📦 Đã nạp {len(ids)} vector khuôn mặt chuẩn '{cached_pipeline_version}'")
    else:
        print(f"📦 Kho vector rỗng. Sẵn sàng nhận đăng ký phiên bản '{PIPELINE_VERSION}'")


def save_embeddings_cache():
    global cached_pipeline_version
    snap_embeddings, snap_student_ids = get_embeddings_snapshot()
    if snap_embeddings is not None and len(snap_student_ids) > 0:
        meta = {
            "model_name": MODEL_NAME,
            "pipeline_version": PIPELINE_VERSION,
            "dim": EMBEDDING_DIM,
            "created_at": datetime.now().isoformat()
        }
        npz_path = EMBEDDINGS_FILE if EMBEDDINGS_FILE.endswith(".npz") else f"{os.path.splitext(EMBEDDINGS_FILE)[0]}.npz"
        save_embeddings_to_npz(npz_path, snap_embeddings, snap_student_ids, meta)
        cached_pipeline_version = PIPELINE_VERSION


def load_pickup_cache():
    if os.path.exists(PICKUP_CACHE_FILE):
        try:
            with open(PICKUP_CACHE_FILE, "rb") as f:
                new_cache = pickle.load(f)
                update_pickup_cache_atomic(new_cache)
                print(f"📦 Đã nạp {len(new_cache)} vector khuôn mặt người đón từ cache {PICKUP_CACHE_FILE}")
        except Exception as e:
            print(f"⚠️ Không thể đọc cache người đón: {e}")
            update_pickup_cache_atomic({})
    else:
        update_pickup_cache_atomic({})


def save_pickup_cache():
    snap_cache = get_pickup_cache_snapshot()
    try:
        with open(PICKUP_CACHE_FILE, "wb") as f:
            pickle.dump(snap_cache, f)
    except Exception as e:
        print(f"⚠️ Không thể ghi cache người đón: {e}")


# ==========================================
# FACE EXTRACTION PIPELINE (YOLOv8 + ArcFace)
# ==========================================
def decode_image_bytes(contents: bytes) -> np.ndarray:
    nparr = np.frombuffer(contents, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(status_code=400, detail="Không thể giải mã tệp ảnh.")
    return img


async def read_image_from_upload(upload_file: UploadFile) -> np.ndarray:
    contents = await upload_file.read()
    return await asyncio.to_thread(decode_image_bytes, contents)


def extract_l2_normalized_embedding(img: np.ndarray, require_face: bool = False) -> Optional[np.ndarray]:
    """
    OPT-001: Pipeline Umeyama 5-Landmark Alignment + ArcFace ONNX (512-dim) + TTA.
    Căn chỉnh khuôn mặt bằng Umeyama Similarity Transform dựa trên 5 điểm mốc
    (mắt trái, mắt phải, mũi, khóe miệng trái, khóe miệng phải) về template ArcFace 112x112 chuẩn.
    Nếu không phát hiện được khuôn mặt hoặc thiếu landmark, trả về None (không fallback crop thô).
    """
    if img is None or img.size == 0:
        return None

    global face_detector, arcface_session, arcface_input_name, arcface_output_name
    if face_detector is None:
        # Fallback if accessed before lifespan
        if yolo_detector is not None:
            face_detector = YOLOFaceDetector(yolo_detector, simulate_landmarks_if_missing=True)
        else:
            return None

    # 1. Phát hiện khuôn mặt lớn nhất & trích xuất 5 landmarks
    det = face_detector.detect(img, conf=0.35)
    if det is None or det.landmarks is None:
        return None

    # 2. Căn chỉnh afin tương đồng Umeyama về chuẩn ArcFace 112x112
    try:
        face_aligned = align_face(img, det.landmarks, size=112)
    except Exception as e:
        print(f"⚠️ Umeyama alignment error: {e}")
        return None

    # 3. Tiền xử lý ArcFace chuẩn (BGR -> RGB -> normalize [-1, 1] -> NCHW)
    face_rgb = cv2.cvtColor(face_aligned, cv2.COLOR_BGR2RGB)
    face_norm = (face_rgb.astype(np.float32) - 127.5) / 128.0
    face_blob = np.transpose(face_norm, (2, 0, 1))
    face_blob = np.expand_dims(face_blob, axis=0)

    # 4. Trích xuất đặc trưng ảnh gốc
    raw_emb1 = arcface_session.run([arcface_output_name], {arcface_input_name: face_blob})[0][0]

    # 5. Kỹ thuật TTA (Test-Time Augmentation): trích xuất thêm ảnh lật ngang
    face_flip = cv2.flip(face_rgb, 1)
    face_flip_norm = (face_flip.astype(np.float32) - 127.5) / 128.0
    face_flip_blob = np.transpose(face_flip_norm, (2, 0, 1))
    face_flip_blob = np.expand_dims(face_flip_blob, axis=0)
    raw_emb2 = arcface_session.run([arcface_output_name], {arcface_input_name: face_flip_blob})[0][0]

    # 6. Kết hợp 2 vector và chuẩn hóa L2
    combined_emb = raw_emb1 + raw_emb2
    norm = np.linalg.norm(combined_emb)
    if norm > 0:
        combined_emb = combined_emb / norm

    return combined_emb


# ==========================================
# API ENDPOINTS
# ==========================================
@app.get("/health")
@app.get("/")
def root():
    snap_emb, snap_ids = get_embeddings_snapshot()
    version_matched = (cached_pipeline_version == PIPELINE_VERSION) if (snap_emb is not None and len(snap_ids) > 0) else True
    return {
        "service": "KidPro Face Attendance AI",
        "status": "ONLINE" if version_matched else "DEGRADED_VERSION_MISMATCH",
        "pipeline_version": PIPELINE_VERSION,
        "cached_pipeline_version": cached_pipeline_version,
        "version_matched": version_matched,
        "model_name": MODEL_NAME,
        "registered_students_count": len(snap_ids),
        "feature_extractor_mode": True,
        "network": "Internal server-to-server ready",
    }


@app.post("/api/v1/register")
async def register_student(
    student_id: str = Form(..., description="Mã số học sinh"),
    name: str = Form(..., description="Họ và tên học sinh"),
    class_name: str = Form(..., description="Tên lớp học"),
    class_id: Optional[str] = Form(None, description="Mã ID lớp học"),
    file: UploadFile = File(..., description="Ảnh chân dung học sinh"),
):
    contents = await file.read()
    embedding, blur_score, err = await asyncio.to_thread(
        _sync_extract_and_blur_check, contents, BLUR_THRESHOLD, False
    )
    if err == "DECODE_ERROR":
        raise HTTPException(status_code=400, detail="Không thể giải mã tệp ảnh.")
    elif err == "BLURRED":
        raise HTTPException(
            status_code=400,
            detail=f"Ảnh chân dung quá mờ hoặc rung lắc (độ nét {blur_score:.1f} < {BLUR_THRESHOLD}). Vui lòng chọn ảnh chụp rõ nét hơn."
        )
    elif err == "NO_FACE":
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

    # 3. Cập nhật Vector Cache trong RAM nguyên tử
    with embeddings_lock:
        snap_emb, snap_ids = get_embeddings_snapshot()
        if len(snap_ids) > 0 and cached_pipeline_version != PIPELINE_VERSION:
            raise HTTPException(
                status_code=409,
                detail=f"EMBEDDING_VERSION_MISMATCH: Kho vector đang ở phiên bản '{cached_pipeline_version}'. Không thể đăng ký mới khi chưa recalculate sang '{PIPELINE_VERSION}'."
            )
        if student_id in snap_ids:
            idx = snap_ids.index(student_id)
            new_emb = snap_emb.copy()
            new_emb[idx] = embedding
            new_ids = list(snap_ids)
        else:
            new_ids = list(snap_ids) + [student_id]
            if snap_emb is None or len(snap_emb) == 0:
                new_emb = np.expand_dims(embedding, axis=0)
            else:
                new_emb = np.vstack([snap_emb, embedding])
        update_embeddings_atomic(new_emb, new_ids)

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
                img_req = urllib.request.Request(
                    full_img_url,
                    headers={'User-Agent': 'KidPro-AI-Engine', 'X-Internal-Service-Key': INTERNAL_SERVICE_KEY}
                )
                with urllib.request.urlopen(img_req, timeout=5) as img_resp:
                    img_bytes = img_resp.read()
                nparr = np.frombuffer(img_bytes, np.uint8)
                img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
                if img is None:
                    continue
                emb = extract_l2_normalized_embedding(img)
                if emb is None:
                    continue

                with embeddings_lock:
                    snap_emb, snap_ids = get_embeddings_snapshot()
                    if sid in snap_ids:
                        idx = snap_ids.index(sid)
                        new_emb = snap_emb.copy()
                        new_emb[idx] = emb
                        new_ids = list(snap_ids)
                    else:
                        new_ids = list(snap_ids) + [sid]
                        if snap_emb is None or len(snap_emb) == 0:
                            new_emb = np.expand_dims(emb, axis=0)
                        else:
                            new_emb = np.vstack([snap_emb, emb])
                    update_embeddings_atomic(new_emb, new_ids)

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
        _, snap_ids = get_embeddings_snapshot()
        return {
            "success": True,
            "synced_count": synced_count,
            "total_registered": len(snap_ids),
        }
    except Exception as e:
        return {"success": False, "error": str(e)}


def _sync_extract_and_blur_check(img_bytes: bytes, threshold: float, require_face: bool = False):
    nparr = np.frombuffer(img_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        return None, 0.0, "DECODE_ERROR"
    is_blurred, blur_score = check_image_blur(img, threshold)
    if is_blurred:
        return None, blur_score, "BLURRED"
    emb = extract_l2_normalized_embedding(img, require_face=require_face)
    if emb is None:
        return None, blur_score, "NO_FACE"
    return emb, blur_score, None


def _sync_estimate_yaw(img_bytes: bytes):
    nparr = np.frombuffer(img_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        return {"face_found": False, "error_code": "DECODE_ERROR", "yaw_estimate": 0.0}
    global face_detector
    if face_detector is None and yolo_detector is not None:
        face_detector = YOLOFaceDetector(yolo_detector, simulate_landmarks_if_missing=True)
    det = face_detector.detect(img, conf=0.25) if face_detector else None
    if det is None or det.landmarks is None:
        return {"face_found": False, "error_code": "NO_FACE", "yaw_estimate": 0.0}
    yaw = estimate_head_yaw(det.landmarks)
    return {"face_found": True, "yaw_estimate": round(yaw, 2)}


def _sync_check_in(
    img_bytes: bytes,
    class_id: Optional[str] = None,
    turn_bytes: Optional[bytes] = None,
    expected_action: Optional[str] = None
):
    """
    OPT-003 & OPT-002 & OPT-004:
    FastAPI acts strictly as a feature extractor and returns:
    - face_found: bool
    - top1_student_id, top1_score
    - top2_student_id, top2_score
    - margin (top1_score - top2_score)
    - pipeline_version, model_name
    - blur_score
    - turn_yaw_estimate, intra_similarity, turn_valid (if turn_bytes provided)
    Does NOT make PRESENT / UNKNOWN decisions (Single Source of Truth on Spring Boot).
    """
    nparr = np.frombuffer(img_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        return {
            "face_found": False,
            "error_code": "DECODE_ERROR",
            "message": "Không thể giải mã tệp ảnh.",
        }

    # 1. Kiểm tra ảnh mờ / rung lắc (WARN-02)
    is_blurred, blur_score = check_image_blur(img, BLUR_THRESHOLD)
    if is_blurred:
        return {
            "face_found": False,
            "error_code": "BLURRED",
            "blur_score": round(blur_score, 2),
            "message": f"Ảnh quá nhòe hoặc rung lắc (độ nét {blur_score:.1f} < {BLUR_THRESHOLD}). Vui lòng giữ yên điện thoại để nhận diện chính xác.",
        }

    # 2. Anti-spoofing check interface (OPT-004)
    if ANTI_SPOOF_ENABLED:
        spoof_res = anti_spoof_detector.check_spoof(img)
        if not spoof_res.is_real:
            return {
                "face_found": False,
                "error_code": "SPOOF_DETECTED",
                "message": "Phát hiện giả mạo khuôn mặt (ảnh in hoặc màn hình phát lại).",
                "spoof_score": round(spoof_res.score, 4),
            }

    # 3. Trích xuất embedding bằng YOLOv8-Face (5 keypoints) + Umeyama + ArcFace
    target_embedding = extract_l2_normalized_embedding(img)
    if target_embedding is None:
        return {
            "face_found": False,
            "error_code": "NO_FACE",
            "message": "Không phát hiện khuôn mặt trong khung hình",
            "blur_score": round(blur_score, 2),
        }

    # Guard lúc chạy OPT-007: Từ chối so khớp chéo phiên bản
    if cached_pipeline_version != PIPELINE_VERSION:
        print(f"🛑 [OPT-007] Từ chối so khớp chéo phiên bản: cached='{cached_pipeline_version}', current='{PIPELINE_VERSION}'")
        return {
            "face_found": False,
            "error_code": "EMBEDDING_VERSION_MISMATCH",
            "message": f"EMBEDDING_VERSION_MISMATCH: Kho vector phiên bản '{cached_pipeline_version}' không tương thích với pipeline '{PIPELINE_VERSION}'. Vui lòng chạy recalculate_embeddings.py.",
            "pipeline_version": PIPELINE_VERSION,
            "cached_pipeline_version": cached_pipeline_version,
        }

    # 4. Optional Turn Verification (OPT-004: Server-Challenged Liveness)
    turn_valid = None
    turn_yaw_estimate = None
    intra_similarity = None

    if turn_bytes is not None and len(turn_bytes) > 0:
        turn_nparr = np.frombuffer(turn_bytes, np.uint8)
        turn_img = cv2.imdecode(turn_nparr, cv2.IMREAD_COLOR)
        if turn_img is None:
            return {
                "face_found": False,
                "error_code": "TURN_DECODE_ERROR",
                "message": "Không thể giải mã ảnh quay đầu cho thử thách liveness.",
            }

        global face_detector
        if face_detector is None and yolo_detector is not None:
            face_detector = YOLOFaceDetector(yolo_detector, simulate_landmarks_if_missing=True)

        turn_det = face_detector.detect(turn_img, conf=0.25) if face_detector else None
        if turn_det is None or turn_det.landmarks is None:
            return {
                "face_found": False,
                "error_code": "TURN_NO_FACE",
                "message": "Không phát hiện khuôn mặt trong ảnh quay đầu.",
            }

        turn_yaw_estimate = round(estimate_head_yaw(turn_det.landmarks), 2)
        turn_embedding = extract_l2_normalized_embedding(turn_img)
        if turn_embedding is not None:
            intra_similarity = round(float(np.dot(target_embedding, turn_embedding)), 4)
            # Two photos must belong to the same person (relaxed cosine threshold >= 0.65 due to pose variation)
            if intra_similarity < 0.65:
                return {
                    "face_found": True,
                    "error_code": "INTRA_IDENTITY_MISMATCH",
                    "intra_similarity": intra_similarity,
                    "message": f"Ảnh chính diện và ảnh quay đầu không cùng một người (độ khớp {intra_similarity:.2f} < 0.65).",
                }

        # Check turn direction if expected_action is provided
        if expected_action in ("TURN_LEFT", "TURN_RIGHT"):
            turn_valid = abs(turn_yaw_estimate) >= 7.0
        else:
            turn_valid = True

    # 5. Lấy snapshot an toàn luồng của danh sách học sinh
    active_embeddings, active_student_ids = get_embeddings_snapshot()
    if active_embeddings is None or len(active_student_ids) == 0:
        return {
            "face_found": True,
            "top1_student_id": None,
            "top1_score": 0.0,
            "top2_student_id": None,
            "top2_score": 0.0,
            "margin": 0.0,
            "pipeline_version": PIPELINE_VERSION,
            "model_name": MODEL_NAME,
            "blur_score": round(blur_score, 2),
            "message": "Chưa có học sinh nào được đăng ký trong hệ thống",
        }

    if class_id:
        allowed_ids = set(_get_student_ids_by_class(class_id))
        class_indices = [i for i, sid in enumerate(active_student_ids) if sid in allowed_ids]
        if not class_indices:
            return {
                "face_found": True,
                "top1_student_id": None,
                "top1_score": 0.0,
                "top2_student_id": None,
                "top2_score": 0.0,
                "margin": 0.0,
                "pipeline_version": PIPELINE_VERSION,
                "model_name": MODEL_NAME,
                "blur_score": round(blur_score, 2),
                "message": "Chưa có học sinh nào trong lớp này được đăng ký trong hệ thống",
            }
        active_embeddings = active_embeddings[class_indices]
        active_student_ids = [active_student_ids[i] for i in class_indices]

    # 6. Tính Cosine Similarity & Nhóm điểm cao nhất theo từng học sinh riêng biệt
    scores = np.dot(active_embeddings, target_embedding)
    student_max_scores = {}
    for sid, score in zip(active_student_ids, scores):
        s_val = float(score)
        if sid not in student_max_scores or s_val > student_max_scores[sid]:
            student_max_scores[sid] = s_val

    # Sắp xếp các học sinh khác nhau theo điểm giảm dần
    sorted_candidates = sorted(student_max_scores.items(), key=lambda x: x[1], reverse=True)
    top1_id, top1_score = sorted_candidates[0] if len(sorted_candidates) > 0 else (None, 0.0)
    top2_id, top2_score = sorted_candidates[1] if len(sorted_candidates) > 1 else (None, 0.0)
    margin = top1_score - top2_score

    res = {
        "face_found": True,
        "top1_student_id": top1_id,
        "top1_score": round(float(top1_score), 4),
        "top2_student_id": top2_id,
        "top2_score": round(float(top2_score), 4),
        "margin": round(float(margin), 4),
        "pipeline_version": PIPELINE_VERSION,
        "model_name": MODEL_NAME,
        "blur_score": round(blur_score, 2),
    }
    if turn_bytes is not None:
        res["turn_valid"] = turn_valid
        res["turn_yaw_estimate"] = turn_yaw_estimate
        res["intra_similarity"] = intra_similarity

    return res


@app.post("/api/v1/check-in", dependencies=[Depends(verify_internal_key)])
async def check_in_face(
    file: UploadFile = File(..., description="Ảnh chụp khuôn mặt chính diện từ camera"),
    turn_file: Optional[UploadFile] = File(None, description="Ảnh quay đầu cho liveness challenge"),
    class_id: Optional[str] = Form(None, description="Chỉ đối chiếu học sinh thuộc lớp này"),
    expected_action: Optional[str] = Form(None, description="Hướng quay yêu cầu TURN_LEFT hoặc TURN_RIGHT"),
):
    try:
        img_bytes = await file.read()
        turn_bytes = await turn_file.read() if turn_file is not None else None
        return await asyncio.to_thread(_sync_check_in, img_bytes, class_id, turn_bytes, expected_action)
    except Exception as e:
        print(f"Lỗi xử lý check-in: {e}")
        return {
            "face_found": False,
            "error_code": "INTERNAL_ERROR",
            "message": f"Lỗi xử lý AI: {str(e)}",
        }


@app.post("/api/v1/estimate-yaw", dependencies=[Depends(verify_internal_key)])
async def estimate_yaw_endpoint(
    file: UploadFile = File(..., description="Ảnh kiểm tra góc quay khuôn mặt"),
):
    try:
        img_bytes = await file.read()
        return await asyncio.to_thread(_sync_estimate_yaw, img_bytes)
    except Exception as e:
        return {
            "face_found": False,
            "error_code": "INTERNAL_ERROR",
            "message": f"Lỗi ước lượng góc quay: {str(e)}",
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
    contents = await file.read()
    embedding, blur_score, err = await asyncio.to_thread(
        _sync_extract_and_blur_check, contents, BLUR_THRESHOLD, True
    )
    if err == "DECODE_ERROR":
        raise HTTPException(status_code=400, detail="Không thể giải mã tệp ảnh.")
    elif err == "BLURRED":
        raise HTTPException(
            status_code=400,
            detail=f"Ảnh quá mờ hoặc rung lắc (độ nét {blur_score:.1f} < {BLUR_THRESHOLD}). Vui lòng chọn ảnh chụp rõ nét hơn."
        )
    elif err == "NO_FACE":
        raise HTTPException(status_code=400, detail="Không phát hiện khuôn mặt rõ ràng trong ảnh.")

    # 3. Lưu vào RAM cache và đĩa
    if photo_url:
        with pickup_lock:
            snap_pickup = get_pickup_cache_snapshot()
            snap_pickup[photo_url] = embedding
            update_pickup_cache_atomic(snap_pickup)
        save_pickup_cache()

    return {
        "status": "SUCCESS",
        "embedding": embedding.tolist(),
        "photo_url": photo_url,
        "message": "Đã trích xuất và nạp cache vector đặc trưng người đón thành công."
    }


def _sync_recognize_pickup(img_bytes: bytes, class_id: Optional[str], candidates_json: str):
    nparr = np.frombuffer(img_bytes, np.uint8)
    probe_img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if probe_img is None:
        return {
            "matched": False,
            "status": "ERROR",
            "similarity": 0.0,
            "message": "Không thể giải mã tệp ảnh.",
        }

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
    pickup_snap = get_pickup_cache_snapshot()

    # 3. Thu thập vector đặc trưng từ candidates
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
                if photo_url and photo_url not in pickup_snap:
                    pickup_snap[photo_url] = ref_emb
                    cache_updated = True
            except Exception:
                ref_emb = None

        if ref_emb is None and photo_url:
            ref_emb = pickup_snap.get(photo_url)

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
                    nparr_ref = np.frombuffer(ref_bytes, np.uint8)
                    ref_img = cv2.imdecode(nparr_ref, cv2.IMREAD_COLOR)
                    if ref_img is not None:
                        ref_emb = extract_l2_normalized_embedding(ref_img)
                        if ref_emb is not None:
                            pickup_snap[photo_url] = ref_emb
                            cache_updated = True
            except Exception as ex:
                print(f"⚠️ Lỗi nạp ảnh phụ huynh {photo_url}: {ex}")

        if ref_emb is not None:
            valid_candidates.append(cand)
            candidate_embeddings.append(ref_emb)

    if cache_updated:
        update_pickup_cache_atomic(pickup_snap)
        save_pickup_cache()

    if not candidate_embeddings:
        return {
            "matched": False,
            "status": "NO_EMBEDDINGS",
            "similarity": 0.0,
            "message": "Không thể trích xuất vector khuôn mặt của danh sách phụ huynh trong lớp.",
        }

    # 4. So khớp ma trận Cosine Similarity
    embs_matrix = np.vstack(candidate_embeddings)
    scores = np.dot(embs_matrix, probe_emb)
    best_idx = int(np.argmax(scores))
    best_score = float(scores[best_idx])
    best_candidate = valid_candidates[best_idx]

    matched = best_score >= PICKUP_FACE_THRESHOLD
    return {
        "matched": matched,
        "similarity": round(best_score, 4),
        "threshold": PICKUP_FACE_THRESHOLD,
        "best_candidate": best_candidate if matched else None,
        "message": "Khớp phụ huynh thành công" if matched else "Không tìm thấy phụ huynh phù hợp trong lớp",
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
    try:
        contents = await file.read()
        return await asyncio.to_thread(_sync_recognize_pickup, contents, class_id, candidates_json)
    except Exception as e:
        print(f"Lỗi recognize-pickup: {e}")
        return {
            "matched": False,
            "similarity": 0.0,
            "error": str(e),
            "message": f"Lỗi xử lý AI: {str(e)}",
        }


def _sync_detect_face(img_bytes: bytes):
    nparr = np.frombuffer(img_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(status_code=400, detail="Không thể giải mã tệp ảnh.")
    embedding = extract_l2_normalized_embedding(img, require_face=True)
    return {"face_detected": embedding is not None}


@app.post("/api/v1/detect")
async def detect_face(
    file: UploadFile = File(..., description="Ảnh cần kiểm tra có khuôn mặt hay không"),
):
    """Kiểm tra ảnh chân dung người đón có khuôn mặt rõ ràng trước khi lưu làm ảnh tham chiếu."""
    contents = await file.read()
    return await asyncio.to_thread(_sync_detect_face, contents)


def _sync_compare_faces(ref_bytes: bytes, probe_bytes: bytes):
    nparr_ref = np.frombuffer(ref_bytes, np.uint8)
    nparr_probe = np.frombuffer(probe_bytes, np.uint8)
    reference_img = cv2.imdecode(nparr_ref, cv2.IMREAD_COLOR)
    probe_img = cv2.imdecode(nparr_probe, cv2.IMREAD_COLOR)

    if reference_img is None or probe_img is None:
        raise HTTPException(status_code=400, detail="Không thể giải mã tệp ảnh.")

    probe_emb = extract_l2_normalized_embedding(probe_img, require_face=True)
    if probe_emb is None:
        raise HTTPException(status_code=422, detail="PROBE_NO_FACE")

    reference_emb = extract_l2_normalized_embedding(reference_img)
    if reference_emb is None:
        raise HTTPException(status_code=422, detail="REFERENCE_NO_FACE")

    similarity = float(np.dot(reference_emb, probe_emb))
    return {"similarity": round(similarity, 4)}


@app.post("/api/v1/compare")
async def compare_faces(
    reference: UploadFile = File(..., description="Ảnh khuôn mặt người đón đã đăng ký"),
    probe: UploadFile = File(..., description="Ảnh giáo viên chụp người đến đón"),
):
    """So khớp 1-1 khuôn mặt người đến đón với ảnh đã đăng ký (BR-022). Ngưỡng do backend quyết định."""
    ref_bytes = await reference.read()
    probe_bytes = await probe.read()
    return await asyncio.to_thread(_sync_compare_faces, ref_bytes, probe_bytes)


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
