# TÀI LIỆU USE CASES VÀ ĐẶC TẢ KỸ THUẬT (FE - BE - API) - VAI TRÒ GIÁO VIÊN MẦM NON (TEACHER)

---

## G5-UC-01: Điểm danh Trẻ Đến Lớp Thủ công

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Giáo viên Mầm non (`TEACHER` / `GIAO_VIEN`)
- **Tác nhân phụ / Hệ thống:** Không có
- **Sự kiện kích hoạt:** Giáo viên truy cập phân hệ Điểm danh lớp học, chọn tab "Điểm danh Thủ công" (`/attendance?tab=manual`).
- **Mô tả (User Story):** Là Giáo viên mầm non phụ trách lớp, tôi muốn tích chọn nhanh trạng thái chuyên cần (Có mặt, Đi muộn, Vắng có phép, Vắng không phép) của từng trẻ trong lớp trên máy tính bảng/điện thoại, để theo dõi quân số thực tế và tự động báo suất ăn cho nhà bếp học đường trước giờ khóa sổ.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Giáo viên đã đăng nhập thành công và được phân công phụ trách lớp học trong niên khóa hiện tại (`academic.teacher_class_assignment`).
  - **PRE-2:** Lớp học đang trong trạng thái hoạt động (`ACTIVE`) và danh sách học sinh đã được xếp lớp hợp lệ.
- **Hậu điều kiện:**
  - **POST-1:** Bản ghi chuyên cần của học sinh được lưu vào bảng `student.attendances` với trạng thái tương ứng.
  - **POST-2:** Dữ liệu sĩ số có mặt tự động đồng bộ sang bảng tổng hợp báo ăn bán trú đợt 1 (07:00) và đợt 2 (08:30) của Nhà bếp.

### 2. Luồng sự kiện chính
1. Giáo viên chọn Lớp học phụ trách và Ngày điểm danh (mặc định là ngày hiện tại).
2. Hệ thống tải danh sách học sinh trong lớp kèm ảnh thẻ, trạng thái điểm danh hiện thời và thông tin đơn xin nghỉ phép (nếu có).
3. Giáo viên tích chọn trạng thái chuyên cần cho từng trẻ: Có mặt (`PRESENT`), Đi muộn (`LATE`), Vắng có phép (`EXCUSED_ABSENCE`), hoặc Vắng không phép (`UNEXCUSED_ABSENCE`).
4. Giáo viên có thể nhấn nút "Tất cả có mặt" để điền nhanh trạng thái có mặt cho các trẻ chưa đánh dấu.
5. Giáo viên nhấn nút **Lưu điểm danh**.
6. Hệ thống kiểm tra khung giờ hợp lệ theo quy tắc **BR-018** và tính toàn vẹn dữ liệu (Bắt ngoại lệ E1, E2, E3).
7. Hệ thống lưu kết quả điểm danh vào cơ sở dữ liệu và hiển thị thông báo **MSG-081**.
8. Hệ thống tự động kích hoạt tính toán sĩ số báo ăn bán trú gửi phân hệ Nhà bếp.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Đồng bộ ngoại tuyến (Offline Caching):**
  - Khi thiết bị mất kết nối mạng, ứng dụng lưu tạm bảng điểm danh vào IndexedDB / LocalStorage của trình duyệt.
  - Khi có mạng trở lại, ứng dụng tự động kích hoạt tiến trình nền gửi dữ liệu lên máy chủ và hiển thị thông báo đồng bộ thành công.
- **Rẽ nhánh A2 — Điều chỉnh trạng thái điểm danh trong ngày:**
  - Giáo viên chọn trẻ cần sửa trạng thái (ví dụ: trẻ chuyển từ Vắng sang Đến muộn), cập nhật ghi chú lý do và nhấn *Cập nhật*.
  - Hệ thống ghi nhận lịch sử điều chỉnh kèm mốc thời gian vào nhật ký kiểm toán.
- **BR-018 (Khung giờ Chốt Điểm danh Bán trú & Điều kiện Hoàn tiền):**
  - Khung giờ chốt báo ăn bán trú kết thúc vào đúng 07:00 sáng với gói ăn bán trú hoàn toàn (sáng, trưa, xế) và 08:30 sáng với gói ăn trưa/xế.
  - Điểm danh sau mốc khóa sổ chỉ cập nhật trạng thái chuyên cần, không làm thay đổi định mức suất ăn đã chốt với Bếp.
- **Thông báo & Ngoại lệ:**
  - `MSG-081`: "Lưu dữ liệu điểm danh lớp học thành công."
  - `E1 (MSG-082)`: "Lớp học chưa có danh sách học sinh được phân bổ."
  - `E2 (MSG-083)`: "Không thể chỉnh sửa điểm danh của các ngày trong quá khứ đã khóa sổ học vụ."
  - `E3 (MSG-084)`: "Phát hiện xung đột trạng thái: Trẻ đã có đơn nghỉ phép được duyệt hợp lệ."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/student/controller/AttendanceController.java` (Định tuyến `/api/teachers/attendance`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/student/service/AttendanceService.java` (Interface)
  - `src/main/java/com/kidpro/domain/student/service/impl/AttendanceServiceImpl.java` (Xử lý lưu điểm danh hàng loạt, tính toán sĩ số báo bếp, kiểm tra BR-018)
- **Repository:**
  - `src/main/java/com/kidpro/domain/student/repository/AttendanceRepository.java` (JPA Repository tương tác bảng `student.attendances`)
  - `src/main/java/com/kidpro/domain/catering/repository/MealHeadcountSnapshotRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/student/entity/Attendance.java` (Bảng `student.attendances`)
- **DTOs:**
  - `src/main/java/com/kidpro/domain/student/dto/request/BatchAttendanceRequestDto.java`
  - `src/main/java/com/kidpro/domain/student/dto/response/AttendanceResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/attendance/tabs/ManualAttendanceTab.tsx` (Bảng danh sách học sinh, nút tích chọn trạng thái, bộ lọc lớp, ghi chú)
  - `kidpro-fe/src/pages/attendance/AttendancePage.tsx` (Trang quản lý điểm danh tổng hợp)
- **API Service Client:**
  - `kidpro-fe/src/api/attendanceApi.ts` (`recordBatchAttendance`, `getAttendanceByDate`)
- **Type Definitions:**
  - `kidpro-fe/src/types/attendance.types.ts` (`Attendance`, `BatchAttendancePayload`, `AttendanceStatus`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G5-UC-01] Điểm Danh Thủ Công*, path: `/attendance?tab=manual`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/api/teachers/attendance` | Lấy danh sách điểm danh theo ngày & lớp | Query: `date` (YYYY-MM-DD), `classId` (UUID) | `List<AttendanceResponseDto>` |
| `POST` | `/api/teachers/attendance/batch` | Điểm danh hàng loạt học sinh trong lớp (BR-018) | `BatchAttendanceRequestDto` (classId, date, list records: studentId, status, notes) | `List<AttendanceResponseDto>` (`MSG-081`) |
| `PUT` | `/api/teachers/attendance/{id}` | Cập nhật trạng thái điểm danh đơn lẻ | Path: `id` (UUID), Body: `{ status, notes }` | `AttendanceResponseDto` |

---

## G5-UC-02: Điểm danh Nhận diện Khuôn mặt (AI)

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Giáo viên Mầm non (`TEACHER` / `GIAO_VIEN`)
- **Tác nhân phụ / Hệ thống:** Microservice AI Vision (YOLOv8-Face + InsightFace ArcFace)
- **Sự kiện kích hoạt:** Giáo viên truy cập tab "Điểm danh Camera AI" tại cổng đón hoặc tại cửa lớp (`/attendance?tab=gate-ai`).
- **Mô tả (User Story):** Là Giáo viên mầm non, tôi muốn mở camera để hệ thống AI tự động phát hiện và nhận diện khuôn mặt của học sinh khi bước vào cửa lớp, giúp việc điểm danh diễn ra tự động, không chạm, chính xác và giảm thiểu thao tác thủ công.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Học sinh đã được chụp ảnh mẫu và trích xuất vector đặc trưng 512 chiều thành công trong bảng `student.face_encoding_file`.
  - **PRE-2:** Thiết bị camera kết nối ổn định và có quyền truy cập video stream.
- **Hậu điều kiện:**
  - **POST-1:** Bản ghi chuyên cần được tự động cập nhật trạng thái [Có mặt] (`PRESENT`) kèm ảnh chụp snapshot và điểm tin cậy (confidence score >= 85%).
  - **POST-2:** Nhật ký nhận diện được lưu trữ tại bảng `student.face_recognition_logs` và gửi thông báo đẩy (Push Notification) đến phụ huynh.

### 2. Luồng sự kiện chính
1. Giáo viên kích hoạt camera nhận diện trên ứng dụng và chọn chế độ đón trẻ đầu ngày.
2. Học sinh bước vào vùng nhận diện của camera.
3. Microservice AI thực hiện cắt khung hình khuôn mặt (bounding box) qua YOLOv8-Face (< 50ms) và trích xuất vector 512 chiều qua InsightFace.
4. Hệ thống so khớp vector đặc trưng với cơ sở dữ liệu `student.face_encoding_file` bằng toán tử khoảng cách Cosine trên PostgreSQL `pgvector` index HNSW (< 0.3s).
5. Hệ thống xác định học sinh có độ tương đồng cao nhất (Cosine Similarity >= 0.85 theo quy tắc **BR-019**).
6. Hệ thống hiển thị hộp xanh viền quanh khuôn mặt, phát âm thanh chào mừng và hiển thị họ tên, lớp của bé trên màn hình.
7. Hệ thống tự động ghi nhận bản ghi điểm danh, lưu ảnh chụp vào bảng `student.attendance_photos`, hiển thị thông báo **MSG-085**.
8. Hệ thống gửi thông báo kèm ảnh tức thì tới ứng dụng di động của Phụ huynh học sinh.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Độ tương đồng dưới ngưỡng quy định (< 0.85):**
  - Hệ thống hiển thị khung viền màu vàng, thông báo không nhận diện được danh tính rõ ràng.
  - Giáo viên chuyển sang chụp lại hoặc điểm danh thủ công trên danh sách lớp.
- **Rẽ nhánh A2 — Chống nhận diện trùng lặp trong thời gian ngắn (Anti-duplicate Scan):**
  - Nếu cùng một học sinh đứng trước camera liên tục trong vòng 10 phút, hệ thống bỏ qua các lần nhận diện tiếp theo để tránh ghi đè dữ liệu.
- **BR-019 (Điểm danh Sinh trắc học AI & Ghi nhận Sức khỏe Đầu ngày):**
  - Hệ thống tự động nhận diện điểm danh trẻ với độ tin cậy trên 85% (Cosine distance <= 0.15).
  - Cơ chế chống điểm danh trùng lặp áp dụng cửa sổ trượt 10 phút.
- **Thông báo & Ngoại lệ:**
  - `MSG-085`: "Nhận diện thành công học sinh [Tên_Học_Sinh] - Lớp [Tên_Lớp]."
  - `E1 (MSG-086)`: "Không tìm thấy dữ liệu sinh trắc học khuôn mặt của học sinh."
  - `E2 (MSG-087)`: "Chất lượng hình ảnh không đạt tiêu chuẩn (quá tối, bị mờ hoặc góc nghiêng quá lớn)."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/student/controller/FaceRecognitionController.java` (Định tuyến `/api/attendance/face-logs`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/student/service/FaceRecognitionService.java`
  - `src/main/java/com/kidpro/domain/student/service/impl/FaceRecognitionServiceImpl.java` (So khớp vector pgvector, ghi log, kích hoạt thông báo phụ huynh)
- **Repository:**
  - `src/main/java/com/kidpro/domain/student/repository/FaceEncodingFileRepository.java`
  - `src/main/java/com/kidpro/domain/student/repository/FaceRecognitionLogRepository.java`
  - `src/main/java/com/kidpro/domain/student/repository/AttendancePhotoRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/student/entity/FaceEncodingFile.java`
  - `src/main/java/com/kidpro/domain/student/entity/FaceRecognitionLog.java`
  - `src/main/java/com/kidpro/domain/student/entity/AttendancePhoto.java`
- **DTOs:**
  - `src/main/java/com/kidpro/domain/student/dto/request/FaceLogRequestDto.java`
  - `src/main/java/com/kidpro/domain/student/dto/response/FaceLogResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/attendance/tabs/GateAiAttendanceTab.tsx` (Giao diện camera stream AI, widget nhận diện khuôn mặt, danh sách log theo thời gian thực)
- **API Service Client:**
  - `kidpro-fe/src/api/attendanceApi.ts` (`recordFaceLog`, `getAttendanceFaceLogs`)
- **Type Definitions:**
  - `kidpro-fe/src/types/attendance.types.ts` (`FaceLog`, `FaceRecognitionPayload`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G5-UC-02] Điểm Danh Camera AI*, path: `/attendance?tab=gate-ai`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/attendance/face-logs` | Ghi nhận kết quả quét camera nhận diện AI | `FaceLogRequestDto` (studentId, confidenceScore, photoUrl, capturedAt, eventType) | `FaceLogResponseDto` (`MSG-085`) |
| `GET` | `/api/attendance/face-logs` | Lấy lịch sử log nhận diện khuôn mặt | Query: `studentId`, `date`, `eventType` | `List<FaceLogResponseDto>` |

---

## G5-UC-03: Ghi nhận Sức khỏe Lúc Tiếp nhận Trẻ

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Giáo viên Mầm non (`TEACHER` / `GIAO_VIEN`)
- **Tác nhân phụ / Hệ thống:** Không có
- **Sự kiện kích hoạt:** Sau khi điểm danh, giáo viên bấm biểu tượng "Kiểm tra sức khỏe đầu ngày" trên dòng thông tin học sinh (`/health?tab=metrics`).
- **Mô tả (User Story):** Là Giáo viên mầm non, tôi muốn quan sát và ghi nhận nhanh các biểu hiện sức khỏe bên ngoài của trẻ (thân nhiệt, biểu hiện ho sốt, vết trầy xước/bầm tím có từ nhà, nốt ban da) vào hệ thống lúc đón trẻ, để lưu vết tình trạng ban đầu minh bạch và thông báo ngay cho phụ huynh.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Học sinh đã được điểm danh có mặt tại lớp trong buổi sáng.
- **Hậu điều kiện:**
  - **POST-1:** Bản ghi kiểm tra sức khỏe được lưu vào bảng `health.health_incidents` hoặc `health.health_metrics`.
  - **POST-2:** Hệ thống tự động gửi tin nhắn thông báo cảnh báo tới phụ huynh nếu phát hiện thân nhiệt trẻ > 37.5°C hoặc có vết trầy xước từ nhà.

### 2. Luồng sự kiện chính
1. Giáo viên chọn học sinh cần ghi nhận kiểm tra sức khỏe đầu ngày.
2. Hệ thống hiển thị biểu mẫu kiểm tra nhanh gồm: Đo thân nhiệt (°C), Trạng thái tinh thần (Vui vẻ, Mệt mỏi, Quấy khóc), Biểu hiện hô hấp/tiêu hóa (Bình thường, Ho, Chảy mũi, Nôn trớ), Dấu hiệu ngoài da (Bình thường, Vết xước, Bầm tím, Nốt ban dị ứng).
3. Giáo viên nhập số đo nhiệt độ và tích chọn các biểu hiện quan sát được.
4. Trường hợp có vết trầy xước hoặc bầm tím mang từ nhà, giáo viên chụp ảnh hiện trạng đính kèm và ghi chú chi tiết vị trí vết thương.
5. Giáo viên nhấn nút **Lưu ghi nhận sức khỏe**.
6. Hệ thống kiểm tra ngưỡng nhiệt độ theo quy tắc **BR-019** và **BR-031** (Bắt ngoại lệ E1, E2).
7. Hệ thống lưu trữ dữ liệu thành công, hiển thị thông báo **MSG-088**.
8. Hệ thống gửi thông báo xác nhận tới tài khoản phụ huynh học sinh để phụ huynh ký xác nhận tình trạng ban đầu.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Thân nhiệt trẻ vượt quá 37.5°C (Sốt nhẹ hoặc Sốt cao):**
  - Hệ thống bật cờ cảnh báo đỏ [SỐT HỌC ĐƯỜNG].
  - Giáo viên cho trẻ ngồi khu vực thoáng mát, đo lại sau 15 phút. Nếu vẫn sốt, kích hoạt chuyển thông tin sang Phòng Y tế trường và gọi điện trực tiếp cho phụ huynh.
- **BR-019 & BR-031 (Quy chuẩn Giám sát Sức khỏe Tiếp nhận & Sơ cứu Y tế):**
  - Bắt buộc ghi nhận biểu hiện sức khỏe chi tiết nếu thân nhiệt trẻ > 37.5°C.
  - Giáo viên không tự ý cho trẻ uống thuốc hạ sốt khi chưa có sự đồng ý bằng văn bản hoặc tin nhắn xác nhận của phụ huynh.
- **Thông báo & Ngoại lệ:**
  - `MSG-088`: "Ghi nhận tình trạng sức khỏe đầu ngày của học sinh thành công."
  - `E1 (MSG-089)`: "Số đo thân nhiệt không hợp lệ (nhiệt độ phải nằm trong khoảng 35.0°C - 42.0°C)."
  - `E2 (MSG-090)`: "Bắt buộc chụp ảnh minh chứng và nhập mô tả khi ghi nhận trẻ có vết thương hoặc bầm tím từ nhà."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/healthmedical/controller/HealthIncidentController.java` (Định tuyến `/api/health/incidents`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/healthmedical/service/HealthIncidentService.java`
  - `src/main/java/com/kidpro/domain/healthmedical/service/impl/HealthIncidentServiceImpl.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/healthmedical/repository/HealthIncidentRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/healthmedical/entity/HealthIncident.java`
- **DTOs:**
  - `src/main/java/com/kidpro/domain/healthmedical/dto/request/HealthCheckInRequestDto.java`
  - `src/main/java/com/kidpro/domain/healthmedical/dto/response/HealthIncidentResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/health/tabs/MedicalIncidentsTab.tsx` (Tab ghi chép kiểm tra sức khỏe và sự cố y tế)
  - `kidpro-fe/src/pages/health/HealthPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/healthApi.ts` (`createMedicalIncident`, `getHealthMetrics`)
- **Type Definitions:**
  - `kidpro-fe/src/types/health.types.ts` (`MedicalIncidentRecord`, `CreateMedicalIncidentPayload`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G5-UC-03] Sức Khỏe Tiếp Nhận*, path: `/health?tab=incidents`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/health/incidents` | Ghi nhận sự vụ kiểm tra sức khỏe đầu ngày | `HealthCheckInRequestDto` (studentId, temperature, symptoms, photoUrl, notes, incidentType) | `HealthIncidentResponseDto` (`MSG-088`) |
| `GET` | `/api/health/incidents/student/{studentId}` | Lịch sử theo dõi sức khỏe của học sinh | Path: `studentId` (UUID) | `List<HealthIncidentResponseDto>` |

---

## G5-UC-04: Xác nhận Trẻ Rời Lớp Cuối ngày thủ công

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Giáo viên Mầm non (`TEACHER` / `GIAO_VIEN`)
- **Tác nhân phụ / Hệ thống:** Không có
- **Sự kiện kích hoạt:** Giáo viên chọn tab "Đón Trả Trẻ" vào giờ tan trường (`/attendance?tab=dismissal`).
- **Mô tả (User Story):** Là Giáo viên mầm non, tôi muốn xác nhận học sinh đã rời lớp và được trao trả tận tay cho phụ huynh hoặc người đón hợp lệ bằng thao tác thủ công, để quản lý sĩ số học sinh còn lại trong lớp và đảm bảo an toàn tuyệt đối.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Học sinh có trạng thái điểm danh buổi sáng là Có mặt (`PRESENT`).
  - **PRE-2:** Người đến đón trẻ thuộc danh sách phụ huynh chính hoặc người đón ủy quyền đã được phê duyệt.
- **Hậu điều kiện:**
  - **POST-1:** Trạng thái đưa đón của học sinh chuyển thành [Đã trả trẻ] (`DISMISSED`) kèm mốc thời gian xuất lớp.
  - **POST-2:** Sĩ số trẻ còn lại trong phòng học tự động giảm 1.

### 2. Luồng sự kiện chính
1. Giáo viên mở danh sách học sinh đang có mặt tại lớp vào giờ tan trường.
2. Người đón đến lớp đón bé; giáo viên đối chiếu nhận diện người đón với danh sách người đón hợp lệ trên màn hình.
3. Giáo viên chọn học sinh tương ứng, chọn người nhận trẻ (Cha, Mẹ, Ông, Bà...) và nhấn nút **Xác nhận Trả trẻ**.
4. Hệ thống kiểm tra tính hợp lệ của người đón và mốc thời gian trả theo quy tắc **BR-020** (Bắt ngoại lệ E1, E2).
5. Hệ thống ghi nhận thời điểm rời lớp thực tế vào bảng `student.attendances`.
6. Hệ thống hiển thị thông báo **MSG-091** và gửi thông báo xác nhận đến ứng dụng của gia đình.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Trả trẻ sớm (Early Dismissal):**
  - Người đón xin đón trẻ về trước giờ tan trường quy định (trước 16:30).
  - Giáo viên kiểm tra đơn xin về sớm hoặc gọi điện xác nhận với phụ huynh chính, nhập lý do về sớm và lưu xác nhận.
- **BR-020 (Quy tắc Bàn giao Trẻ An toàn):**
  - Giáo viên chỉ được phép bàn giao trẻ cho người đón hợp lệ có thông tin trong hồ sơ gia đình.
  - Tuyệt đối không giao trẻ cho người chưa đăng ký hoặc không có mã ủy quyền hợp lệ.
- **Thông báo & Ngoại lệ:**
  - `MSG-091`: "Bàn giao trẻ cho phụ huynh thành công."
  - `E1 (MSG-092)`: "Người đón không nằm trong danh sách người giám hộ được ủy quyền hợp lệ."
  - `E2 (MSG-093)`: "Học sinh đã được xác nhận rời lớp trước đó."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/student/controller/AttendanceController.java` (Endpoint `/api/teachers/attendance/checkout`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/student/service/AttendanceService.java`
  - `src/main/java/com/kidpro/domain/student/service/impl/AttendanceServiceImpl.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/student/repository/AttendanceRepository.java`
  - `src/main/java/com/kidpro/domain/student/repository/StudentGuardianRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/student/entity/Attendance.java`
  - `src/main/java/com/kidpro/domain/student/entity/StudentGuardian.java`
- **DTOs:**
  - `src/main/java/com/kidpro/domain/student/dto/request/ManualCheckoutRequestDto.java`
  - `src/main/java/com/kidpro/domain/student/dto/response/AttendanceResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/attendance/tabs/DismissalPickupTab.tsx` (Danh sách trẻ chờ đón, nút xác nhận trả trẻ, modal đối chiếu người đón)
  - `kidpro-fe/src/pages/attendance/AttendancePage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/attendanceApi.ts` (`recordFaceLog`, `getAttendanceByDate`)
- **Type Definitions:**
  - `kidpro-fe/src/types/attendance.types.ts` (`Attendance`, `StudentGuardian`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G5-UC-04] Đón Trả Trẻ*, path: `/attendance?tab=dismissal`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/teachers/attendance/checkout` | Xác nhận trẻ rời lớp thủ công | `ManualCheckoutRequestDto` (studentId, guardianId, checkoutTime, notes) | `AttendanceResponseDto` (`MSG-091`) |
| `GET` | `/api/teachers/classes/{classId}/remaining-students` | Danh sách học sinh chưa được đón trong lớp | Path: `classId` (UUID) | `List<AttendanceResponseDto>` |

---

## G5-UC-05: Ghi nhận Mốc giờ Trẻ Đón Muộn & Tính Phí

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Giáo viên Mầm non (`TEACHER` / `GIAO_VIEN`)
- **Tác nhân phụ / Hệ thống:** Hệ thống Tự động Tính Phí Trông Muộn (Billing Engine)
- **Sự kiện kích hoạt:** Giáo viên thực hiện thao tác trả trẻ sau mốc 17:00 chiều (`/attendance?tab=late-pickup`).
- **Mô tả (User Story):** Là Giáo viên mầm non trông muộn, tôi muốn hệ thống tự động ghi nhận chính xác mốc giờ phụ huynh đến đón con sau 17:00 và tự động tính phụ phí trông muộn lũy tiến (30.000 VNĐ/giờ, miễn phí 30 phút ân hạn ban đầu sau 17:00), để tự động kết chuyển vào bảng học phí tháng sau mà không cần ghi chép sổ tay.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Học sinh vẫn còn ở lại trường sau 17:00 ngày làm việc.
  - **PRE-2:** Cấu hình khung phí trông muộn đã được Kế toán thiết lập (`BR-020`, `BR-037`).
- **Hậu điều kiện:**
  - **POST-1:** Bản ghi đón muộn gồm số phút và số tiền phụ phí được lưu vào bảng `student.attendances`.
  - **POST-2:** Dữ liệu tự động phát sinh một khoản thu ngoài dự kiến trong phiếu báo học phí kỳ tiếp theo của học sinh.

### 2. Luồng sự kiện chính
1. Phụ huynh đến đón trẻ sau 17:00 chiều.
2. Giáo viên quét mã hoặc chọn học sinh trên tab "Theo dõi Đón Muộn".
3. Hệ thống ghi nhận mốc thời gian thực hiện thao tác (ví dụ: 17:45).
4. Hệ thống tự động tính số phút trễ so với giờ tan trường (17:00) và áp dụng công thức lũy tiến theo quy tắc **BR-020**:
   - Từ 17:01 đến 17:30: Trong khung ân hạn 30 phút $ightarrow$ Phụ phí = 0 VNĐ.
   - Từ 17:31 đến 18:00: Trễ trong block giờ thứ nhất $ightarrow$ Phụ phí = 30.000 VNĐ.
   - Sau 18:00: Mỗi block giờ tiếp theo cộng thêm 30.000 VNĐ/giờ.
5. Giáo viên cho phụ huynh xem thời gian và số tiền phụ phí tính toán trên màn hình.
6. Giáo viên bấm **Xác nhận Bàn giao & Chốt Phí Đón Muộn**.
7. Hệ thống cập nhật bảng dữ liệu, hiển thị thông báo **MSG-094**.
8. Hệ thống gửi thông báo hóa đơn đón muộn tức thì về máy phụ huynh.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Miễn giảm phí đón muộn do trường hợp bất khả kháng:**
  - Phụ huynh có đơn giải trình lý do chính đáng (tai nạn, bão lũ), Giáo viên tích chọn *Yêu cầu xem xét miễn trừ*, nhập lý do.
  - Bản ghi được đánh dấu chờ Ban Giám hiệu phê duyệt miễn giảm trước khi kế toán chốt sổ.
- **BR-020 (Quy tắc Tính Phí Đón Muộn Lũy tiến):**
  - Mốc tính muộn bắt đầu từ sau 17:00. Miễn phí 30 phút đầu của mỗi giờ tan (sau 17h30 mới tính phí của giờ đầu).
  - Đơn giá chuẩn: 30.000 VNĐ/giờ/trẻ.
- **Thông báo & Ngoại lệ:**
  - `MSG-094`: "Ghi nhận mốc giờ đón muộn thành công. Phụ phí phát sinh: [Số_Tiền] VNĐ."
  - `E1 (MSG-095)`: "Thời gian đón không nằm trong khung giờ quy định tính đón muộn (trước 17:00)."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/student/controller/LatePickupController.java` (Định tuyến `/api/attendance/late-pickups`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/student/service/LatePickupService.java`
  - `src/main/java/com/kidpro/domain/student/service/impl/LatePickupServiceImpl.java` (Thuật toán tính phí lũy tiến BR-020, tích hợp công nợ finance)
- **Repository:**
  - `src/main/java/com/kidpro/domain/student/repository/AttendanceRepository.java`
  - `src/main/java/com/kidpro/domain/finance/repository/InvoiceRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/student/entity/Attendance.java`
- **DTOs:**
  - `src/main/java/com/kidpro/domain/student/dto/request/LatePickupRecordDto.java`
  - `src/main/java/com/kidpro/domain/student/dto/response/LatePickupResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/attendance/tabs/LatePickupTrackingTab.tsx` (Bảng thống kê trẻ đón muộn, bộ tính phí lũy tiến trực quan, lịch sử đón muộn)
- **API Service Client:**
  - `kidpro-fe/src/api/attendanceApi.ts` (`getLatePickupRules`, `recordBatchAttendance`)
- **Type Definitions:**
  - `kidpro-fe/src/types/attendance.types.ts` (`LatePickupRecord`, `LatePickupFeeRule`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G5-UC-05] Theo Dõi Đón Muộn*, path: `/attendance?tab=late-pickup`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/attendance/late-pickups/record` | Ghi nhận trả trẻ muộn và tính phụ phí tự động | `LatePickupRecordDto` (studentId, pickupTime, guardianId, reason) | `LatePickupResponseDto` (`MSG-094`) |
| `GET` | `/api/admin/late-pickup-rules` | Lấy bảng quy tắc tính phụ phí đón muộn | Không có | `List<LatePickupFeeRule>` |

---

## G5-UC-06: Xác thực Người Đón AI & Bàn giao Trẻ An toàn

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Giáo viên Mầm non (`TEACHER` / `GIAO_VIEN`)
- **Tác nhân phụ / Hệ thống:** Camera AI nhận diện khuôn mặt người lớn & Quét QR OTP
- **Sự kiện kích hoạt:** Người đến đón trẻ đứng trước camera tại cổng trường hoặc cửa lớp (`/attendance?tab=stranger-alerts`).
- **Mô tả (User Story):** Là Giáo viên mầm non phụ trách trả trẻ, tôi muốn hệ thống camera AI đối chiếu khuôn mặt người đến đón với cơ sở dữ liệu người giám hộ hợp lệ, phát hiện và kích hoạt chuông cảnh báo người lạ nếu không khớp, để ngăn chặn tuyệt đối nguy cơ bắt cóc hoặc bàn giao nhầm trẻ em.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Phụ huynh đã đăng ký danh sách người đón ủy quyền kèm ảnh chân dung (`G4-UC-03`).
- **Hậu điều kiện:**
  - **POST-1:** Hệ thống cấp phép mở chốt cửa an toàn nếu người đón hợp lệ.
  - **POST-2:** Trường hợp người lạ, hệ thống khóa chốt bàn giao, chụp ảnh snapshot lưu vết và gửi cảnh báo khẩn cấp tới BGH và Phụ huynh.

### 2. Luồng sự kiện chính
1. Người đón đứng trước trạm kiểm soát an toàn đón trẻ.
2. Camera AI quét khuôn mặt người đón, trích xuất vector 512 chiều và đối chiếu với danh sách `student.face_encoding_file` của học sinh tương ứng.
3. Nếu độ tương đồng Cosine >= 0.85 (Khớp với Cha, Mẹ hoặc Người ủy quyền):
   - Màn hình hiển thị: "HỢP LỆ: [Họ tên người đón] - Mối quan hệ: [Mẹ/Bố/Ông/Bà] đón bé [Tên học sinh]".
   - Hệ thống cho phép giáo viên bấm xác nhận trao trả trẻ.
4. Nếu độ tương đồng < 0.85 (Không nhận diện được hoặc Người lạ nghi vấn):
   - Hệ thống bật cờ cảnh báo đỏ [CẢNH BÁO NGƯỜI LẠ - STRANGER ALERT] theo quy tắc **BR-021** (Bắt ngoại lệ E1, E2).
   - Hệ thống chặn thao tác bàn giao trẻ trên ứng dụng.
   - Giáo viên tiếp cận trực tiếp người đón, yêu cầu xuất trình Giấy tờ tùy thân (CCCD) hoặc Mã QR ủy quyền đón hộ đột xuất 60 phút (`G5-UC-07`).
5. Sau khi giáo viên xác minh thành công (qua gọi điện phụ huynh hoặc quét mã QR hợp lệ), giáo viên nhập ghi chú giải tỏa cảnh báo và bấm **Giải tỏa Cảnh báo & Trả Trẻ**.
6. Hệ thống ghi nhận biên bản xử lý sự cố vào `student.face_recognition_logs` và hiển thị thông báo **MSG-096**.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Xác thực qua Mã QR Ủy quyền Đón hộ Đột xuất 60 phút:**
  - Người đón xuất trình mã QR do cha mẹ tạo từ ứng dụng di động.
  - Giáo viên dùng máy tính bảng quét mã QR và yêu cầu người đón đọc mã PIN 4 chữ số.
  - Hệ thống kiểm tra mã QR chưa hết hạn (< 60 phút) và mã PIN khớp $ightarrow$ Cấp quyền bàn giao trẻ.
- **BR-021 (Xác thực Sinh trắc học Người Đón & Xử lý Người Lạ Nghi vấn):**
  - Hệ thống đối chiếu khuôn mặt người đón với cơ sở dữ liệu ủy quyền. Trường hợp không khớp, hệ thống chặn bàn giao và kích hoạt cảnh báo người lạ tới BGH và Phụ huynh.
- **Thông báo & Ngoại lệ:**
  - `MSG-096`: "Xác thực danh tính người đón hợp lệ. Bàn giao trẻ an toàn."
  - `E1 (MSG-097)`: "CẢNH BÁO: Phát hiện người lạ không có trong danh sách ủy quyền đón trẻ!"
  - `E2 (MSG-098)`: "Mã QR đón hộ đột xuất đã hết hạn sử dụng hoặc mã PIN không chính xác."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/student/controller/FaceRecognitionController.java`
  - `src/main/java/com/kidpro/domain/student/controller/EmergencyPickupController.java`
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/student/service/FaceRecognitionService.java`
  - `src/main/java/com/kidpro/domain/student/service/EmergencyPickupService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/student/repository/FaceRecognitionLogRepository.java`
  - `src/main/java/com/kidpro/domain/student/repository/EmergencyPickupAuthorizationRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/student/entity/FaceRecognitionLog.java`
  - `src/main/java/com/kidpro/domain/student/entity/EmergencyPickupAuthorization.java`
- **DTOs:**
  - `src/main/java/com/kidpro/domain/student/dto/request/ResolveStrangerAlertDto.java`
  - `src/main/java/com/kidpro/domain/student/dto/response/FaceLogResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/attendance/tabs/StrangerAlertHandlingTab.tsx` (Màn hình giám sát cảnh báo người lạ, đối soát CCCD, modal giải tỏa cảnh báo)
- **API Service Client:**
  - `kidpro-fe/src/api/attendanceApi.ts` (`getUnresolvedAlerts`, `resolveStrangerAlert`, `useEmergencyPickup`)
- **Type Definitions:**
  - `kidpro-fe/src/types/attendance.types.ts` (`FaceLog`, `EmergencyPickupAuthorization`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G5-UC-06] Cảnh Báo Người Lạ*, path: `/attendance?tab=stranger-alerts`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/api/attendance/face-logs/unresolved-alerts` | Danh sách cảnh báo người lạ chưa giải tỏa | Không có | `List<FaceLogResponseDto>` |
| `PUT` | `/api/attendance/face-logs/{id}/resolve-alert` | Xác minh và giải tỏa cảnh báo người lạ (BR-021) | Path: `id`, Body: `ResolveStrangerAlertDto` (notes, strangerName, idCard, outcome) | `FaceLogResponseDto` (`MSG-096`) |
| `PUT` | `/api/academic/emergency-pickups/{id}/use` | Sử dụng mã ủy quyền đón hộ khẩn cấp | Path: `id` | `EmergencyPickupAuthorization` |

---

## G5-UC-08: Quản lý Vận hành & Chốt An toàn Tuyến Xe Buýt

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Giáo viên Đưa đón Xe buýt (`TEACHER` / `MONITOR_TEACHER`)
- **Tác nhân phụ / Hệ thống:** Tài xế xe buýt (`DRIVER`), Định vị GPS
- **Sự kiện kích hoạt:** Giáo viên xe buýt bắt đầu ca đón học sinh buổi sáng hoặc ca trả học sinh buổi chiều.
- **Mô tả (User Story):** Là Giáo viên phụ trách xe buýt đưa đón học sinh, tôi muốn điểm danh trẻ lên/xuống tại từng điểm dừng trên lộ trình và chụp ảnh góc rộng xác nhận khoang xe rỗng hoàn toàn ở cuối ca xe, để đảm bảo không một trẻ nào bị bỏ quên trên xe buýt.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Xe buýt đã được phân công tuyến đường và danh sách học sinh đăng ký dịch vụ đưa đón hợp lệ.
  - **PRE-2:** Tài xế và Giáo viên đã đăng nhập và đồng bộ lịch trình chuyến xe.
- **Hậu điều kiện:**
  - **POST-1:** Trạng thái đưa đón của trẻ được cập nhật thời gian thực (Đã lên xe, Đã tới trường, Đã trả tận nhà).
  - **POST-2:** Bức ảnh chụp khoang xe rỗng và biên bản chốt an toàn được tải lên máy chủ, lưu trữ bất biến phục vụ kiểm toán an toàn.

### 2. Luồng sự kiện chính
1. Giáo viên mở ứng dụng xe buýt, chọn Tuyến xe và Chuyến xe (Ca sáng đón đến trường hoặc Ca chiều trả về).
2. Tại mỗi điểm dừng đón/trả:
   - Giáo viên đón trẻ từ tay phụ huynh, bấm điểm danh [ĐÃ LÊN XE].
   - Hệ thống tự động gửi thông báo thời gian thực tới điện thoại phụ huynh kèm tọa độ GPS điểm đón.
3. Khi xe về tới trường (ca sáng):
   - Giáo viên hướng dẫn toàn bộ trẻ xuống xe và bàn giao cho Giáo viên chủ nhiệm lớp học.
   - Hai giáo viên ký xác nhận biên bản bàn giao quân số trên màn hình.
4. Bước chốt an toàn bắt buộc (Safety Cabin Check) theo quy tắc **BR-024**:
   - Giáo viên xe buýt đi từ đầu xe đến cuối xe, kiểm tra từng hàng ghế, gầm ghế.
   - Giáo viên đứng ở cuối khoang xe, quét mã QR dán cố định tại đuôi xe để kích hoạt máy ảnh.
   - Giáo viên chụp ảnh góc rộng toàn cảnh khoang xe không còn một hành khách nào.
5. Giáo viên nhấn nút **Chốt An Toàn & Kết Thúc Chuyến Xe**.
6. Hệ thống kiểm tra đối soát sĩ số 100% học sinh đã rời xe an toàn (Bắt ngoại lệ E1, E2).
7. Hệ thống khóa chuyến xe, lưu ảnh xác nhận và hiển thị thông báo **MSG-099**.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Phát hiện học sinh ngủ quên trên xe:**
  - Giáo viên phát hiện còn trẻ trong xe, lập tức hủy thao tác chốt an toàn, đưa trẻ xuống xe và thông báo cho BGH.
- **BR-024 (Quy trình Vận hành Đưa đón & Kiểm tra Khoang Xe Buýt):**
  - Điểm danh học sinh từng điểm dừng; tài xế và giáo viên bắt buộc quét mã QR đuôi xe và chụp ảnh khoang xe trống trước khi khóa cửa xe; đối soát sĩ số bàn giao đạt 100%.
- **Thông báo & Ngoại lệ:**
  - `MSG-099`: "Chuyến xe hoàn tất. Biên bản chốt an toàn khoang xe đã được phê duyệt."
  - `E1 (MSG-100)`: "Không thể kết thúc chuyến xe: Vẫn còn học sinh chưa được ghi nhận rời xe!"
  - `E2 (MSG-101)`: "Ảnh xác nhận khoang xe rỗng không hợp lệ hoặc chụp không đúng vị trí mã QR đuôi xe."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/student/controller/BusAttendanceController.java` (Định tuyến `/api/attendance/bus`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/student/service/BusAttendanceService.java`
  - `src/main/java/com/kidpro/domain/student/service/impl/BusAttendanceServiceImpl.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/student/repository/AttendanceRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/student/entity/Attendance.java`
- **DTOs:**
  - `src/main/java/com/kidpro/domain/student/dto/request/BusCheckinDto.java`
  - `src/main/java/com/kidpro/domain/student/dto/request/BusSafetyClosureDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/attendance/tabs/BusTripManagementTab.tsx` (Lộ trình chuyến xe, danh sách điểm dừng, camera quét QR đuôi xe)
- **API Service Client:**
  - `kidpro-fe/src/api/attendanceApi.ts`
- **Type Definitions:**
  - `kidpro-fe/src/types/attendance.types.ts`
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G5-UC-08] Xe Buýt Học Đường*, path: `/attendance?tab=bus-management`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/attendance/bus/stops/checkin` | Điểm danh trẻ lên/xuống tại điểm dừng | `BusCheckinDto` (tripId, studentId, stopId, action, gpsLocation) | `AttendanceResponseDto` |
| `POST` | `/api/attendance/bus/trips/{id}/safety-closure` | Chốt an toàn chụp ảnh khoang xe rỗng (BR-024) | Path: `id`, Body: `BusSafetyClosureDto` (photoUrl, qrTailScanToken, checkedBy) | `ApiResponse` (`MSG-099`) |

---

## G7-UC-01: Nhập Chỉ số Phát triển Thể chất (Chiều cao, Cân nặng)

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Giáo viên Mầm non (`TEACHER` / `GIAO_VIEN`)
- **Tác nhân phụ / Hệ thống:** Thuật toán phân loại thể trạng chuẩn WHO (Z-Score Engine)
- **Sự kiện kích hoạt:** Định kỳ hàng tháng/quý theo kế hoạch y tế học đường, Giáo viên truy cập tab "Chỉ số Thể chất" (`/health?tab=class-metrics`).
- **Mô tả (User Story):** Là Giáo viên mầm non, tôi muốn nhập số liệu chiều cao (cm) và cân nặng (kg) đo định kỳ của toàn bộ học sinh trong lớp, để hệ thống tự động tính toán chỉ số BMI, đối chiếu Z-score chuẩn WHO và tự động xếp loại thể trạng dinh dưỡng (Bình thường, Thấp còi, Gầy còm, Thừa cân/Béo phì).
- **Điều kiện tiên quyết:**
  - **PRE-1:** Giáo viên được phân công phụ trách lớp học.
  - **PRE-2:** Trẻ có thông tin ngày sinh và giới tính chính xác trong hồ sơ học sinh.
- **Hậu điều kiện:**
  - **POST-1:** Dữ liệu số đo được lưu vào bảng `health.health_metrics`.
  - **POST-2:** Biểu đồ tăng trưởng thể lực của trẻ trên ứng dụng phụ huynh được tự động vẽ thêm điểm đo mới.

### 2. Luồng sự kiện chính
1. Giáo viên chọn Lớp học và Đợt khám/đo thể chất định kỳ (ví dụ: "Đo thể lực Đầu năm học 2026-2027").
2. Hệ thống tải bảng nhập liệu toàn lớp (Batch Entry Sheet) gồm: Họ tên bé, Ngày sinh, Giới tính, Chiều cao lần trước, Cân nặng lần trước.
3. Giáo viên nhập Chiều cao (cm, 1 chữ số thập phân) và Cân nặng (kg, 1 chữ số thập phân) cho từng học sinh.
4. Hệ thống tính toán tức thì chỉ số BMI ($BMI = Cân\_nặng / (Chiều\_cao/100)^2$) và đối chiếu thang chuẩn Z-score của WHO theo độ tuổi (tính theo tháng) và giới tính:
   - Thể trạng Cân nặng theo Tuổi: Suy dinh dưỡng nhẹ cân, Bình thường, Thừa cân.
   - Thể trạng Chiều cao theo Tuổi: Thấp còi, Bình thường, Cao hơn chuẩn.
   - Thể trạng BMI theo Tuổi: Gầy còm, Bình thường, Nguy cơ béo phì, Béo phì.
5. Giáo viên kiểm tra lại toàn bộ danh sách lớp và nhấn **Lưu Sổ Theo Dõi Thể Chất**.
6. Hệ thống kiểm tra tính hợp lý của số liệu theo quy tắc **BR-031** (Bắt ngoại lệ E1, E2, E3).
7. Hệ thống lưu trữ dữ liệu, hiển thị thông báo **MSG-131**.
8. Hệ thống gửi thông báo kết quả kiểm tra thể lực đến ứng dụng của từng phụ huynh.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Cảnh báo sụt cân hoặc béo phì đột ngột:**
  - Nếu học sinh bị sụt quá 1.5 kg hoặc tăng quá 2.5 kg so với tháng trước, hệ thống hiển thị hộp thoại màu cam yêu cầu giáo viên kiểm tra và đo lại số liệu.
- **BR-031 (Đánh giá Thể lực theo Chuẩn WHO):**
  - Chỉ số phát triển thể lực của trẻ được đối chiếu tự động theo biểu đồ tăng trưởng Z-score của WHO theo từng tháng tuổi.
- **Thông báo & Ngoại lệ:**
  - `MSG-131`: "Lưu chỉ số phát triển thể chất của lớp học thành công."
  - `E1 (MSG-132)`: "Chiều cao học sinh không hợp lệ (phải từ 50.0 cm đến 140.0 cm)."
  - `E2 (MSG-133)`: "Cân nặng học sinh không hợp lệ (phải từ 5.0 kg đến 50.0 kg)."
  - `E3 (MSG-134)`: "Ngày sinh của học sinh chưa được khai báo đầy đủ để tính độ tuổi tháng."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/healthmedical/controller/HealthMetricController.java` (Định tuyến `/api/health/metrics`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/healthmedical/service/HealthMetricService.java`
  - `src/main/java/com/kidpro/domain/healthmedical/service/impl/HealthMetricServiceImpl.java` (Thuật toán tính Z-score WHO, phân loại thể trạng dinh dưỡng)
- **Repository:**
  - `src/main/java/com/kidpro/domain/healthmedical/repository/HealthMetricRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/healthmedical/entity/HealthMetric.java` (Bảng `health.health_metrics`)
- **DTOs:**
  - `src/main/java/com/kidpro/domain/healthmedical/dto/request/BatchHealthMetricRequestDto.java`
  - `src/main/java/com/kidpro/domain/healthmedical/dto/response/HealthMetricResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/health/tabs/ClassHealthMetricsTab.tsx` (Bảng nhập số đo thể chất cả lớp theo đợt, huy hiệu thể trạng WHO tự động đổi màu)
  - `kidpro-fe/src/pages/health/HealthPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/healthApi.ts` (`saveBatchHealthMetrics`, `getClassStudentsForMetrics`, `getStudentGrowthHistory`)
- **Type Definitions:**
  - `kidpro-fe/src/types/health.types.ts` (`HealthMetric`, `BatchHealthMetricsPayload`, `BatchStudentHealthEntry`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G7-UC-01] Chỉ Số Thể Chất*, path: `/health?tab=class-metrics`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/api/health/metrics/class/{classId}/entry-sheet` | Bảng nhập liệu đo thể chất học sinh của lớp | Path: `classId` (UUID) | `List<BatchStudentHealthEntry>` |
| `POST` | `/api/health/metrics/batch` | Lưu hàng loạt số đo chiều cao cân nặng cả lớp (BR-031) | `BatchHealthMetricRequestDto` (classId, measurementDate, list records) | `ApiResponse` (`MSG-131`) |
| `GET` | `/api/health/metrics/student/{studentId}/growth-history` | Lịch sử đo tăng trưởng vẽ biểu đồ WHO | Path: `studentId` | `List<HealthMetric>` |

---

## G7-UC-02: Ghi chép Nhật ký Xử lý Sự cố Sơ cứu Y tế

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Giáo viên Mầm non (`TEACHER` / `GIAO_VIEN`) hoặc Cán bộ Y tế
- **Tác nhân phụ / Hệ thống:** Ban Giám hiệu, Phụ huynh
- **Sự kiện kích hoạt:** Khi xảy ra sự cố va chạm, té ngã, sốt cao đột ngột hoặc ngộ độc dị ứng trong giờ học (`/health?tab=incidents`).
- **Mô tả (User Story):** Là Giáo viên mầm non phụ trách lớp, tôi muốn ghi nhận lập tức biên bản nhật ký sự vụ sơ cứu y tế (nguyên nhân, biểu hiện, sơ cấp cứu ban đầu, thân nhiệt, thời gian) và phát cảnh báo khẩn cấp tới Ban Giám hiệu và Phụ huynh, để phối hợp điều trị y tế kịp thời và bảo vệ an toàn tính mạng cho trẻ.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Học sinh xảy ra sự cố có mặt tại trường.
- **Hậu điều kiện:**
  - **POST-1:** Sự cố được lưu trữ vào bảng `health.health_incidents` với trạng thái [Đang xử lý] hoặc [Đã hoàn tất sơ cứu].
  - **POST-2:** Hệ thống tự động đẩy cuộc gọi / tin nhắn khẩn cấp tới Phụ huynh và Ban Giám hiệu trường.

### 2. Luồng sự kiện chính
1. Khi có sự cố xảy ra tại lớp, Giáo viên sơ cứu tại chỗ cho trẻ theo phác đồ an toàn mầm non.
2. Giáo viên mở ứng dụng và chọn chức năng **Ghi chép Nhật ký Sơ cứu Y tế**.
3. Giáo viên chọn học sinh bị sự cố và phân loại sự vụ: Ngã/Chấn thương phần mềm, Chảy máu cam, Dị ứng thức ăn, Hóc dị vật, Sốt cao co giật.
4. Giáo viên nhập: Mốc thời gian xảy ra, Vị trí vết thương, Thân nhiệt hiện tại, Các bước sơ cứu đã thực hiện tại chỗ (rửa cồn đỏ, băng gạc, chườm lạnh...).
5. Giáo viên chụp ảnh hiện trường vết thương đính kèm biên bản.
6. Trường hợp sự cố nặng, giáo viên bật nút [CHUYỂN TUYẾN Y TẾ / BÁO ĐỘNG ĐỎ BGH].
7. Giáo viên bấm **Lưu & Phát Cảnh Báo Khẩn Cấp**.
8. Hệ thống kiểm tra quy tắc y tế **BR-031** (Bắt ngoại lệ E1, E2).
9. Hệ thống gửi thông báo PUSH cấp bách tới tài khoản Phụ huynh, kích hoạt thông báo đỏ trên Dashboard Ban Giám hiệu và hiển thị thông báo **MSG-135**.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Trẻ có phản ứng phản vệ dị ứng thực phẩm nặng:**
  - Hệ thống đối chiếu dữ liệu dị ứng (`health.allergy_alert`), hiển thị ngay phác đồ cấp cứu dị ứng của nhà trường.
  - Giáo viên chuyển ngay trẻ xuống Phòng Y tế và gọi xe cấp cứu 115.
- **BR-031 (Nguyên tắc Sơ cứu & Sử dụng Thuốc Khẩn cấp):**
  - Nhân viên y tế/giáo viên thực hiện sơ cứu tại chỗ; tuyệt đối không tự ý cho trẻ uống thuốc hạ sốt hoặc thuốc kháng sinh khi chưa có sự đồng ý của phụ huynh hoặc chỉ định của bác sĩ.
- **Thông báo & Ngoại lệ:**
  - `MSG-135`: "Biên bản sơ cứu y tế học đường đã được ghi nhận và gửi thông báo khẩn cấp."
  - `E1 (MSG-136)`: "Bắt buộc mô tả chi tiết biện pháp sơ cứu đã thực hiện đối với sự cố mức độ nghiêm trọng."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/healthmedical/controller/HealthIncidentController.java`
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/healthmedical/service/HealthIncidentService.java`
  - `src/main/java/com/kidpro/domain/healthmedical/service/impl/HealthIncidentServiceImpl.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/healthmedical/repository/HealthIncidentRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/healthmedical/entity/HealthIncident.java`
- **DTOs:**
  - `src/main/java/com/kidpro/domain/healthmedical/dto/request/HealthIncidentCreateDto.java`
  - `src/main/java/com/kidpro/domain/healthmedical/dto/response/HealthIncidentResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/health/tabs/MedicalIncidentsTab.tsx`
  - `kidpro-fe/src/pages/health/HealthPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/healthApi.ts`
- **Type Definitions:**
  - `kidpro-fe/src/types/health.types.ts` (`MedicalIncidentRecord`, `CreateMedicalIncidentPayload`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G7-UC-02] Nhật Ký Sơ Cứu Y Tế*, path: `/health?tab=incidents`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/health/incidents` | Tạo biên bản ghi chép sơ cứu y tế | `HealthIncidentCreateDto` | `HealthIncidentResponseDto` (`MSG-135`) |
| `PUT` | `/api/health/incidents/{id}/resolve` | Cập nhật kết quả hồi phục sau sơ cứu | Path: `id`, Body: `{ outcome, doctorNotes }` | `HealthIncidentResponseDto` |

---

## G9-UC-04: Đánh giá Trẻ theo Chuẩn Phát triển 5 Lĩnh vực

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Giáo viên Chủ nhiệm (`TEACHER` / `HOMEROOM_TEACHER`)
- **Tác nhân phụ / Hệ thống:** Ban Giám hiệu
- **Sự kiện kích hoạt:** Cuối mỗi học kỳ hoặc cuối năm học, Giáo viên chọn tab "Đánh giá 5 Lĩnh vực" (`/academic?tab=early-childhood-evaluation`).
- **Mô tả (User Story):** Là Giáo viên chủ nhiệm, tôi muốn chấm điểm và viết nhận xét chi tiết sự tiến bộ của trẻ theo 5 lĩnh vực phát triển chuẩn mầm non của Bộ GD&ĐT (Thể chất, Nhận thức, Ngôn ngữ, Tình cảm - Kỹ năng xã hội, Thẩm mỹ), để lập phiếu theo dõi sự phát triển gửi Ban Giám hiệu thẩm tra và công bố trên sổ liên lạc điện tử của phụ huynh.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Học sinh đang học tại lớp và có thời gian theo học tối thiểu 30 ngày trong kỳ đánh giá.
  - **PRE-2:** Niên khóa và kỳ đánh giá định kỳ đang trong trạng thái Mở.
- **Hậu điều kiện:**
  - **POST-1:** Phiếu đánh giá được lưu ở trạng thái [Chờ Ban Giám hiệu duyệt] (`PENDING_APPROVAL`) trong bảng `student.development_evaluation`.
  - **POST-2:** BGH có thể truy cập để rà soát chất lượng sư phạm (`G9-UC-05`).

### 2. Luồng sự kiện chính
1. Giáo viên chọn Lớp học, Niên khóa và Kỳ đánh giá (Cuối Học kỳ I hoặc Cuối Năm học).
2. Hệ thống tải danh sách học sinh của lớp kèm biểu mẫu đánh giá 5 lĩnh vực theo độ tuổi (Nhà trẻ hoặc Mẫu giáo):
   - **Lĩnh vực 1 - Thể chất:** Vận động thô, vận động tinh, thói quen tự phục vụ và giữ gìn vệ sinh (Đạt / Chưa đạt).
   - **Lĩnh vực 2 - Nhận thức:** Khả năng khám phá thế giới xung quanh, làm quen với toán học và biểu tượng không gian (Đạt / Chưa đạt).
   - **Lĩnh vực 3 - Ngôn ngữ:** Kỹ năng nghe hiểu, diễn đạt lời nói, kể chuyện và làm quen chữ viết (Đạt / Chưa đạt).
   - **Lĩnh vực 4 - Tình cảm & Kỹ năng xã hội:** Ý thức về bản thân, thể hiện cảm xúc, kỹ năng ứng xử và tuân thủ quy tắc lớp học (Đạt / Chưa đạt).
   - **Lĩnh vực 5 - Thẩm mỹ:** Cảm thụ và thể hiện cảm xúc qua âm nhạc, tạo hình, vẽ xé dán (Đạt / Chưa đạt).
3. Giáo viên tích chọn kết quả (Đạt / Chưa đạt) cho từng tiêu chí thành phần và chấm điểm tổng kết từng lĩnh vực.
4. Giáo viên viết lời nhận xét sư phạm tổng quát về sự tiến bộ, thế mạnh và điểm cần phối hợp rèn luyện thêm tại nhà cho từng trẻ (tối thiểu 50 từ).
5. Giáo viên nhấn **Lưu Bản Nháp** hoặc **Gửi Ban Giám Hiệu Phê Duyệt**.
6. Hệ thống kiểm tra dung lượng nhận xét và sự đầy đủ của 5 lĩnh vực theo quy tắc **BR-049** (Bắt ngoại lệ E1, E2, E3).
7. Hệ thống chuyển trạng thái phiếu đánh giá thành `PENDING_APPROVAL` và hiển thị thông báo **MSG-181**.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Ban Giám hiệu từ chối phiếu đánh giá:**
  - BGH gửi trả phiếu kèm lý do nhận xét sơ sài, giáo viên mở lại phiếu, chỉnh sửa nhận xét theo yêu cầu và nộp lại.
- **BR-049 (Tiêu chuẩn Đánh giá 5 Lĩnh vực Phát triển & Dung lượng Nhận xét):**
  - Phiếu đánh giá định kỳ bắt buộc chấm điểm đầy đủ cả 5 lĩnh vực phát triển theo Thông tư Bộ GD&ĐT.
  - Phần nhận xét sư phạm của giáo viên bắt buộc có dung lượng tối thiểu 50 từ và không dùng các mẫu rập khuôn sao chép.
- **Thông báo & Ngoại lệ:**
  - `MSG-181`: "Gửi phiếu đánh giá phát triển của học sinh lên Ban Giám hiệu thành công."
  - `E1 (MSG-182)`: "Chưa chấm điểm đầy đủ cả 5 lĩnh vực phát triển theo quy định."
  - `E2 (MSG-183)`: "Lời nhận xét của giáo viên quá ngắn (yêu cầu tối thiểu 50 từ theo BR-049)."
  - `E3 (MSG-184)`: "Kỳ đánh giá đã khóa sổ, không thể nộp thêm phiếu đánh giá mới."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/student/controller/DevelopmentEvaluationApprovalController.java` (Định tuyến `/api/academic/development-evaluations`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/student/service/DevelopmentEvaluationApprovalService.java`
  - `src/main/java/com/kidpro/domain/student/service/impl/DevelopmentEvaluationApprovalServiceImpl.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/student/repository/DevelopmentEvaluationRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/student/entity/DevelopmentEvaluation.java` (Bảng `student.development_evaluation`)
- **DTOs:**
  - `src/main/java/com/kidpro/domain/student/dto/request/DevelopmentEvaluationSubmitDto.java`
  - `src/main/java/com/kidpro/domain/student/dto/response/DevelopmentEvaluationApprovalDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/academic/tabs/EarlyChildhoodEvaluationTab.tsx` (Bảng chấm 5 lĩnh vực, đếm từ nhận xét, nút gửi duyệt)
  - `kidpro-fe/src/pages/academic/components/EarlyChildhoodRadarModal.tsx` (Biểu đồ radar mạng nhện 5 trục thể hiện mức độ phát triển)
- **API Service Client:**
  - `kidpro-fe/src/api/developmentEvaluationApi.ts` (`submitEvaluation`, `getEvaluationsByClass`)
  - `kidpro-fe/src/api/healthApi.ts` (`createEvaluation`, `updateEvaluation`)
- **Type Definitions:**
  - `kidpro-fe/src/types/health.types.ts` (`DevelopmentEvaluation`, `FiveDomainCriteria`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G9-UC-04] Đánh Giá 5 Lĩnh Vực*, path: `/academic?tab=early-childhood-evaluation`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/api/health/evaluations/class/{classId}` | Lấy danh sách phiếu đánh giá của lớp | Path: `classId`, Query: `term`, `academicYear` | `List<DevelopmentEvaluation>` |
| `POST` | `/api/health/evaluations` | Lưu nháp hoặc nộp phiếu đánh giá 5 lĩnh vực (BR-049) | `DevelopmentEvaluationSubmitDto` (studentId, 5 domains score, comments, status) | `DevelopmentEvaluation` (`MSG-181`) |
| `PUT` | `/api/health/evaluations/{id}` | Cập nhật phiếu đánh giá khi bị yêu cầu sửa đổi | Path: `id`, Body: `DevelopmentEvaluationSubmitDto` | `DevelopmentEvaluation` |

---

## G9-UC-07: Báo cáo Hư hỏng Cơ sở Vật chất Lớp

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Giáo viên Mầm non (`TEACHER` / `GIAO_VIEN`)
- **Tác nhân phụ / Hệ thống:** Nhân viên Quản trị Thiết bị / Kế toán
- **Sự kiện kích hoạt:** Giáo viên phát hiện đồ dùng, đồ chơi hoặc trang thiết bị phòng học bị hư hỏng (`/academic?tab=classroom-equipment`).
- **Mô tả (User Story):** Là Giáo viên đứng lớp, tôi muốn lập phiếu báo hỏng trang thiết bị phòng học (quạt trần, điều hòa, đồ chơi bập bênh, lan can, đèn chiếu sáng...) kèm hình ảnh minh chứng hiện trường, để bộ phận kỹ thuật hậu cần và Ban Giám hiệu tiếp nhận sửa chữa kịp thời, đảm bảo an toàn cho học sinh.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Giáo viên phụ trách phòng học phát sinh sự cố hư hỏng tài sản.
- **Hậu điều kiện:**
  - **POST-1:** Phiếu báo hỏng được tạo ở trạng thái [Chờ Tiếp Nhận] trong danh mục quản lý tài sản.
  - **POST-2:** Hệ thống gửi thông báo tới bộ phận Kỹ thuật / Quản trị cơ sở vật chất của nhà trường.

### 2. Luồng sự kiện chính
1. Giáo viên truy cập tab "Thiết bị & Cơ sở Vật chất Phòng học".
2. Hệ thống tải danh mục trang thiết bị được phân bổ trong phòng học của lớp.
3. Giáo viên chọn thiết bị bị hỏng hoặc chọn "Báo hỏng ngoài danh mục".
4. Giáo viên chọn mức độ nghiêm trọng: Bình thường (Hao mòn nhẹ), Cần sửa gấp, hoặc Nguy hiểm an toàn cho trẻ (Hở điện, nứt vỡ sắc nhọn).
5. Giáo viên nhập mô tả tình trạng hư hỏng và chụp ảnh hiện trường thực tế tải lên hệ thống.
6. Giáo viên nhấn **Gửi Báo Cáo Hư Hỏng**.
7. Hệ thống kiểm tra tính hợp lệ và ảnh minh chứng theo quy tắc **BR-051** và **BR-052** (Bắt ngoại lệ E1, E2).
8. Hệ thống lưu phiếu báo hỏng, hiển thị thông báo **MSG-185**.
9. Nếu sự cố đánh dấu [Nguy hiểm an toàn cho trẻ], hệ thống kích hoạt thông báo đỏ khẩn cấp tới BGH và Kỹ thuật trường.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Thiết bị đang trong quá trình bảo dưỡng:**
  - Nếu thiết bị đã có phiếu báo hỏng đang chờ thợ sửa, hệ thống hiển thị mã phiếu cũ và chặn tạo thêm phiếu trùng.
- **BR-051 & BR-052 (Quy định Báo hỏng & Xử lý Sự cố Cơ sở Vật chất):**
  - Khi báo hỏng trang thiết bị bắt buộc phải đính kèm ảnh chụp minh chứng hiện trường.
  - Sự cố thiết bị được đánh dấu gây nguy hiểm an toàn cho trẻ bắt buộc phải được bộ phận kỹ thuật tiếp nhận xử lý trong vòng 02 giờ.
- **Thông báo & Ngoại lệ:**
  - `MSG-185`: "Gửi báo cáo hư hỏng thiết bị thành công."
  - `E1 (MSG-186)`: "Bắt buộc chụp ảnh đính kèm hiện trường khi gửi báo cáo hư hỏng tài sản."
  - `E2 (MSG-187)`: "Thiết bị này đã có phiếu báo hỏng đang trong tiến trình xử lý."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/academic/controller/ClassroomEquipmentController.java` (Định tuyến `/api/academic/equipment/incidents`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/academic/service/ClassroomEquipmentService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/academic/repository/ClassroomRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/academic/entity/Classroom.java`
- **DTOs:**
  - `src/main/java/com/kidpro/domain/academic/dto/request/EquipmentIncidentRequestDto.java`
  - `src/main/java/com/kidpro/domain/academic/dto/response/EquipmentIncidentResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/academic/tabs/ClassroomEquipmentTab.tsx` (Danh sách trang thiết bị lớp, modal báo hỏng, tải ảnh chụp)
  - `kidpro-fe/src/pages/academic/AcademicPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/facilityClassroomApi.ts`
- **Type Definitions:**
  - `kidpro-fe/src/types/classroom.types.ts`
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G9-UC-07] Báo Hỏng Thiết Bị*, path: `/academic?tab=equipment`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/academic/equipment/incidents` | Gửi báo cáo hư hỏng thiết bị phòng học | `EquipmentIncidentRequestDto` (classroomId, equipmentName, severity, photoUrl, description) | `EquipmentIncidentResponseDto` (`MSG-185`) |
| `GET` | `/api/academic/equipment/incidents/class/{classroomId}` | Lịch sử các phiếu báo hỏng của phòng học | Path: `classroomId` (UUID) | `List<EquipmentIncidentResponseDto>` |

---

## G9-UC-08: Soạn Thảo & Nộp Kế hoạch Giáo án Tuần

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Giáo viên Mầm non (`TEACHER` / `GIAO_VIEN`)
- **Tác nhân phụ / Hệ thống:** Ban Giám hiệu (Phó Hiệu trưởng phụ trách Chuyên môn)
- **Sự kiện kích hoạt:** Hàng tuần trước thời hạn 17:00 ngày thứ Năm, Giáo viên truy cập tab "Kế hoạch Giáo án Tuần" (`/academic?tab=weekly-lesson-plan`).
- **Mô tả (User Story):** Là Giáo viên mầm non đứng lớp, tôi muốn soạn thảo trực tuyến hoặc tải lên kế hoạch giáo án tuần theo chủ đề bài giảng (hoạt động học, góc chơi, ngoài trời, sinh hoạt chiều) kèm tệp tài liệu giáo án, để trình Ban Giám hiệu kiểm duyệt và phê duyệt trước khi đưa vào áp dụng giảng dạy tuần tới.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Giáo viên đã được phân công chuyên môn và giảng dạy tại lớp.
  - **PRE-2:** Chủ đề năm học và phân phối chương trình của khối lớp đã được kích hoạt.
- **Hậu điều kiện:**
  - **POST-1:** Bản giáo án tuần được lưu ở trạng thái [Chờ Phê Duyệt] (`SUBMITTED`) trên hệ thống.
  - **POST-2:** BGH nhận được thông báo kiểm duyệt giáo án tuần trên cổng điều hành (`G9-UC-09`).

### 2. Luồng sự kiện chính
1. Giáo viên chọn Lớp học, Tuần học (ví dụ: "Tuần 08: Từ 20/10/2026 đến 24/10/2026") và Chủ đề tuần (ví dụ: "Bé và Gia đình thân yêu").
2. Giáo viên nhập khung nội dung các hoạt động giáo dục từ Thứ Hai đến Thứ Sáu:
   - Đón trẻ & Thể dục sáng.
   - Hoạt động học có chủ đích (Toán, Khám phá khoa học, Âm nhạc, Tạo hình).
   - Hoạt động chơi ở các góc (Góc phân vai, Góc xây dựng, Góc học tập).
   - Hoạt động dạo chơi ngoài trời.
   - Hoạt động ăn, ngủ, vệ sinh & Sinh hoạt chiều.
3. Giáo viên đính kèm tệp tài liệu giáo án chi tiết (Word / PDF / PPTX, dung lượng <= 20MB).
4. Giáo viên kiểm tra lại nội dung và nhấn nút **Nộp Giáo Án Cho BGH**.
5. Hệ thống kiểm tra thời hạn nộp trước 17:00 thứ Năm và dung lượng tệp theo quy tắc **BR-053** (Bắt ngoại lệ E1, E2, E3).
6. Hệ thống chuyển trạng thái giáo án sang `SUBMITTED`, hiển thị thông báo **MSG-188**.
7. Hệ thống tự động ghi nhật ký nộp giáo án đúng hạn phục vụ bình xét thi đua giáo viên.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Chỉnh sửa theo yêu cầu của Ban Giám hiệu:**
  - Khi BGH trả về yêu cầu sửa chữa kèm góp ý sư phạm, hệ thống gửi thông báo cho giáo viên.
  - Giáo viên cập nhật lại giáo án và nộp lại trước 12:00 ngày thứ Bảy.
- **BR-053 (Thời hạn Nộp Giáo án Tuần & Kiểm soát Dung lượng):**
  - Giáo viên bắt buộc nộp giáo án trước 17:00 ngày thứ Năm hàng tuần, đầy đủ hoạt động 5 ngày; dung lượng tệp đính kèm không quá 20MB.
  - Sau thời điểm chốt, hệ thống khóa quyền nộp bổ sung và đánh dấu giáo án nộp muộn.
- **Thông báo & Ngoại lệ:**
  - `MSG-188`: "Nộp kế hoạch giáo án tuần lên Ban Giám hiệu thành công."
  - `E1 (MSG-189)`: "Đã quá thời hạn nộp giáo án tuần (hạn chót là 17:00 ngày thứ Năm)."
  - `E2 (MSG-190)`: "Tệp đính kèm vượt quá dung lượng tối đa cho phép (20MB)."
  - `E3 (MSG-191)`: "Chưa điền đầy đủ kế hoạch hoạt động giáo dục cho đủ 5 ngày trong tuần."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/academic/controller/LessonPlanApprovalController.java` (Định tuyến `/api/academic/lesson-plans`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/academic/service/LessonPlanApprovalService.java`
  - `src/main/java/com/kidpro/domain/academic/service/impl/LessonPlanApprovalServiceImpl.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/academic/repository/ClassEntityRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/academic/entity/ClassEntity.java`
- **DTOs:**
  - `src/main/java/com/kidpro/domain/academic/dto/request/LessonPlanReviewRequestDto.java`
  - `src/main/java/com/kidpro/domain/academic/dto/response/LessonPlanApprovalDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/academic/tabs/WeeklyLessonPlanTab.tsx` (Biểu mẫu soạn giáo án 5 ngày, kéo thả tệp tài liệu, đồng hồ đếm ngược hạn nộp)
  - `kidpro-fe/src/pages/academic/AcademicPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/lessonPlanApprovalApi.ts`
- **Type Definitions:**
  - `kidpro-fe/src/types/classroom.types.ts`
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G9-UC-08] Soạn Kế Hoạch Giáo Án*, path: `/academic?tab=lesson-plan`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/academic/lesson-plans` | Nộp kế hoạch giáo án tuần (BR-053) | `MultipartFormData`: metadata JSON (week, classId, theme, dailyPlans) + file đính kèm | `LessonPlanApprovalDto` (`MSG-188`) |
| `GET` | `/api/academic/lesson-plans/class/{classId}` | Lấy danh sách giáo án đã nộp theo lớp | Path: `classId`, Query: `academicYear` | `List<LessonPlanApprovalDto>` |

---

## G10-UC-02: Tiếp nhận & Đối chiếu Thuốc Phụ huynh Gửi

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Giáo viên Mầm non (`TEACHER` / `GIAO_VIEN`)
- **Tác nhân phụ / Hệ thống:** Phụ huynh học sinh
- **Sự kiện kích hoạt:** Phụ huynh gửi đơn dặn thuốc trực tuyến và mang thuốc đến bàn giao tận tay giáo viên vào đầu ngày đón trẻ (`/health?tab=medication-admin`).
- **Mô tả (User Story):** Là Giáo viên đứng lớp, tôi muốn tiếp nhận thuốc thực tế phụ huynh gửi, đối chiếu với đơn dặn thuốc điện tử trên ứng dụng (tên thuốc, hạn sử dụng, liều dùng, đơn thuốc bác sĩ), kiểm tra nhãn dán định danh và bấm xác nhận tiếp nhận, để đảm bảo không nhận nhầm thuốc và tuyệt đối an toàn cho trẻ.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Phụ huynh đã tạo đơn dặn thuốc thành công trên ứng dụng (`G10-UC-01`).
  - **PRE-2:** Thuốc mang đến trường có nhãn định danh tên học sinh và lớp học rõ ràng.
- **Hậu điều kiện:**
  - **POST-1:** Đơn dặn thuốc chuyển trạng thái từ [Chờ Tiếp Nhận] sang [Đã Tiếp Nhận & Sẵn Sàng Cho Uống] (`RECEIVED`) trong bảng `health.medication_request`.
  - **POST-2:** Hệ thống tự động đặt lịch chuông cảnh báo nhắc giờ uống thuốc cho Giáo viên trên điện thoại/máy tính bảng.

### 2. Luồng sự kiện chính
1. Phụ huynh bàn giao thuốc cho Giáo viên tại cửa lớp.
2. Giáo viên mở tab "Quản lý Cho Uống Thuốc", chọn học sinh tương ứng.
3. Hệ thống hiển thị chi tiết đơn dặn thuốc điện tử: Ảnh chụp đơn thuốc của bác sĩ, Tên các loại thuốc, Liều lượng từng lần, Giờ dặn uống (ví dụ: 11:30 sau ăn trưa), Hướng dẫn đặc biệt (uống cùng nước ấm, lắc đều trước khi uống).
4. Giáo viên đối chiếu thuốc thực tế:
   - Kiểm tra hạn dùng trên bao bì thuốc.
   - Kiểm tra tên thuốc và hàm lượng khớp với đơn bác sĩ.
   - Kiểm tra nhãn tên của trẻ dán trên hộp thuốc.
5. Giáo viên tích chọn [ĐÃ ĐỐI CHIẾU KHỚP ĐƠN] và nhấn **Xác Nhận Tiếp Nhận Thuốc**.
6. Hệ thống kiểm tra điều kiện an toàn y tế theo quy tắc **BR-029** và **BR-030** (Bắt ngoại lệ E1, E2, E3).
7. Hệ thống cập nhật trạng thái đơn thuốc thành `RECEIVED`, hiển thị thông báo **MSG-201**.
8. Hệ thống gửi thông báo xác nhận đã nhận thuốc tức thì đến ứng dụng phụ huynh.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Thuốc không có đơn bác sĩ hoặc không rõ nguồn gốc:**
  - Giáo viên từ chối tiếp nhận theo quy định an toàn y tế học đường, giải thích cho phụ huynh và ghi lý do từ chối vào hệ thống.
- **BR-029 & BR-030 (Điều kiện Tiếp nhận Thuốc & Nhãn Định danh):**
  - Chỉ tiếp nhận thuốc có đơn bác sĩ kê đơn rõ ràng họ tên trẻ, liều lượng và thời điểm uống.
  - Bao bì thuốc bắt buộc phải có nhãn tên và lớp của trẻ; phụ huynh bắt buộc bàn giao trực tiếp tận tay giáo viên, không bỏ vào balo trẻ.
- **Thông báo & Ngoại lệ:**
  - `MSG-201`: "Tiếp nhận và đối chiếu thuốc của học sinh thành công."
  - `E1 (MSG-202)`: "Từ chối tiếp nhận: Thuốc không có đơn chỉ định của bác sĩ chuyên khoa theo BR-029."
  - `E2 (MSG-203)`: "Bao bì thuốc đã quá hạn sử dụng hoặc bị mờ nhãn định danh."
  - `E3 (MSG-204)`: "Khoảng cách giữa hai liều uống quá gần nhau (< 4 giờ theo quy định)."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/healthmedical/controller/MedicationAdminController.java` (Định tuyến `/api/health/medications`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/healthmedical/service/MedicationAdminService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/healthmedical/repository/MedicationRequestRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/healthmedical/entity/MedicationRequest.java` (Bảng `health.medication_request`)
- **DTOs:**
  - `src/main/java/com/kidpro/domain/healthmedical/dto/response/MedicationResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/health/tabs/MedicationAdministrationTab.tsx` (Danh sách đơn dặn thuốc trong ngày, thẻ đối chiếu nhãn thuốc, nút tiếp nhận)
  - `kidpro-fe/src/pages/health/HealthPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/healthApi.ts` (`getMedications`, `submitMedication`)
- **Type Definitions:**
  - `kidpro-fe/src/types/health.types.ts`
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G10-UC-02] Tiếp Nhận Thuốc*, path: `/health?tab=medications`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/api/health/medications` | Danh sách đơn thuốc cần cho uống trong ngày | Query: `date`, `classId` | `List<MedicationResponseDto>` |
| `PUT` | `/api/health/medications/{id}/receive` | Xác nhận tiếp nhận thuốc sau đối chiếu (BR-030) | Path: `id`, Body: `{ teacherNotes }` | `MedicationResponseDto` (`MSG-201`) |
| `PUT` | `/api/health/medications/{id}/reject` | Từ chối tiếp nhận thuốc không hợp lệ | Path: `id`, Body: `{ rejectReason }` | `MedicationResponseDto` |

---

## G10-UC-03: Xác nhận Cho Trẻ Uống Thuốc Kèm Ảnh Chụp

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Giáo viên Mầm non (`TEACHER` / `GIAO_VIEN`)
- **Tác nhân phụ / Hệ thống:** Hệ thống Thông báo Đẩy (FCM)
- **Sự kiện kích hoạt:** Hệ thống bật chuông cảnh báo đến giờ cho trẻ uống thuốc hoặc giáo viên chủ động thực hiện theo cữ uống (`/health?tab=medication-admin`).
- **Mô tả (User Story):** Là Giáo viên mầm non, tôi muốn nhận cảnh báo nhắc giờ tự động, lấy đúng thuốc của trẻ, đối chiếu liều lượng và chụp ảnh xác nhận quá trình trẻ uống thuốc để gửi báo cáo tức thì cho phụ huynh, nhằm đảm bảo đúng thuốc, đúng liều, đúng giờ và minh bạch trách nhiệm y tế.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Đơn thuốc đã được tiếp nhận ở bước G10-UC-02 (`STATUS = RECEIVED`).
  - **PRE-2:** Học sinh đang có mặt tại lớp học.
- **Hậu điều kiện:**
  - **POST-1:** Bản ghi lịch sử uống thuốc được lưu vào bảng `health.medication_admin_logs` kèm ảnh chụp minh chứng.
  - **POST-2:** Đơn dặn thuốc chuyển trạng thái thành [Đã Uống Thuốc] (`ADMINISTERED`) và phụ huynh nhận được thông báo kèm hình ảnh.

### 2. Luồng sự kiện chính
1. Đến giờ dặn thuốc (ví dụ: 11:30), hệ thống phát âm thanh chuông nhắc nhở trên thiết bị của giáo viên.
2. Giáo viên vào tab Cho Uống Thuốc, chọn đơn thuốc đến giờ của bé.
3. Giáo viên lấy đúng túi thuốc đã gán nhãn, chuẩn bị cốc nước ấm và rót đúng liều lượng (ví dụ: 5ml siro hoặc 1 viên).
4. Giáo viên quan sát cho học sinh uống thuốc.
5. Giáo viên kích hoạt camera trên ứng dụng, chụp ảnh rõ nét khoảnh khắc bé đang uống thuốc hoặc cầm cốc thuốc.
6. Giáo viên ghi chú biểu hiện của trẻ (uống ngoan, nôn trớ sau uống nếu có) và nhấn nút **Xác Nhận Đã Cho Uống Thuốc**.
7. Hệ thống kiểm tra tính hợp lệ của ảnh chụp theo quy tắc **BR-030** (Bắt ngoại lệ E1, E2).
8. Hệ thống lưu bản ghi vào `health.medication_admin_logs`, cập nhật trạng thái đơn thuốc thành `ADMINISTERED`, hiển thị thông báo **MSG-205**.
9. Hệ thống gửi thông báo Push Notification kèm ảnh chụp minh chứng tức thì tới ứng dụng của phụ huynh.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Trẻ nôn trớ thuốc sau khi uống:**
  - Giáo viên ghi nhận tình trạng nôn trớ, đo nhiệt độ của trẻ. Tuyệt đối không tự ý cho uống bù liều mà phải gọi điện xin ý kiến phụ huynh và bác sĩ.
- **BR-030 (Bằng chứng Cho Uống Thuốc Minh bạch):**
  - Giáo viên bắt buộc chụp ảnh bằng chứng lúc cho trẻ uống thuốc; ảnh phải rõ mặt trẻ và cốc/viên thuốc để đẩy thông báo minh chứng tới phụ huynh.
- **Thông báo & Ngoại lệ:**
  - `MSG-205`: "Xác nhận cho học sinh uống thuốc thành công. Ảnh minh chứng đã gửi tới phụ huynh."
  - `E1 (MSG-206)`: "Bắt buộc chụp ảnh minh chứng thực tế khi hoàn tất cho trẻ uống thuốc."
  - `E2 (MSG-207)`: "Chưa tới khung giờ dặn uống thuốc hoặc hai lần uống cách nhau chưa đủ 4 giờ."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/healthmedical/controller/MedicationAdminController.java`
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/healthmedical/service/MedicationAdminService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/healthmedical/repository/MedicationAdminLogRepository.java`
  - `src/main/java/com/kidpro/domain/healthmedical/repository/MedicationRequestRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/healthmedical/entity/MedicationAdminLog.java` (Bảng `health.medication_admin_logs`)
  - `src/main/java/com/kidpro/domain/healthmedical/entity/MedicationRequest.java`
- **DTOs:**
  - `src/main/java/com/kidpro/domain/healthmedical/dto/request/AdministerMedicationRequestDto.java`
  - `src/main/java/com/kidpro/domain/healthmedical/dto/response/MedicationResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/health/tabs/MedicationAdministrationTab.tsx` (Thao tác chụp ảnh cho uống thuốc, đếm cữ uống, gửi thông báo)
  - `kidpro-fe/src/pages/health/HealthPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/healthApi.ts` (`administerMedication`)
- **Type Definitions:**
  - `kidpro-fe/src/types/health.types.ts`
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G10-UC-03] Xác Nhận Cho Uống Thuốc*, path: `/health?tab=medications`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `PUT` | `/api/health/medications/{id}/administer` | Xác nhận cho uống thuốc kèm ảnh minh chứng (BR-030) | Path: `id`, Body: `AdministerMedicationRequestDto` (proofPhotoUrl, witnessTeacherId, notes) | `MedicationResponseDto` (`MSG-205`) |

---

## G10-UC-04: Ghi nhận Nhật ký Giấc ngủ & Vệ sinh Hằng ngày

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Giáo viên Mầm non (`TEACHER` / `GIAO_VIEN`)
- **Tác nhân phụ / Hệ thống:** Không có
- **Sự kiện kích hoạt:** Vào đầu giờ chiều sau giờ ngủ trưa và cuối ngày sinh hoạt (`/health?tab=journal`).
- **Mô tả (User Story):** Là Giáo viên mầm non, tôi muốn ghi nhận nhanh tình trạng giấc ngủ trưa (ngủ ngon giấc, trằn trọc, khó ngủ, thời lượng ngủ) và nhật ký đi vệ sinh tiêu hóa của từng trẻ trong ngày, để gửi báo cáo thường nhật về sổ liên lạc điện tử giúp cha mẹ theo dõi nếp sinh hoạt và phát hiện sớm bất thường tiêu hóa của con.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Học sinh có mặt tại lớp trong ngày ghi nhận nhật ký.
- **Hậu điều kiện:**
  - **POST-1:** Bản ghi hoạt động được lưu vào bảng `student.daily_activities`.
  - **POST-2:** Bảng Dòng thời gian sinh hoạt của trẻ trên ứng dụng phụ huynh được cập nhật tức thời.

### 2. Luồng sự kiện chính
1. Giáo viên mở tab "Nhật ký Hoạt động Lớp", chọn danh sách lớp học phụ trách.
2. Hệ thống hiển thị bảng ghi nhận sinh hoạt ngày:
   - **Bữa ăn:** Ăn hết suất, Ăn 2/3 suất, Ăn ít / Cần cô đút.
   - **Giấc ngủ trưa:** Thời gian bắt đầu ngủ (mặc định 11:45) - Thời gian thức dậy (mặc định 14:00); Chất lượng giấc ngủ: Ngủ sâu giấc, Hay giật mình, Khó ngủ / Không ngủ.
   - **Nhật ký Tiêu hóa / Vệ sinh:** Đi tiểu bình thường; Đại tiện (Kèm số lần, tính chất phân: Bình thường, Táo bón, Phân lỏng / Tiêu chảy).
3. Giáo viên có thể dùng tính năng "Áp dụng cả lớp ngủ ngon" và chỉ tích chỉnh sửa cho các trẻ có biểu hiện đặc biệt.
4. Trường hợp trẻ có dấu hiệu bất thường về tiêu hóa (tiêu chảy phân lỏng >= 2 lần), giáo viên ghi chú chi tiết và chụp ảnh tã lót nếu cần thiết.
5. Giáo viên nhấn **Lưu & Đăng Nhật Ký Sinh Hoạt**.
6. Hệ thống kiểm tra tính toàn vẹn dữ liệu, lưu vào bảng `student.daily_activities`, hiển thị thông báo **MSG-208**.
7. Hệ thống tự động gửi thông báo tổng hợp sinh hoạt thường nhật tới gia đình trẻ.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Cảnh báo dấu hiệu rối loạn tiêu hóa:**
  - Nếu trẻ đi ngoài phân lỏng từ 2 lần trở lên trong ngày, hệ thống bật cờ cảnh báo vàng trên màn hình giáo viên và tự động gửi tin nhắn lưu ý cha mẹ theo dõi tại nhà.
- **BR-032 (Quy chuẩn Đồng bộ Thông tin Thường nhật & Cảnh báo):**
  - Mọi bất thường về giấc ngủ và tiêu hóa phải được ghi nhận trung thực; tuyệt đối không che giấu thông tin trẻ sốt hoặc tiêu chảy tại lớp.
- **Thông báo & Ngoại lệ:**
  - `MSG-208`: "Đã lưu nhật ký sinh hoạt, giấc ngủ và vệ sinh của lớp học thành công."
  - `E1 (MSG-209)`: "Thời lượng ngủ không hợp lệ (giờ thức dậy phải sau giờ bắt đầu ngủ)."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/student/controller/DailyActivityController.java` (Định tuyến `/api/health/nap-records` & `/api/health/meal-records`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/student/service/DailyActivityService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/student/repository/DailyActivityRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/student/entity/DailyActivity.java` (Bảng `student.daily_activities`)
- **DTOs:**
  - `src/main/java/com/kidpro/domain/student/dto/request/DailyActivityRecordDto.java`
  - `src/main/java/com/kidpro/domain/student/dto/response/DailyActivityResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/health/tabs/ClassroomJournalTab.tsx` (Bảng ghi nhanh ăn ngủ vệ sinh, bộ lọc lớp, nút áp dụng mẫu nhanh)
  - `kidpro-fe/src/pages/health/HealthPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/healthApi.ts` (`createNapRecord`, `createMealRecord`, `getNapRecordsByStudent`)
- **Type Definitions:**
  - `kidpro-fe/src/types/health.types.ts` (`NapRecord`, `MealRecord`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G10-UC-04] Nhật Ký Hoạt Động*, path: `/health?tab=journal`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/health/nap-records` | Ghi nhận nhật ký giấc ngủ trưa | `DailyActivityRecordDto` (studentId, date, startTime, endTime, sleepQuality, notes) | `NapRecord` (`MSG-208`) |
| `POST` | `/api/health/meal-records` | Ghi nhận lượng ăn các bữa trong ngày | `DailyActivityRecordDto` (studentId, date, mealType, intakeLevel, notes) | `MealRecord` |
| `GET` | `/api/health/nap-records/student/{studentId}` | Lấy lịch sử giấc ngủ của học sinh | Path: `studentId`, Query: `date` | `List<NapRecord>` |

---

## G10-UC-09: Tiếp nhận & Phê duyệt Đơn Xin Nghỉ Học

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Giáo viên Chủ nhiệm (`TEACHER` / `HOMEROOM_TEACHER`)
- **Tác nhân phụ / Hệ thống:** Phụ huynh học sinh, Bếp ăn bán trú
- **Sự kiện kích hoạt:** Phụ huynh gửi đơn xin nghỉ học qua ứng dụng trước giờ học (`/attendance?tab=leave-requests`).
- **Mô tả (User Story):** Là Giáo viên chủ nhiệm lớp, tôi muốn xem xét lý do và phê duyệt đơn xin nghỉ học của phụ huynh trước 08:30 sáng, để hệ thống tự động cập nhật sĩ số vắng có phép, đồng bộ danh sách giảm suất ăn với Nhà bếp và làm căn cứ hoàn trả tiền ăn hợp lệ cho phụ huynh theo quy định.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Phụ huynh đã gửi đơn xin nghỉ học hợp lệ trước thời điểm chốt giờ quy định.
- **Hậu điều kiện:**
  - **POST-1:** Trạng thái đơn xin nghỉ chuyển thành [Đã Phê Duyệt] (`APPROVED`) trong bảng `student.leave_requests`.
  - **POST-2:** Dữ liệu tự động gán trạng thái vắng có phép (`EXCUSED_ABSENCE`) trên bảng điểm danh ngày và giảm trừ suất ăn với Nhà bếp.

### 2. Luồng sự kiện chính
1. Giáo viên mở tab "Duyệt Đơn Xin Nghỉ", hệ thống hiển thị danh sách các đơn nghỉ học mới nhận.
2. Giáo viên bấm xem chi tiết đơn gồm: Tên học sinh, Khoảng ngày xin nghỉ (Từ ngày - Đến ngày), Lý do nghỉ (Bị ốm, Đi du lịch cùng gia đình, Việc riêng), Tệp đơn thuốc/giấy hẹn bác sĩ đính kèm (nếu có).
3. Giáo viên đối chiếu mốc thời gian nộp đơn với quy tắc **BR-018** và **BR-064** (Nộp trước 07:00 sáng đối với gói ăn trọn gói hoặc trước 08:00 sáng).
4. Giáo viên nhập ghi chú dặn dò phụ huynh chăm sóc trẻ tại nhà (ví dụ: "Chúc con mau khỏe, cô đã nhận đơn nhé").
5. Giáo viên nhấn nút **Phê Duyệt Đơn** (hoặc **Từ Chối** kèm lý do).
6. Hệ thống kiểm tra thẩm quyền theo quy tắc **BR-065** (Bắt ngoại lệ E1, E2).
7. Hệ thống cập nhật trạng thái đơn thành `APPROVED`, tự động đánh dấu cờ `mealRefundApplied = true` nếu đơn nộp đúng hạn.
8. Hệ thống hiển thị thông báo **MSG-215**, đồng bộ sang Bếp bán trú và gửi thông báo xác nhận tới máy phụ huynh.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Đơn nộp muộn sau 08:30 sáng:**
  - Giáo viên vẫn có thể duyệt phép để lưu vết chuyên cần của học sinh, tuy nhiên hệ thống sẽ đánh cờ `mealRefundApplied = false` (không được hoàn tiền ăn bữa đó do Bếp đã nấu suất ăn).
- **BR-064 & BR-065 (Thời hạn Nộp & Thẩm quyền Duyệt Đơn Nghỉ Học):**
  - Đơn xin nghỉ học nộp trước 08:00 sáng của ngày nghỉ; Giáo viên chủ nhiệm phê duyệt trước 08:30 sáng.
  - Khi đơn được duyệt, hệ thống tự động đồng bộ sang Bếp bán trú để giảm trừ suất ăn và tính hoàn phí vào kỳ học phí tới.
- **Thông báo & Ngoại lệ:**
  - `MSG-215`: "Phê duyệt đơn xin nghỉ học của học sinh thành công."
  - `E1 (MSG-216)`: "Đơn xin nghỉ học đã được xử lý trước đó."
  - `E2 (MSG-217)`: "Giáo viên không có quyền phê duyệt đơn nghỉ học của học sinh thuộc lớp khác."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/student/controller/LeaveRequestController.java` (Định tuyến `/api/parents/leave-requests`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/student/service/LeaveRequestService.java`
  - `src/main/java/com/kidpro/domain/student/service/impl/LeaveRequestServiceImpl.java` (Đồng bộ chuyên cần, kích hoạt hoàn tiền ăn BR-036, BR-065)
- **Repository:**
  - `src/main/java/com/kidpro/domain/student/repository/LeaveRequestRepository.java`
  - `src/main/java/com/kidpro/domain/student/repository/AttendanceRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/student/entity/LeaveRequest.java` (Bảng `student.leave_requests`)
- **DTOs:**
  - `src/main/java/com/kidpro/domain/student/dto/request/LeaveRequestReviewDto.java`
  - `src/main/java/com/kidpro/domain/student/dto/response/LeaveRequestResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/attendance/tabs/LeaveRequestReviewTab.tsx` (Danh sách đơn xin nghỉ chờ duyệt, nút phê duyệt/từ chối, thông tin hoàn tiền ăn)
  - `kidpro-fe/src/pages/attendance/AttendancePage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/attendanceApi.ts` (`reviewLeaveRequest`, `getStudentLeaveRequests`)
- **Type Definitions:**
  - `kidpro-fe/src/types/attendance.types.ts` (`LeaveRequest`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G10-UC-09] Duyệt Đơn Xin Nghỉ*, path: `/attendance?tab=leave-requests`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/api/parents/leave-requests` | Lấy danh sách đơn xin nghỉ học của lớp | Query: `classId`, `status`, `date` | `List<LeaveRequest>` |
| `PUT` | `/api/parents/leave-requests/{id}` | Phê duyệt hoặc từ chối đơn xin nghỉ học (BR-065) | Path: `id`, Body: `LeaveRequestReviewDto` (status: 'APPROVED' \| 'REJECTED', reviewNotes, mealRefundApplied) | `LeaveRequest` (`MSG-215`) |

---

## G11-UC-02: Đăng Thông báo Riêng của Lớp

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Giáo viên Chủ nhiệm (`TEACHER` / `HOMEROOM_TEACHER`)
- **Tác nhân phụ / Hệ thống:** Phụ huynh của lớp
- **Sự kiện kích hoạt:** Giáo viên muốn thông báo công việc nội bộ lớp (nhắc nhở chuẩn bị trang phục dã ngoại, mang đồ dùng học tập, thông báo họp phụ huynh) (`/comms?tab=announcements`).
- **Mô tả (User Story):** Là Giáo viên chủ nhiệm, tôi muốn đăng thông báo nội bộ riêng cho lớp học kèm hình ảnh minh họa hoặc tệp đính kèm, để toàn thể phụ huynh trong lớp nắm bắt kịp thời mà không bị làm phiền phụ huynh lớp khác.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Giáo viên có tài khoản hợp lệ và quyền chủ nhiệm lớp học.
- **Hậu điều kiện:**
  - **POST-1:** Bản tin được lưu vào bảng `comms.announcements` với phạm vi áp dụng `TARGET_TYPE = CLASS` và mã lớp cụ thể.
  - **POST-2:** 100% tài khoản phụ huynh trong lớp nhận được thông báo đẩy trên điện thoại.

### 2. Luồng sự kiện chính
1. Giáo viên truy cập phân hệ Truyền thông & Bảng tin, chọn nút **Tạo Bản Tin Lớp**.
2. Giáo viên chọn Lớp học nhận thông báo (hệ thống tự động khóa theo lớp chủ nhiệm).
3. Giáo viên nhập: Tiêu đề bản tin, Nội dung chi tiết thông báo (hỗ trợ định dạng văn bản giàu ký tự Rich-text).
4. Giáo viên chọn mức độ ưu tiên: Bình thường hoặc Quan trọng.
5. Giáo viên đính kèm hình ảnh hoặc tệp tin đính kèm (ảnh poster hoạt động, tệp thông tri).
6. Giáo viên nhấn nút **Đăng Bản Tin**.
7. Hệ thống kiểm tra quy tắc bảo mật thông tin học sinh theo quy tắc **BR-056** (Bắt ngoại lệ E1, E2).
8. Hệ thống lưu bản tin, hiển thị thông báo **MSG-231**.
9. Hệ thống gửi thông báo Push Notification tức thì tới ứng dụng của phụ huynh có con học tại lớp.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Chỉnh sửa hoặc xóa bản tin đã đăng:**
  - Giáo viên có quyền sửa đổi nội dung hoặc gỡ bản tin trong vòng 24 giờ kể từ khi đăng. Hệ thống lưu lịch sử sửa đổi.
- **BR-056 (Phạm vi Đăng Thông báo Lớp học & Bảo mật Thông tin Học sinh):**
  - Bản tin của lớp học chỉ được hiển thị cho phụ huynh và giáo viên của lớp đó; tuyệt đối không công khai thông tin bệnh án, hoàn cảnh gia đình hoặc kết quả đánh giá cá nhân của trẻ lên bảng tin chung.
- **Thông báo & Ngoại lệ:**
  - `MSG-231`: "Đăng thông báo nội bộ lớp học thành công."
  - `E1 (MSG-232)`: "Tiêu đề hoặc nội dung thông báo không được để trống."
  - `E2 (MSG-233)`: "Vi phạm quy định bảo mật: Phát hiện thông tin bệnh án cá nhân của trẻ trong nội dung bản tin chung."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/comms/controller/AnnouncementController.java` (Định tuyến `/api/comms/announcements`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/comms/service/AnnouncementService.java`
  - `src/main/java/com/kidpro/domain/comms/service/impl/AnnouncementServiceImpl.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/comms/repository/AnnouncementRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/comms/entity/Announcement.java` (Bảng `comms.announcements`)
- **DTOs:**
  - `src/main/java/com/kidpro/domain/comms/dto/request/AnnouncementCreateRequestDto.java`
  - `src/main/java/com/kidpro/domain/comms/dto/response/AnnouncementDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/comms/AnnouncementsPage.tsx` (Bảng tin thông báo, bộ soạn thảo rich text, modal tạo thông báo mới)
- **API Service Client:**
  - `kidpro-fe/src/api/announcementApi.ts` (`createAnnouncement`, `getAnnouncements`)
- **Type Definitions:**
  - `kidpro-fe/src/types/comms.types.ts`
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G11-UC-02] Thông Báo Lớp Học*, path: `/comms`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/comms/announcements` | Tạo thông báo nội bộ của lớp học (BR-056) | `AnnouncementCreateRequestDto` (title, content, targetType: 'CLASS', classId, priority) | `AnnouncementDto` (`MSG-231`) |
| `GET` | `/api/comms/announcements` | Danh sách thông báo theo lớp | Query: `targetType`, `classId` | `List<AnnouncementDto>` |

---

## G11-UC-04: Tạo & Quản lý Nhóm Chat Chung của Lớp

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Giáo viên Chủ nhiệm (`TEACHER` / `HOMEROOM_TEACHER`)
- **Tác nhân phụ / Hệ thống:** Toàn thể Phụ huynh trong lớp
- **Sự kiện kích hoạt:** Giáo viên mở không gian trò chuyện nhóm lớp trên ứng dụng di động.
- **Mô tả (User Story):** Là Giáo viên chủ nhiệm, tôi muốn quản trị không gian thảo luận nhóm của toàn thể phụ huynh trong lớp, chia sẻ thông tin nhanh, ghim tin nhắn quan trọng và bật/tắt tính năng chat của phụ huynh khi cần thiết, để duy trì môi trường trao đổi văn minh, đúng mực.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Lớp học đã được thiết lập và danh sách tài khoản phụ huynh đã được kích hoạt.
- **Hậu điều kiện:**
  - **POST-1:** Tin nhắn được truyền tải theo thời gian thực qua giao thức WebSocket và lưu tại bảng `comms.daily_messages`.
  - **POST-2:** Trạng thái ghim hoặc khóa chat được áp dụng tức thì cho tất cả thành viên trong nhóm.

### 2. Luồng sự kiện chính
1. Giáo viên mở phòng Chat Nhóm của Lớp.
2. Hệ thống tải lịch sử tin nhắn của lớp.
3. Giáo viên gửi tin nhắn thông tin hoạt động hoặc tài liệu.
4. Giáo viên có quyền:
   - Ghim tin nhắn quan trọng lên đầu giao diện trò chuyện.
   - Xóa tin nhắn có nội dung không phù hợp hoặc vi phạm chuẩn mực giao tiếp.
   - Bật chế độ "Chỉ Giáo viên được gửi tin nhắn" (khóa chat tạm thời khi ngoài giờ hành chính hoặc tránh spam tin nhắn) theo quy tắc **BR-058** và **BR-059**.
5. Hệ thống áp dụng cấu hình quản trị, hiển thị thông báo **MSG-235**.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Ngoài khung giờ liên lạc sư phạm (sau 21:30):**
  - Hệ thống tự động chuyển phòng chat sang chế độ Yên tĩnh (Silent Mode). Tin nhắn gửi sau 21:30 không phát âm thanh chuông thông báo trên máy giáo viên để bảo đảm thời gian nghỉ ngơi.
- **BR-058 & BR-059 (Khung giờ Liên lạc & Quyền Điều hành Nhóm Chat):**
  - Khung giờ tương tác chuẩn từ 07:00 đến 21:30 hàng ngày.
  - Giáo viên chủ nhiệm có toàn quyền kiểm duyệt nội dung, khóa tính năng gửi tin của phụ huynh và xóa tin nhắn vi phạm.
- **Thông báo & Ngoại lệ:**
  - `MSG-235`: "Cập nhật trạng thái điều hành nhóm chat lớp thành công."
  - `E1 (MSG-236)`: "Thành viên đã bị tạm khóa quyền gửi tin nhắn trong nhóm chat."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/comms/controller/ClassChatController.java` (Định tuyến `/api/comms/chat/rooms`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/comms/service/ClassChatService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/comms/repository/DailyMessageRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/comms/entity/DailyMessage.java` (Bảng `comms.daily_messages`)
- **DTOs:**
  - `src/main/java/com/kidpro/domain/comms/dto/request/ChatMessageSendDto.java`
  - `src/main/java/com/kidpro/domain/comms/dto/response/ChatMessageDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/comms/ClassChatRoomTab.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/commsApi.ts`
- **Type Definitions:**
  - `kidpro-fe/src/types/comms.types.ts`
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G11-UC-04] Nhóm Chat Lớp*, path: `/comms?tab=chat`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/comms/chat/rooms/{classId}/messages` | Gửi tin nhắn trong nhóm chat lớp | Path: `classId`, Body: `ChatMessageSendDto` (content, attachments) | `ChatMessageDto` |
| `PUT` | `/api/comms/chat/rooms/{classId}/lock` | Bật/tắt chế độ khóa chat của phụ huynh (BR-059) | Path: `classId`, Body: `{ isMuted: boolean }` | `ApiResponse` (`MSG-235`) |

---

## G11-UC-05: Đăng Album Ảnh & Hoạt động Học tập của Lớp

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Giáo viên Mầm non (`TEACHER` / `GIAO_VIEN`)
- **Tác nhân phụ / Hệ thống:** Phụ huynh học sinh
- **Sự kiện kích hoạt:** Sau các giờ học năng khiếu, góc chơi sáng tạo hoặc chuyến dã ngoại ngoại khóa (`/health?tab=journal`).
- **Mô tả (User Story):** Là Giáo viên mầm non, tôi muốn tạo album ảnh theo ngày hoặc theo sự kiện, tải lên các hình ảnh sinh hoạt vui vẻ và gắn thẻ các học sinh có mặt, để phụ huynh có thể theo dõi trực quan khoảnh khắc trưởng thành của con tại trường.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Ảnh chụp đạt chất lượng, phù hợp với môi trường sư phạm mầm non.
- **Hậu điều kiện:**
  - **POST-1:** Bài đăng nhật ký hoạt động kèm album ảnh được lưu vào bảng `academic.classroom_journal_post`.
  - **POST-2:** Phụ huynh của các học sinh được gắn thẻ nhận được thông báo để xem và tải ảnh về máy.

### 2. Luồng sự kiện chính
1. Giáo viên mở tab "Nhật Ký & Album Ảnh Hoạt Động Lớp", nhấn nút **Tạo Album Mới**.
2. Giáo viên nhập: Tên hoạt động (ví dụ: "Giờ học tạo hình: Làm thiệp tặng mẹ 20/10"), Ngày hoạt động, Mô tả ngắn gọn về bài học.
3. Giáo viên chọn tải lên các tệp ảnh thực tế (tối đa 50 ảnh/hoạt động).
4. Hệ thống hiển thị xem trước danh sách ảnh. Giáo viên gắn thẻ (tag) các học sinh có mặt trong từng ảnh hoặc chọn "Tất cả học sinh trong lớp".
5. Giáo viên nhấn nút **Đăng Album Ảnh**.
6. Hệ thống kiểm tra giới hạn số lượng ảnh và quy chuẩn bản quyền theo quy tắc **BR-060** (Bắt ngoại lệ E1, E2).
7. Hệ thống nén ảnh tối ưu, lưu trữ vào bảng `academic.classroom_journal_post`, hiển thị thông báo **MSG-238**.
8. Hệ thống gửi thông báo tới phụ huynh có con được gắn thẻ trong album.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Chỉnh sửa hoặc gắn thẻ bổ sung:**
  - Giáo viên có thể mở lại album để xóa bớt ảnh chụp mờ hoặc gắn thẻ thêm các bé bị sót.
- **BR-060 (Giới hạn Album Ảnh & Bảo vệ Quyền Riêng tư Trẻ em):**
  - Mỗi album ảnh giới hạn tối đa không quá 50 ảnh/hoạt động.
  - Nghiêm cấm tuyệt đối đăng tải hình ảnh nhạy cảm hoặc vi phạm quyền riêng tư của trẻ em theo Nghị định 13/2023/NĐ-CP.
- **Thông báo & Ngoại lệ:**
  - `MSG-238`: "Đăng album ảnh hoạt động lớp học thành công."
  - `E1 (MSG-239)`: "Số lượng ảnh trong album vượt quá giới hạn tối đa cho phép (50 ảnh theo BR-060)."
  - `E2 (MSG-240)`: "Định dạng tệp ảnh không hợp lệ (chỉ hỗ trợ JPG, JPEG, PNG, WEBP)."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/academic/controller/ClassroomJournalController.java` (Định tuyến `/api/health/journal-posts`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/academic/service/ClassroomJournalService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/academic/repository/ClassroomJournalPostRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/academic/entity/ClassroomJournalPost.java` (Bảng `academic.classroom_journal_post`)
- **DTOs:**
  - `src/main/java/com/kidpro/domain/academic/dto/request/JournalPostCreateDto.java`
  - `src/main/java/com/kidpro/domain/academic/dto/response/JournalPostResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/health/tabs/ClassroomJournalTab.tsx` (Thư viện album ảnh lớp, bộ tải ảnh đa tệp, modal gắn thẻ học sinh)
  - `kidpro-fe/src/pages/health/HealthPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/healthApi.ts` (`createJournalPost`, `getJournalPosts`, `updateJournalPost`)
- **Type Definitions:**
  - `kidpro-fe/src/types/health.types.ts` (`ClassroomJournalPost`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G11-UC-05] Album Hoạt Động*, path: `/health?tab=journal`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/health/journal-posts` | Tạo album ảnh hoạt động lớp học (BR-060) | `JournalPostCreateDto` (classId, title, content, photoUrls, taggedStudentIds) | `ClassroomJournalPost` (`MSG-238`) |
| `GET` | `/api/health/journal-posts/class/{classId}` | Danh sách album ảnh của lớp học | Path: `classId` (UUID) | `List<ClassroomJournalPost>` |
| `PUT` | `/api/health/journal-posts/{id}` | Cập nhật thông tin hoặc bổ sung ảnh album | Path: `id`, Body: `Partial<JournalPostCreateDto>` | `ClassroomJournalPost` |
| `DELETE` | `/api/health/journal-posts/{id}` | Xóa album ảnh hoạt động | Path: `id` | `Void` |
