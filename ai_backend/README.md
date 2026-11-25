# HƯỚNG DẪN CHẠY DEMO ĐIỂM DANH KHUÔN MẶT AI (KIDPRO POC)

Hệ thống gồm các thành phần:
1. **Spring Boot Backend**: Nhận request từ app và gọi AI qua mạng nội bộ.
2. **AI Backend Server (Python FastAPI + YOLOv8 + ArcFace)**: Chỉ xử lý nhận diện, không mở public port trong production.
3. **Mobile Client (Flutter / Android CameraX)**: Kết nối tới Spring Boot Backend.

---

## BƯỚC 1: KHỞI ĐỘNG AI BACKEND TRÊN LAPTOP

### 1. Cài đặt môi trường Python
Mở Terminal hoặc PowerShell tại thư mục `D:\kidpro_dt\ai_backend`:

```bash
cd D:\kidpro_dt\ai_backend

# 1. Tạo môi trường ảo Python (khuyên dùng Python 3.10 hoặc 3.11)
python -m venv venv

# Kích hoạt venv (trên Windows PowerShell):
.\venv\Scripts\Activate.ps1
# (hoặc trên Git Bash / CMD: source venv/Scripts/activate)

# 2. Cài đặt các thư viện cần thiết
pip install -r requirements.txt
```

### 2. Khởi chạy Server FastAPI
Khi chạy AI độc lập để phát triển, đặt `VECTOR_STORE_MODE=file` và cấu hình `INTERNAL_SERVICE_KEY` trước khi khởi động; khóa phải trùng với Spring Boot nếu backend gọi AI.

```bash
python main.py
# Hoặc chạy trực tiếp với uvicorn:
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```
`--host 0.0.0.0` chỉ dùng cho môi trường phát triển được kiểm soát. Trong production, không publish AI port `8000`; chỉ Spring Boot gọi dịch vụ AI qua Docker network nội bộ.

Lần đầu chạy, InsightFace sẽ tự động tải model `buffalo_sc` (~150MB) từ CDN về thư mục `~/.insightface/models/`.

### 3. Kiểm tra Server hoạt động
- Mở trình duyệt trên Laptop truy cập: [http://localhost:8000/docs](http://localhost:8000/docs) (Swagger UI)
- Swagger chỉ để kiểm tra tài liệu/health. API đăng ký yêu cầu header nội bộ; đăng ký thật qua Spring Boot, không gửi khóa vào trình duyệt.

---

## BƯỚC 2: TÌM ĐỊA CHỈ IP LAN CỦA LAPTOP

Để điện thoại kết nối được với Laptop, cả 2 thiết bị cần **kết nối chung một mạng Wi-Fi**:

1. Trên Laptop, mở PowerShell/CMD gõ:
   ```cmd
   ipconfig
   ```
2. Tìm dòng `IPv4 Address` của mạng Wi-Fi đang dùng, ví dụ:
   ```text
   IPv4 Address. . . . . . . . . . . : 192.168.1.15
   ```
3. Với app, Base URL là địa chỉ Spring Boot Backend, ví dụ:
   `http://192.168.1.15:8080`

FastAPI port `8000` chỉ dùng nội bộ giữa backend và AI; không mở cổng này ra Internet hoặc cho điện thoại truy cập trực tiếp.

---

## BƯỚC 3: ĐĂNG KÝ KHUÔN MẶT HỌC SINH MẪU

`/api/v1/register` là API nội bộ, yêu cầu header `X-Internal-Service-Key`. Khi deploy production, đăng ký khuôn mặt từ app qua Spring Boot; không mở cổng AI ra Internet hoặc nhập khóa nội bộ vào trình duyệt.

Các hướng dẫn đăng ký trực tiếp bằng Web Demo, Swagger hoặc script là tài liệu PoC cũ; các công cụ đó không tự gửi header nội bộ. Dùng luồng đăng ký của app qua Spring Boot.

---

## BƯỚC 4: CHẠY MOBILE CLIENT TRÊN ĐIỆN THOẠI ANDROID

### Lựa chọn 1: Dùng Flutter App (`kidpro_mobile`)
1. Cấu hình URL Spring Boot Backend (không phải AI port `8000`), ví dụ `http://192.168.1.15:8080`.
   - Nếu AI chạy nội bộ trên EC2 qua Docker, dùng URL công khai của Spring Boot Backend ở cổng `8080`; backend gọi AI trên Docker network riêng.
   - Có thể cấu hình khi build bằng `--dart-define=BASE_URL=http://YOUR_EC2_PUBLIC_IP:8080`.
2. Chạy ứng dụng Flutter:
   ```bash
   cd D:\kidpro_dt\kidpro_mobile
   flutter run
   ```
3. Đăng nhập tài khoản Giáo viên -> Vào mục **"Điểm danh sáng"** -> Bấm icon **Camera AI** góc trên -> Khung quét nhận diện khuôn mặt xuất hiện.
4. Hướng camera vào khuôn mặt học sinh đã đăng ký và bấm nút **"Chụp & Điểm danh khuôn mặt"**:
   - Nếu đúng học sinh: Viền đổi sang **Xanh lá**, hiển thị Card thông tin họ tên, lớp, độ khớp (ví dụ: `87.5%`).
   - Nếu người lạ / chưa đăng ký: Viền đổi sang **Đỏ chớp nháy cảnh báo**, hiển thị nút **"Thử lại"** và **"Điểm danh thủ công (Manual Fallback)"**.

### Lựa chọn 2: Dùng Native Android Project (`android_client_demo`)
- Mở thư mục `android_client_demo` bằng Android Studio.
- Nhấn Run lên thiết bị Android hoặc Emulator.
- Bấm nút **"IP Server"** ở góc phải trên để nhập IP Laptop `http://192.168.1.15:8000/`.
- CameraX tự động stream 720p, nén JPEG 80% (640px) và gọi Retrofit nhận kết quả dưới 150ms.

---

## Lưu vector khuôn mặt khi deploy production

Production dùng `VECTOR_STORE_MODE=database` (mặc định). Spring Boot là nơi lưu vector chính trong PostgreSQL tại `student.face_encoding_file.face_embedding` (`vector(512)`). AI chỉ nạp vector vào RAM để nhận diện; chế độ này không đọc hoặc ghi các file vector cache `embeddings.npz` và `pickup_embeddings.pkl`.

Đặt `BACKEND_URL` trỏ tới Spring Boot trên Docker network, ví dụ `http://kidpro-be:8080`. Bắt buộc cấu hình `INTERNAL_SERVICE_KEY` cho AI và cùng giá trị đó trong `AI_INTERNAL_SERVICE_KEY` của Spring Boot; ứng dụng không còn dùng khóa mặc định. Khi khởi động, AI nạp vector học sinh từ PostgreSQL; vector thiếu/khác pipeline được nhập từ file `.npz` cũ nếu khớp phiên bản hoặc trích xuất lại từ ảnh. Vector phụ huynh/người giám hộ cũng được kiểm tra và bổ sung từ ảnh nếu thiếu. Các cập nhật đi qua API nội bộ Spring Boot.

Chỉ xóa file vector cũ trên EC2 sau khi xác minh các bản ghi cần thiết trong PostgreSQL đã có vector và AI health báo đủ số học sinh. Chế độ phát triển lưu cache cục bộ chỉ bật rõ ràng bằng `VECTOR_STORE_MODE=file`; ở chế độ database, thiếu `BACKEND_URL` sẽ khiến AI dừng khởi động thay vì quay về lưu file.
