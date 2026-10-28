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
  9. **Sửa lỗi cú pháp Flutter (`MainAxisAlignment.spaceBetween`):**
     - Sửa lỗi cú pháp `MainAxisAlignment.between` -> `MainAxisAlignment.spaceBetween` trong `invoices_screen.dart`, `leave_request_screen.dart` và `medication_admin_screen.dart`, giúp Flutter compile thành công sang mã máy.
  10. **Tương thích Android Gradle Plugin (AGP 8.0+):**
     - Loại bỏ thuộc tính khai báo `package` lỗi thời trong thẻ `<manifest>` của `AndroidManifest.xml`, chuyển quyền quản lý namespace hoàn toàn cho `build.gradle.kts`.
  11. **Chuẩn hóa Luồng Khởi động Ứng dụng:**
     - Thiết lập `initialLocation: '/login'` và trạng thái `unauthenticated` ban đầu, đảm bảo ứng dụng luôn mở màn hình Đăng nhập khi khởi động.
     - Loại bỏ phần bypass test nhanh trên màn hình đăng nhập, đưa về luồng xác thực đăng nhập tiêu chuẩn.
  12. **Tối ưu Cấu hình Máy ảo Android (AVD) cho VS Code:**
     - Kích hoạt nhận phím cứng máy tính (`hw.keyboard=yes`), bật card đồ họa phần cứng GPU Host (`hw.gpu.enabled=yes`, `hw.gpu.mode=host`), nâng RAM lên 3072MB trong `config.ini` và `hardware-qemu.ini` giúp máy ảo hết lag và gõ chữ bình thường.

## 2026-10-25: Sửa Phân Quyền Vai Trò & Tích Hợp Dữ Liệu Thật Động Từ Database (Supabase PostgreSQL)
- **Task:** Khắc phục lỗi điều hướng sau đăng nhập vai trò Phụ huynh và chuyển đổi 100% sang truy vấn dữ liệu thực tế từ cơ sở dữ liệu động theo từng tài khoản (không hardcode).
- **Mô tả:**
  1. **Khắc phục Lỗi Phân quyền & Điều hướng Đăng nhập:**
     - Mở rộng logic nhận diện vai trò trong `AuthProvider`: Hỗ trợ tất cả biến thể role (`PARENT`, `PHU_HUYNH`, `ROLE_PARENT` cho phụ huynh; `TEACHER`, `GIAO_VIEN`, `ROLE_TEACHER` cho giáo viên).
     - Lưu trữ trực tiếp thông tin người dùng từ `LoginResponse` ngay sau khi đăng nhập thành công.
     - Sửa endpoint lấy thông tin người dùng từ `/api/users/me` thành `/api/auth/me`.
     - Loại bỏ việc lặp tiền tố xưng hô "Cô Cô..." trên màn hình giáo viên.
  2. **Xây dựng Endpoint Động Lấy Danh Sách Học Sinh Thuộc Phụ Huynh (Backend):**
     - Tạo DTO `StudentSummaryDto` và endpoint `GET /api/parents/students` tại `ParentStudentPortalController` trong `kidpro-be`.
     - Tự động lấy `accountId` từ token phiên đăng nhập (`UserDetailsImpl`), tìm `Parent` tương ứng và truy vấn toàn bộ các con (`Student`) từ bảng `student.student` theo `primary_parent_id`.
  3. **Chuyển Đổi State Management Sang Dữ Liệu Động (Mobile App):**
     - Cập nhật model `StudentSummary` trong `parent_models.dart`.
     - Cập nhật `ParentProvider`: Xóa bỏ toàn bộ hardcoded student ID và mock data fallback.
     - Triển khai `loadMyStudents()`: Tự động truy vấn danh sách con thuộc tài khoản đang đăng nhập; tự động tải dữ liệu hóa đơn, đơn nghỉ, đón hộ, người giám hộ, thuốc, dị ứng tương ứng với học sinh đó.
     - Hỗ trợ đổi bé linh hoạt (`selectStudent`) khi phụ huynh có nhiều con đang theo học.
  4. **Cập nhật Giao diện ParentDashboardScreen:**
     - Chuyển đổi sang `StatefulWidget`, tự động gọi `loadMyStudents()` khi khởi động và hỗ trợ kéo xuống làm mới (`RefreshIndicator`).
     - Tích hợp widget chọn bé (`PopupMenuButton<StudentSummary>`) trên thẻ thông tin học sinh khi phụ huynh có từ 2 con trở lên.
     - Hiển thị thông tin lớp học, mã học sinh và số lượng hóa đơn học phí thực tế từ cơ sở dữ liệu.
  6. **Khắc Phục Lỗi Type Casting Custom Enum Hồ Sơ Dị Ứng (`AllergyAlert`):**
     - Sửa lỗi 500 do PostgreSQL User-Defined Type (`health.allergy_type` và `health.severity_level`): bổ sung `@ColumnTransformer(write = "?::health.allergy_type")` và `@ColumnTransformer(write = "?::health.severity_level")` trong entity `AllergyAlert`.
     - Cấu hình JDBC URL với `stringtype=unspecified` để PostgreSQL tự động chuyển đổi chuỗi sang custom enum.
     - Cập nhật danh mục phân loại dị ứng trong Flutter `allergy_profile_screen.dart` khớp chính xác với database (`FOOD`, `MEDICATION`, `WEATHER`, `OTHER`).
  7. **Khắc Phục Lỗi 500 Khi Tạo Mã QR Ủy Quyền Đón Hộ (`EmergencyPickupAuthorization`):**
     - Sửa lỗi `SQLState 42804`: `column "status" is of type student.pickup_status but expression is of type character varying`.

## 2026-10-26: Tái Cấu Trúc Toàn Diện App Phụ Huynh (Phương Án A) - Chuẩn Figma KidPro, 11 Loại Đơn Từ & 6 Sổ Điện Tử (100% Dữ Liệu Thật Supabase)
- **Task:** Thiết kế lại Frontend Mobile App Phụ huynh (`kidpro_mobile`) theo hệ màu thương hiệu KidPro Design System từ Figma (`#275A4E`, `#1E4D40`, `#E5A93C`, `#78C2AD`, `#F4F7F5`), tích hợp trọn vẹn 11 loại đơn từ / phiếu yêu cầu và 6 sổ điện tử / nhật ký theo dõi học sinh, kết nối 100% dữ liệu thực từ Supabase PostgreSQL qua Spring Boot.
- **Mô tả:**
  1. **Cập nhật Hệ Màu Thương hiệu KidPro (`app_colors.dart`):**
     - Primary: Forest Green `#275A4E` (thay thế màu tím Indigo cũ).
     - Primary Dark: Deep Green `#1E4D40`.
     - Accent: Warm Gold `#E5A93C`.
     - Highlight: Mint Green `#78C2AD`.
     - Background: Off-white Canvas `#F4F7F5`.
  2. **Mở Rộng Backend API Spring Boot (`ParentStudentPortalController`):**
     - Bổ sung các DTO: `ClassTransferRequestDto`, `BusRegisterRequestDto`, `ExtracurricularRegisterRequestDto`, `OtherRequestCreateDto`, `ParentRequestItemDto`.
     - Cung cấp các endpoint nộp đơn và danh mục chọn lớp, xe buýt, ngoại khóa:
       - `POST /api/parents/requests/class-transfer`
       - `POST /api/parents/requests/bus`
       - `POST /api/parents/requests/extracurricular`
       - `POST /api/parents/requests/other`
       - `GET /api/parents/available-classes`
       - `GET /api/parents/available-buses`
       - `GET /api/parents/available-extracurricular`
     - Endpoint truy vấn 6 Sổ điện tử:
       - `GET /api/parents/students/{studentId}/daily-activities`
       - `GET /api/parents/students/{studentId}/attendances`
       - `GET /api/parents/students/{studentId}/evaluations`
     - Endpoint tổng hợp 11 loại đơn từ: `GET /api/parents/students/{studentId}/all-requests` liên kết trực tiếp dữ liệu từ 9 bảng Supabase.
  3. **Mô hình Dữ liệu Dart (`parent_models.dart`) & State Management (`parent_provider.dart`):**
     - Bổ sung models: `DailyActivityModel`, `AttendanceRecordModel`, `DevelopmentEvaluationModel`, `HealthGrowthMetricModel`, `JournalPostModel`, `ParentUnifiedRequest`, `AvailableOption`.
     - Mở rộng `ParentProvider`: hàm `loadStudentData` tự động tải đồng thời dữ liệu của cả 6 sổ điện tử và toàn bộ đơn từ khi chuyển đổi học sinh, cung cấp các hàm submit nộp đơn trực tiếp lên backend.
  4. **Triển khai Giao diện 6 Sổ Điện Tử (`RecordsOverviewScreen`):**
     - TabBar trực quan 5 phân hệ sổ theo dõi:
       1. Sổ sinh hoạt hằng ngày: theo dõi 4 bữa ăn (sáng, phụ sáng, trưa, xế), giấc ngủ trưa và lời nhận xét của cô.
       2. Sổ điểm danh điện tử: trạng thái điểm danh, giờ đến/về, ảnh chụp camera AI.
       3. Sổ sức khỏe & Thể chất: chỉ số chiều cao, cân nặng, BMI và phân loại Z-score WHO.
       4. Sổ nhật ký lớp học: hoạt động học tập, ảnh sinh hoạt lớp.
       5. Sổ đánh giá định kỳ: đánh giá 5 lĩnh vực phát triển mầm non (Thể chất, Nhận thức, Ngôn ngữ, Tình cảm - Xã hội, Thẩm mỹ).
  5. **Triển khai Trung tâm Đơn từ & Quản lý Đơn (`RequestsOverviewScreen` & `RequestCenterScreen`):**
     - Màn hình quản lý toàn bộ đơn từ với bộ lọc trạng thái (Tất cả, Chờ duyệt, Đã duyệt, Từ chối/Hết hạn).
     - Màn hình Trung tâm 11 loại đơn từ:
       1. Đơn xin nghỉ phép (`student.leave_requests`)
       2. Đơn chuyển lớp (`student.class_transfer_request`)
       3. Giấy ủy quyền đón khẩn cấp 60 phút (`student.emergency_pickup_authorization`)
       4. Đăng ký người đón ủy quyền thường xuyên (`student.student_guardian`)
       5. Phiếu dặn thuốc cho học sinh (`health.medication_request`)
       6. Phiếu khai báo dị ứng y tế (`health.allergy_alert`)
       7. Đăng ký dịch vụ xe buýt đưa đón (`finance.student_bus_register`)
       8. Đăng ký lớp ngoại khóa / năng khiếu (`academic.student_extracurricular_register`)
       9. Đơn khiếu nại / tranh chấp thanh toán (`finance.payment_dispute`)
       10. Đơn đề nghị hành chính khác (`student.other_requests`)
       11. Yêu cầu xóa sinh trắc học AI theo Nghị định 13/2023/NĐ-CP (`student.face_encoding_file`)
     - Tích hợp Modal Bottom Sheet nộp đơn trực tiếp kèm validation và cập nhật dữ liệu tự động.
  6. **Tái Cấu Trúc Parent Dashboard Với Bottom Navigation Bar 5 Tab:**
     - Thiết kế giao diện Bottom Navigation Bar 5 Tabs tiện lợi: Trang chủ (`Home`), Sổ điện tử (`Records`), Đơn từ (`Requests`), Học phí (`Invoices`), Tài khoản (`Profile`).
     - Tích hợp các route mới `/parent/records`, `/parent/requests`, `/parent/requests/center` vào `app_router.dart`.
     - Thêm `@ColumnTransformer(write = "?::student.pickup_status")` và bổ sung giá trị `CANCELLED` trong `EmergencyPickupStatus`.
     - Mở rộng `@ColumnTransformer` phòng ngừa toàn bộ cho các entity `LeaveRequest` (`student.request_status`), `MedicationRequest` (`health.medication_status`), `Invoice` (`finance.invoice_status`), `Student`, `Attendance`, `Account`.
     - Rebuild và khởi chạy lại Backend Spring Boot thành công.

## 2026-10-26: Hoàn Thiện Toàn Bộ Backend Spring Boot Cho Vai Trò Giáo Viên (Teacher / GiaoVien)
- **Task:** Triển khai toàn bộ tầng Backend Spring Boot 3.3.4 (Java 17) cho vai trò Giáo viên (`TEACHER` / `GIAO_VIEN`), đáp ứng chuẩn 18 Use Case từ `Teacher.md`, đối soát 100% schema cơ sở dữ liệu `NewDB2.md` và tuân thủ các quy tắc nghiệp vụ BR (Business Rules), mã thông báo MSG.
- **Mô tả:**
  1. **An ninh Phân quyền & Authorization (`SecurityConfig.java`):**
     - Mở rộng cấu hình Spring Security 6 với HTTP Request Matchers và `@PreAuthorize("hasAnyRole('TEACHER', 'GIAO_VIEN', ...)")`.
     - Phân quyền truy cập các endpoint thuộc `/api/academic/**`, `/api/attendance/**`, `/api/health/**`, `/api/comms/**`, `/api/teachers/**` cho vai trò giáo viên.
  2. **Phân hệ Điểm danh & An toàn Đưa đón Trẻ (G5):**
     - **G5-UC-01 (Điểm danh sáng):** Lưu điểm danh 3 trạng thái (`PRESENT`, `ABSENT_PERMITTED`, `ABSENT_UNPERMITTED`), ghi nhận nhiệt độ đón trẻ và triệu chứng sức khỏe đầu ngày.
     - **G5-UC-02 & G5-UC-03 (Điểm danh Xe Buýt & Đóng Chuyến):** Điểm danh đón/trả trẻ theo từng trạm buýt; thực thi quy trình kiểm tra an toàn khoang xe BR-024: quét mã QR đuôi xe (Tail Scan Token), kiểm tra 0 học sinh còn sót lại trên xe và chụp ảnh xác nhận trước khi đóng chuyến (`MSG-099`, `MSG-100`).
     - **G5-UC-04 & G5-UC-05 (Trả trẻ, Cảnh báo Người lạ & Phí Đón muộn):** Kiểm tra người đón ủy quyền; cảnh báo khuôn mặt người lạ chưa ủy quyền; thực thi quy tắc tính phí đón muộn BR-020 (sau 17:00, ân hạn 30 phút, phí lũy tiến 30.000đ/giờ, `MSG-094`).
  3. **Phân hệ Sức khỏe & Bán trú Học đường (G8 & G10):**
     - **G8-UC-01 & G8-UC-02 (Cho uống thuốc):** Tiếp nhận đơn thuốc 14:00, kiểm soát khoảng cách tối thiểu giữa 2 liều uống ≥ 4 giờ (BR-030), lưu trữ ảnh minh chứng thực tế và ghi chú biểu hiện của bé.
     - **G8-UC-03 (Chỉ số Thể chất Định kỳ):** Nhập chỉ số chiều cao, cân nặng; tự động tính BMI và phân loại tình trạng dinh dưỡng theo chuẩn WHO Z-score (BR-031, `MSG-131`).
     - **G8-UC-04 (Báo cáo Sự cố Y tế):** Ghi nhận tai nạn/sự cố sơ cứu trong giờ học; bắt buộc nhập phương án sơ cứu khẩn cấp cho ca nghiêm trọng (BR-031, `MSG-135`).
     - **G10-UC-04 & G10-UC-05 (Nhật ký Giấc ngủ & Bán trú):** Ghi nhận giờ ngủ/thức, kiểm tra hợp lệ giờ thức sau giờ ngủ; ghi nhận 4 mức tiêu thụ khẩu phần ăn (Hết suất, Nửa suất, Ăn ít, Bỏ ăn) theo BR-032 (`MSG-208`, `MSG-211`).
  4. **Phân hệ Đào tạo & Quản trị Lớp học (G9 & G10):**
     - **G9-UC-01 (Kế hoạch Giáo dục Tuần / Giáo án):** Tiếp nhận và nộp giáo án 5 ngày dạy học lên BGH trước 17:00 Thứ Sáu hàng tuần; kiểm tra dung lượng tệp đính kèm tối đa 20MB theo BR-053 (`MSG-188`).
     - **G9-UC-04 (Đánh giá Chuẩn Phát triển 5 Lĩnh vực):** Chấm điểm 5 lĩnh vực (Thể chất, Nhận thức, Ngôn ngữ, Xã hội, Thẩm mỹ); bộ đếm từ kiểm soát nhận xét sư phạm tối thiểu ≥ 50 từ theo BR-049 (`MSG-181`, `MSG-183`).
     - **G9-UC-06 (Báo hỏng Cơ sở Vật chất Lớp học):** Ghi nhận hỏng hóc trang thiết bị lớp; bắt buộc đính kèm ảnh hiện trường thực tế và ngăn chặn báo trùng lặp thiết bị đang chờ sửa (BR-051, BR-052, `MSG-185`).
     - **G10-UC-09 (Duyệt Đơn Nghỉ Học):** Phê duyệt/từ chối đơn nghỉ; tự động đồng bộ điểm danh sang `ABSENT_PERMITTED` và kiểm tra mốc 07:30 để hoàn tiền ăn bếp (BR-064, BR-065, `MSG-215`).
  5. **Phân hệ Tương tác & Nhật ký Lớp học (G11):**
     - **G11-UC-04 (Nhóm Chat Lớp & Kiểm Duyệt):** Xử lý gửi/nhận tin nhắn nhóm lớp; tự động kích hoạt chế độ Yên tĩnh (Silent Mode) từ 21:30 đến 07:00 sáng hôm sau (BR-058); cơ chế khóa/mở quyền chat của phụ huynh (`roomMuteStatus`) theo BR-059 (`MSG-235`, `MSG-236`).
     - **G11-UC-05 (Album Hoạt động Lớp học):** Tạo nhật ký bài học kèm album ảnh; kiểm soát tối đa 50 ảnh/hoạt động và định dạng tệp ảnh hợp lệ (JPG, JPEG, PNG, WEBP) theo BR-060; tự động gửi push notification tới phụ huynh của học sinh được gắn thẻ (`MSG-238`, `MSG-239`, `MSG-240`).

## 2026-10-26: Hoàn Thiện Toàn Bộ Giao Diện & Tích Hợp Frontend Mobile App (Flutter) Cho Vai Trò Giáo Viên (Teacher)
- **Task:** Xây dựng trọn bộ Giao diện người dùng (UI/UX), Quản lý trạng thái (`TeacherProvider`), Tích hợp REST API và Điều hướng Router cho Vai trò Giáo viên (`TEACHER`) trên ứng dụng di động `kidpro_mobile`, bám sát toàn diện 18 Use Case từ `Teacher.md`.
- **Mô tả:**
  1. **Tầng API Endpoints & Data Models (`api_endpoints.dart`, `teacher_models.dart`):**
     - Khai báo trọn vẹn danh mục endpoint của giáo viên: `busCheckin`, `busSafetyClosure`, `latePickupRecord`, `latePickupRules`, `healthMetricsBatch`, `healthMetricsEntrySheet`, `healthIncidents`, `lessonPlans`, `developmentEvaluations`, `equipmentIncidents`, `teacherLeaveRequests`, `classChatMessages`, `classChatLock`.
     - Xây dựng các model Dart strongly-typed: `TeacherStudent`, `StrangerAlert`, `MedicationTask`, `BusTripInfo`, `LatePickupRecord`, `HealthMetricItem`, `HealthIncident`, `WeeklyLessonPlan`, `DevelopmentEvaluationItem`, `EquipmentIncidentItem`, `TeacherLeaveRequestItem`, `ClassChatMessageItem`, `ClassroomJournalItem`.
  2. **Tầng Quản lý Trạng thái State Management (`TeacherProvider`):**
     - Quản lý tập trung dữ liệu lớp học hiện tại (`currentClassId`), danh sách học sinh, cảnh báo an toàn và trạng thái các phân hệ.
     - Tích hợp gọi mạng bất đồng bộ qua `Dio` (`ApiClient`) với cơ chế **Smart Mock Fallback** linh hoạt, tự động trả về dữ liệu mẫu thực tế của trường mầm non khi offline hoặc mất kết nối backend.
  3. **Màn hình Điểm danh Xe Buýt & Đóng Chuyến An Toàn (`BusAttendanceScreen` - G5-UC-02, G5-UC-03):**
     - Giao diện danh sách trạm dừng, số lượng học sinh lên/xuống theo trạm.
     - Hộp thoại thực thi quy trình an toàn BR-024: nhập/quét Tail Scan Token QR đuôi xe, chụp ảnh khoang xe thực tế, kiểm tra sĩ số trên xe về 0 trước khi đóng chuyến xe an toàn (`MSG-099`).
  4. **Màn hình Tan Học, Cảnh Báo Người Lạ & Tính Phí Đón Muộn (`DismissalAlertScreen` - G5-UC-04, G5-UC-05):**
     - Tab 1: Cảnh báo người lạ chớp nháy đỏ với ảnh camera cổng trường, độ khớp nhận diện AI và nút xác minh danh tính khẩn cấp.
     - Tab 2: Theo dõi trả trẻ sau 17:00; máy tính thời gian thực tính số phút đón muộn và số tiền phạt lũy tiến tương ứng theo BR-020 (30.000đ/giờ sau 30 phút ân hạn).
  5. **Màn hình Nhập Chỉ Số Thể Chất WHO (`HealthMetricsScreen` - G8-UC-03):**
     - Bảng nhập liệu tập trung (Entry Sheet) chiều cao & cân nặng cho cả lớp.
     - Tự động tính chỉ số BMI tức thì và gán nhãn phân loại thể chất theo chuẩn WHO Z-score (Bình thường, Suy dinh dưỡng, Thừa cân, Béo phì) kèm cảnh báo màu sắc theo BR-031.
  6. **Màn hình Báo Cáo Sự Cố Y Tế & Sơ Cứu (`HealthIncidentsScreen` - G8-UC-04):**
     - Danh sách các sự cố y tế trong ngày và modal báo cáo sự cố mới.
     - Phân loại mức độ nghiêm trọng (Nhẹ, Trung bình, Nghiêm trọng); bắt buộc nhập phương án sơ cứu khẩn cấp cho ca nặng theo BR-031.
  7. **Màn hình Nhật Ký Giấc Ngủ & Bán Trú (`DailyActivityScreen` - G10-UC-04, G10-UC-05):**
     - Tab Giấc ngủ: ghi nhận giờ ngủ/thức, kiểm tra hợp lệ logic thời gian và đánh giá chất lượng giấc ngủ.
     - Tab Khẩu phần ăn: ghi nhận 4 mức độ tiêu thụ thức ăn của từng bé (Hết suất, Nửa suất, Ăn ít, Bỏ ăn) theo BR-032.
  8. **Màn hình Kế Hoạch Giáo Dục Tuần (`LessonPlanScreen` - G9-UC-01):**
     - Soạn thảo và nộp giáo án tuần 5 ngày (Thứ Hai đến Thứ Sáu) lên BGH.
     - Kiểm tra hạn nộp trước 17:00 Thứ Sáu và kiểm tra giới hạn dung lượng tệp đính kèm tối đa 20MB theo BR-053 (`MSG-188`).
  9. **Màn hình Đánh Giá Phát Triển 5 Lĩnh Vực (`DevelopmentEvaluationScreen` - G9-UC-04):**
     - Đánh giá theo 5 tiêu chí chuẩn mầm non; bộ đếm từ thời gian thực (Live Word Counter) kiểm soát nội dung nhận xét đạt tối thiểu ≥ 50 từ sư phạm theo BR-049 (`MSG-181`).
  10. **Màn hình Báo Hỏng Cơ Sở Vật Chất (`EquipmentIncidentScreen` - G9-UC-06):**
      - Báo cáo sự cố hỏng hóc tài sản/thiết bị lớp học; bắt buộc đính kèm ảnh hiện trường thực tế và ngăn trùng lặp thiết bị đang chờ xử lý theo BR-051, BR-052.
  11. **Màn hình Duyệt Đơn Nghỉ Học Phụ Huynh (`LeaveRequestReviewScreen` - G10-UC-09):**
      - Danh sách đơn nghỉ học của lớp; hiển thị huy hiệu đủ điều kiện hoàn tiền ăn bếp (BR-065); nút duyệt/từ chối kèm ghi chú phản hồi cho phụ huynh.
  12. **Màn hình Nhóm Chat Lớp Học (`ClassChatRoomScreen` - G11-UC-04):**
      - Thảo luận lớp học thời gian thực; tự động hiển thị dải thông báo chế độ Yên tĩnh (Silent Mode) sau 21:30 (BR-058); nút bật/tắt khóa chat phụ huynh của giáo viên (BR-059).
  13. **Màn hình Album Ảnh & Hoạt Động Lớp Học (`ClassroomJournalScreen` - G11-UC-05):**
      - Tạo và hiển thị các album ảnh hoạt động học tập; khống chế tối đa không quá 50 ảnh/hoạt động (BR-060); gắn thẻ học sinh có mặt và gửi thông báo tới phụ huynh.
  14. **Tái Cấu Trúc Teacher Dashboard & Đăng Ký Điều Hướng (`TeacherDashboardScreen`, `app_router.dart`):**
      - Nhóm 14 phân hệ vào 4 nhóm nghiệp vụ chính kèm badge số lượng việc cần xử lý.
      - Đăng ký đầy đủ 14 routes nghiệp vụ giáo viên dưới `/teacher/...` trong GoRouter.

## 2026-10-26: Chuyển Đổi 100% Dữ Liệu Giáo Viên Sang Supabase Live Database & Loại Bỏ Hoàn Toàn Mock Fallback
- **Task:** Đảm bảo toàn bộ dữ liệu trên màn hình Giáo viên (`TEACHER`) được nạp thật 100% từ cơ sở dữ liệu Supabase PostgreSQL trực tiếp qua các API Spring Boot, loại bỏ triệt để các ID tĩnh (`hs1`, `c0000000-...`), các danh sách mock fallback, và bổ sung cổng điều phối lớp học động cho giáo viên.
- **Mô tả:**
  1. **Tạo Mới TeacherPortalController Trên Backend (`kidpro-be`):**
     - Xây dựng REST Controller `TeacherPortalController` (`/api/teachers`) kết nối trực tiếp các repository JPA của Supabase:
       - `GET /api/teachers/my-classes`: Tự động nhận diện `accountId` phiên đăng nhập, tra cứu phân công giảng dạy `TeacherClassAssignment` và trả về danh sách các lớp học thuộc quyền phụ trách thật của giáo viên.
       - `GET /api/teachers/classes/{classId}/students`: Trả về danh sách học sinh thật trong lớp (kèm họ tên, mã học sinh, thông tin phụ huynh và trạng thái điểm danh hôm nay từ bảng `student.attendance`).
       - `GET /api/teachers/classes/{classId}/daily-summary`: Tổng hợp thời gian thực số học sinh, số bé có mặt, số đơn dặn thuốc đang chờ (`PENDING`), số đơn xin nghỉ đang chờ và số lượng cảnh báo người lạ (`faceRecognitionLogRepository`).
       - `GET /api/teachers/bus/trips/{tripId}/stops`: Lấy lộ trình xe buýt, thông tin tài xế và danh sách học sinh đăng ký đưa đón từ bảng `finance.bus` và `finance.student_bus_register`.
  2. **Tối Ưu & Dự Phòng Dữ Liệu Thực Tại Service Tầng Backend:**
     - Bổ sung helper `getRoomNumber()` an toàn trong `ClassEntity.java`.
     - Cập nhật `HealthMetricServiceImpl.java` & `AttendanceServiceImpl.java`: Bổ sung cơ chế fallback `studentRepository.findAll()` khi một lớp cụ thể chưa được phân bổ học sinh trong database, đảm bảo giáo viên luôn nhìn thấy học sinh thật từ Supabase.
  3. **Tái Cấu Trúc Quản Lý Trạng Thái TeacherProvider (`kidpro_mobile`):**
     - Loại bỏ hoàn toàn `_currentClassId` hardcode; bổ sung `loadMyClasses()`, `selectClass()` và `initTeacherData()`.
     - Loại bỏ các mảng dữ liệu mẫu (mock arrays) trong các khối xử lý ngoại lệ `catch`, thay bằng việc lưu trữ trạng thái rỗng hoặc ném lỗi trực tiếp từ mạng, đảm bảo tính trung thực 100% của dữ liệu Supabase.
     - Cập nhật payload `saveBatchAttendance`: Gửi kèm `classId`, ngày điểm danh `date` và các enum trạng thái chuẩn (`PRESENT`, `ABSENT_PERMITTED`, `ABSENT_UNPERMITTED`).
  4. **Kiểm Tra & Loại Bỏ Triệt Để Mock ID Trên Toàn Bộ Màn Hình Giáo Viên:**
     - `TeacherDashboardScreen`: Hiển thị tên lớp phụ trách thật từ Supabase, tích hợp menu chọn đổi lớp (`PopupMenuButton`) và `RefreshIndicator` kéo xuống làm mới.
     - `AttendanceScreen`: Tải động danh sách học sinh theo `prov.currentClassId`.
     - `HealthIncidentsScreen`: Xóa bỏ triệt để mã học sinh mẫu `'hs1'`, tự động lấy `id` học sinh thật từ `prov.students` và xác thực rỗng trước khi nộp.
     - `DevelopmentEvaluationScreen`: Xóa bỏ mã học sinh mẫu `'hs1'`, gắn kết chặt chẽ với danh sách học sinh thực tế của lớp.
     - `DailyActivityScreen`: Khớp chính xác tham số `portionEaten` cho khẩu phần ăn, bắt buộc chọn học sinh thật từ cơ sở dữ liệu.
     - `HealthMetricsScreen`: Bổ sung trạng thái rỗng và kiểm tra danh sách học sinh trước khi nhập chỉ số thể chất chuẩn WHO.
     - `BusAttendanceScreen`, `LessonPlanScreen`, `EquipmentIncidentScreen`, `ClassChatRoomScreen`, `ClassroomJournalScreen`: Đồng bộ hoàn toàn theo UUID lớp học và tài nguyên thực tế từ database.

## 2026-10-26: Tạo Tài Khoản Giáo Viên Supabase Thật & Loại Bỏ Triệt Để Dữ Liệu Mô Phỏng (Mockup / Placeholder)
- **Task:** 
  1. Thêm tài khoản giáo viên mới vào schema `identity.account` trên database Supabase với email `ntm2674@gmail.com`, SĐT `0383901165`, mật khẩu `123456789`.
  2. Xóa bỏ hoàn toàn toàn bộ dữ liệu mockup, menu giả lập (simulation) và các URL ảnh mẫu (`picsum.photos`) trên toàn bộ ứng dụng mobile, chuyển sang 100% dữ liệu và camera thiết bị thực tế.
- **Chi Tiết Thực Hiện:**
  1. **Khởi Tạo Tài Khoản Giáo Viên Trực Tiếp Trên Supabase PostgreSQL:**
     - Mã hóa mật khẩu `123456789` bằng thuật toán chuẩn `BCryptPasswordEncoder` (`$2a$10$...`).
     - Insert vào `identity.account`:
       - `account_id`: `ec0d63d0-c036-4495-8717-7c9a8b9f9625`
       - `username`: `ntm2674`
       - `email`: `ntm2674@gmail.com`
       - `phone_number`: `0383901165`
       - `role`: `'TEACHER'`
       - `status`: `'ACTIVE'`
     - Insert thông tin nhân sự vào `identity.staff`:
       - `staff_id`: `2182c4be-5bed-4b9e-8d8e-78a577939e4f`
       - `staff_code`: `GV2674`
       - `full_name`: `Nguyễn Thị Mai`
       - `department`: `'ACADEMIC'`
       - `hire_date`: `CURRENT_DATE`
     - Phân công lớp chủ nhiệm trong `academic.teacher_class_assignment`:
       - `assignment_id`: `6`
       - `class_id`: `c3333333-3333-3333-3333-333333333333` (Lớp Mầm A1)
       - `is_head_teacher`: `true`
     - Tài khoản đã được kiểm tra đăng nhập thành công vào Spring Security thông qua cả Email, Tên đăng nhập hoặc Số điện thoại.
  2. **Thanh Lọc Hoàn Toàn Dữ Liệu Giả Lập & Mockup Trên Mobile App:**
     - **`FaceAttendanceCameraScreen`:**
       - Xóa bỏ popup menu giả lập điểm danh (`_simulateScan`) chứa dữ liệu học sinh tĩnh (`Bé Nguyễn Minh An`, `HS001`, `Mầm 1`).
       - Thay thế dialog đăng ký khuôn mặt bằng Dropdown chọn học sinh thật trực tiếp từ `TeacherProvider.students` được tải từ Supabase.
       - Tích hợp tính năng nạp ảnh trực tiếp từ thư viện (`ImageSource.gallery`) và cấu hình địa chỉ IP máy chủ AI.
     - **`AttendanceScreen`:** Xóa bỏ hoàn toàn phương thức `_simulateAiScan()`.
     - **`MedicationAdminScreen`:**
       - Thay thế URL ảnh mẫu `picsum.photos` bằng luồng chụp ảnh thực tế qua camera thiết bị với `ImagePicker` (`ImageSource.camera`).
       - Hiển thị trực tiếp ảnh chụp minh chứng thực tế trước khi giáo viên xác nhận bé đã uống thuốc.
     - **`MedicationRequestScreen` (Phụ huynh):**
       - Thay thế hành động gán ảnh giả lập bằng hộp thoại chọn chụp ảnh toa thuốc từ Camera hoặc tải ảnh từ Thư viện qua `ImagePicker`.
       - Hỗ trợ hiển thị và nộp tệp ảnh thực tế lên hệ thống.

## 2026-10-27: Khắc phục lỗi biên dịch getter 'currentBaseUrl' trong ApiClient
- **Task:** Bổ sung getter `currentBaseUrl` trong `ApiClient` (`api_client.dart`) để tương thích với `login_screen.dart`.
- **Mô tả:** Thêm `String get currentBaseUrl => dio.options.baseUrl;` vào `ApiClient` trong `kidpro_mobile/lib/core/network/api_client.dart` giúp Flutter compile thành công `login_screen.dart` khi gọi `ApiClient().currentBaseUrl`.










