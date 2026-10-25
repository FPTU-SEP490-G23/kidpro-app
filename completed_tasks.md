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

## 2026-10-11: Cấu hình Bỏ qua Đăng nhập (Bypass Auth) để Test Offline & AI Điểm danh
- **Task:** Tối ưu luồng truy cập Mobile Client không cần tài khoản DB.
- **Mô tả:**
  1. `app_router.dart`: Chuyển `initialLocation` sang `/teacher`, mở quyền truy cập trực tiếp các route mà không bắt buộc đăng nhập khi chưa kết nối database.
  2. `auth_provider.dart`: Thiết lập tài khoản giả lập mặc định (`GIAO_VIEN`), tự động fallback đăng nhập khi backend DB offline.
  3. `login_screen.dart`: Bổ sung 2 nút tắt "Vào vai trò Giáo viên" và "Vào vai trò Phụ huynh".
  4. `teacher_dashboard_screen.dart`: Bổ sung card truy cập trực tiếp "Camera AI Điểm danh (Test)".
  5. `teacher_provider.dart`: Cung cấp danh sách học sinh mẫu khi offline.
  6. `face_attendance_camera_screen.dart`: Bổ sung `image_picker` chụp camera thật từ điện thoại, dialog đăng ký khuôn mặt mới trực tiếp từ mobile, kiểm tra kết nối ping server và điểm danh gửi ảnh thực tế lên FastAPI AI Engine.

## 2026-10-24: Đối Soát Database Supabase Live & Hoàn Thiện Toàn Bộ Backend Cho Role Phụ Huynh (Parent)
- **Task:** Kết nối đối soát Supabase live schema và triển khai trọn bộ Backend REST API phục vụ Mobile App cho vai trò Phụ huynh (`PARENT`).
- **Mô tả:**
  1. **Đối soát Database Supabase PostgreSQL Thực Tế:**
     - Kết nối trực tiếp vào cụm cơ sở dữ liệu Supabase Live (`aws-0-ap-south-1.pooler.supabase.com:5432`) qua pooler.
     - Kiểm tra toàn bộ 14 bảng trong schema `student`, 7 bảng trong `health`, 10 bảng trong `finance`, 9 bảng trong `communication` và 6 bảng trong `identity`.
     - Xuất và lưu trữ cấu trúc schema live (`supabase_live_schema.json`), xác nhận cơ sở dữ liệu đã đồng bộ 100% với tài liệu kiến trúc mới `NewDB2.md`.
  2. **Hoàn thiện Đặc tả Kỹ thuật Chuẩn Mực:**
     - Biên soạn tài liệu kỹ thuật chi tiết `kidpro-app/Parent.md` (102.5 KB) và `kidpro-app/Teacher.md` (109.4 KB) chuẩn hóa 6 phần từ `KeToan.md`, đặc tả rõ các quy tắc nghiệp vụ BR-001 đến BR-070, DTOs, Controllers, Services và danh mục API.
  3. **Xây dựng Tầng Backend (kidpro-be) cho Vai trò Phụ huynh (Parent):**
     - **G10-UC-08: Nộp Đơn Xin Nghỉ Học Trực Tuyến:**
       - DTOs: `CreateLeaveRequestDto`, `LeaveRequestResponseDto`.
       - Service: `LeaveRequestService`, `LeaveRequestServiceImpl` (Xử lý quy tắc BR-018 chặn ngày quá khứ; quy tắc BR-036/BR-064 tự động tính cờ hoàn tiền ăn bán trú nộp trước 08:00 AM).
       - Controller: `ParentStudentPortalController` (`POST /api/parents/leave-requests`, `GET /api/parents/leave-requests`, `DELETE /api/parents/leave-requests/{id}`).
     - **G5-UC-07: Mã QR Ủy Quyền Đón Hộ Đột Xuất (60 Phút):**
       - DTOs: `EmergencyPickupCreateDto`, `EmergencyPickupResponseDto`.
       - Service: `EmergencyPickupService`, `EmergencyPickupServiceImpl` (Xử lý BR-022 hiệu lực tối đa 60 phút, mã OTP/PIN 4-6 số, chuỗi mã hóa ký số QR code dùng 1 lần, tự động chuyển trạng thái `EXPIRED`).
       - Controller: `ParentStudentPortalController` (`POST /api/parents/emergency-pickups`, `GET /api/parents/emergency-pickups`, `PUT /api/parents/emergency-pickups/{id}/revoke`).
     - **G4-UC-03: Người Đón Ủy Quyền Thường Xuyên:**
       - DTOs: `RegisterGuardianRequestDto`, `GuardianResponseDto`.
       - Service: `StudentGuardianService`, `StudentGuardianServiceImpl` (Xử lý BR-012 khống chế tối đa 03 người đón hợp lệ ngoài bố mẹ, thu hồi quyền đón lập tức).
       - Controller: `ParentStudentPortalController` (`POST /api/parents/guardians`, `GET /api/parents/students/{studentId}/guardians`, `DELETE /api/parents/guardians/{id}`).
     - **G8-UC-08, G8-UC-09, G8-UC-11: Học Phí, VietQR Động & Biên Lai Điện Tử:**
       - Service: Mở rộng `TuitionManagementService` và `TuitionManagementServiceImpl` với hàm `getInvoicesByStudentId`.
       - Controller: `ParentInvoicePortalController` (`GET /api/parents/invoices`, `GET /api/parents/invoices/{id}`, `GET /api/parents/invoices/{id}/vietqr` sinh VietQR EMVCo chuẩn BR-040, `GET /api/parents/invoices/{id}/receipt` tải biên lai điện tử ký số BR-042).
     - **G10-UC-01: Đơn Dặn Uống Thuốc Trực Tuyến:**
       - DTOs: `MedicationSubmitRequestDto`, `MedicationResponseDto`.
       - Service: `MedicationAdminService`, `MedicationAdminServiceImpl` (Xử lý BR-029/BR-030 quản lý đơn thuốc kê toa).
       - Controller: `ParentMedicationPortalController` (`POST /api/parents/medications`, `GET /api/parents/medications`, `DELETE /api/parents/medications/{id}`).
     - **G4-UC-06: Hồ Sơ Cảnh Báo Dị Ứng Y Tế:**
       - DTOs: `AllergyAlertCreateDto`, `AllergyAlertResponseDto`.
       - Service: `AllergyAlertService`, `AllergyAlertServiceImpl` (Xử lý BR-014 ghi nhận dị ứng thực phẩm/thuốc mức độ nguy hiểm).
       - Controller: `ParentAllergyPortalController` (`POST /api/parents/allergies`, `GET /api/parents/allergies`, `DELETE /api/parents/allergies/{id}`).
     - **UC-Decree13: Yêu Cầu Xóa Dữ Liệu Sinh Trắc Học (Nghị định 13/2023/NĐ-CP):**
       - DTO: `BiometricPurgeCertificateDto`.
       - Service: `BiometricPurgeService`, `BiometricPurgeServiceImpl` (Xác thực OTP 2FA, hủy kích hoạt vector 512 chiều trong `student.face_encoding_file`, sinh chứng thư số tiêu hủy dữ liệu kèm mã băm SHA-256).
       - Controller: `ParentBiometricPurgePortalController` (`POST /api/parents/students/{studentId}/biometric-purge/request-otp`, `POST /api/parents/students/{studentId}/biometric-purge/confirm`).

## 2026-10-25: Hoàn Thiện Toàn Bộ Giao Diện Mobile App (Flutter) Cho Vai Trò Phụ Huynh (Parent)
- **Task:** Xây dựng trọn bộ Giao diện người dùng (UI/UX), Tầng Quản lý Trạng thái (Provider), Tích hợp REST API và Điều hướng Router cho Vai trò Phụ huynh (`PARENT`) trên ứng dụng di động `kidpro_mobile`.
- **Mô tả:**
  1. **Tầng API Endpoints & Data Models (`api_endpoints.dart`, `parent_models.dart`):**
     - Khai báo đầy đủ các route endpoint cho học phí, VietQR, đơn xin nghỉ, ủy quyền đón hộ khẩn cấp, người đón thường xuyên, dặn uống thuốc, cảnh báo dị ứng y tế, và tiêu hủy sinh trắc học NĐ 13.
     - Xây dựng và chuẩn hóa các DTO model Dart: `Invoice`, `VietQrPayment`, `LeaveRequest`, `MedicationRequest`, `EmergencyPickup`, `AuthorizedGuardian`, `AllergyAlert`, `BiometricPurgeCertificate`, `ChatThread`, `ChatMessage`.
     - Serialisation `fromJson` / `toJson` tương thích chuẩn với Backend DTOs và hỗ trợ linh hoạt các trường dữ liệu tùy biến.
  2. **Tầng Quản lý Trạng thái State Management (`ParentProvider`):**
     - Quản lý ngữ cảnh học sinh đang chọn (`selectedStudentId`, `selectedStudentName`).
     - Cung cấp đầy đủ các phương thức tải dữ liệu, thêm mới, hủy bỏ và cập nhật trạng thái thời gian thực cho tất cả 8 nghiệp vụ phụ huynh.
     - Tích hợp cơ chế **Smart Mock Fallback**, tự động cung cấp dữ liệu giả lập chuẩn nghiệp vụ giúp kiểm thử offline mượt mà ngay cả khi Backend chưa khởi chạy hoặc mất mạng.
  3. **Màn hình Ủy quyền Đón hộ Đột xuất (`EmergencyPickupScreen` - G5-UC-07):**
     - Tạo mã QR động hiệu lực tối đa 60 phút và mã PIN/OTP 4-6 số xác thực theo quy chuẩn an toàn **BR-022**.
     - Render QR Code bảo mật bằng `qr_flutter`, hiển thị mã OTP nổi bật, cảnh báo đếm ngược thời gian và nút sao chép thông tin gửi Zalo/SMS cho người đón hộ.
     - Tab Lịch sử theo dõi danh sách các mã đón kèm nút **"Thu hồi"** lập tức chuyển trạng thái sang `EXPIRED`.
  4. **Màn hình Người đón Thường xuyên (`AuthorizedGuardiansScreen` - G4-UC-03):**
     - Quản lý danh sách người đón thường xuyên ngoài bố mẹ (Ông, Bà, Bác, Cô, Chú, Tài xế, Giúp việc...).
     - Tự động kiểm tra và thực thi quy định an toàn trả trẻ **BR-012**: Khống chế trần **tối đa 03 người** đón hợp lệ; bật hộp thoại cảnh báo khi đạt giới hạn.
     - Modal đăng ký người đón mới kèm danh mục quan hệ và chức năng thu hồi quyền đón ngay lập tức.
  5. **Màn hình Hồ sơ Dị ứng Y tế của Bé (`AllergyProfileScreen` - G4-UC-06):**
     - Khai báo dị ứng theo 3 nhóm dị nguyên: Thực phẩm (`FOOD`), Thuốc (`MEDICATION`), Môi trường (`ENVIRONMENTAL`).
     - Gán 3 mức độ nguy hiểm với màu sắc trực quan: Nghiêm trọng / Sốc phản vệ (`SEVERE` - Đỏ), Trung bình (`MODERATE` - Cam), Nhẹ (`MILD` - Xanh).
     - Banner cam kết quy chuẩn **BR-014**: Dữ liệu dị ứng được liên thông trực tiếp tới bảng cảnh báo của Bếp trưởng và Nhân viên Y tế nhà trường.
  6. **Màn hình Quyền riêng tư AI & Tiêu hủy Sinh trắc học (`BiometricPurgeScreen` - UC-Decree13):**
     - Thực thi Điều 9 Nghị định 13/2023/NĐ-CP về quyền rút lại sự đồng ý thu thập và xử lý dữ liệu sinh trắc học của trẻ em.
     - Quy trình 3 bước chặt chẽ: Tiếp nhận lý do & Yêu cầu mã OTP -> Xác thực 2 lớp (2FA) -> Tiêu hủy vĩnh viễn vector khuôn mặt 512 chiều trong AI Engine.
     - Hiển thị **Chứng thư số Tiêu hủy Dữ liệu** chính thức với mã chứng thư, mã băm mật mã học **SHA-256**, thời gian tiêu hủy và con dấu điện tử KidPro.
  7. **Nâng cấp Đơn xin nghỉ học & Đơn dặn thuốc (`LeaveRequestScreen`, `MedicationRequestScreen`):**
     - Chuyển đổi giao diện sang cấu trúc 2 Tab (Nộp đơn mới & Lịch sử đơn).
     - **Đơn xin nghỉ học:** Hỗ trợ chọn dải ngày xin nghỉ (`DateRangePicker`), tự động kiểm tra mốc **08:00 AM** theo **BR-018 / BR-036 / BR-064** để xác định điều kiện hoàn tiền ăn bán trú, hỗ trợ hủy đơn đang chờ duyệt.
     - **Đơn dặn thuốc:** Đính kèm ảnh minh chứng đơn thuốc/vỏ thuốc theo **BR-029**, ghi chú liều lượng, giờ uống, theo dõi trạng thái tiếp nhận và cho uống thuốc của giáo viên.
  8. **Nâng cấp Dashboard Phụ huynh & Điều hướng Router (`ParentDashboardScreen`, `app_router.dart`):**
     - Bổ sung thẻ thông tin học sinh hiện tại và trạng thái điểm danh trong ngày.
     - Cấu trúc lưới 8 phím tắt chức năng chia thành 2 nhóm: Tiện ích học tập & An toàn sức khỏe.
     - Đăng ký đầy đủ 4 route mới trong `GoRouter`: `/parent/emergency-pickup`, `/parent/guardians`, `/parent/allergies`, `/parent/biometric-purge`.




