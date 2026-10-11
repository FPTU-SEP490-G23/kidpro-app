# Completed Tasks

## 2026-10-11: Khởi tạo và Thiết lập Mã Nguồn KidPro Mobile App
- **Task:** Khởi tạo Flutter project `kidpro_mobile` và thiết lập kiến trúc Feature-First / Clean Architecture.
- **Mô tả:** 
  1. Cấu hình `pubspec.yaml` với đầy đủ dependencies: `dio`, `provider`, `go_router`, `flutter_secure_storage`, `qr_flutter`, `cached_network_image`, `firebase_core`, `firebase_messaging`.
  2. Xây dựng Network Layer (`ApiClient`, `AuthInterceptor` xử lý đính kèm Bearer JWT, tự động refresh token khi gặp 401, lưu trữ an toàn trong `SecureStorageHelper`).
  3. Xây dựng Module Authentication: `LoginRequest`, `LoginResponse`, `UserProfile`, `AuthProvider`, `LoginScreen` kết nối trực tiếp `/api/auth/login`.
  4. Cấu hình Điều hướng `GoRouter` (`app_router.dart`) với Route Guards tự động phân quyền theo vai trò `PHU_HUYNH` và `GIAO_VIEN`.
  5. Xây dựng Phân hệ Phụ huynh (Parent BFF):
     - Dashboard & Timeline sự kiện trong ngày (`/parent/dashboard`).
     - Quản lý Học phí & Thanh toán VietQR Napas 247 động 1-chạm (`/parent/invoices`, `/parent/invoices/:id/pay`).
     - Đơn xin nghỉ học có kiểm soát mốc 08:00 AM (`/parent/leave`).
     - Đơn dặn thuốc kèm chụp ảnh đơn/vỏ thuốc (`/parent/medication`).
     - Tin nhắn 1-1 thời gian thực với giáo viên (`/parent/chat`, `/parent/chat/:threadId`).
  6. Xây dựng Phân hệ Giáo viên (Teacher BFF):
     - Dashboard nhiệm vụ và cảnh báo an toàn tức thì.
     - Điểm danh buổi sáng 3 trạng thái màu sắc + batch save (`/teacher/attendance`).
     - Màn hình quét đón trẻ lúc tan học kèm hộp thoại cảnh báo người lạ chớp nháy đỏ (`/teacher/dismissal`).
     - Quản lý uống thuốc lúc 14:00 yêu cầu chụp ảnh thực tế minh chứng (`/teacher/medication`).

## 2026-10-11: Triển khai PoC AI Face Attendance (FastAPI + InsightFace & Mobile Client)
- **Task:** Xây dựng hệ thống End-to-End điểm danh khuôn mặt AI.
- **Mô tả:**
  1. Tạo AI Backend Server tại `ai_backend/`:
     - Sử dụng FastAPI + InsightFace `buffalo_sc` (CPU Execution) + OpenCV + SQLite + Vector Embeddings Cache.
     - `POST /api/v1/register`: Trích xuất vector 512 chiều chuẩn hóa $L_2$, lưu SQLite và cache RAM.
     - `POST /api/v1/check-in`: Tích vô hướng ma trận Cosine Similarity `np.dot` (ngưỡng 0.65). Trả về `PRESENT` hoặc `UNKNOWN`.
     - Cung cấp `web_demo.html` trực quan để test webcam trực tiếp trên Laptop và `test_client.py`.
  2. Tích hợp Mobile Client:
     - Flutter Screen: `FaceAttendanceCameraScreen` trong `kidpro_mobile` kèm cấu hình IP LAN linh hoạt, hiệu ứng quét AI, viền Xanh lá / Đỏ cảnh báo, Fallback điểm danh thủ công.
     - Native Android Kotlin (`android_client_demo/`): CameraX 720p, nén JPEG 80% (640px), Retrofit/OkHttp timeout 10s, `usesCleartextTraffic="true"`.
     - Viết tài liệu `ai_backend/README.md` hướng dẫn chi tiết từng bước chạy demo trên mạng Wi-Fi nội bộ.
