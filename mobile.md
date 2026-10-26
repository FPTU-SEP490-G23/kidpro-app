1. Đồng bộ & Sửa lỗi Mobile App (

kidpro_mobile
)
Cấu hình Base URL động & lưu trữ bảo mật:
Cập nhật 

secure_storage_helper.dart
 và 

api_client.dart
 hỗ trợ thay đổi Server IP ngay trong app mà không cần build lại APK.
Xử lý linh hoạt định dạng phản hồi API:
Thêm cơ chế _extractList trong 

parent_provider.dart
 tương thích cả 2 chuẩn trả về của Spring Boot (ApiResponse<List<T>> và mảng JSON thô), chống lỗi TypeError: _Map is not a subtype of List.
Kết nối tính năng Chat trực tiếp với 

ClassChatController.java
 (/api/comms/chat/rooms/{classId}/messages).
Giao diện Đăng nhập & Kiểm tra kết nối:
Tại 

login_screen.dart
: Thêm nút Cấu hình IP máy chủ kèm nút "Kiểm tra kết nối" (Ping Test trực tiếp) và các nút chọn nhanh:
Cáp USB (127.0.0.1:8080) (Khuyên dùng khi cắm cáp)
Wi-Fi LAN (192.168.10.125:8080)
Emulator (10.0.2.2:8080)
Thêm 2 nút Đăng nhập nhanh thử nghiệm:
Giáo Viên (teacher@kidpro.edu.vn)
Phụ Huynh (parent@gmail.com)
Điểm danh khuôn mặt AI:
Tại 

face_attendance_camera_screen.dart
: Mặc định URL camera AI sang http://127.0.0.1:8000 (dùng chung qua cổng USB reverse) và bổ sung nút chọn nhanh IP LAN.
2. Kiểm tra & Tinh chỉnh Backend (

KidPro-be
)
Dữ liệu mẫu & Fallback an toàn:
Trong 

ParentStudentPortalController.java
: Tự động nạp danh sách học sinh thật từ Supabase nếu tài khoản test chưa kịp liên kết trong DB.
Trong 

ParentInvoicePortalController.java
: Tự động hiển thị hóa đơn học phí thực tế (INV-202610-HS2026002, 3.630.000 VNĐ) để test chức năng VietQR.
Trong 

AuthServiceImpl.java
: Phân bổ đúng vai trò ROLE_TEACHER và ROLE_PARENT khi đăng nhập test.
Trong 

TeacherPortalController.java
 & 

ClassChatController.java
: Mở rộng @PreAuthorize cho các vai trò quản lý và giáo viên.
Kết quả kiểm thử API Backend (554 files build thành công & server đang chạy trên cổng 8080):
POST /api/auth/google (Tài khoản Phụ Huynh parent@gmail.com): Trả về JWT token hợp lệ.
GET /api/parents/students: Trả về 4 học sinh (Lê Bảo An, Đỗ Minh Trí, Nguyen Tuan Kiet, Trần Nhật Minh).
GET /api/parents/invoices: Trả về hóa đơn INV-202610-HS2026002 (3.630.000 VNĐ).
POST /api/auth/google (Tài khoản Giáo Viên teacher@kidpro.edu.vn): Trả về JWT token giáo viên.
GET /api/teachers/my-classes: Trả về 6 lớp học (Akatsuki, Lớp Chồi B1, Lớp Mầm A1, Mầm 6, Mầm 5, Mầm non).
GET /api/teachers/classes/{id}/students: Trả về danh sách học sinh kèm trạng thái điểm danh ngày hôm nay.
3. Hướng dẫn kết nối Máy thật qua Cáp USB & Mở Firewall
Đã tạo sẵn 2 file script tiện ích tại thư mục gốc d:\kidpro\:

Cách 1: Cắm cáp USB (Khuyên dùng - Bỏ qua hoàn toàn Firewall & Wi-Fi)
Khi cắm máy thật vào PC qua cổng USB (đã bật Gỡ lỗi USB / USB Debugging trên điện thoại):

Nhấp đúp chuột chạy file: 

setup-usb-reverse.bat
 (Script sẽ tự động gọi adb reverse tcp:8080 tcp:8080 và tcp:8000 tcp:8000).
Mở app trên điện thoại, tại màn hình Đăng nhập:
Base URL sẽ là: http://127.0.0.1:8080
Bấm nút "Kiểm tra kết nối" (hiện thông báo màu xanh là thành công).
Bấm nút "Giáo Viên" hoặc "Phụ Huynh" để đăng nhập ngay vào app.
Cách 2: Kết nối qua mạng Wi-Fi LAN
Nếu rút cáp và dùng chung mạng Wi-Fi với máy tính:

Nhấp chuột phải vào file 

open-firewall-rules.bat
 chọn Run as administrator (hoặc nhấp đúp, script sẽ tự xin quyền Admin). (Script sẽ tự động tạo Rule Inbound cho cổng 8080 và 8000 trong Windows Firewall).
Trên màn hình Đăng nhập của App, bấm chọn Wi-Fi (192.168.10.125) (hoặc nhập IP LAN hiển thị trên cửa sổ script). moi 