# KIDPRO - Comprehensive Software Requirement Specification (SRS) & System Architecture
**Dự án:** Hệ thống Quản trị Mầm non Thông minh, An toàn Trẻ nhỏ, Bếp ăn Bán trú & Quyết toán Học phí Động (KIDPRO)
**Tài liệu tham chiếu:** `documents_required/SEP490_G23_Report3.docx` (Release Ready 3.0) & `kidpro-be/NewDB2.md`
**Niên khóa / Đơn vị thực hiện:** Đồ án Tốt nghiệp Kỹ sư CNTT - Đại học FPT Hà Nội (SEP490 - Nhóm G23)

---

## 1. System Architecture & External Integrations (Kiến trúc & Tích hợp Ngoại vi)
KIDPRO là nền tảng quản trị trường mầm non toàn diện hoạt động theo mô hình đa cơ sở (Multi-tenant), kết nối đồng bộ giữa Cán bộ Quản trị, Ban Giám hiệu, Giáo vụ, Kế toán, Giáo viên, Nhà bếp và Phụ huynh học sinh.
Hệ thống tích hợp các dịch vụ công nghệ chuyên sâu:
*   **AI Facial Recognition Microservice:** Xây dựng trên nền tảng Python (FastAPI), sử dụng mô hình YOLOv8-Face cho tác vụ phát hiện khuôn mặt thời gian thực (< 50ms) và InsightFace (ArcFace) để trích xuất vector đặc trưng sinh trắc học 512 chiều. So khớp tốc độ cao qua PostgreSQL extension `pgvector` với chỉ mục HNSW (`vector_cosine_ops`) đạt độ trễ matching < 0.3s.
*   **Payment Gateway (VietQR / PayOS):** Tự động sinh mã VietQR động theo chuẩn Napas247 chứa chính xác số tiền và mã hóa đơn. Tiếp nhận Webhook/IPN tức thì trong 3 giây để tự động gạch nợ trên sổ kế toán điện tử.
*   **Cloud Object Storage (Supabase Storage / AWS S3):** Lưu trữ an toàn ảnh mẫu khuôn mặt sinh trắc học, ảnh snapshot điểm danh thời gian thực, đơn thuốc y tế và tem niêm phong mẫu thức ăn 24h (truy cập qua Presigned URLs hết hạn sau 15 phút).
*   **Push Notifications (Firebase Cloud Messaging - FCM):** Đẩy thông báo tức thời (kèm ảnh chụp check-in/out, thông báo uống thuốc, nhắc nợ, cảnh báo dị ứng) tới ứng dụng di động của phụ huynh và giáo viên.
*   **Email & SMS OTP Gateway:** Gửi thông báo chính thức, hợp đồng đào tạo, biên lai điện tử và mã xác thực OTP phục vụ quy trình bàn giao ủy quyền đón trẻ đột xuất.
*   **Tuân thủ Pháp lý & Quy chuẩn:**
    - *Nghị định 13/2023/NĐ-CP:* Bảo vệ dữ liệu cá nhân & sinh trắc học mầm non, hỗ trợ chức năng xóa vĩnh viễn dữ liệu khuôn mặt (Decree 13 Erasure) khi trẻ chuyển trường hoặc tốt nghiệp.
    - *Quyết định 1246/QĐ-BYT:* Quy trình kiểm thực 3 bước và lưu mẫu thức ăn 24 giờ tại bếp ăn bán trú học đường.
    - *Thông tư 51/2020/TT-BGDĐT:* Đánh giá sự phát triển của trẻ theo chuẩn 5 lĩnh vực mầm non.

---

## 2. Actors Definition (Các Tác nhân Hệ thống)
| STT | Tác nhân (Actor) | Tên tiếng Việt | Vai trò & Trách nhiệm chính |
| :---: | :--- | :--- | :--- |
| 1 | **Platform Super Admin** | Quản trị viên Nền tảng | Vận hành toàn bộ nền tảng hệ thống, quản lý danh sách các trường (Tenants), cấu hình tham số AI/Payment toàn cục, giám sát tài nguyên máy chủ và nhật ký bảo mật. |
| 2 | **Board of Directors (Principal / BGH)** | Ban Giám hiệu Nhà trường | Lãnh đạo nhà trường, phê duyệt kế hoạch mở lớp, phân công giáo viên, ban hành thời khóa biểu, biểu phí dịch vụ, thực đơn tuần, kế hoạch giáo án và theo dõi các chỉ số tài chính, an toàn trường học. |
| 3 | **Academic Affairs Staff (Giáo vụ)** | Cán bộ Giáo vụ | Quản lý tuyển sinh, tiếp nhận hồ sơ trẻ, tổ chức xếp lớp, chuyển lớp, lập thời khóa biểu tuần, đối soát hồ sơ người đón ủy quyền, quản lý cơ sở vật chất và xử lý thủ tục rút học bạ. |
| 4 | **School Accountant (Kế toán)** | Kế toán Trường học | Thiết lập danh mục khoản thu, cấu hình chính sách miễn giảm, thực hiện chạy tính học phí động định kỳ hàng tháng, đối soát webhook VietQR, thu tiền mặt thủ công và xuất hóa đơn điện tử. |
| 5 | **Preschool Teacher (Giáo viên)** | Giáo viên Mầm non | Sử dụng Tablet/Mobile App để điểm danh AI đầu ngày, ghi nhận sức khỏe tiếp nhận trẻ, quét khuôn mặt người đón lúc tan trường, tiếp nhận đơn thuốc và chụp ảnh khi cho uống, ghi nhật ký sinh hoạt và soạn giáo án điện tử. |
| 6 | **Kitchen Staff (Nhân viên Bếp)** | Nhân viên Bếp / Bếp trưởng | Lập thực đơn tuần, theo dõi dashboard chốt suất ăn bán trú 2 đợt (07:00 và 08:30), bóc tách suất ăn riêng cho trẻ dị ứng, ghi chép sổ kiểm thực 3 bước và lưu mẫu thức ăn 24 giờ. |
| 7 | **Parent / Legal Guardian** | Phụ huynh / Người giám hộ | Sử dụng Mobile App để đăng ký dữ liệu khuôn mặt con, quản lý người đón ủy quyền, tạo mã QR đón hộ đột xuất, nộp đơn xin nghỉ/dặn thuốc trực tuyến, theo dõi dòng thời gian sinh hoạt và thanh toán học phí 1 chạm qua VietQR. |
| 8 | **AI Recognition Microservice** | Dịch vụ AI Nhận diện (External) | Microservice xử lý mô hình YOLOv8-Face và trích xuất vector 512 chiều InsightFace so khớp với cơ sở dữ liệu PostgreSQL. |
| 9 | **Payment Gateway (VietQR/PayOS)** | Cổng Thanh toán (External) | Hạ tầng ngân hàng sinh mã QR chuyển khoản động và phát Webhook gạch nợ tự động. |
| 10 | **Firebase Cloud Messaging (FCM)** | Dịch vụ Push Notification (External) | Chuyển phát thông báo đẩy thời gian thực kèm ảnh tới thiết bị di động. |
| 11 | **Cloud Object Storage** | Kho Lưu trữ Đám mây (External) | Lưu trữ tệp tin media, ảnh sinh trắc học, hóa đơn, tài liệu minh chứng. |
| 12 | **Email Service (SMTP)** | Dịch vụ Email (External) | Gửi thông báo xác minh, biên lai thu tiền điện tử và thông tin tài khoản. |
| 13 | **SMS OTP Gateway** | Dịch vụ Tin nhắn OTP (External) | Gửi mã xác thực dùng một lần qua SMS phục vụ xác minh giao dịch và đăng nhập. |

---

## 3. Core Automated Workflows & Background Engines (Quy trình Nghiệp vụ & Dịch vụ Ngầm)
### 3.1. Điểm danh AI & Đồng bộ Suất ăn Bán trú 2 Mốc Thời gian (07:00 & 08:30)
*   **Đợt 1 (07:00 AM - Bữa sáng):** Hệ thống tự động quét danh sách học sinh đăng ký Gói ăn sáng (Toàn phần) và loại trừ các đơn xin nghỉ học nộp trước 07:00 AM (theo BR-018). Bếp nhận số lượng suất ăn sáng để chế biến.
*   **Đợt 2 (08:30 AM - Bữa trưa & Bữa xế):** Giáo viên hoàn tất điểm danh AI/thủ công. Đúng 08:30 AM, hệ thống tự động chốt số lượng suất ăn trưa và xế, khóa sổ dữ liệu và gửi snapshot tới Kitchen Dashboard. Phụ huynh nộp đơn nghỉ trước 08:30 AM được tính hoàn tiền ăn; nộp sau 08:30 AM vẫn tính suất ăn ngày hôm đó.

### 3.2. Quy trình Đón trả Trẻ An toàn & Mã QR Ủy quyền Đón hộ Đột xuất (60 phút)
*   **Đón trẻ bằng AI:** Giáo viên hướng camera quét khuôn mặt người đón tại cổng. Hệ thống so khớp vector 512 chiều với danh sách phụ huynh chính hoặc người đón ủy quyền đã được xác minh (tối đa 3 người theo BR-012). Màn hình viền xanh xác thực hợp lệ.
*   **Ủy quyền Đón hộ Đột xuất:** Phụ huynh tạo mã ủy quyền trên Mobile App, tải ảnh chân dung và số điện thoại người đón hộ. Hệ thống sinh mã QR động bảo mật có hiệu lực trong vòng 60 phút (BR-022). Giáo viên quét mã QR/nhập mã OTP đối chiếu ảnh trước khi bàn giao trẻ.
*   **Theo dõi Trả trẻ Muộn sau 17:00:** Mốc giờ trả trẻ sau 17:00 được ghi nhận tự động. Hệ thống tính phụ phí trông muộn lũy tiến 30.000 VNĐ/giờ (miễn phí 30 phút đầu của mỗi giờ theo BR-020) và tự động cộng dồn vào hóa đơn học phí tháng kế tiếp.

### 3.3. Động cơ Tính Học phí Động & Gạch Nợ Tự động qua Webhook VietQR (3 Giây)
*   **Công thức Quyết toán Học phí Tháng:**
    $$\text{Tổng học phí} = \text{Học phí cơ bản} + \text{Tiền dịch vụ bán trú} + \text{Phí xe buýt} + \text{CLB Ngoại khóa} - \text{Khấu trừ tiền ăn vắng có phép} - \text{Miễn giảm chính sách} + \text{Phụ phí đón muộn} + \text{Khoản phát sinh}$$
*   **Quy trình Gạch nợ Webhook:** Phụ huynh quét mã VietQR động -> Ngân hàng chuyển tiền -> VietQR/PayOS phát webhook kèm chữ ký số HMAC-SHA512 -> Backend KIDPRO xác thực chữ ký -> Cập nhật trạng thái hóa đơn sang `PAID` trong vòng 3 giây -> Tự động kích hoạt biên lai điện tử và bắn FCM thông báo tới phụ huynh.

### 3.4. Quản lý An toàn Bếp Bán trú: Kiểm thực 3 Bước & Lưu Mẫu 24 Giờ (QĐ 1246/QĐ-BYT)
*   **Kiểm thực 3 bước:** Bước 1 (Kiểm tra nguyên liệu nhập kho), Bước 2 (Kiểm tra trong quá trình sơ chế nấu nướng), Bước 3 (Kiểm tra cảm quan khay thức ăn trước khi chia phần cho trẻ).
*   **Lưu mẫu thức ăn 24h:** Mỗi món ăn lưu mẫu từ 100g đến 150g (hoặc 150ml chất lỏng), niêm phong tem có chữ ký người lưu và lưu trữ ở nhiệt độ $2.0^{\circ}\text{C} - 8.0^{\circ}\text{C}$ trong vòng 24 giờ. Tiêu hủy mẫu an toàn có ghi chép nhật ký.

### 3.5. Quy trình Chăm sóc Sức khỏe: Dặn Thuốc Kèm Ảnh Chụp & Theo dõi Z-Score Chuẩn WHO
*   **Dặn thuốc trực tuyến:** Phụ huynh tạo đơn thuốc trên App kèm ảnh đơn thuốc bác sĩ. Giáo viên tiếp nhận thuốc thực tế tại lớp đối chiếu nhãn định danh.
*   **Uống thuốc kèm ảnh chụp làm chứng:** Đến cữ thuốc, App giáo viên phát chuông nhắc. Giáo viên cho trẻ uống và bắt buộc chụp ảnh làm chứng để hệ thống lưu trữ và đẩy thông báo tới phụ huynh.
*   **Theo dõi thể chất Z-Score:** Hệ thống tự động tính chỉ số BMI và xếp loại thể trạng (Bình thường, Suy dinh dưỡng, Béo phì, Còi cọc) theo chuẩn WHO dựa trên độ tuổi tính bằng tháng.

### 3.6. Quản lý Tuyến Xe Buýt & Kiểm tra Chụp ảnh Khoang Xe Trống
*   Giáo viên phụ trách xe điểm danh học sinh lên/xuống tại các trạm. Khi xe về tới trường (sáng) hoặc điểm trả cuối (chiều), giáo viên kiểm tra và bắt buộc chụp ảnh toàn bộ khoang xe trống tải lên hệ thống để xác nhận an toàn, tuyệt đối phòng chống nguy cơ bỏ quên học sinh trên xe buýt.

---

## 4. Feature Requirements & 87 Detailed Use Cases (Danh mục 87 Use Cases theo 11 Phân hệ)

### Phân hệ 1: Quản trị Nền tảng Kỹ thuật & Cấu hình Hệ thống
| Mã UC (UC-ID) | Tên Use Case | Mô tả Chi tiết Nghiệp vụ |
| :---: | :--- | :--- |
| **G1-UC-01** | Đăng nhập Quản trị Kỹ thuật | Là users, tôi muốn đăng nhập bằng tài khoản và mật khẩu, để truy cập vào hệ thống. |
| **G1-UC-02** | Thiết lập Vai trò Mới trong Hệ thống | Là Quản trị viên Hệ thống, tôi muốn tạo vai trò mới và chọn các quyền sử dụng, để phân quyền cho các bộ phận nhân sự trong trường. |
| **G1-UC-03** | Xem Nhật ký Lỗi & Sự kiện Hệ thống | Là Quản trị viên Hệ thống, tôi muốn xem nhật ký lỗi và các hoạt động của hệ thống, để theo dõi và xử lý sự cố kịp thời. |

### Phân hệ 2: Quản lý Cơ sở, Cấu hình Năm học & Nhân sự
| Mã UC (UC-ID) | Tên Use Case | Mô tả Chi tiết Nghiệp vụ |
| :---: | :--- | :--- |
| **G2-UC-01** | Thiết lập Năm học & Học kỳ | Là Ban Giám hiệu, tôi muốn tạo năm học mới và cấu hình thời gian các học kỳ, để làm căn cứ tổ chức lớp học và kế hoạch chăm sóc nuôi dạy trẻ. |
| **G2-UC-02** | Quản lý Khối lớp & Định mức Sĩ số | Là Ban Giám hiệu, tôi muốn xem và cấu hình định mức sĩ số tối đa cho từng khối lớp (Nhà trẻ, Mầm, Chồi, Lá), để đảm bảo chất lượng chăm sóc và tuân thủ quy định giáo dục mầm non. |
| **G2-UC-03** | Quản lý Danh mục Phòng học | Là Ban Giám hiệu, tôi muốn khai báo và quản lý danh sách các phòng học trong trường, để phục vụ việc bố trí lớp học và phân công không gian sinh hoạt cho học sinh. |
| **G2-UC-04** | Quản lý Hồ sơ & Trạng thái Nhân sự | Là Ban Giám hiệu, tôi muốn xem danh sách cán bộ giáo viên, thêm mới hồ sơ, cập nhật thông tin và khóa hoặc mở khóa tài khoản nhân sự, để quản lý toàn diện đội ngũ nhân sự trong nhà trường. |
| **G2-UC-05** | Gán Vai trò & Quyền hạn Nhân sự | Là Ban Giám hiệu, tôi muốn gán các vai trò chức năng (Giáo vụ, Giáo viên, Kế toán, Bếp) cho từng nhân sự, để nhân sự có đúng quyền thực hiện công việc được giao. |
| **G2-UC-06** | Xem Nhật ký Thao tác Quản trị | Là Ban Giám hiệu, tôi muốn xem lịch sử các thao tác của nhân sự trên hệ thống (thêm, sửa, xóa, duyệt dữ liệu), để theo dõi tiến độ công việc và bảo đảm tính minh bạch trong quản lý nhà trường. |

### Phân hệ 3: Quản lý Lớp học, Thời khóa biểu & Phân công Giảng dạy
| Mã UC (UC-ID) | Tên Use Case | Mô tả Chi tiết Nghiệp vụ |
| :---: | :--- | :--- |
| **G3-UC-01** | Quản lý Danh sách & Cập nhật Thông tin Lớp học | Là Cán bộ Giáo vụ, tôi muốn xem danh sách các lớp học theo từng khối, tra cứu sĩ số và cập nhật thông tin lớp học (phòng học phân bổ, tên lớp), để quản lý tổ chức lớp học chính xác trong năm học. |
| **G3-UC-02** | Lập Kế hoạch Mở Lớp học Mới | Là Cán bộ Giáo vụ, tôi muốn lập kế hoạch mở các lớp học mới cho năm học, để trình Ban Giám hiệu phê duyệt trước khi đưa vào giảng dạy. |
| **G3-UC-03** | Phê duyệt Mở Lớp học Mới | Là Ban Giám hiệu, tôi muốn xem xét và phê duyệt hoặc từ chối các kế hoạch mở lớp mới do Giáo vụ gửi lên, để chính thức thành lập lớp học trong năm học mới. |
| **G3-UC-04** | Lập Kế hoạch Phân công Giáo viên Chủ nhiệm & Phụ tá | Là Cán bộ Giáo vụ, tôi muốn lập dự thảo phân công Giáo viên Chủ nhiệm và Giáo viên Phụ tá cho từng lớp học, để trình Ban Giám hiệu phê duyệt trước khi năm học bắt đầu. |
| **G3-UC-05** | Phê duyệt Kế hoạch Phân công Giảng dạy | Là Ban Giám hiệu, tôi muốn xem xét và phê duyệt hoặc từ chối danh sách phân công giáo viên phụ trách các lớp học, để chính thức ban hành nhiệm vụ giảng dạy cho giáo viên. |
| **G3-UC-06** | Xếp Trẻ vào Lớp học | Là Cán bộ Giáo vụ, tôi muốn chọn học sinh chưa có lớp và xếp vào các lớp học phù hợp với độ tuổi, để hoàn thiện danh sách học sinh cho từng lớp trước khi vào năm học. |
| **G3-UC-07** | Lập Phiếu Đề xuất Chuyển Lớp cho Học sinh | Là Phụ huynh, tôi muốn tạo đơn chuyển lớp cho con tôi. |
| **G3-UC-08** | Phê duyệt Chuyển Lớp cho Học sinh | Là Giáo vụ, tôi muốn xem xét và phê duyệt hoặc từ chối phiếu đề xuất chuyển lớp cho học sinh, để chính thức điều chuyển học sinh sang lớp mới. |
| **G3-UC-09** | Xây dựng Khung Thời khóa biểu Tuần | Là Cán bộ Giáo vụ, tôi muốn sắp xếp thời khóa biểu tuần cho từng lớp học (các hoạt động học tập, vui chơi, ăn ngủ, giáo viên và phòng chức năng), để trình Ban Giám hiệu phê duyệt. |
| **G3-UC-10** | Phê duyệt & Ban hành Thời khóa biểu | Là Ban Giám hiệu, tôi muốn xem xét và phê duyệt thời khóa biểu tuần của các lớp học, để chính thức ban hành cho giáo viên thực hiện và công bố trên ứng dụng của phụ huynh. |
| **G3-UC-11** | Lập Kế hoạch Kết chuyển Học sinh Đầu Năm | Là Cán bộ Giáo vụ, tôi muốn lập danh sách kết chuyển học sinh từ khối lớp cũ lên khối lớp mới khi sang niên khóa mới (từ Mầm lên Chồi, Chồi lên Lá, hoặc Lá tốt nghiệp ra trường), để chuẩn bị dữ liệu học sinh cho năm học mới. |
| **G3-UC-12** | Đóng & Lưu trữ Hồ sơ Lớp học | Là Cán bộ Giáo vụ, tôi muốn thực hiện đóng hồ sơ lớp học khi kết thúc năm học, để chuyển toàn bộ dữ liệu lớp sang trạng thái chỉ đọc và lưu trữ lịch sử. |

### Phân hệ 4: Hồ sơ Học sinh & Liên kết Phụ huynh
| Mã UC (UC-ID) | Tên Use Case | Mô tả Chi tiết Nghiệp vụ |
| :---: | :--- | :--- |
| **G4-UC-01** | Quản lý Danh sách & Hồ sơ Học sinh | Là Cán bộ Giáo vụ, tôi muốn tiếp nhận hồ sơ, tạo mới và tra cứu thông tin lý lịch của trẻ, để quản lý dữ liệu học sinh trong toàn trường. |
| **G4-UC-02** | Đăng ký Dữ liệu Khuôn mặt AI cho Trẻ | Là Phụ huynh, tôi muốn chụp và tải ảnh khuôn mặt đạt chuẩn của con lên ứng dụng di động, để hệ thống trích xuất dữ liệu sinh trắc học và kích hoạt nhận diện điểm danh tự động tại trường. |
| **G4-UC-03** | Đăng ký & Quản lý Người Đón Ủy quyền | Là Phụ huynh, tôi muốn chủ động khai báo, cập nhật và thu hồi quyền đón con cho người thân ngay trên ứng dụng di động, để quyền đón được kiểm soát an toàn và có hiệu lực tức thì theo thời gian thực. |
| **G4-UC-04** | Xử lý Hồ sơ Rút học bạ & Chuyển trường | Là Cán bộ Giáo vụ, tôi muốn tiếp nhận đơn xin rút hồ sơ hoặc chuyển trường của phụ huynh, đối chiếu tình trạng tài chính và hoàn tất thủ tục bàn giao học bạ, để đóng trạng thái học tập của học sinh tại trường một cách hợp lệ. |
| **G4-UC-05** | Đơn xin Rút Hồ sơ Học bạ & Chuyển trường | Là Phụ huynh, tôi muốn nộp đơn xin rút hồ sơ học bạ và chuyển trường trực tuyến, để nhà trường tiến hành thủ tục quyết toán công nợ và bàn giao học bạ hợp lệ cho con. |
| **G4-UC-06** | Cập nhật Hồ sơ Sức khỏe & Dị ứng của Trẻ | Là Phụ huynh, tôi muốn ghi nhận thông tin tiền sử bệnh án, dị ứng thực phẩm và cảnh báo y tế đặc thù của trẻ, để nhà trường  phòng ngừa rủi ro cho trẻ. |
| **G4-UC-07** | Đăng ký Dịch vụ Bán trú & Đưa đón Xe buýt | Là Phụ huynh, tôi muốn đăng ký hoặc thay đổi gói dịch vụ ăn bán trú linh hoạt (Toàn phần, Tiêu chuẩn không ăn sáng, hoặc Tùy chọn không ăn chiều) và tuyến xe buýt đưa đón cho con, để nhà trường sắp xếp định mức suất ăn từng bữa và bố trí lộ trình xe phù hợp. |
| **G4-UC-08** | Kích hoạt Tài khoản Ứng dụng Phụ huynh | Là Cán bộ Giáo vụ, tôi muốn khởi tạo và gửi thông tin kích hoạt tài khoản Mobile App cho cha mẹ học sinh, để phụ huynh có thể đăng nhập theo dõi hoạt động và thông tin của con tại trường. |
| **G4-UC-09** | Liên kết Tài khoản Phụ huynh có Nhiều Con | Là Cán bộ Giáo vụ, tôi muốn liên kết hồ sơ của nhiều học sinh là anh chị em ruột vào cùng một tài khoản phụ huynh, để cha mẹ dễ dàng chuyển đổi theo dõi các con trên một tài khoản ứng dụng duy nhất. |

### Phân hệ 5: Điểm danh Đến/Về & Điều phối Đón trả An toàn
| Mã UC (UC-ID) | Tên Use Case | Mô tả Chi tiết Nghiệp vụ |
| :---: | :--- | :--- |
| **G5-UC-01** | Điểm danh Trẻ Đến Lớp Thủ công | Là Giáo viên, tôi muốn tích chọn nhanh trạng thái chuyên cần (Có mặt, Đi muộn, Vắng mặt) của từng trẻ trên ứng dụng, để theo dõi quân số lớp và báo suất ăn cho bếp học đường. |
| **G5-UC-02** | Điểm danh Nhận diện Khuôn mặt (AI) | Là Giáo viên, tôi muốn bật camera AI để hệ thống tự động nhận diện khuôn mặt học sinh khi trẻ bước vào lớp, giúp việc điểm danh diễn ra tức thì, chính xác và không chạm. |
| **G5-UC-03** | Ghi nhận Sức khỏe Lúc Tiếp nhận Trẻ | Là Giáo viên, tôi muốn quan sát và ghi nhận nhanh các biểu hiện sức khỏe bên ngoài của trẻ (mệt mỏi, ho, nốt ban, vết trầy xước/bầm tím có từ nhà) lên hệ thống, để lưu vết tình trạng ban đầu và thông báo ngay cho phụ huynh. |
| **G5-UC-04** | Xác nhận Trẻ Rời Lớp Cuối ngày thủ công | Là Giáo viên, tôi muốn xác nhận trẻ đã rời khỏi lớp học và được bàn giao cho người đón hợp lệ, để quản lý chính xác số lượng học sinh còn lại trong phòng học và tránh thất lạc trẻ. |
| **G5-UC-05** | Ghi nhận Mốc giờ Trẻ Đón Muộn & Tính Phí | Là Giáo viên, tôi muốn hệ thống tự động ghi nhận thời điểm trả trẻ thực tế sau 17:00 và tự động tính phụ phí trông muộn theo quy tắc lũy tiến 30.000 VNĐ/giờ (miễn phí 30 phút đầu của mỗi giờ), để tự động kết chuyển phụ phí vào học phí kỳ tới mà không phải tính toán thủ công. |
| **G5-UC-06** | Xác thực Người Đón AI & Bàn giao Trẻ An toàn | Là Giáo viên, tôi muốn xác thực danh tính người đến đón qua nhận diện khuôn mặt, quét mã QR/PIN, tra cứu thủ công hoặc xử lý trả trẻ sớm, để hệ thống đối chiếu quyền đón hợp lệ, ngăn chặn người lạ và gửi thông báo hoàn tất bàn giao tới gia đình. |
| **G5-UC-07** | Tạo & Quản lý Mã QR Ủy quyền Đón hộ Đột xuất | Là Phụ huynh, tôi muốn tạo nhanh mã QR ủy quyền đón hộ dùng một lần (kèm số điện thoại và ảnh chân dung người đón hộ) và quản lý trạng thái mã trên ứng dụng, để nhờ người quen đón con an toàn khi gia đình có việc bận đột xuất. |
| **G5-UC-08** | Quản lý Vận hành & Chốt An toàn Tuyến Xe Buýt | Là Giáo viên, tôi muốn điểm danh học sinh lên/xuống xe theo các điểm dừng trên lộ trình, đối soát bàn giao trẻ vào lớp (buổi sáng) và chụp ảnh xác nhận khoang xe trống (cả sáng và chiều), để hệ thống quản lý trọn vẹn hành trình đưa đón, giảm thiểu nguy cơ bỏ quên trẻ và lưu lại bằng chứng an toàn minh bạch. |

### Phân hệ 6: An toàn Thực phẩm & Bếp Bán trú Học đường
| Mã UC (UC-ID) | Tên Use Case | Mô tả Chi tiết Nghiệp vụ |
| :---: | :--- | :--- |
| **G6-UC-01** | Lập Kế hoạch Thực đơn Tuần Bán trú | Là Nhân viên Bếp, tôi muốn lập kế hoạch món ăn chi tiết cho từng bữa (sáng, trưa, xế) theo từng khối lớp để đảm bảo khẩu phần dinh dưỡng đạt chuẩn quy định trước khi trình Ban Giám hiệu phê duyệt. |
| **G6-UC-02** | Phê duyệt & Ban hành Thực đơn Tuần | Là Ban Giám hiệu, tôi muốn thẩm định cơ cấu dinh dưỡng, định mức chi phí và tính phong phú của thực đơn tuần do Bếp trình lên, để phê duyệt công bố toàn trường hoặc từ chối kèm lý do yêu cầu Bếp chỉnh sửa kịp thời. |
| **G6-UC-03** | Xem Danh sách Học sinh Dị ứng & Suất Ăn Riêng | Là Nhân viên Bếp, tôi muốn xem danh sách các trẻ có tiền sử dị ứng thực phẩm và yêu cầu ăn kiêng đặc biệt theo từng lớp kèm món ăn thay thế an toàn, để bố trí nấu riêng và gắn thẻ nhận diện khay ăn, ngăn ngừa tuyệt đối nguy cơ sốc phản vệ cho trẻ. |
| **G6-UC-04** | Chốt Suất Ăn Bán Trú theo Bữa & Gói Đăng Ký | Là Nhân viên Bếp, tôi muốn hệ thống tự động bóc tách và chốt số lượng suất ăn cần nấu theo từng bữa (sáng, trưa, xế) dựa trên gói đăng ký ăn của từng học sinh và thời điểm nộp đơn xin nghỉ của phụ huynh (trước 07:00 và trước 08:30 theo BR-027), để chuẩn bị định lượng nấu chính xác, tránh lãng phí bữa sáng và thiếu hụt bữa trưa. |
| **G6-UC-05** | Ghi nhận Sổ Kiểm thực 3 Bước & Lưu Mẫu 24h | Là Nhân viên Bếp, tôi muốn ghi nhận kết quả kiểm tra nguồn gốc thực phẩm nhập kho (Bước 1), kiểm tra vệ sinh nấu nướng (Bước 2), kiểm tra cảm quan trước khi ăn (Bước 3) và lưu mã niêm phong mẫu thức ăn 24 giờ trên cùng một biểu mẫu điện tử, để đáp ứng đầy đủ quy chuẩn Quyết định 1246/QĐ-BYT và sẵn sàng kết xuất tệp PDF phục vụ thanh tra an toàn thực phẩm. |
| **G6-UC-06** | Xem Thực đơn & Ảnh Suất ăn Hàng ngày của Con | Là Phụ huynh, tôi muốn xem chi tiết thực đơn các bữa ăn trong ngày của con kèm định lượng calo và hình ảnh chụp khay cơm thực tế do nhà bếp tải lên, để an tâm về chất lượng dinh dưỡng và vệ sinh an toàn thực phẩm mà con được thụ hưởng tại trường. |

### Phân hệ 7: Chăm sóc Trẻ & Sức khỏe Học đường
| Mã UC (UC-ID) | Tên Use Case | Mô tả Chi tiết Nghiệp vụ |
| :---: | :--- | :--- |
| **G7-UC-01** | Nhập Chỉ số Phát triển Thể chất (Chiều cao, Cân nặng) | Là Giáo viên, tôi muốn nhập số liệu chiều cao và cân nặng của học sinh trong lớp, để hệ thống tự động tính toán chỉ số Z-score theo chuẩn WHO, phân loại thể trạng và cập nhật vào biểu đồ tăng trưởng của trẻ. |
| **G7-UC-02** | Ghi chép Nhật ký Xử lý Sự cố Sơ cứu Y tế | Là Giáo viên, tôi muốn ghi nhận nhanh nhật ký sự vụ y tế, đo thân nhiệt, ghi biện pháp sơ cứu đã áp dụng và phát báo động khẩn cấp tới phụ huynh và giáo vụ, để phối hợp xử lý kịp thời và bảo vệ tính mạng cho trẻ. |
| **G7-UC-03** | Xem Biểu đồ Tăng trưởng Thể chất Chiều cao & Cân nặng | Là Phụ huynh, tôi muốn xem biểu đồ tăng trưởng chiều cao, cân nặng và chỉ số BMI của con theo chuẩn quốc tế WHO từ lúc nhập học đến hiện tại, để theo dõi sự phát triển thể chất và nhận khuyến nghị dinh dưỡng từ nhà trường. |
| **G7-UC-04** | Xem Báo cáo Tổng hợp Sức khỏe Lớp & Toàn trường | Là Cán bộ Giáo vụ, tôi muốn xem dashboard thống kê trực quan về tỷ lệ phát triển thể chất của học sinh và kết xuất Sổ theo dõi thể lực định kỳ theo mẫu chuẩn Bộ GD&ĐT, để chủ động can thiệp dinh dưỡng và phục vụ công tác thanh kiểm tra y tế học đường. |

### Phân hệ 8: Quyết toán Học phí & Cổng VietQR
| Mã UC (UC-ID) | Tên Use Case | Mô tả Chi tiết Nghiệp vụ |
| :---: | :--- | :--- |
| **G8-UC-01** | Thiết lập Danh mục Khoản thu Học phí | Là Kế toán Trường học, tôi muốn cấu hình các danh mục khoản thu trong năm học/học kỳ (Học phí, Tiền ăn, Bán trú, Tuyến xe buýt, CLB ngoại khóa...), để làm cơ sở tính học phí tự động cho toàn bộ học sinh theo khối lớp. |
| **G8-UC-02** | Phê duyệt Cấu hình Khoản thu Học phí | Là Ban Giám hiệu, tôi muốn thẩm định và phê duyệt danh mục các khoản thu học phí cùng đơn giá quy định do Kế toán thiết lập, để chính thức ban hành biểu phí cho toàn trường hoặc yêu cầu điều chỉnh nếu chưa hợp lý. |
| **G8-UC-03** | Cấu hình Chính sách Miễn giảm Học phí | Là Kế toán Trường học, tôi muốn thiết lập các quy định miễn giảm học phí theo từng nhóm đối tượng học sinh (Con cán bộ giáo viên, diện chính sách, có anh em ruột học cùng, học bổng...), để hệ thống tự động khấu trừ chính xác số tiền cần thu hàng tháng. |
| **G8-UC-04** | Lập Bảng Tính Học phí Tháng Dự thu | Là Kế toán Trường học, tôi muốn hệ thống tự động tổng hợp danh sách học sinh và tính toán các khoản học phí, tiền ăn, phụ phí và miễn giảm, để lập dự thảo bảng học phí toàn trường trình Ban Giám hiệu phê duyệt. |
| **G8-UC-05** | Thêm Khoản Thu / Khoản Phạt Phát sinh | Là Kế toán Trường học, tôi muốn thêm các khoản thu phát sinh ngoài kế hoạch (đền bù hư hỏng tài sản, mua bổ sung đồng phục/balo...) cho từng học sinh cụ thể, để tổng hợp đầy đủ vào phiếu báo học phí của tháng. |
| **G8-UC-06** | Phê duyệt Bảng Tổng hợp Học phí Toàn trường | Là Ban Giám hiệu, tôi muốn rà soát và phê duyệt bảng tổng hợp học phí toàn trường do Kế toán lập, để chính thức ban hành số liệu thu học phí và cho phép phát hành phiếu báo tới phụ huynh. |
| **G8-UC-07** | Phát hành Thông báo Học phí tới Phụ huynh | Là Kế toán Trường học, tôi muốn phát hành phiếu báo học phí tháng kèm thời hạn thanh toán đến từng tài khoản phụ huynh qua ứng dụng di động, để phụ huynh nắm được chi tiết các khoản cần đóng và tiến hành thanh toán đúng hạn. |
| **G8-UC-08** | Xem Chi tiết Phiếu báo Học phí Tháng | Là Phụ huynh, tôi muốn xem chi tiết bảng kê các khoản thu học phí tháng, các khoản giảm trừ tiền ăn và số tiền thực tế phải nộp của từng con, để nắm rõ cơ sở tính tiền trước khi thanh toán. |
| **G8-UC-09** | Thanh toán Học phí qua Quét mã VietQR Động | Là Phụ huynh, tôi muốn quét hoặc lưu mã VietQR động có sẵn số tiền và nội dung chuyển khoản chuẩn, để thanh toán học phí nhanh chóng và được hệ thống tự động gạch nợ tức thì mà không cần nộp biên lai giấy. |
| **G8-UC-10** | Ghi nhận Thu Học phí Tiền mặt Thủ công | Là Kế toán Trường học, tôi muốn ghi nhận khoản thu học phí bằng tiền mặt và gạch nợ thủ công trên hệ thống, để cập nhật trạng thái đã nộp tiền cho học sinh và xuất phiếu thu tiền mặt ngay tại chỗ. |
| **G8-UC-11** | Xuất Hóa đơn Điện tử & Biên lai Thu tiền | Là Kế toán Trường học (hoặc Phụ huynh), tôi muốn xuất biên lai thu tiền / hóa đơn điện tử định dạng PDF có mã số thuế và chữ ký số của nhà trường, để lưu trữ làm chứng từ kế toán hợp lệ hoặc cung cấp cho cơ quan thanh quyết toán. |
| **G8-UC-12** | Xem Báo cáo Doanh thu & Công nợ Quá hạn | Là Ban Giám hiệu, tôi muốn xem báo cáo tổng hợp tiến độ thu học phí toàn trường, tỷ lệ nợ đọng theo khối lớp và danh sách chi tiết các phụ huynh chưa hoàn tất nghĩa vụ nộp tiền, để có biện pháp đôn đốc thu nợ và cân đối dòng tiền trường học. |

### Phân hệ 9: Hoạt động Giáo dục, Ngoại khóa & Cơ sở Vật chất
| Mã UC (UC-ID) | Tên Use Case | Mô tả Chi tiết Nghiệp vụ |
| :---: | :--- | :--- |
| **G9-UC-01** | Mở Lớp Câu lạc bộ Ngoại khóa | Là Ban Giám hiệu, tôi muốn khởi tạo các lớp năng khiếu (Vẽ, Múa, Võ thuật, Tiếng Anh...) kèm chỉ tiêu sĩ số, học phí và lịch học, để công bố cho phụ huynh đăng ký cho trẻ. |
| **G9-UC-02** | Phân công Giáo viên Phụ trách Câu lạc bộ | Là Cán bộ Giáo vụ, tôi muốn phân công giáo viên cơ hữu hoặc cộng tác viên năng khiếu phụ trách từng lớp CLB, để giáo viên tiếp nhận danh sách học sinh và thực hiện giảng dạy. |
| **G9-UC-03** | Đăng ký Tham gia Câu lạc bộ Ngoại khóa | Là Phụ huynh, tôi muốn chọn và đăng ký các môn năng khiếu phù hợp với sở thích của con, để con phát triển toàn diện và hệ thống tự động ghi nhận học phí vào kỳ thu tới. |
| **G9-UC-04** | Đánh giá Trẻ theo Chuẩn Phát triển 5 Lĩnh vực | Là Giáo viên Chủ nhiệm, tôi muốn chấm điểm và nhận xét chỉ số phát triển của trẻ theo 5 lĩnh vực (Thể chất, Nhận thức, Ngôn ngữ, Tình cảm - Kỹ năng xã hội, Thẩm mỹ) chuẩn Bộ GD&ĐT, để lập phiếu theo dõi sự phát triển gửi BGH duyệt. |
| **G9-UC-05** | Phê duyệt Phiếu Đánh giá Trẻ Định kỳ | Là Ban Giám hiệu, tôi muốn rà soát và phê duyệt phiếu đánh giá phát triển của học sinh, để bảo đảm tính chuẩn mực sư phạm trước khi công bố trên Sổ liên lạc điện tử cho phụ huynh. |
| **G9-UC-06** | Quản lý Danh mục Thiết bị & Đồ chơi Mầm non | Là Cán bộ Giáo vụ hoặc Ban Giám hiệu, tôi muốn quản lý danh mục đồ dùng, giáo cụ, đồ chơi mầm non phân bổ theo từng phòng học, để theo dõi hiện trạng sử dụng và hao mòn tài sản. |
| **G9-UC-07** | Báo cáo Hư hỏng Cơ sở Vật chất Lớp | Là Giáo viên, tôi muốn gửi phiếu báo cáo sự cố hư hỏng kèm hình ảnh hiện trường, để bộ phận Hậu cần và Ban Giám hiệu kịp thời sửa chữa, thay thế, đảm bảo an toàn cho trẻ. |
| **G9-UC-08** | Soạn Thảo & Nộp Kế hoạch Giáo án Tuần | Là Giáo viên, tôi muốn soạn thảo và nộp kế hoạch giáo án điện tử theo chủ đề 4 tuần lên hệ thống, để Ban Giám hiệu kiểm duyệt nội dung trước khi đưa vào giảng dạy. |
| **G9-UC-09** | Phê duyệt Kế hoạch Giáo án Tuần | Là Ban Giám hiệu, tôi muốn thẩm tra nội dung bài giảng và phê duyệt kế hoạch giáo án của các khối lớp, để đảm bảo chất lượng giảng dạy và chuẩn mực sư phạm trước khi tháng bắt đầu |
| **G9-UC-10** | Xuất Báo cáo Đánh giá Chất lượng Phát triển của Trẻ | Là Ban Giám hiệu, tôi muốn kết xuất báo cáo thống kê tỷ lệ đạt chuẩn theo 5 lĩnh vực phát triển theo từng độ tuổi và toàn trường, để nộp cơ quan quản lý Giáo dục và đánh giá hiệu quả giảng dạy. |

### Phân hệ 10: Sổ Liên Lạc Điện Tử & Chăm Sóc Thường Nhật
| Mã UC (UC-ID) | Tên Use Case | Mô tả Chi tiết Nghiệp vụ |
| :---: | :--- | :--- |
| **G10-UC-01** | Tạo Đơn Dặn Uống Thuốc Trực tuyến | Là Phụ huynh, tôi muốn tạo đơn dặn thuốc trực tuyến với đầy đủ thông tin chỉ định y khoa và thời gian dùng thuốc, để giáo viên tiếp nhận và cho con uống thuốc đúng quy định an toàn y tế học đường. |
| **G10-UC-02** | Tiếp nhận & Đối chiếu Thuốc Phụ huynh Gửi | Là Giáo viên, tôi muốn đối chiếu thuốc thực tế phụ huynh gửi với đơn dặn thuốc trên ứng dụng, kiểm tra nhãn định danh và xác nhận tiếp nhận, để đảm bảo không nhận nhầm thuốc và an toàn trước khi cho trẻ uống. |
| **G10-UC-03** | Xác nhận Cho Trẻ Uống Thuốc Kèm Ảnh Chụp | Là Giáo viên, tôi muốn nhận cảnh báo nhắc giờ tự động, lấy đúng thuốc của trẻ, đối chiếu liều lượng và chụp ảnh xác nhận quá trình trẻ uống thuốc để gửi báo cáo tức thì cho phụ huynh, nhằm đảm bảo đúng thuốc, đúng liều, đúng giờ và minh bạch trách nhiệm y tế. |
| **G10-UC-04** | Ghi nhận Nhật ký Giấc ngủ & Vệ sinh Hằng ngày | Là Giáo viên, tôi muốn ghi nhận nhanh tình trạng ngủ trưa và nhật ký vệ sinh của trẻ trong ngày, để phụ huynh nắm bắt thói quen sinh hoạt và phát hiện sớm bất thường tiêu hóa của con. |
| **G10-UC-05** | Trao đổi Tin nhắn Trực tiếp giữa Phụ huynh và Giáo viên | Là Phụ huynh (hoặc Giáo viên), tôi muốn nhắn tin trực tiếp và gửi hình ảnh trao đổi riêng 1-1 với cô giáo, để cập nhật thói quen, tâm lý, sức khỏe của con một cách bảo mật. |
| **G10-UC-06** | Xem Nhật ký & Album Ảnh của Con | Là Phụ huynh, tôi muốn xem ảnh sinh hoạt thường nhật của con, thả tim, bình luận và tải ảnh chất lượng cao về máy, để lưu giữ kỷ niệm tuổi thơ của con. |
| **G10-UC-07** | Xem Phiếu Đánh giá Sự Phát triển của Trẻ | Là Phụ huynh, tôi muốn xem chi tiết phiếu đánh giá 5 lĩnh vực phát triển và nhận xét của cô giáo về con, để hiểu rõ điểm mạnh, điểm cần rèn luyện thêm của con tại nhà. |
| **G10-UC-08** | Nộp Đơn Xin Nghỉ Học Trực Tuyến | Là Phụ huynh, tôi muốn nộp đơn xin nghỉ học trực tuyến, để giáo viên chủ nhiệm nắm bắt sĩ số và trường tự động hoàn tiền ăn theo quy định. |
| **G10-UC-09** | Tiếp nhận & Phê duyệt Đơn Xin Nghỉ Học | Là Giáo viên Chủ , tôi muốn xem xét lý do và phê duyệt đơn xin nghỉ học của phụ huynh trước 08:30 sáng, để hệ thống tự động cập nhật sĩ số báo ăn với Nhà bếp và làm căn cứ hoàn tiền ăn. |

### Phân hệ 11: Cổng Truyền Thông Nhà Trường, Tương Tác Lớp Học & Khảo Sát
| Mã UC (UC-ID) | Tên Use Case | Mô tả Chi tiết Nghiệp vụ |
| :---: | :--- | :--- |
| **G11-UC-01** | Soạn thảo & Đăng Thông báo Toàn trường | Là Ban Giám hiệu hoặc Cán bộ Giáo vụ, tôi muốn đăng thông báo chung (Lịch nghỉ lễ, Kế hoạch tiêm chủng, Hoạt động dã ngoại...) gửi đến toàn thể phụ huynh và giáo viên, để thông tin được truyền tải nhanh chóng và chính xác. |
| **G11-UC-02** | Đăng Thông báo Riêng của Lớp | Là Giáo viên Chủ nhiệm, tôi muốn đăng thông báo nội bộ của lớp (chuẩn bị trang phục, mang đồ dùng học tập, họp phụ huynh lớp...), để toàn bộ phụ huynh trong lớp nắm bắt kịp thời. |
| **G11-UC-03** | Phát Tin nhắn Thông báo Khẩn cấp | Là Ban Giám hiệu, tôi muốn phát thông báo khẩn cấp có mức ưu tiên cao nhất tới toàn bộ phụ huynh và giáo viên, để đảm bảo an toàn tuyệt đối cho học sinh và điều phối xử lý kịp thời. |
| **G11-UC-04** | Tạo & Quản lý Nhóm Chat Chung của Lớp | Là Giáo viên ,tôi muốn tham gia không gian thảo luận nhóm của toàn thể phụ huynh trong lớp, để cùng nhau trao đổi các hoạt động chung của lớp học. |
| **G11-UC-05** | Đăng Album Ảnh & Hoạt động Học tập của Lớp | Là Giáo viên, tôi muốn tạo album ảnh theo ngày hoặc theo sự kiện và gắn thẻ học sinh có mặt, để phụ huynh theo dõi khoảnh khắc thực tế của con tại trường. |
| **G11-UC-06** | Tạo Phiếu Khảo sát & Thu thập Ý kiến Phụ huynh | Là Cán bộ Giáo vụ, tôi muốn tạo phiếu khảo sát trực tuyến với các câu hỏi đánh giá dịch vụ (chất lượng bữa ăn, thái độ giáo viên, cơ sở vật chất...), để lắng nghe phản hồi của phụ huynh nhằm nâng cao chất lượng trường học. |
| **G11-UC-07** | Làm Phiếu Khảo sát Đánh giá Trường học | Là Phụ huynh, tôi muốn trả lời các câu hỏi đánh giá và gửi đóng góp ý kiến trực tuyến, để bày tỏ nguyện vọng và giúp nhà trường cải tiến chất lượng chăm sóc, nuôi dưỡng con. |
| **G11-UC-08** | Đăng Bản tin Y tế Học đường & Dịch bệnh | Là Cán bộ Giáo , tôi muốn đăng bản tin tuyên truyền y tế và cảnh báo dịch bệnh, để phụ huynh chủ động theo dõi triệu chứng và phòng bệnh cho trẻ tại gia đình. |

---

## 5. Database Architecture & Business Entity Mapping (Lược đồ Cơ sở Dữ liệu NewDB2)
Cơ sở dữ liệu KIDPRO được thiết kế chuẩn hóa trên hệ quản trị **PostgreSQL 16**, phân tách thành **7 Schemas logic độc lập** gồm **50 Bảng dữ liệu** và tích hợp tiện ích mở rộng **`pgvector`** phục vụ trí tuệ nhân tạo:

### 5.1. Bảng Tổng hợp 7 Schemas & 50 Bảng Dữ liệu

#### Schema `identity` (6 Bảng)
| Tên Bảng (Table Name) | Ý nghĩa Nghiệp vụ & Dữ liệu Lưu trữ |
| :--- | :--- |
| `identity.file` | Quản lý tập trung các tệp tin đính kèm, ảnh chân dung, ảnh mẫu sinh trắc học, hóa đơn, tài liệu. |
| `identity.account` | Tài khoản người dùng hệ thống, lưu trữ mã băm mật khẩu Argon2id/BCrypt, SĐT định danh, email và vai trò. |
| `identity.admin` | Thông tin định danh quản trị viên nền tảng và Ban Giám hiệu. |
| `identity.parent` | Thông tin hồ sơ phụ huynh đại diện chính (họ tên, CCCD, địa chỉ, nghề nghiệp). |
| `identity.staff` | Hồ sơ cán bộ giáo viên nhân viên (mã nhân sự, phòng ban, trình độ chuyên môn, ngày vào làm). |
| `identity.audit_log` | Nhật ký kiểm toán an toàn hệ thống, ghi nhận thao tác CRUD, địa chỉ IP và dữ liệu cũ/mới (JSONB). |

#### Schema `academic` (8 Bảng)
| Tên Bảng (Table Name) | Ý nghĩa Nghiệp vụ & Dữ liệu Lưu trữ |
| :--- | :--- |
| `academic.academic_years` | Danh mục niên khóa và cấu hình thời gian các học kỳ I, học kỳ II. |
| `academic.classroom` | Danh mục phòng học cơ sở vật chất, sức chứa, tòa nhà. |
| `academic.classes` | Danh sách các lớp học chính khóa, khối lớp (INFANT, TODDLER, NURSERY, KINDERGARTEN), sĩ số tối đa. |
| `academic.timetable` | Khung thời khóa biểu hoạt động trong tuần của lớp học. |
| `academic.classroom_journal_post` | Bài đăng nhật ký hoạt động của lớp học kèm tệp tin hình ảnh/video. |
| `academic.extracurricular_class` | Các lớp câu lạc bộ ngoại khóa năng khiếu (Vẽ, Múa, Võ, Tiếng Anh...). |
| `academic.teacher_class_assignment` | Phân công giáo viên chủ nhiệm, giáo viên phụ tá hoặc giáo viên dạy ngoại khóa. |
| `academic.student_extracurricular_register` | Bản ghi đăng ký tham gia lớp học ngoại khóa của học sinh. |

#### Schema `student` (12 Bảng)
| Tên Bảng (Table Name) | Ý nghĩa Nghiệp vụ & Dữ liệu Lưu trữ |
| :--- | :--- |
| `student.student` | Hồ sơ học sinh mầm non (mã học sinh, họ tên, ngày sinh, giới tính, liên kết phụ huynh chính 1-N). |
| `student.student_guardian` | Danh sách người đón ủy quyền hợp lệ / giám hộ phụ của học sinh (ông, bà, người thân). |
| `student.attendances` | Bảng điểm danh chuyên cần hàng ngày (trạng thái Có mặt, Vắng có phép, Vắng không phép, Đi muộn). |
| `student.attendance_photos` | Lưu trữ URL và siêu dữ liệu ảnh snapshot chụp thực tế khi điểm danh lúc đến và về. |
| `student.face_encoding_file` | Lưu trữ ảnh mẫu chuẩn và Vector đặc trưng khuôn mặt 512 chiều (face_embedding vector(512)). |
| `student.face_recognition_logs` | Nhật ký nhận diện AI đối chiếu giữa ảnh chụp thực tế và vector mẫu, điểm tin cậy confidence score. |
| `student.leave_requests` | Đơn xin nghỉ học của phụ huynh gửi giáo viên chủ nhiệm phê duyệt. |
| `student.class_transfer_request` | Đơn xin chuyển lớp cho học sinh giữa các lớp trong cùng khối. |
| `student.emergency_pickup_authorization` | Ủy quyền đón hộ đột xuất có hiệu lực 60 phút, mã QR bảo mật và mã OTP 6 số. |
| `student.daily_activities` | Nhật ký sinh hoạt hằng ngày gộp (Lượng ăn 4 bữa, chất lượng giấc ngủ trưa, nhật ký tiêu hóa/vệ sinh). |
| `student.development_evaluation` | Phiếu đánh giá sự phát triển của trẻ theo chuẩn 5 lĩnh vực mầm non (Bộ GD&ĐT). |
| `student.other_requests` | Các đơn từ, phiếu kiến nghị hoặc yêu cầu hành chính khác của phụ huynh. |

#### Schema `health` (5 Bảng)
| Tên Bảng (Table Name) | Ý nghĩa Nghiệp vụ & Dữ liệu Lưu trữ |
| :--- | :--- |
| `health.allergy_alert` | Cảnh báo tiền sử dị ứng của trẻ (loại dị ứng thức ăn, thuốc, thời tiết; mức độ nghiêm trọng). |
| `health.health_metrics` | Chỉ số đo thể chất định kỳ (chiều cao, cân nặng, chỉ số BMI, phân loại Z-score chuẩn WHO). |
| `health.health_incidents` | Nhật ký ghi chép sự cố sơ cứu y tế học đường, đo thân nhiệt và biện pháp xử lý sơ cấp cứu. |
| `health.medication_request` | Đơn phụ huynh dặn cho trẻ uống thuốc tại trường kèm ảnh chụp đơn thuốc của bác sĩ. |
| `health.medication_admin_log` | Nhật ký giáo viên cho trẻ uống thuốc kèm ảnh chụp làm chứng thực tế. |

#### Schema `catering` (4 Bảng)
| Tên Bảng (Table Name) | Ý nghĩa Nghiệp vụ & Dữ liệu Lưu trữ |
| :--- | :--- |
| `catering.weekly_menus` | Danh mục thực đơn bán trú theo tuần của năm học. |
| `catering.menu_item` | Chi tiết các món ăn theo từng bữa (sáng, phụ sáng, trưa, xế), ngày trong tuần và định lượng calo. |
| `catering.meal_headcount_snapshot` | Bản snapshot chốt số lượng suất ăn cần nấu 2 đợt (07:00 AM bữa sáng và 08:30 AM bữa trưa/xế). |
| `catering.food_sample_retention_log` | Sổ kiểm thực 3 bước và lưu mẫu thức ăn 24 giờ (khối lượng 100-150g, nhiệt độ 2-8 độ C). |

#### Schema `finance` (10 Bảng)
| Tên Bảng (Table Name) | Ý nghĩa Nghiệp vụ & Dữ liệu Lưu trữ |
| :--- | :--- |
| `finance.service` | Danh mục các dịch vụ học đường (học phí, tiền ăn bán trú, xe buýt, câu lạc bộ ngoại khóa). |
| `finance.discount_policy` | Chính sách miễn giảm học phí (con giáo viên, diện chính sách, học sinh thứ hai trong gia đình). |
| `finance.bus` | Danh mục xe buýt trường học, tài xế, số điện thoại, sức chứa và lộ trình đón trả. |
| `finance.teacher_bus_assignment` | Phân công giáo viên giám sát xe buýt và kiểm tra xác nhận khoang xe trống an toàn. |
| `finance.student_discount` | Bảng áp dụng chính sách miễn giảm cụ thể cho từng học sinh. |
| `finance.student_bus_register` | Học sinh đăng ký dịch vụ xe buýt (loại 2 chiều, 1 chiều sáng hoặc 1 chiều chiều). |
| `finance.invoice` | Hóa đơn học phí tháng của học sinh (tổng tiền, miễn giảm, số tiền thực nộp, chuỗi mã VietQR thanh toán). |
| `finance.invoice_item` | Chi tiết từng dòng khoản thu trong hóa đơn học phí (tiền học, tiền ăn, hoàn trả tiền ăn, phụ phí đón muộn). |
| `finance.payment_transaction` | Lịch sử giao dịch thanh toán thành công qua cổng VietQR PayOS, chuyển khoản hoặc tiền mặt. |
| `finance.payment_dispute` | Phiếu khiếu nại sai lệch học phí do phụ huynh gửi yêu cầu kế toán đối soát xử lý. |

#### Schema `communication` (4 Bảng)
| Tên Bảng (Table Name) | Ý nghĩa Nghiệp vụ & Dữ liệu Lưu trữ |
| :--- | :--- |
| `communication.daily_message` | Kênh tin nhắn trao đổi bảo mật 1-1 giữa giáo viên chủ nhiệm và phụ huynh. |
| `communication.notifications` | Hộp thư thông báo đẩy cá nhân hóa gửi đến tài khoản người dùng. |
| `communication.announcements` | Bảng tin thông báo chung toàn trường hoặc thông báo nội bộ của lớp học. |
| `communication.announcement_views` | Theo dõi danh sách và thời điểm người dùng đã xem thông báo. |

### 5.2. Cấu trúc Lưu trữ Vector Đặc trưng Khuôn mặt 512 chiều (`pgvector`)
Hệ thống sử dụng tiện ích mở rộng `pgvector` trên bảng `student.face_encoding_file` để tối ưu hóa việc nhận diện sinh trắc học:
```sql
-- 1. Kích hoạt extension pgvector
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;

-- 2. Bảng lưu trữ vector đặc trưng khuôn mặt
CREATE TABLE student.face_encoding_file (
    face_file_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    person_type student.recognized_person_type NOT NULL DEFAULT 'STUDENT',
    student_id UUID REFERENCES student.student(student_id) ON DELETE CASCADE,
    parent_id UUID REFERENCES identity.parent(parent_id) ON DELETE CASCADE,
    guardian_id BIGINT REFERENCES student.student_guardian(guardian_id) ON DELETE CASCADE,
    photo_url TEXT NOT NULL,
    storage_path TEXT,
    file_size BIGINT,
    face_embedding vector(512), -- Vector đặc trưng 512 chiều trích xuất từ InsightFace ArcFace
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_face_encoding_owner CHECK (
        (student_id IS NOT NULL AND parent_id IS NULL AND guardian_id IS NULL) OR
        (student_id IS NULL AND parent_id IS NOT NULL AND guardian_id IS NULL) OR
        (student_id IS NULL AND parent_id IS NULL AND guardian_id IS NOT NULL)
    )
);

-- 3. Tạo chỉ mục HNSW Cosine Distance siêu nhanh
CREATE INDEX idx_face_embedding_hnsw
    ON student.face_encoding_file
    USING hnsw (face_embedding vector_cosine_ops)
    WHERE is_active = TRUE;
```

---

## 6. Screen Architecture & Role Authorization Matrix (Hệ thống Màn hình & Phân quyền RBAC)
Hệ thống bao gồm **74 Màn hình Web Admin Portal** và **80 Màn hình Mobile App & Trạm Vận hành** được phân quyền chặt chẽ theo 7 vai trò người dùng:
*   `[SA]` : Platform Super Admin (Quản trị viên Nền tảng)
*   `[PR]` : Board of Directors / Principal (Ban Giám hiệu)
*   `[AA]` : Academic Affairs Officer (Cán bộ Giáo vụ)
*   `[AC]` : School Accountant (Kế toán)
*   `[TE]` : Preschool Teacher (Giáo viên)
*   `[KI]` : Kitchen Staff (Nhân viên Bếp)
*   `[PA]` : Parent (Phụ huynh)

### 6.1. Phân bổ Nhóm Màn hình Web Admin Portal (74 Màn hình)
1.  **Platform Administration Desk (Screens 1 - 16):** Đăng nhập Admin, Dashboard giám sát KPI nền tảng, Quản lý các trường mầm non (Tenants), Phân quyền vai trò RBAC, Cấu hình API tích hợp (PayOS, FCM, AI), Nhật ký kiểm toán bảo mật.
2.  **School Principal Desk - BGH (Screens 17 - 30):** Dashboard điều hành Ban Giám hiệu, Cấu hình niên khóa/học kỳ, Duyệt định mức sĩ số & mở lớp, Phê duyệt chính sách học phí, Duyệt giáo án tuần, Phê duyệt thực đơn bán trú, Giám sát dòng tiền và Phát thông báo khẩn cấp toàn trường.
3.  **Academic Affairs Desk - Giáo vụ (Screens 31 - 56):** Dashboard tuyển sinh tiếp nhận học sinh, Phân chia xếp lớp, Lập thời khóa biểu tuần (Drag-and-Drop), Phê duyệt hồ sơ người đón ủy quyền, Xử lý chuyển lớp/rút học bạ và Quản lý cơ sở vật chất phòng học.
4.  **School Accountant Desk - Kế toán (Screens 57 - 74):** Dashboard tài chính, Cấu hình danh mục khoản thu & chính sách miễn giảm, Chạy bảng tính học phí động tháng, Đối soát webhook VietQR PayOS, Quản lý bàn thu tiền mặt thủ công, Xử lý khiếu nại học phí và Kết xuất hóa đơn điện tử PDF.

### 6.2. Phân bổ Nhóm Màn hình Mobile App & Trạm Vận hành (80 Màn hình)
1.  **Class Teacher Mobile App (Screens 75 - 109):** Dashboard lớp học, Điểm danh nhận diện khuôn mặt camera AI, Điểm danh thủ công fallback, Ghi nhận sức khỏe đầu ngày, Quét khuôn mặt xác thực người đón tại cổng, Cảnh báo người lạ, Ghi nhận trả trẻ muộn sau 17:00, Tiếp nhận đơn thuốc và chụp ảnh khi cho uống thuốc, Đăng album ảnh hoạt động lớp, Nhắn tin 1-1 với phụ huynh, Chấm điểm 5 lĩnh vực phát triển.
2.  **Parent Mobile App (Screens 110 - 142):** Dashboard phụ huynh, Hồ sơ y tế & cảnh báo dị ứng của con, Đăng ký ảnh khuôn mặt chuẩn cho con, Khai báo người đón ủy quyền hợp lệ, Tạo mã QR ủy quyền đón hộ đột xuất 60 phút, Nộp đơn xin nghỉ học trực tuyến, Gửi đơn dặn thuốc, Dòng thời gian sinh hoạt của con (ăn, ngủ, học), Bảng kê học phí chi tiết và Thanh toán 1 chạm qua mã VietQR động, Quyền yêu cầu xóa dữ liệu sinh trắc học theo Nghị định 13.
3.  **Kitchen Staff Tablet/Operations Station (Screens 143 - 153):** Dashboard bếp ăn bán trú, Lịch thực đơn tuần và định lượng calo, Cảnh báo danh sách trẻ dị ứng & xuất nhãn khay ăn riêng, Màn hình theo dõi chốt suất ăn bán trú đợt 1 (07:00) và đợt 2 (08:30), Biểu mẫu điện tử Sổ kiểm thực 3 bước và Quản lý lưu mẫu thức ăn 24 giờ.

---

## 7. Core Business Rules (70 Quy tắc Nghiệp vụ Cốt lõi BR-001 đến BR-070)
| Mã BR | Tên Quy tắc Nghiệp vụ | Nội dung Đặc tả Chi tiết |
| :---: | :--- | :--- |
| **BR-001** | Quy chuẩn Xác thực & Bảo mật Mật khẩu Đăng nhập | Người dùng hệ thống bắt buộc thiết lập mật khẩu tối thiểu 8 ký tự bao gồm chữ hoa, chữ thường, số và ký tự đặc biệt; hệ thống tự động khóa tài khoản 15 phút nếu nhập sai quá 5 lần liên tiếp. |
| **BR-002** | Quy tắc Khởi tạo & Phân quyền Vai trò | Mã vai trò và tên vai trò không được phép trùng lặp trong hệ thống; mỗi vai trò mới khởi tạo bắt buộc phải được gán tối thiểu 01 quyền hạn chức năng. |
| **BR-003** | Bất biến Dữ liệu Nhật ký Hệ thống & Quản trị | Dữ liệu nhật ký lỗi hệ thống, nhật ký hoạt động và nhật ký thao tác quản trị chỉ được phép tra cứu, tuyệt đối không được sửa đổi, ghi đè hoặc xóa bỏ dưới mọi hình thức. |
| **BR-004** | Quy định Thời gian & Tính Không Chồng lấn của Năm học | Ngày kết thúc năm học/học kỳ bắt buộc phải sau ngày bắt đầu; khoảng thời gian năm học mới không được phép chồng lấn với bất kỳ năm học nào đang áp dụng. |
| **BR-005** | Quy định Định mức Sĩ số & Đặt tên Duy nhất | Sĩ số học sinh không được vượt quá định mức tối đa từng khối lớp (Nhà trẻ: 24-26; Mầm-Chồi-Lá: 30-35); mã phòng học, tên phòng và tên lớp học phải là duy nhất. |
| **BR-006** | Quản lý Hồ sơ Nhân sự, Định danh & Chống Tự khóa | Mỗi nhân sự có SĐT duy nhất để định danh; nhân sự thuộc Ban Giám hiệu tuyệt đối không được phép tự khóa tài khoản của chính mình trên hệ thống. |
| **BR-007** | Thẩm quyền Phê duyệt & Kích hoạt Lớp học Mới | Chỉ Ban Giám hiệu mới có quyền phê duyệt kế hoạch mở lớp; kế hoạch sau khi được duyệt sẽ tự động kích hoạt trạng thái sẵn sàng tiếp nhận học sinh. |
| **BR-008** | Quy định Giáo viên Chủ nhiệm Duy nhất & Chống Trùng lịch | Mỗi lớp học tại một thời điểm chỉ có đúng 01 Giáo viên Chủ nhiệm; hệ thống tuyệt đối không cho phép xếp cùng một giáo viên hoặc một phòng học trùng khung giờ. |
| **BR-009** | Quy định Kết chuyển Học sinh Niên khóa Mới | Học sinh hoàn thành năm học được tự động nâng lên khối lớp liền kề; học sinh khối Lá hoàn thành chương trình được chuyển trạng thái Ra trường/Tốt nghiệp. |
| **BR-010** | Bảo toàn & Lưu trữ Hồ sơ Lớp học Đã Đóng | Cán bộ Giáo vụ chỉ được đóng và lưu trữ lớp học khi toàn bộ học sinh đã hoàn tất kết chuyển hoặc chuyển trạng thái; hồ sơ lớp đã đóng là bất biến. |
| **BR-011** | Tiêu chuẩn Độ tuổi & Ảnh Sinh trắc học Tiếp nhận Trẻ | Học sinh nhập học phải đủ từ 12 đến 72 tháng tuổi; ảnh sinh trắc học bắt buộc chụp thẳng mặt, rõ nét, phông nền sáng, định dạng JPG/PNG dung lượng tối đa 5MB. |
| **BR-012** | Quy định Số lượng & Vô hiệu hóa Quyền Đón Ủy quyền | Mỗi học sinh được đăng ký tối đa không quá 03 người đón ủy quyền hợp lệ; khi phụ huynh thu hồi quyền đón, hệ thống lập tức vô hiệu hóa trên toàn mạng lưới. |
| **BR-013** | Kích hoạt Dữ liệu Nhận diện Sinh trắc học Học sinh | Dữ liệu khuôn mặt của học sinh chỉ được hệ thống tự động kích hoạt vào danh sách nhận diện điểm danh sau khi hồ sơ nhập học được Ban Giám hiệu phê duyệt chính thức. |
| **BR-014** | Cảnh báo Bắt buộc Tiền sử Dị ứng Thực phẩm | Mọi học sinh có tiền sử dị ứng thực phẩm bắt buộc phải có thông tin cảnh báo hiển thị trên hồ sơ sức khỏe và tự động đồng bộ sang Bếp bán trú và Giáo viên chủ nhiệm. |
| **BR-015** | Khống chế Sức chứa & Hạn mức Xe buýt Học đường | Hệ thống không cho phép đăng ký dịch vụ đưa đón xe buýt khi số lượng học sinh đăng ký trên tuyến đã đạt sức chứa tối đa theo thiết kế của xe. |
| **BR-016** | Định danh & Liên kết Đa con Tài khoản Phụ huynh | Mỗi số điện thoại phụ huynh là mã định danh duy nhất; hệ thống cho phép liên kết nhiều hồ sơ học sinh là con cùng một gia đình vào chung một tài khoản quản lý. |
| **BR-017** | Thẩm quyền Chuyển lớp, Rút hồ sơ & Quyết toán Phí | Ban Giám hiệu là cấp duy nhất có thẩm quyền phê duyệt đơn xin chuyển lớp hoặc rút hồ sơ thôi học; hồ sơ thôi học chuyển trạng thái bất biến và tự động kích hoạt tính toán hoàn phí. |
| **BR-018** | Khung giờ Chốt Điểm danh Bán trú & Điều kiện Hoàn tiền | Khung giờ chốt báo ăn bán trú kết thúc vào đúng 7:00 sáng với gói ăn bán trú hoàn toàn (sáng, trưa, xế)và với 08:30 sáng mỗi ngày với gói ăn bán trú(trưa và xế); ngày nghỉ có phép báo trước 2 mốc thời gian 7:00 và 08:30 ở 2 gói bán trú mới được hệ thống ghi nhận tính giảm trừ tiền ăn. |
| **BR-019** | Điểm danh Sinh trắc học AI & Ghi nhận Sức khỏe Đầu ngày | Hệ thống tự động nhận diện điểm danh trẻ với độ chính xác trên 85%; chống điểm danh trùng lặp trong 10 phút; bắt buộc ghi nhận biểu hiện sức khỏe nếu thân nhiệt > 37.5°C. |
| **BR-020** | Quy tắc Bàn giao Trẻ An toàn & Tính Phí Đón Muộn Lũy tiến | Giáo viên chỉ được phép bàn giao trẻ cho người đón hợp lệ; thời gian đón trẻ sau 17:30 được tự động tính phí lũy tiến theo từng block đưa vào bảng học phí. Ví dụ 17h tan thì sau 17h30 mới tính phí của giờ đầu. |
| **BR-021** | Xác thực Sinh trắc học Người Đón & Xử lý Người Lạ Nghi vấn | Hệ thống đối chiếu khuôn mặt người đón với cơ sở dữ liệu ủy quyền; trường hợp không khớp, hệ thống chặn bàn giao và kích hoạt cảnh báo người lạ tới BGH và Phụ huynh. |
| **BR-022** | Hiệu lực Mã QR Ủy quyền Đón hộ Đột xuất & Mã PIN Bảo mật | Mã QR đón hộ đột xuất chỉ có hiệu lực tối đa 4 giờ trong ngày và chỉ sử dụng được 01 lần; người đón bắt buộc phải quét mã QR và nhập đúng mã PIN bảo mật 4 chữ số. |
| **BR-023** | Thẩm quyền Phê duyệt Đơn Đón Con Sớm | Giáo viên chủ nhiệm có thẩm quyền duyệt đơn đón con sớm hợp lệ nộp trước giờ tan trường; trường hợp người đón không có trong danh sách, phải gọi điện xác minh phụ huynh. |
| **BR-024** | Quy trình Vận hành Đưa đón, Điểm danh & Kiểm tra Khoang Xe Buýt | Giáo viên xe buýt điểm danh từng trẻ lúc lên/xuống xe; tài xế và giáo viên bắt buộc đi xuống cuối xe quét mã QR đuôi xe để xác nhận khoang xe rỗng trước khi rời xe; đối soát sĩ số bàn giao 100% cho GVCN tại trường. |
| **BR-025** | Tiêu chuẩn Năng lượng & Cân đối Dinh dưỡng Thực đơn Tuần | Năng lượng bữa ăn tại trường phải đạt  theo quy định của Viện Dinh dưỡng; không lặp lại món chính quá 2 lần trong 1 tuần. |
| **BR-026** | Gắn nhãn Dị ứng, Lưu Mẫu Thức ăn 24h & Tiêu hủy Có Biên bản | Khay ăn học sinh dị ứng phải có nhãn cảnh báo đỏ riêng biệt; bếp bán trú bắt buộc lưu mẫu thức ăn đủ 24 giờ trong tủ lạnh chuyên dụng; tiêu hủy mẫu phải có biên bản kiểm tra. |
| **BR-027** | Quy trình Kiểm thực 3 Bước Bắt buộc theo Quyết định 1246/QĐ-BYT | Nhà trường bắt buộc thực hiện và lưu nhật ký số quy trình kiểm thực 3 bước: Kiểm tra nguồn gốc nguyên liệu nhập, kiểm tra quá trình sơ chế nấu nướng và kiểm tra thức ăn trước khi cho trẻ ăn. |
| **BR-028** | Khung giờ Khóa sổ Báo ăn theo Bữa & Phê duyệt Thực đơn | Hệ thống tự động khóa sổ báo ăn trưa lúc 08:30 sáng; Hiệu phó phụ trách bán trú bắt buộc phê duyệt thực đơn tuần tiếp theo trước 17:00 ngày thứ Sáu hàng tuần; từ chối phải ghi rõ lý do. |
| **BR-029** | Điều kiện Tiếp nhận Thuốc Kê đơn & Giãn cách Liều uống | Nhà trường chỉ tiếp nhận thuốc có đơn bác sĩ ghi rõ thông tin họ tên trẻ, liều lượng và thời điểm uống; khoảng cách giữa 2 liều cùng loại tối thiểu phải đủ 4 giờ. |
| **BR-030** | Gắn nhãn Định danh Thuốc, Bàn giao Trực tiếp & Bằng chứng Uống thuốc | Bao bì thuốc phải có nhãn tên và lớp của trẻ; phụ huynh bàn giao trực tiếp tận tay; giáo viên bắt buộc chụp ảnh bằng chứng lúc cho trẻ uống thuốc đẩy thông báo tới phụ huynh. |
| **BR-031** | Đánh giá Thể lực theo Chuẩn WHO & Quy tắc Sơ cứu Y tế | Chỉ số phát triển thể lực của trẻ được đối chiếu tự động theo biểu đồ tăng trưởng Z-score của WHO; nhân viên y tế thực hiện sơ cứu tại chỗ và tuyệt đối không tự ý cho uống thuốc hạ sốt khi chưa có sự đồng ý của phụ huynh. |
| **BR-032** | Đồng bộ & Cảnh báo Dị ứng Xuyên suốt Hệ thống | Thông tin dị ứng thực phẩm và thuốc của trẻ tự động đồng bộ sang màn hình Bếp bán trú, Giáo viên đứng lớp và Y tế học đường. |
| **BR-033** | Tính Hợp lệ & Bất biến của Danh mục Khoản thu | Mỗi khoản thu có mã duy nhất và đơn giá lớn hơn 0; khoản thu sau khi đã phát sinh hóa đơn hoặc phiếu báo tự động chuyển sang trạng thái bất biến, cấm sửa xóa. |
| **BR-034** | Chính sách Miễn giảm Học phí, Khống chế Trần & Thứ tự Ưu tiên | Chính sách miễn giảm chỉ áp dụng cho các khoản thu nằm trong danh mục quy định; tổng mức miễn giảm tối đa không quá 100%; trường hợp học sinh thuộc nhiều diện ưu tiên thì áp dụng mức cao nhất. |
| **BR-035** | Tính Học phí Trẻ Nhập/Thôi học Giữa kỳ & Tính Dự thu | Trẻ nhập học hoặc thôi học giữa kỳ được tính học phí theo số ngày học thực tế tính từ ngày bắt đầu/kết thúc; bảng dự thu học phí là duy nhất cho mỗi lớp trong một kỳ tính phí. |
| **BR-036** | Tiêu chí Giảm trừ & Công thức Hoàn trả Tiền ăn Bán trú | Tiền hoàn ăn tháng = Số ngày nghỉ phép hợp lệ được duyệt trước 08:00 × Đơn giá suất ăn/ngày; dữ liệu ngày nghỉ sau khi đã chốt quyết toán vào phiếu báo sẽ chuyển sang bất biến, cấm tính trùng. |
| **BR-037** | Căn cứ Hợp lệ & Khống chế Trần Khoản thu Phát sinh | Các khoản phí phát sinh (tiền phạt đón muộn, mua thêm đồng phục) chỉ được ghi nhận trước thời điểm chốt bảng học phí; tổng khoản tiền phạt phát sinh không được vượt quá 20% tổng học phí tháng. |
| **BR-038** | Thẩm quyền Phê duyệt, Phát hành & Bất biến Phiếu báo Học phí | Chỉ Hiệu trưởng/Chủ tịch Hội đồng trường mới có quyền phê duyệt bảng học phí; phiếu báo sau khi được gửi tới phụ huynh tự động khóa sổ bất biến; thời hạn nộp học phí là 10 ngày kể từ ngày phát hành. |
| **BR-039** | Bảo mật Tra cứu & Hiển thị Minh bạch Cơ cấu Khoản thu | Phụ huynh chỉ được quyền tra cứu thông tin học phí của chính con mình; phiếu báo học phí hiển thị chi tiết từng khoản thu, các khoản miễn giảm và tiền hoàn ăn được đối trừ. |
| **BR-040** | Cấu trúc Tiêu chuẩn, Hiệu lực & Tự động Gạch nợ VietQR Động | Mã VietQR động chứa chính xác số tiền và mã hóa đơn theo chuẩn EMVCo, hiệu lực tối đa 15 phút; hệ thống tự động gạch nợ tức thì khi nhận được thông báo chuyển khoản thành công khớp số tiền. |
| **BR-041** | Thẩm quyền Thu Tiền mặt & Khóa Đồng bộ Giao dịch | Chỉ Thủ quỹ nhà trường mới có quyền lập phiếu thu tiền mặt tại phòng Kế toán; trong quá trình lập phiếu thu tiền mặt, hệ thống tạm khóa đồng bộ cổng thanh toán online để chống thanh toán trùng. |
| **BR-042** | Tính Hợp pháp & Bất biến của Chứng từ Ký số & Hóa đơn | Biên lai/Hóa đơn điện tử bắt buộc được ký số hợp chuẩn và xuất trong vòng 24 giờ sau khi thanh toán; chứng từ đã ký số là bất biến tuyệt đối, không thể sửa xóa. |
| **BR-043** | Tiêu chí Phân loại Công nợ Quá hạn & Tần suất Nhắc nợ | Công nợ quá hạn được phân loại tự động (Quá hạn 1-5 ngày: Nhắc nhở mềm; Quá hạn trên 5 ngày: Cảnh báo; Quá hạn trên 15 ngày: Khóa dịch vụ gia tăng); tần suất gửi thông báo nhắc nợ tối đa 2 lần/tuần. |
| **BR-044** | Công thức Tỷ lệ Thu hồi Học phí & Đối soát Tài chính | Tỷ lệ thu hồi học phí = (Tổng số tiền thực thu / Tổng số tiền phải thu) × 100%; hệ thống tự động đối soát lệch dòng tiền giữa sổ kế toán và tài khoản ngân hàng định kỳ hàng ngày. |
| **BR-045** | Quy chế Mở lớp CLB Ngoại khóa, Sĩ số & Phòng học | Lớp câu lạc bộ năng khiếu có sĩ số định mức từ 10-20 trẻ/lớp; phòng học ngoại khóa phải là phòng chức năng chuyên dụng và không bị trùng lịch với lớp khác. |
| **BR-046** | Tiêu chuẩn Chuyên môn & Định mức Giờ dạy Giáo viên CLB | Giáo viên phụ trách bộ môn năng khiếu bắt buộc phải có chứng chỉ chuyên môn phù hợp; định mức giờ dạy tối đa không quá 12 tiết/tuần để đảm bảo chất lượng. |
| **BR-047** | Thời hạn Đăng ký, Rút khỏi CLB & Độ tuổi Tham gia | Thời hạn tiếp nhận đăng ký kết thúc trước ngày khai giảng 03 ngày; học sinh được rút khỏi CLB và hoàn 100% học phí nếu nộp đơn trước buổi học thứ 2; trẻ phải đủ độ tuổi quy định theo từng bộ môn. |
| **BR-048** | Khung giờ Điểm danh CLB & An toàn Chuyển tiếp Học sinh | Giáo viên CLB chỉ được điểm danh trong vòng 15 phút đầu giờ học; Giáo viên chủ nhiệm bắt buộc bàn giao trực tiếp tận tay từng học sinh cho Giáo viên ngoại khóa và ký nhận bàn giao. |
| **BR-049** | Tiêu chuẩn Đánh giá 5 Lĩnh vực Phát triển & Dung lượng Nhận xét | Phiếu đánh giá định kỳ bắt buộc chấm điểm đầy đủ 5 lĩnh vực phát triển theo Thông tư 28/BGDĐT; phần nhận xét sư phạm của giáo viên bắt buộc có dung lượng tối thiểu 50 từ và không dùng mẫu sao chép. |
| **BR-050** | Khóa sổ Kỳ Đánh giá & Thẩm quyền Công bố Kết quả | Kỳ đánh giá sau khi hết thời hạn sẽ tự động khóa sổ bất biến; Ban Giám hiệu là cấp duy nhất có quyền phê duyệt công bố kết quả đánh giá tới phụ huynh; trường hợp từ chối phải ghi rõ lý do. |
| **BR-051** | Quản lý Tài sản Phòng học, Điều chuyển & Minh chứng Báo hỏng | Mỗi tài sản/thiết bị có mã Barcode/QR duy nhất; việc điều chuyển tài sản giữa các phòng phải có biên bản bàn giao số; khi báo hỏng bắt buộc phải chụp ảnh minh chứng hiện trường. |
| **BR-052** | Ưu tiên Xử lý Sự cố Nguy hiểm, Hạn mức Duyệt & Bất biến Sửa chữa | Sự cố thiết bị gây nguy hiểm an toàn cho trẻ phải được tiếp nhận và xử lý trong vòng 2 giờ; chi phí sửa chữa trên 10 triệu đồng bắt buộc BGH phê duyệt; thiết bị đang sửa cấm lập phiếu báo hỏng trùng. |
| **BR-053** | Thời hạn Nộp Giáo án Tuần, Kiểm soát Dung lượng & Phê duyệt | Giáo viên nộp giáo án trước 17:00 ngày thứ Năm hàng tuần, đầy đủ hoạt động 5 ngày, tệp đính kèm không quá 20MB; Ban Giám hiệu duyệt trước thứ Bảy; hệ thống tự động khóa lịch vào 07:00 sáng thứ Hai. |
| **BR-054** | Điều kiện Kết xuất Báo cáo Đánh giá & Công thức Đạt chuẩn | Báo cáo tổng hợp đánh giá chỉ được kết xuất khi 100% học sinh trong khối lớp đã được đánh giá đầy đủ; Tỷ lệ đạt chuẩn = (Số học sinh đạt / Tổng số học sinh) × 100%. |
| **BR-055** | Kiểm duyệt Nội dung & Hẹn giờ Phát hành Thông báo Toàn trường | Mọi thông báo toàn trường bắt buộc qua Ban Giám hiệu kiểm duyệt nội dung trước khi phát hành; cho phép thiết lập hẹn giờ gửi tự động theo khung giờ quy định. |
| **BR-056** | Phạm vi Đăng Thông báo Lớp học & Bảo mật Thông tin Học sinh | Bản tin của lớp học chỉ được hiển thị cho phụ huynh và giáo viên của lớp đó; tuyệt đối không công khai thông tin bệnh án, hoàn cảnh gia đình hoặc kết quả đánh giá cá nhân của trẻ lên bảng tin chung. |
| **BR-057** | Thẩm quyền Phát Thông báo Khẩn cấp & Giới hạn Tần suất | Chỉ Ban Giám hiệu mới có quyền kích hoạt tính năng phát thông báo khẩn cấp (Push Notification + SMS); giới hạn tối đa không quá 02 thông báo khẩn cấp trong một ngày. |
| **BR-058** | Khung giờ Liên lạc Sư phạm, Bảo mật Tin nhắn & Thời hạn Thu hồi | Khung giờ gửi tin nhắn trực tiếp giữa phụ huynh và giáo viên từ 07:00 đến 21:30 hàng ngày; tin nhắn sau 21:30 chuyển chế độ im lặng; cho phép thu hồi tin nhắn trong vòng 15 phút kể từ lúc gửi. |
| **BR-059** | Quyền Thành viên & Thẩm quyền Điều hành Nhóm Chat Lớp | Thành viên nhóm chat lớp bắt buộc là phụ huynh có con đang theo học tại lớp; Giáo viên chủ nhiệm có toàn quyền kiểm duyệt nội dung, khóa tính năng chat khi cần thiết và xóa tin nhắn vi phạm. |
| **BR-060** | Giới hạn Album Ảnh, Bảo vệ Quyền Riêng tư & Bản quyền Trường | Mỗi album ảnh giới hạn tối đa 50 ảnh/hoạt động; cấm đăng ảnh có nội dung nhạy cảm; phụ huynh chỉ có quyền tải ảnh có mặt con mình; bản quyền hình ảnh thuộc về nhà trường. |
| **BR-061** | Tính Duy nhất, Bất biến & Nguyên tắc Ẩn danh trong Khảo sát | Mỗi phụ huynh chỉ được làm phiếu khảo sát đúng 01 lần; câu trả lời sau khi nộp là bất biến, không thể chỉnh sửa; hệ thống bảo đảm ẩn danh danh tính phụ huynh để đảm bảo tính khách quan. |
| **BR-062** | Căn cứ Y khoa & Kiểm duyệt Bản tin Y tế Học đường | Nội dung bản tin y tế bắt buộc trích dẫn từ nguồn Bộ Y tế hoặc CDC; Cán bộ Y tế học đường biên tập và Ban Giám hiệu bắt buộc kiểm duyệt trước khi đăng tải lên hệ thống. |
| **BR-063** | Quyền Riêng tư Tra cứu Phiếu Đánh giá Cá nhân của Trẻ | Phụ huynh chỉ có quyền xem phiếu đánh giá định kỳ của con mình; hệ thống tuyệt đối không công khai bảng xếp loại hoặc điểm đánh giá của trẻ này cho phụ huynh trẻ khác. |
| **BR-064** | Thời hạn Nộp, Tính Hợp lệ & Duy nhất của Đơn Nghỉ học | Đơn xin nghỉ học bắt buộc nộp trước 08:00 sáng của ngày bắt đầu nghỉ; thời gian xin nghỉ không được nằm trong quá khứ; tại một thời điểm mỗi học sinh chỉ có duy nhất một đơn nghỉ có hiệu lực. |
| **BR-065** | Thẩm quyền Duyệt Đơn Nghỉ & Tự động Đồng bộ Giảm Tiền ăn | Giáo viên chủ nhiệm phê duyệt đơn xin nghỉ học trước 08:30 sáng; khi đơn được duyệt, hệ thống tự động đồng bộ sang Bếp bán trú để giảm trừ suất ăn và tính hoàn phí. |
| **BR-066** | Quy định Tiếp nhận Hồ sơ Tuyển sinh Trực tuyến | Hồ sơ tuyển sinh trực tuyến bắt buộc phải đính kèm đầy đủ bản chụp giấy khai sinh và thông tin cư trú hợp lệ; hệ thống tự động đánh số thứ tự tiếp nhận và gửi mã tra cứu hồ sơ qua SMS/Email cho phụ huynh. |
| **BR-067** | Thời hạn Phản hồi Kết quả Sơ tuyển & Xác nhận Nhập học | Ban Giám hiệu bắt buộc phản hồi kết quả xét tuyển sơ bộ trong vòng 03 ngày làm việc; phụ huynh có thời hạn 07 ngày kể từ khi có thông báo trúng tuyển để hoàn tất thủ tục nhập học chính thức. |
| **BR-068** | Quy định Đăng ký & Hủy Dịch vụ Trực tuyến Bán trú/Xe buýt | Phụ huynh đăng ký dịch vụ bán trú hoặc xe buýt trước ngày 25 hàng tháng để áp dụng cho tháng tiếp theo; trường hợp hủy dịch vụ phải nộp đơn trước tối thiểu 05 ngày làm việc để kế toán kịp quyết toán công nợ. |
| **BR-069** | Nguyên tắc Công khai Biểu phí & Tính Bất biến Niên khóa | Biểu phí học phí và dịch vụ gia tăng được niêm yết công khai trên Cổng thông tin điện tử của trường; biểu phí áp dụng cố định trong toàn bộ niên khóa, không được tự ý điều chỉnh tăng giá giữa năm học. |
| **BR-070** | Tiếp nhận & Quy trình Phản hồi Góp ý, Khiếu nại của Phụ huynh | Mọi phản ánh, khiếu nại của phụ huynh gửi qua Cổng thông tin phải được hệ thống tự động phân loại, chuyển đúng bộ phận phụ trách và bắt buộc phản hồi bằng văn bản số trong vòng 48 giờ làm việc. |

---

## 8. Non-Functional Requirements & SLAs (Yêu cầu Phi chức năng & Cam kết Chất lượng)
*   **Hiệu năng Xử lý AI (AI Performance):**
    - Phát hiện khuôn mặt (YOLOv8-Face) và trích xuất vector 512 chiều (InsightFace) hoàn thành trong <= 50ms.
    - So khớp khoảng cách Cosine trên PostgreSQL pgvector với HNSW index đạt tốc độ <= 0.3s.
    - Tốc độ xử lý Webhook thanh toán VietQR PayOS gạch nợ thành công trong <= 3s.
*   **Hiệu năng Hệ thống (Web & Mobile Latency):** Thời gian phản hồi trung bình cho các thao tác CRUD và tải dữ liệu bảng <= 300ms.
*   **Độ Sẵn sàng & Tin cậy (Reliability & Uptime):**
    - Cam kết thời gian hoạt động hệ thống đạt tối thiểu **99.5%**.
    - Ứng dụng di động của giáo viên hỗ trợ cơ chế lưu bộ nhớ đệm ngoại tuyến (Offline Caching) cho tác vụ điểm danh thủ công khi mất kết nối mạng WiFi tại lớp, tự động đồng bộ khi có kết nối trở lại.
    - Cơ sở dữ liệu tự động sao lưu định kỳ hàng ngày (Daily Automated Backup). Thời gian phục hồi sự cố nghiêm trọng (RTO) <= 4h.
*   **Bảo mật & An toàn Thông tin (Security & Data Protection):**
    - Mật khẩu người dùng được băm mã hóa một chiều an toàn bằng BCrypt (Cost Factor 10+) hoặc Argon2id.
    - Cơ chế xác thực phân tán qua cặp JWT Token: Access Token (thời hạn 15 phút), Refresh Token (7 ngày hoặc 30 ngày nếu chọn Ghi nhớ đăng nhập). Hỗ trợ cơ chế thu hồi phiên tức thì qua Redis khi đổi mật khẩu hoặc bị khóa tài khoản.
    - Đường dẫn tệp ảnh nhạy cảm trên Cloud Storage sử dụng Presigned URLs với thời gian hết hạn sau 15 phút.
    - Tuân thủ tuyệt đối **Nghị định 13/2023/NĐ-CP** về quyền được xóa dữ liệu cá nhân sinh trắc học khi học sinh tốt nghiệp hoặc chuyển trường.
*   **Chống Tấn công Từ chối Dịch vụ (Rate Limiting):** Giới hạn tối đa 60 requests/phút trên mỗi địa chỉ IP đối với các API công khai (Đăng nhập, Quên mật khẩu, Xác thực OTP) để phòng chống Brute-force và DDoS.