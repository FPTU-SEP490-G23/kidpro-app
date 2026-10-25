# TÀI LIỆU USE CASES VÀ ĐẶC TẢ KỸ THUẬT (FE - BE - API) - VAI TRÒ PHỤ HUYNH HỌC SINH (PARENT)

---

## G4-UC-02: Đăng ký Dữ liệu Khuôn mặt AI cho Trẻ

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Phụ huynh Học sinh (`PARENT` / `PHU_HUYNH`)
- **Tác nhân phụ / Hệ thống:** Microservice AI Vision (YOLOv8-Face, ArcFace InsightFace)
- **Sự kiện kích hoạt:** Phụ huynh truy cập tab "Sinh trắc học Khuôn mặt" trên ứng dụng di động (`/parent?tab=face-biometrics`).
- **Mô tả (User Story):** Là Phụ huynh học sinh, tôi muốn chụp và tải 3 góc ảnh chân dung rõ nét (chính diện, nghiêng trái, nghiêng phải) của con lên ứng dụng sau khi đồng thuận điều khoản Nghị định 13/2023/NĐ-CP, để hệ thống trích xuất vector đặc trưng 512 chiều và kích hoạt tính năng nhận diện điểm danh tự động tại trường.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Phụ huynh đã đăng nhập tài khoản di động và tài khoản đã liên kết với hồ sơ học sinh (`student.student`).
  - **PRE-2:** Phụ huynh đồng ý cam kết điều khoản bảo vệ dữ liệu cá nhân theo Nghị định 13/2023/NĐ-CP.
- **Hậu điều kiện:**
  - **POST-1:** Bản ghi vector đặc trưng khuôn mặt 512 chiều được mã hóa và lưu vào bảng `student.face_encoding_file` với trạng thái [Hoạt động] (`is_active = true`).
  - **POST-2:** Hệ thống lập chỉ mục HNSW vector Cosine và kích hoạt nhận diện khuôn mặt tự động tại cổng trường và lớp học.

### 2. Luồng sự kiện chính
1. Phụ huynh chọn học sinh (nếu có nhiều con) và chọn tính năng **Đăng Ký Khuôn Mặt AI**.
2. Hệ thống hiển thị Thỏa thuận xử lý dữ liệu sinh trắc học mầm non theo **Nghị định 13/2023/NĐ-CP**.
3. Phụ huynh tích chọn đồng ý thỏa thuận bảo mật và bấm **Tiếp Tục**.
4. Ứng dụng kích hoạt camera hướng dẫn chụp 3 góc ảnh đạt chuẩn:
   - Ảnh 1: Chính diện (Frontal angle) - Mắt nhìn thẳng, không đeo kính râm, phông sáng.
   - Ảnh 2: Nghiêng trái 15 độ (Left tilt).
   - Ảnh 3: Nghiêng phải 15 độ (Right tilt).
5. Phụ huynh xem trước 3 bức ảnh và nhấn **Gửi Xác Thực & Trích Xuất AI**.
6. Hệ thống gửi ảnh tới AI Microservice để kiểm tra chất lượng (độ sắc nét, độ sáng, không bị che khuất) và trích xuất vector 512 chiều qua ArcFace theo quy tắc **BR-011** và **BR-013** (Bắt ngoại lệ E1, E2, E3).
7. Hệ thống lưu vector vào `student.face_encoding_file`, hiển thị thông báo **MSG-071**.
8. Ứng dụng cập nhật trạng thái hồ sơ khuôn mặt: [Đã Kích Hoạt Điểm Danh AI].

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Phụ huynh từ chối cung cấp dữ liệu sinh trắc học:**
  - Phụ huynh nhấn nút *Từ chối cấp quyền sinh trắc học*, nhập lý do.
  - Hệ thống ghi nhận biên bản từ chối, chuyển chế độ điểm danh của con sang hoàn toàn thủ công (`MANUAL_ONLY`).
- **BR-011 & BR-013 (Tiêu chuẩn Ảnh Sinh trắc học & Kích hoạt AI):**
  - Ảnh sinh trắc học bắt buộc chụp thẳng mặt, rõ nét, phông nền sáng, định dạng JPG/PNG dung lượng tối đa 5MB.
  - Vector sinh trắc học chỉ được kích hoạt nhận diện khi hồ sơ học sinh đã được phê duyệt hợp lệ.
- **Thông báo & Ngoại lệ:**
  - `MSG-071`: "Đăng ký dữ liệu khuôn mặt nhận diện thành công cho học sinh."
  - `E1 (MSG-072)`: "Ảnh chân dung bị mờ, không đủ độ sáng hoặc có nhiều hơn một khuôn mặt trong khung hình."
  - `E2 (MSG-073)`: "Dung lượng ảnh vượt quá 5MB quy định."
  - `E3 (MSG-074)`: "Phụ huynh chưa ký xác nhận đồng thuận điều khoản bảo mật Nghị định 13."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/student/controller/FaceBiometricEnrollmentController.java` (Định tuyến `/api/parents/students/{studentId}/face-enrollment`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/student/service/FaceBiometricEnrollmentService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/student/repository/FaceEncodingFileRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/student/entity/FaceEncodingFile.java`
- **DTOs:**
  - `src/main/java/com/kidpro/domain/student/dto/request/FaceEnrollmentRequestDto.java`
  - `src/main/java/com/kidpro/domain/student/dto/response/FaceProfileResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/parent/tabs/StudentFaceBiometricTab.tsx` (Khung chụp 3 góc ảnh, thanh tiến trình AI, thỏa thuận Nghị định 13)
  - `kidpro-fe/src/pages/parent/ParentPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/parentApi.ts` (`getStudentFaceProfile`, `saveDecree13Consent`, `enrollStudentFacePhotos`, `refuseFaceBiometrics`)
- **Type Definitions:**
  - `kidpro-fe/src/types/parent.types.ts` (`StudentFaceBiometricProfile`, `Decree13ConsentAgreement`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G4-UC-02] Khuôn Mặt AI Của Bé*, path: `/parent?tab=face-biometrics`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/api/parents/students/{studentId}/face-profile` | Lấy thông tin hồ sơ khuôn mặt hiện tại | Path: `studentId` (UUID) | `StudentFaceBiometricProfile` |
| `POST` | `/api/parents/students/{studentId}/decree13-consent` | Lưu biên bản đồng thuận Nghị định 13 | Body: `Decree13ConsentAgreement` | `ApiResponse` |
| `POST` | `/api/parents/students/{studentId}/face-enrollment` | Tải 3 góc ảnh và trích xuất vector AI (BR-011) | `FaceEnrollmentRequestDto` (photos: [{angle, photoUrl}]) | `StudentFaceBiometricProfile` (`MSG-071`) |
| `POST` | `/api/parents/students/{studentId}/face-refusal` | Phụ huynh từ chối sinh trắc học | Body: `{ reason }` | `ApiResponse` |

---

## G4-UC-03: Đăng ký & Quản lý Người Đón Ủy quyền

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Phụ huynh Học sinh (`PARENT` / `PHU_HUYNH`)
- **Tác nhân phụ / Hệ thống:** Cán bộ Giáo vụ (kiểm duyệt hồ sơ)
- **Sự kiện kích hoạt:** Phụ huynh chọn tab "Người Đón Ủy Quyền" trên ứng dụng di động (`/parent?tab=authorized-guardians`).
- **Mô tả (User Story):** Là Phụ huynh học sinh, tôi muốn chủ động khai báo thông tin người thân đón hộ thường xuyên (Ông, Bà, Cô, Chú, Người giúp việc...) kèm số điện thoại, ảnh chân dung và căn cước công dân, hoặc thu hồi quyền đón ngay trên ứng dụng di động, để quyền đón con được kiểm soát an toàn tuyệt đối theo thời gian thực.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Tài khoản phụ huynh chính đang hoạt động.
- **Hậu điều kiện:**
  - **POST-1:** Hồ sơ người đón ủy quyền được lưu vào bảng `student.student_guardian` ở trạng thái [Chờ Duyệt] hoặc [Đã Kích Hoạt].
  - **POST-2:** Dữ liệu khuôn mặt người đón được đồng bộ sang cổng đón trường để camera AI nhận diện khi bàn giao trẻ.

### 2. Luồng sự kiện chính
1. Phụ huynh mở danh sách người đón được ủy quyền của con.
2. Phụ huynh nhấn nút **Thêm Người Đón Mới**.
3. Phụ huynh nhập các thông tin: Họ và tên người đón, Mối quan hệ với bé (Ông nội, Bà ngoại, Bác, Cô, Tài xế gia đình...), Số điện thoại định danh, Số CCCD.
4. Phụ huynh tải lên: Ảnh chân dung rõ mặt người đón, Ảnh chụp 2 mặt CCCD.
5. Phụ huynh nhấn **Lưu Đăng Ký Người Đón**.
6. Hệ thống kiểm tra số lượng người đón tối đa theo quy tắc **BR-012** (Bắt ngoại lệ E1, E2, E3).
7. Hệ thống lưu hồ sơ, hiển thị thông báo **MSG-075**.
8. Hệ thống trích xuất vector khuôn mặt người đón vào cơ sở dữ liệu nhận diện an toàn.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Thu hồi quyền đón của người thân:**
  - Phụ huynh chọn người đón trong danh sách, nhấn *Xóa/Thu hồi quyền đón*.
  - Hệ thống yêu cầu nhập mật khẩu tài khoản phụ huynh để xác nhận bảo mật.
  - Hệ thống vô hiệu hóa ngay lập tức trên toàn bộ hệ thống camera cổng và ứng dụng giáo viên.
- **BR-012 (Quy định Số lượng & Vô hiệu hóa Quyền Đón Ủy quyền):**
  - Mỗi học sinh chỉ được đăng ký tối đa không quá 03 người đón ủy quyền hợp lệ (ngoài bố và mẹ).
  - Khi phụ huynh thu hồi quyền đón, hệ thống lập tức vô hiệu hóa trên toàn mạng lưới theo thời gian thực.
- **Thông báo & Ngoại lệ:**
  - `MSG-075`: "Đăng ký thông tin người đón ủy quyền thành công."
  - `E1 (MSG-076)`: "Số lượng người đón ủy quyền đã đạt giới hạn tối đa (tối đa 03 người theo BR-012)."
  - `E2 (MSG-077)`: "Số điện thoại hoặc số CCCD người đón không đúng định dạng."
  - `E3 (MSG-078)`: "Ảnh chân dung hoặc ảnh CCCD bị mờ, không nhận diện được thông tin."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/student/controller/StudentGuardianController.java` (Định tuyến `/api/parents/students/{studentId}/guardians`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/student/service/StudentGuardianService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/student/repository/StudentGuardianRepository.java`
  - `src/main/java/com/kidpro/domain/student/repository/FaceEncodingFileRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/student/entity/StudentGuardian.java` (Bảng `student.student_guardian`)
- **DTOs:**
  - `src/main/java/com/kidpro/domain/student/dto/request/RegisterGuardianRequestDto.java`
  - `src/main/java/com/kidpro/domain/student/dto/response/GuardianResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/parent/tabs/AuthorizedGuardiansTab.tsx` (Danh sách thẻ người đón, modal thêm người đón, nút thu hồi kèm mật khẩu)
  - `kidpro-fe/src/pages/parent/ParentPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/parentApi.ts` (`getAuthorizedGuardians`, `registerAuthorizedGuardian`, `revokeAuthorizedGuardian`)
- **Type Definitions:**
  - `kidpro-fe/src/types/parent.types.ts` (`AuthorizedGuardian`, `RegisterGuardianPayload`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G4-UC-03] Người Đón Ủy Quyền*, path: `/parent?tab=guardians`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/api/parents/students/{studentId}/guardians` | Danh sách người đón ủy quyền của bé | Path: `studentId` | `List<AuthorizedGuardian>` |
| `POST` | `/api/parents/students/{studentId}/guardians` | Đăng ký người đón mới (BR-012) | `RegisterGuardianPayload` (fullName, relationship, phone, idCardNumber, photoUrl) | `AuthorizedGuardian` (`MSG-075`) |
| `DELETE` | `/api/parents/students/{studentId}/guardians/{id}` | Thu hồi quyền đón của người thân | Path: `studentId`, `id`, Header/Query: `passwordConfirm` | `ApiResponse` |

---

## G4-UC-05: Đơn xin Rút Hồ sơ Học bạ & Chuyển trường

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Phụ huynh Học sinh (`PARENT` / `PHU_HUYNH`)
- **Tác nhân phụ / Hệ thống:** Ban Giám hiệu, Kế toán, Giáo vụ
- **Sự kiện kích hoạt:** Phụ huynh truy cập tab "Đơn Từ Sự Vụ Học Sinh" và chọn nộp đơn rút hồ sơ (`/parent?tab=petitions`).
- **Mô tả (User Story):** Là Phụ huynh học sinh, tôi muốn nộp đơn xin rút hồ sơ học bạ và chuyển trường trực tuyến cho con kèm lý do và ngày kết thúc học dự kiến, để nhà trường tiến hành thủ tục quyết toán công nợ và bàn giao học bạ hợp lệ cho con.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Học sinh đang học chính thức tại trường.
- **Hậu điều kiện:**
  - **POST-1:** Đơn rút hồ sơ được lưu vào bảng `student.other_requests` ở trạng thái [Chờ Tiếp Nhận].
  - **POST-2:** Hệ thống tự động kích hoạt tiến trình rà soát công nợ tại phòng Kế toán.

### 2. Luồng sự kiện chính
1. Phụ huynh chọn chức năng **Lập Đơn Xin Rút Hồ Sơ / Chuyển Trường**.
2. Phụ huynh nhập các thông tin: Lý do chuyển trường (Chuyển nơi cư trú, Chuyển sang trường tiểu học, Lý do gia đình...), Tên trường chuyển đến (nếu có), Ngày học cuối cùng dự kiến tại trường.
3. Phụ huynh đính kèm giấy tờ chứng minh (Giấy chuyển hộ khẩu, Quyết định công tác của bố mẹ nếu có).
4. Phụ huynh nhấn **Gửi Đơn Lên Ban Giám Hiệu**.
5. Hệ thống kiểm tra quy tắc phê duyệt và quyết toán công nợ theo quy tắc **BR-017** (Bắt ngoại lệ E1, E2).
6. Hệ thống tạo đơn thành công, hiển thị thông báo **MSG-079**.
7. Hệ thống chuyển đơn tới bàn làm việc của Cán bộ Giáo vụ và Kế toán để tính toán hoàn phí/quyết toán học phí còn thiếu.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Theo dõi tiến độ quyết toán hồ sơ:**
  - Phụ huynh có thể tra cứu trạng thái đơn: [Đang kiểm tra tài chính] $ightarrow$ [Đã ký duyệt bàn giao] $ightarrow$ [Hoàn tất thủ tục].
- **BR-017 (Thẩm quyền Chuyển lớp, Rút hồ sơ & Quyết toán Phí):**
  - Ban Giám hiệu là cấp duy nhất có thẩm quyền phê duyệt đơn xin rút hồ sơ; hồ sơ thôi học chuyển trạng thái bất biến và tự động kích hoạt tính toán hoàn phí.
- **Thông báo & Ngoại lệ:**
  - `MSG-079`: "Nộp đơn xin rút hồ sơ và chuyển trường thành công. Nhà trường sẽ xử lý trong vòng 03 ngày làm việc."
  - `E1 (MSG-080)`: "Học sinh đang có đơn rút hồ sơ khác đang chờ xử lý."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/student/controller/StudentAffairsPetitionController.java` (Định tuyến `/api/academic/petitions`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/student/service/StudentAffairsPetitionService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/student/repository/OtherRequestRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/student/entity/OtherRequest.java` (Bảng `student.other_requests`)
- **DTOs:**
  - `src/main/java/com/kidpro/domain/student/dto/request/PetitionCreateRequestDto.java`
  - `src/main/java/com/kidpro/domain/student/dto/response/PetitionResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/parent/tabs/StudentAffairsPetitionTab.tsx` (Biểu mẫu nộp đơn sự vụ, dòng trạng thái quyết toán)
  - `kidpro-fe/src/pages/parent/ParentPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/parentApi.ts` (`submitStudentPetition`, `getStudentPetitions`)
- **Type Definitions:**
  - `kidpro-fe/src/types/parent.types.ts` (`StudentPetitionItem`, `CreatePetitionPayload`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G4-UC-05] Rút Hồ Sơ Chuyển Trường*, path: `/parent?tab=petitions`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/academic/petitions` | Nộp đơn rút hồ sơ chuyển trường (BR-017) | `CreatePetitionPayload` (studentId, petitionType: 'WITHDRAWAL', reason, effectiveDate) | `StudentPetitionItem` (`MSG-079`) |
| `GET` | `/api/academic/petitions` | Danh sách đơn từ sự vụ đã gửi | Query: `studentId` | `List<StudentPetitionItem>` |

---

## G4-UC-06: Cập nhật Hồ sơ Sức khỏe & Dị ứng của Trẻ

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Phụ huynh Học sinh (`PARENT` / `PHU_HUYNH`)
- **Tác nhân phụ / Hệ thống:** Giáo viên chủ nhiệm, Nhà bếp bán trú
- **Sự kiện kích hoạt:** Phụ huynh phát hiện trẻ có dị ứng mới hoặc thay đổi tình trạng tiền sử bệnh án (`/parent?tab=health-profile`).
- **Mô tả (User Story):** Là Phụ huynh học sinh, tôi muốn cập nhật chi tiết tiền sử bệnh án, các loại thực phẩm gây dị ứng (hải sản, đậu phộng, trứng, sữa bò...) và mức độ nghiêm trọng lên hồ sơ sức khỏe của con, để hệ thống tự động cảnh báo xuyên suốt sang Bếp bán trú và Giáo viên đứng lớp, ngăn ngừa rủi ro sốc phản vệ.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Học sinh có hồ sơ hợp lệ tại trường.
- **Hậu điều kiện:**
  - **POST-1:** Cảnh báo dị ứng được lưu vào bảng `health.allergy_alert`.
  - **POST-2:** Bếp bán trú tự động nhận nhãn cảnh báo đỏ trên thực đơn và khay ăn của trẻ (`BR-014`, `BR-026`).

### 2. Luồng sự kiện chính
1. Phụ huynh chọn tính năng **Cập Nhật Cảnh Báo Dị Ứng & Tiền Sử Y Tế**.
2. Phụ huynh chọn Nhóm dị ứng: Dị ứng Thực phẩm (Hải sản, Đậu phộng, Trứng, Sữa chua...), Dị ứng Thuốc (Kháng sinh Penicillin...), Dị ứng Môi trường (Phấn hoa, Lông động vật, Thời tiết).
3. Phụ huynh chọn Mức độ nguy hiểm: Nhẹ (Mẩn ngứa ngoài da), Trung bình (Sưng môi mắt, nôn ói), Nghiêm trọng / Sốc phản vệ (Khó thở, co thắt thanh quản).
4. Phụ huynh nhập phác đồ sơ cứu khẩn cấp gia đình dặn dò và tải lên giấy khám của bệnh viện.
5. Phụ huynh nhấn nút **Lưu Cảnh Báo Y Tế**.
6. Hệ thống kiểm tra quy tắc đồng bộ theo quy tắc **BR-014** và **BR-032** (Bắt ngoại lệ E1).
7. Hệ thống lưu cảnh báo thành công, hiển thị thông báo **MSG-111**.
8. Hệ thống lập tức đồng bộ cảnh báo đỏ sang Dashboard Bếp bán trú và giao diện điểm danh của Giáo viên.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Cập nhật hết dị ứng sau khi điều trị:**
  - Phụ huynh gửi yêu cầu giải tỏa cảnh báo dị ứng kèm kết quả xét nghiệm dị nguyên âm tính của bệnh viện.
- **BR-014 & BR-032 (Cảnh báo Bắt buộc & Đồng bộ Xuyên suốt Hệ thống):**
  - Mọi học sinh có tiền sử dị ứng thực phẩm bắt buộc phải có thông tin cảnh báo hiển thị trên hồ sơ sức khỏe và tự động đồng bộ sang Bếp bán trú và Giáo viên chủ nhiệm theo thời gian thực.
- **Thông báo & Ngoại lệ:**
  - `MSG-111`: "Cập nhật hồ sơ dị ứng và tiền sử y tế của con thành công. Thông tin đã được thông báo tới Bếp và Cô giáo."
  - `E1 (MSG-112)`: "Bắt buộc mô tả triệu chứng và tải giấy xét nghiệm đối với mức độ sốc phản vệ nghiêm trọng."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/healthmedical/controller/AllergyAlertController.java` (Định tuyến `/api/health/allergies`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/healthmedical/service/AllergyAlertService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/healthmedical/repository/AllergyAlertRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/healthmedical/entity/AllergyAlert.java` (Bảng `health.allergy_alert`)
- **DTOs:**
  - `src/main/java/com/kidpro/domain/healthmedical/dto/request/AllergyAlertCreateDto.java`
  - `src/main/java/com/kidpro/domain/healthmedical/dto/response/AllergyAlertResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/parent/tabs/StudentHealthAllergyTab.tsx` (Biểu mẫu chọn dị nguyên, mức độ nguy hiểm, đính kèm kết quả khám)
  - `kidpro-fe/src/pages/parent/ParentPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/healthApi.ts`
- **Type Definitions:**
  - `kidpro-fe/src/types/health.types.ts`
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G4-UC-06] Hồ Sơ Dị Ứng Của Bé*, path: `/parent?tab=allergy`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/health/allergies` | Đăng ký cảnh báo dị ứng mới của trẻ (BR-014) | `AllergyAlertCreateDto` (studentId, allergenName, allergenType, severity, emergencyAction) | `AllergyAlertResponseDto` (`MSG-111`) |
| `GET` | `/api/health/allergies/student/{studentId}` | Lấy danh sách dị ứng của học sinh | Path: `studentId` | `List<AllergyAlertResponseDto>` |

---

## G4-UC-07: Đăng ký Dịch vụ Bán trú & Đưa đón Xe buýt

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Phụ huynh Học sinh (`PARENT` / `PHU_HUYNH`)
- **Tác nhân phụ / Hệ thống:** Kế toán (tính phí), Quản trị viên Xe buýt
- **Sự kiện kích hoạt:** Định kỳ trước ngày 25 hàng tháng, Phụ huynh truy cập tab "Dịch Vụ Bán Trú & Xe Buýt" (`/parent?tab=services-registration`).
- **Mô tả (User Story):** Là Phụ huynh học sinh, tôi muốn đăng ký hoặc thay đổi gói dịch vụ ăn bán trú linh hoạt (Toàn phần 3 bữa, Tiêu chuẩn 2 bữa trưa/xế, hoặc Tùy chọn) và đăng ký tuyến xe buýt đưa đón đón tận nhà/điểm dừng, để nhà trường sắp xếp định mức suất ăn và điều phối lộ trình xe buýt phù hợp cho tháng tới.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Thời điểm đăng ký thực hiện trước ngày 25 hàng tháng theo quy tắc **BR-068**.
- **Hậu điều kiện:**
  - **POST-1:** Gói dịch vụ mới được kích hoạt áp dụng cho tháng tiếp theo.
  - **POST-2:** Học phí và tiền ăn bán trú được tự động tổng hợp vào bảng tính học phí dự thu kỳ tới.

### 2. Luồng sự kiện chính
1. Phụ huynh chọn học sinh cần đăng ký dịch vụ.
2. Hệ thống hiển thị các gói dịch vụ hiện tại và lựa chọn cho tháng tiếp theo:
   - **Gói Bán Trú:** Gói Toàn Phần (Sáng + Trưa + Xế), Gói Tiêu Chuẩn (Trưa + Xế), Gói Không Ăn Bán Trú.
   - **Dịch vụ Xe Buýt Học Đường:** Chọn Tuyến đường (ví dụ: Tuyến Quận 5 - Quận 1), Chiều đưa đón (Hai chiều, Chiều đón sáng, Chiều trả chiều), Chọn Điểm dừng gần nhà.
3. Hệ thống hiển thị số lượng chỗ còn trống trên tuyến xe buýt đã chọn.
4. Hệ thống tính toán dự kiến số tiền học phí chênh lệch phát sinh hàng tháng.
5. Phụ huynh nhấn nút **Xác Nhận Đăng Ký Dịch Vụ**.
6. Hệ thống kiểm tra sức chứa tối đa của tuyến xe buýt theo quy tắc **BR-015** và thời hạn nộp theo **BR-068** (Bắt ngoại lệ E1, E2).
7. Hệ thống lưu thông tin đăng ký, hiển thị thông báo **MSG-115**.
8. Hệ thống gửi thông báo phân tuyến xe buýt tới ứng dụng phụ huynh.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Tuyến xe buýt đã hết chỗ:**
  - Hệ thống báo tuyến đã đạt giới hạn tối đa theo tải trọng xe (BR-015), đưa phụ huynh vào danh sách chờ hoặc gợi ý tuyến lân cận.
- **BR-015 & BR-068 (Khống chế Sức chứa Xe buýt & Thời hạn Đăng ký Dịch vụ):**
  - Hệ thống không cho phép đăng ký xe buýt khi số lượng học sinh đã đạt sức chứa thiết kế của xe.
  - Phụ huynh bắt buộc đăng ký hoặc thay đổi dịch vụ trước ngày 25 hàng tháng để áp dụng cho tháng tiếp theo.
- **Thông báo & Ngoại lệ:**
  - `MSG-115`: "Đăng ký dịch vụ bán trú và xe buýt thành công cho tháng tiếp theo."
  - `E1 (MSG-116)`: "Tuyến xe buýt đã đạt số lượng tối đa hành khách theo thiết kế (BR-015)."
  - `E2 (MSG-117)`: "Đã quá thời hạn thay đổi dịch vụ cho tháng tới (hạn chót là ngày 25 hàng tháng theo BR-068)."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/student/controller/StudentServiceRegistrationController.java` (Định tuyến `/api/parents/services/registration`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/student/service/StudentServiceRegistrationService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/student/repository/StudentRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/student/entity/Student.java`
- **DTOs:**
  - `src/main/java/com/kidpro/domain/student/dto/request/ServiceRegistrationRequestDto.java`
  - `src/main/java/com/kidpro/domain/student/dto/response/ServiceRegistrationResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/parent/tabs/ServicesSubscriptionTab.tsx` (Bảng chọn gói bán trú, bản đồ chọn điểm dừng xe buýt, tính phí dự kiến)
  - `kidpro-fe/src/pages/parent/ParentPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/parentApi.ts`
- **Type Definitions:**
  - `kidpro-fe/src/types/parent.types.ts`
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G4-UC-07] Đăng Ký Bán Trú & Xe Buýt*, path: `/parent?tab=subscription`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/parents/services/registration` | Đăng ký dịch vụ bán trú / xe buýt (BR-015, BR-068) | `ServiceRegistrationRequestDto` (studentId, boardingPackage, busRouteId, busStopId) | `ServiceRegistrationResponseDto` (`MSG-115`) |
| `GET` | `/api/parents/services/registration/current` | Lấy dịch vụ hiện tại đang sử dụng | Query: `studentId` | `ServiceRegistrationResponseDto` |

---

## G5-UC-07: Tạo & Quản lý Mã QR Ủy quyền Đón hộ Đột xuất

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Phụ huynh Học sinh (`PARENT` / `PHU_HUYNH`)
- **Tác nhân phụ / Hệ thống:** Giáo viên trực cổng/trả trẻ
- **Sự kiện kích hoạt:** Gia đình có việc bận đột xuất, cần nhờ người quen/hàng xóm đón hộ con vào cuối ngày (`/parent?tab=emergency-pickup`).
- **Mô tả (User Story):** Là Phụ huynh học sinh, tôi muốn tạo nhanh một mã QR ủy quyền đón hộ dùng một lần (kèm số điện thoại, ảnh chân dung người đón hộ và mã PIN 4 chữ số bảo mật) có hiệu lực 60 phút, để nhờ người quen đón con an toàn khi gia đình không thể đến kịp.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Học sinh đang có mặt tại trường trong ngày tạo mã.
- **Hậu điều kiện:**
  - **POST-1:** Bản ghi ủy quyền được tạo trong bảng `student.emergency_pickup_authorization` với mã bảo mật, mã OTP và thời hạn 60 phút.
  - **POST-2:** Khi người đón quét mã thành công tại trường, mã chuyển trạng thái thành [ĐÃ SỬ DỤNG] (`USED`) và tự động vô hiệu hóa.

### 2. Luồng sự kiện chính
1. Phụ huynh mở ứng dụng, chọn tính năng **Ủy Quyền Đón Con Đột Xuất (60 Phút)**.
2. Phụ huynh nhập các thông tin người đón hộ: Họ và tên người đón hộ, Số điện thoại người đón hộ, Số CCCD.
3. Phụ huynh chụp hoặc tải ảnh chân dung người đón hộ (để cô giáo đối chiếu mặt).
4. Phụ huynh thiết lập Mã PIN bảo mật 4 chữ số (để người đón đọc cho cô giáo).
5. Phụ huynh nhấn nút **Tạo Mã QR Ủy Quyền**.
6. Hệ thống sinh mã QR động được ký số chứa token dùng 1 lần và gán thời hạn hết hạn 60 phút theo quy tắc **BR-022** (Bắt ngoại lệ E1, E2).
7. Hệ thống lưu bản ghi vào `student.emergency_pickup_authorization`, hiển thị thông báo **MSG-121**.
8. Phụ huynh chụp màn hình gửi ảnh mã QR kèm dặn dò mã PIN cho người thân qua Zalo/Tin nhắn.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Hủy mã ủy quyền đột xuất:**
  - Nếu gia đình sắp xếp đón được, phụ huynh bấm nút *Hủy ủy quyền*. Hệ thống lập tức vô hiệu hóa mã QR.
- **BR-022 (Hiệu lực Mã QR Ủy quyền Đón hộ Đột xuất & Mã PIN Bảo mật):**
  - Mã QR đón hộ đột xuất chỉ có hiệu lực tối đa 60 phút (hoặc 4 giờ nếu đăng ký ca đón) và chỉ được sử dụng đúng 01 lần duy nhất; người đón bắt buộc phải quét mã QR và đọc đúng mã PIN 4 chữ số.
- **Thông báo & Ngoại lệ:**
  - `MSG-121`: "Tạo mã QR ủy quyền đón hộ đột xuất thành công. Mã có hiệu lực trong 60 phút."
  - `E1 (MSG-122)`: "Thông tin họ tên hoặc số điện thoại người đón hộ không hợp lệ."
  - `E2 (MSG-123)`: "Đã có một mã ủy quyền đón hộ khác đang trong thời gian có hiệu lực."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/student/controller/EmergencyPickupController.java` (Định tuyến `/api/parents/emergency-pickups`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/student/service/EmergencyPickupService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/student/repository/EmergencyPickupAuthorizationRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/student/entity/EmergencyPickupAuthorization.java` (Bảng `student.emergency_pickup_authorization`)
- **DTOs:**
  - `src/main/java/com/kidpro/domain/student/dto/request/EmergencyPickupCreateDto.java`
  - `src/main/java/com/kidpro/domain/student/dto/response/EmergencyPickupResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/parent/tabs/EmergencyPickupTab.tsx` (Biểu mẫu tạo mã đón hộ, đồng hồ đếm ngược 60 phút, mã QR hiển thị kèm nút chia sẻ)
  - `kidpro-fe/src/pages/parent/ParentPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/parentApi.ts` (`createEmergencyPickup`, `getTodayEmergencyPickups`, `revokeEmergencyPickup`)
- **Type Definitions:**
  - `kidpro-fe/src/types/parent.types.ts` (`EmergencyPickupPayload`, `EmergencyPickupRecord`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G5-UC-07] Đón Hộ Khẩn Cấp*, path: `/parent?tab=emergency-pickup`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/parents/emergency-pickups` | Tạo mã QR ủy quyền đón hộ đột xuất 60 phút (BR-022) | `EmergencyPickupPayload` (studentId, guardianName, phone, idCard, photoUrl, pinCode) | `EmergencyPickupRecord` (`MSG-121`) |
| `GET` | `/api/academic/emergency-pickups/today` | Lấy danh sách mã ủy quyền trong ngày | Query: `studentId` | `List<EmergencyPickupRecord>` |
| `PUT` | `/api/academic/emergency-pickups/{id}/revoke` | Hủy hiệu lực mã ủy quyền trước thời hạn | Path: `id` | `ApiResponse` |

---

## G6-UC-06: Xem Thực đơn & Ảnh Suất ăn Hàng ngày của Con

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Phụ huynh Học sinh (`PARENT` / `PHU_HUYNH`)
- **Tác nhân phụ / Hệ thống:** Nhân viên Bếp bán trú
- **Sự kiện kích hoạt:** Phụ huynh mở ứng dụng xem bữa ăn của con (`/parent?tab=daily-menu`).
- **Mô tả (User Story):** Là Phụ huynh học sinh, tôi muốn xem chi tiết thực đơn các bữa ăn trong ngày của con (bữa sáng, bữa trưa, bữa xế) kèm định lượng calo và hình ảnh chụp khay cơm thực tế do nhà bếp tải lên, để an tâm về chất lượng dinh dưỡng và vệ sinh an toàn thực phẩm con được thụ hưởng tại trường.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Thực đơn tuần đã được Ban Giám hiệu phê duyệt (`G6-UC-02`).
  - **PRE-2:** Bếp đã tải ảnh khay cơm thực tế lên hệ thống.
- **Hậu điều kiện:**
  - **POST-1:** Phụ huynh xem được hình ảnh trực quan và hàm lượng dinh dưỡng của bữa ăn.

### 2. Luồng sự kiện chính
1. Phụ huynh chọn ngày cần xem thực đơn (mặc định ngày hiện tại).
2. Hệ thống tải thực đơn 3 bữa trong ngày của khối lớp bé theo học:
   - **Bữa Sáng:** Tên món ăn (ví dụ: Cháo sườn bắp ngọt), Tráng miệng (Sữa chua tiệt trùng), Calo dự kiến.
   - **Bữa Trưa:** Món mặn (Thịt bò xào củ quả), Món canh (Canh cải xanh tôm tươi), Cơm trắng, Tráng miệng (Chuối chín).
   - **Bữa Xế (Chiều):** Bánh flan caramel hoặc sữa hạt sen.
3. Hệ thống hiển thị ảnh chụp khay ăn mẫu thực tế do bếp trưởng chụp kiểm thực bước 3 tải lên.
4. Trường hợp học sinh có cảnh báo dị ứng thực phẩm, hệ thống hiển thị thêm tab [Suất Ăn Riêng Của Bé] kèm ảnh khay ăn thay thế an toàn.
5. Phụ huynh có thể bấm nút "Thả tim" hoặc để lại phản hồi về bữa ăn cho nhà trường.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Nhà bếp chưa tải ảnh khay ăn thực tế:**
  - Hệ thống hiển thị thực đơn dạng danh sách kèm thông báo: "Nhà bếp đang chuẩn bị khay cơm, ảnh sẽ được cập nhật trước giờ ăn 15 phút".
- **BR-025 & BR-027 (Tiêu chuẩn Dinh dưỡng & Kiểm thực Suất ăn):**
  - Thực đơn hiển thị calo đạt chuẩn dinh dưỡng lứa tuổi mầm non; khay ăn được chụp thực tế trong quy trình kiểm thực 3 bước theo Quyết định 1246/QĐ-BYT.
- **Thông báo & Ngoại lệ:**
  - `MSG-125`: "Tải dữ liệu thực đơn và hình ảnh bữa ăn thành công."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/catering/controller/WeeklyMenuApprovalController.java` (Định tuyến `/api/catering/menus`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/catering/service/WeeklyMenuApprovalService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/catering/repository/WeeklyMenuRepository.java`
  - `src/main/java/com/kidpro/domain/catering/repository/MenuItemRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/catering/entity/WeeklyMenu.java`
  - `src/main/java/com/kidpro/domain/catering/entity/MenuItem.java`
- **DTOs:**
  - `src/main/java/com/kidpro/domain/catering/dto/response/MenuItemResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/parent/tabs/DailyMealMenuTab.tsx` (Thẻ thực đơn 3 bữa trực quan, album ảnh khay cơm, chi tiết calo)
  - `kidpro-fe/src/pages/parent/ParentPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/kitchenApi.ts`
- **Type Definitions:**
  - `kidpro-fe/src/types/kitchen.types.ts`
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G6-UC-06] Thực Đơn Của Con*, path: `/parent?tab=menu`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/api/catering/menus/daily` | Lấy thực đơn và ảnh khay cơm theo ngày | Query: `date`, `gradeLevel`, `studentId` | `List<MenuItemResponseDto>` |

---

## G7-UC-03: Xem Biểu đồ Tăng trưởng Thể chất Chiều cao & Cân nặng

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Phụ huynh Học sinh (`PARENT` / `PHU_HUYNH`)
- **Tác nhân phụ / Hệ thống:** Tiêu chuẩn Z-score của Tổ chức Y tế Thế giới (WHO)
- **Sự kiện kích hoạt:** Phụ huynh chọn tab "Biểu Đồ Tăng Trưởng Thể Chất" trên ứng dụng di động (`/parent?tab=growth-chart`).
- **Mô tả (User Story):** Là Phụ huynh học sinh, tôi muốn xem biểu đồ tăng trưởng chiều cao, cân nặng và chỉ số khối cơ thể (BMI) của con theo đường cong chuẩn quốc tế của WHO từ lúc nhập học đến hiện tại, để theo dõi sự phát triển thể chất và nhận khuyến nghị dinh dưỡng từ nhà trường.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Giáo viên hoặc nhân viên y tế đã nhập chỉ số cân đo định kỳ của bé (`G7-UC-01`).
- **Hậu điều kiện:**
  - **POST-1:** Giao diện trực quan hiển thị vị trí đường cong phát triển của bé so với đường trung vị (-2SD, 0, +2SD).

### 2. Luồng sự kiện chính
1. Phụ huynh mở màn hình Biểu đồ Tăng trưởng của bé.
2. Hệ thống tải toàn bộ lịch sử các lần cân đo (chiều cao, cân nặng, ngày đo, độ tuổi tính theo tháng tại thời điểm đo).
3. Hệ thống vẽ 3 biểu đồ tăng trưởng chuẩn WHO:
   - **Biểu đồ Cân nặng theo Tuổi (Weight-for-Age):** Xác định nguy cơ nhẹ cân / bình thường / thừa cân.
   - **Biểu đồ Chiều cao theo Tuổi (Height-for-Age):** Xác định thấp còi / chuẩn chiều cao.
   - **Biểu đồ BMI theo Tuổi (BMI-for-Age):** Đánh giá tình trạng gầy còm hay nguy cơ béo phì.
4. Hệ thống hiển thị chấm tròn định vị kết quả đo mới nhất của con và dự báo tốc độ tăng trưởng.
5. Hệ thống hiển thị Khuyến nghị dinh dưỡng & vận động cá nhân hóa do Chuyên gia dinh dưỡng / Bác sĩ trường cung cấp.
6. Phụ huynh có thể xuất tệp PDF sổ theo dõi thể lực định kỳ để lưu giữ.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Bé có nguy cơ suy dinh dưỡng hoặc béo phì:**
  - Hệ thống bật thông báo tư vấn kèm thực đơn bổ sung vi chất và liên kết nhắn tin trực tiếp với nhân viên y tế học đường.
- **BR-031 (Đánh giá Thể lực theo Chuẩn WHO):**
  - Biểu đồ tăng trưởng tính toán chuẩn xác theo phân vị Z-score WHO dành cho trẻ dưới 5 tuổi theo giới tính và độ tuổi từng tháng.
- **Thông báo & Ngoại lệ:**
  - `MSG-141`: "Tải biểu đồ tăng trưởng thể chất thành công."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/healthmedical/controller/HealthMetricController.java` (Định tuyến `/api/health/metrics/student/{studentId}/growth-history`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/healthmedical/service/HealthMetricService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/healthmedical/repository/HealthMetricRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/healthmedical/entity/HealthMetric.java` (Bảng `health.health_metrics`)
- **DTOs:**
  - `src/main/java/com/kidpro/domain/healthmedical/dto/response/HealthMetricResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/parent/tabs/StudentGrowthChartTab.tsx` (Đồ thị Recharts đường cong WHO, bảng lịch sử cân đo, khuyến nghị dinh dưỡng)
  - `kidpro-fe/src/pages/parent/ParentPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/healthApi.ts` (`getStudentGrowthHistory`, `getHealthMetricsByStudent`)
- **Type Definitions:**
  - `kidpro-fe/src/types/health.types.ts` (`HealthMetric`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G7-UC-03] Biểu Đồ Tăng Trưởng*, path: `/parent?tab=growth-chart`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/api/health/metrics/student/{studentId}/growth-history` | Lấy dữ liệu tọa độ vẽ biểu đồ WHO (BR-031) | Path: `studentId` | `List<HealthMetric>` |

---

## G8-UC-08: Xem Chi tiết Phiếu báo Học phí Tháng

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Phụ huynh Học sinh (`PARENT` / `PHU_HUYNH`)
- **Tác nhân phụ / Hệ thống:** Không có
- **Sự kiện kích hoạt:** Phụ huynh nhận được thông báo phát hành học phí tháng hoặc truy cập tab "Học Phí Của Bé" (`/parent?tab=invoices`).
- **Mô tả (User Story):** Là Phụ huynh học sinh, tôi muốn xem chi tiết bảng kê các khoản thu học phí tháng, các khoản tiền ăn đã trừ do nghỉ phép hợp lệ, tiền trông muộn phát sinh và số tiền thực tế phải nộp của từng con, để nắm rõ cơ sở tính toán minh bạch trước khi thanh toán.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Phiếu báo học phí tháng đã được Ban Giám hiệu phê duyệt và phát hành chính thức (`G8-UC-06`, `G8-UC-07`).
- **Hậu điều kiện:**
  - **POST-1:** Hệ thống hiển thị chi tiết hóa đơn, trạng thái thanh toán (`UNPAID` / `PAID`) và nút chuyển sang cổng thanh toán VietQR.

### 2. Luồng sự kiện chính
1. Phụ huynh chọn học sinh và chọn kỳ thu phí cần tra cứu (ví dụ: "Tháng 10/2026").
2. Hệ thống tải thông tin chi tiết phiếu báo học phí gồm:
   - **Khoản thu định mức:** Học phí chính khóa, Tiền ăn bán trú (22 ngày tiêu chuẩn x 35.000đ = 770.000đ), Tiền xe buýt đưa đón.
   - **Khoản giảm trừ chính sách:** Miễn giảm con thứ 2 (Học sinh có anh em ruột học cùng trường), Học bổng hoặc diện chính sách.
   - **Khoản hoàn trả tiền ăn bán trú:** Số ngày nghỉ phép hợp lệ nộp đơn trước 08:00 sáng được duyệt ($N 	imes 35.000$ VNĐ).
   - **Khoản thu phát sinh ngoài kế hoạch:** Tiền trông muộn lũy kế sau 17:00, Tiền mua bổ sung đồng phục/balo.
   - **Tổng tiền thực tế phải nộp:** Bằng số và Bằng chữ (tiếng Việt).
   - **Hạn chót thanh toán:** 10 ngày kể từ ngày phát hành phiếu báo.
3. Phụ huynh kiểm tra đối chiếu chi tiết từng khoản mục theo quy tắc **BR-039**.
4. Phụ huynh có thể bấm nút **Thanh Toán Ngay Qua VietQR** (`G8-UC-09`) hoặc nút **Gửi Khiếu Nại Tra Soát** nếu phát hiện sai lệch số ngày ăn.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Khiếu nại sai lệch học phí / tiền hoàn ăn:**
  - Phụ huynh bấm *Gửi khiếu nại*, nhập nội dung nghi vấn sai lệch (ví dụ: con nghỉ phép 4 ngày nhưng phiếu chỉ trừ tiền ăn 2 ngày).
  - Hệ thống tạo phiếu tra soát chuyển về phòng Kế toán xử lý (`BR-070`).
- **BR-039 (Bảo mật Tra cứu & Hiển thị Minh bạch Cơ cấu Khoản thu):**
  - Phụ huynh chỉ được quyền tra cứu học phí của chính con mình.
  - Phiếu báo hiển thị rõ ràng cơ cấu: Học phí cơ bản + Dịch vụ bán trú/xe buýt - Giảm trừ chính sách - Hoàn trả tiền ăn + Phụ phí đón muộn.
- **Thông báo & Ngoại lệ:**
  - `MSG-161`: "Tải dữ liệu phiếu báo học phí chi tiết thành công."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/finance/controller/TuitionManagementController.java` (Định tuyến `/api/finance/invoices`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/finance/service/TuitionManagementService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/finance/repository/InvoiceRepository.java`
  - `src/main/java/com/kidpro/domain/finance/repository/InvoiceItemRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/finance/entity/Invoice.java` (Bảng `finance.invoices`)
  - `src/main/java/com/kidpro/domain/finance/entity/InvoiceItem.java`
- **DTOs:**
  - `src/main/java/com/kidpro/domain/finance/dto/response/TuitionInvoiceResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/parent/tabs/TuitionInvoicesTab.tsx` (Bảng kê chi tiết học phí, thẻ trạng thái thanh toán, modal khiếu nại sai lệch)
  - `kidpro-fe/src/pages/parent/components/InvoiceDisputeModal.tsx`
  - `kidpro-fe/src/pages/parent/ParentPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/parentApi.ts` (`getTuitionInvoices`, `getInvoiceByReference`, `submitInvoiceDispute`)
- **Type Definitions:**
  - `kidpro-fe/src/types/parent.types.ts` (`TuitionInvoiceItem`, `InvoiceDisputePayload`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G8-UC-08] Phiếu Báo Học Phí*, path: `/parent?tab=invoices`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/api/finance/invoices` | Lấy danh sách hóa đơn học phí của học sinh | Query: `studentId` | `List<TuitionInvoiceItem>` |
| `GET` | `/api/finance/invoices/ref/{referenceCode}` | Chi tiết hóa đơn theo mã tham chiếu | Path: `referenceCode` | `TuitionInvoiceItem` |
| `POST` | `/api/parents/invoices/{id}/disputes` | Nộp khiếu nại tra soát sai lệch tiền (BR-070) | Path: `id`, Body: `InvoiceDisputePayload` (disputeReason, requestedAdjustment) | `ApiResponse` |

---

## G8-UC-09: Thanh toán Học phí qua Quét mã VietQR Động

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Phụ huynh Học sinh (`PARENT` / `PHU_HUYNH`)
- **Tác nhân phụ / Hệ thống:** Cổng Thanh toán VietQR Napas247 / PayOS Webhook
- **Sự kiện kích hoạt:** Phụ huynh bấm nút "Thanh toán ngay bằng VietQR" trên hóa đơn học phí (`/parent?tab=invoices`).
- **Mô tả (User Story):** Là Phụ huynh học sinh, tôi muốn quét hoặc tải ảnh mã VietQR động có sẵn số tiền chính xác và nội dung chuyển khoản chuẩn theo định dạng Napas247, để thanh toán học phí nhanh chóng qua ứng dụng ngân hàng và được hệ thống tự động gạch nợ tức thì mà không cần nộp biên lai giấy.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Hóa đơn học phí ở trạng thái Chờ thanh toán (`UNPAID`).
  - **PRE-2:** Cổng tích hợp VietQR PayOS đang ở trạng thái hoạt động bình thường.
- **Hậu điều kiện:**
  - **POST-1:** Giao dịch ngân hàng được khớp lệnh thành công qua Webhook (< 3 giây), hóa đơn chuyển trạng thái sang [Đã Thanh Toán] (`PAID`).
  - **POST-2:** Hệ thống tự động phát hành biên lai điện tử có chữ ký số (`G8-UC-11`).

### 2. Luồng sự kiện chính
1. Phụ huynh chọn hóa đơn cần thanh toán và nhấn **Thanh Toán VietQR 1-Chạm**.
2. Hệ thống sinh mã VietQR động theo chuẩn EMVCo chứa thông tin: Số tài khoản ngân hàng nhà trường (MBBank), Tên chủ tài khoản (TRƯỜNG MẦM NON QUỐC TẾ KIDPRO), Số tiền chính xác cần nộp, Nội dung chuyển khoản chuẩn hóa (ví dụ: `KIDPRO INV-2026-10-00842`).
3. Màn hình hiển thị mã QR cùng Deep-link mở thẳng ứng dụng ngân hàng của phụ huynh.
4. Phụ huynh mở ứng dụng ngân hàng trên điện thoại, quét mã QR (hoặc nhấn nút mở ứng dụng ngân hàng tự động).
5. Phụ huynh kiểm tra lại thông tin hiển thị trên app ngân hàng và bấm xác nhận chuyển tiền.
6. Ngân hàng chuyển tiền thành công; Cổng PayOS bắn tín hiệu Webhook tức thì (< 3 giây) tới máy chủ KIDPRO kèm chữ ký bảo mật HMAC-SHA512 theo quy tắc **BR-040**.
7. Máy chủ KIDPRO xác thực chữ ký Webhook, đối soát đúng số tiền và mã hóa đơn, tự động gạch nợ thành công (`STATUS = PAID`).
8. Màn hình phụ huynh tự động đổi sang màu xanh chúc mừng: "Thanh toán học phí thành công! Biên lai điện tử đã sẵn sàng" kèm thông báo **MSG-165**.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Chuyển khoản sai lệch số tiền hoặc sai cú pháp nội dung:**
  - Tiền đã trừ tại tài khoản phụ huynh nhưng hệ thống không thể tự động gạch nợ do không khớp mã hóa đơn.
  - Hệ thống ghi nhận vào bảng chờ tra soát thủ công của Kế toán (`G8-UC-10`).
- **BR-040 (Cấu trúc Tiêu chuẩn, Hiệu lực & Tự động Gạch nợ VietQR Động):**
  - Mã VietQR động chứa chính xác số tiền và mã hóa đơn theo chuẩn EMVCo, hiệu lực tối đa 15 phút.
  - Hệ thống tự động gạch nợ tức thì khi nhận được thông báo chuyển khoản thành công khớp số tiền từ Webhook.
- **Thông báo & Ngoại lệ:**
  - `MSG-165`: "Thanh toán học phí qua VietQR thành công. Hệ thống đã tự động gạch nợ và phát hành biên lai điện tử."
  - `E1 (MSG-166)`: "Mã VietQR đã hết hạn hiệu lực (quá 15 phút). Vui lòng tạo lại mã mới."
  - `E2 (MSG-167)`: "Hóa đơn này đã được thanh toán hoặc đang được xử lý giao dịch tại quầy."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/finance/controller/PaymentWebhookController.java` (Định tuyến `/api/payments/webhook`)
  - `src/main/java/com/kidpro/domain/finance/controller/VietQrController.java`
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/finance/service/VietQrPaymentService.java`
  - `src/main/java/com/kidpro/domain/finance/service/impl/VietQrPaymentServiceImpl.java` (Tạo chuỗi VietQR EMVCo, giải mã và xác thực chữ ký HMAC-SHA512 Webhook)
- **Repository:**
  - `src/main/java/com/kidpro/domain/finance/repository/InvoiceRepository.java`
  - `src/main/java/com/kidpro/domain/finance/repository/TransactionRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/finance/entity/Invoice.java`
- **DTOs:**
  - `src/main/java/com/kidpro/domain/finance/dto/response/VietQrPaymentInfoDto.java`
  - `src/main/java/com/kidpro/domain/finance/dto/request/PayOsWebhookPayloadDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/parent/components/VietQrPaymentModal.tsx` (Modal hiển thị mã QR động, nút sao chép số tiền/nội dung, hiệu ứng Polling trạng thái gạch nợ)
  - `kidpro-fe/src/pages/parent/tabs/TuitionInvoicesTab.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/parentApi.ts` (`getInvoiceVietQrData`, `simulatePaymentWebhook`)
- **Type Definitions:**
  - `kidpro-fe/src/types/parent.types.ts` (`VietQrPaymentInfo`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G8-UC-09] Thanh Toán VietQR*, path: `/parent?tab=invoices`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/api/finance/invoices/{id}/vietqr` | Lấy dữ liệu mã VietQR động (BR-040) | Path: `id` | `VietQrPaymentInfo` |
| `POST` | `/api/payments/webhook` | Webhook ngân hàng bắn dữ liệu chuyển khoản tự động gạch nợ | `PayOsWebhookPayloadDto` (referenceCode, amount, bankTransId, status) | `ApiResponse` (`MSG-165`) |

---

## G8-UC-11: Xuất Hóa đơn Điện tử & Biên lai Thu tiền

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Phụ huynh Học sinh (`PARENT` / `PHU_HUYNH`) hoặc Kế toán
- **Tác nhân phụ / Hệ thống:** Dịch vụ Chứng thực Chữ ký số VNPT-CA / Viettel-CA
- **Sự kiện kích hoạt:** Sau khi thanh toán học phí thành công, phụ huynh bấm nút "Xem / Tải Biên Lai Điện Tử" (`/parent?tab=invoices`).
- **Mô tả (User Story):** Là Phụ huynh học sinh, tôi muốn xem và tải về biên lai thu tiền / hóa đơn điện tử định dạng PDF có mã số thuế, số biên lai, chi tiết các khoản thu và chữ ký số hợp chuẩn của nhà trường, để lưu trữ chứng từ thanh toán hợp lệ phục vụ quyết toán thuế hoặc thanh toán chi phí tại cơ quan.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Hóa đơn học phí đã được thanh toán hoàn tất (`STATUS = PAID`).
- **Hậu điều kiện:**
  - **POST-1:** Tệp biên lai điện tử PDF được ký số được tải về thiết bị của phụ huynh.

### 2. Luồng sự kiện chính
1. Phụ huynh chọn hóa đơn đã thanh toán thành công, nhấn **Tải Biên Lai Thu Tiền (PDF)**.
2. Hệ thống tải dữ liệu biên lai điện tử chính thức gồm:
   - Thông tin Đơn vị phát hành: Trường Mầm Non Quốc Tế KIDPRO, Mã số thuế, Địa chỉ, SĐT hotline, Tài khoản ngân hàng.
   - Thông tin Người nộp tiền: Họ tên phụ huynh, Tên học sinh, Lớp học, Niên khóa.
   - Bảng kê chi tiết các khoản thu: Học phí, Bán trú, Đón muộn, Giảm trừ chính sách, Hoàn tiền ăn.
   - Tổng tiền đã thu bằng số và bằng chữ tiếng Việt.
   - Dấu mộc Chữ ký số điện tử: "Ký bởi: TRƯỜNG MẦM NON QUỐC TẾ KIDPRO", Thuật toán SHA-256 with RSA 2048-bit, Thời gian ký số hợp lệ.
3. Hệ thống tạo tài liệu PDF chuẩn in ấn A4 theo quy tắc **BR-042**.
4. Phụ huynh có thể xem trước trực tiếp trên màn hình hoặc nhấn nút Tải tệp PDF về máy tính/điện thoại.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Xác thực tính toàn vẹn chữ ký số:**
  - Phụ huynh có thể bấm nút *Kiểm tra tính hợp lệ chữ ký số*. Hệ thống đối soát chứng chỉ số của trường với Cơ quan chứng thực Quốc gia RootCA.
- **BR-042 (Tính Hợp pháp & Bất biến của Chứng từ Ký số):**
  - Biên lai/Hóa đơn điện tử bắt buộc được ký số hợp chuẩn và xuất trong vòng 24 giờ sau khi thanh toán; chứng từ đã ký số là bất biến tuyệt đối, không thể sửa xóa.
- **Thông báo & Ngoại lệ:**
  - `MSG-168`: "Biên lai thu tiền điện tử hợp lệ. Đã tải tệp PDF thành công."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/finance/controller/ElectronicReceiptController.java` (Định tuyến `/api/finance/invoices/{id}/receipt`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/finance/service/ElectronicReceiptService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/finance/repository/InvoiceRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/finance/entity/Invoice.java`
- **DTOs:**
  - `src/main/java/com/kidpro/domain/finance/dto/response/ElectronicReceiptDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/parent/components/ElectronicReceiptModal.tsx` (Mẫu hóa đơn thanh toán điện tử chuẩn in ấn, huy hiệu chứng thực CA)
  - `kidpro-fe/src/pages/parent/tabs/TuitionInvoicesTab.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/parentApi.ts` (`getElectronicReceipt`)
- **Type Definitions:**
  - `kidpro-fe/src/types/parent.types.ts` (`ElectronicReceiptData`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G8-UC-11] Biên Lai Thu Tiền*, path: `/parent?tab=invoices`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/api/finance/invoices/{id}/receipt` | Lấy chi tiết biên lai thu tiền điện tử có chữ ký số (BR-042) | Path: `id` | `ElectronicReceiptData` (`MSG-168`) |

---

## G9-UC-03: Đăng ký Tham gia Câu lạc bộ Ngoại khóa Năng khiếu

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Phụ huynh Học sinh (`PARENT` / `PHU_HUYNH`)
- **Tác nhân phụ / Hệ thống:** Cán bộ Giáo vụ
- **Sự kiện kích hoạt:** Phụ huynh chọn tab "Câu Lạc Bộ Ngoại Khóa" đầu mỗi học kỳ (`/parent?tab=extracurricular`).
- **Mô tả (User Story):** Là Phụ huynh học sinh, tôi muốn chọn và đăng ký các lớp câu lạc bộ năng khiếu ngoài giờ (Hội họa sáng tạo, Múa ballet, Võ thuật Taekwondo, Tiếng Anh giao tiếp...) phù hợp với sở thích và lứa tuổi của con, để con phát triển toàn diện và hệ thống tự động ghi nhận học phí vào kỳ thu tiếp theo.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Lớp câu lạc bộ đã được Ban Giám hiệu mở và công bố sĩ số còn trống (`G9-UC-01`).
  - **PRE-2:** Học sinh đủ độ tuổi quy định của môn học năng khiếu.
- **Hậu điều kiện:**
  - **POST-1:** Bản ghi đăng ký được lưu vào bảng `academic.student_extracurricular_register` ở trạng thái [Đã Đăng Ký] (`REGISTERED`).
  - **POST-2:** Học sinh có tên trong danh sách điểm danh lớp CLB và học phí được đẩy sang phân hệ Tài chính.

### 2. Luồng sự kiện chính
1. Phụ huynh xem danh sách các Câu lạc bộ Ngoại khóa đang mở: Tên môn, Giáo viên phụ trách, Lịch học trong tuần (ví dụ: Thứ Ba - Thứ Năm: 16:30 - 17:30), Phòng học chức năng, Học phí kỳ, Sĩ số hiện tại / Định mức tối đa.
2. Phụ huynh bấm xem chi tiết đề cương môn học và mục tiêu rèn luyện.
3. Phụ huynh chọn môn học phù hợp cho con và nhấn nút **Đăng Ký Tham Gia**.
4. Hệ thống kiểm tra điều kiện độ tuổi, tính trùng lịch học và sĩ số tối đa theo quy tắc **BR-045** và **BR-047** (Bắt ngoại lệ E1, E2, E3).
5. Hệ thống ghi nhận đăng ký thành công, hiển thị thông báo **MSG-175**.
6. Hệ thống thêm lịch học CLB vào Lịch hoạt động tuần của trẻ trên ứng dụng phụ huynh.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Rút khỏi Câu lạc bộ & Hoàn phí:**
  - Phụ huynh có thể nộp đơn xin rút khỏi CLB trước buổi học thứ 2 theo quy định **BR-047**. Hệ thống sẽ tự động hoàn 100% học phí môn học vào kỳ tới.
- **BR-045 & BR-047 (Sĩ số Định mức & Thời hạn Đăng ký CLB):**
  - Sĩ số lớp CLB năng khiếu từ 10-20 trẻ; không cho phép đăng ký khi đã đủ sĩ số.
  - Thời hạn tiếp nhận kết thúc trước ngày khai giảng 03 ngày; trẻ được rút và hoàn 100% phí nếu báo trước buổi học thứ 2.
- **Thông báo & Ngoại lệ:**
  - `MSG-175`: "Đăng ký tham gia câu lạc bộ năng khiếu thành công."
  - `E1 (MSG-176)`: "Lớp câu lạc bộ đã đạt giới hạn sĩ số tối đa (20 học sinh theo BR-045)."
  - `E2 (MSG-177)`: "Trẻ chưa đủ độ tuổi quy định để tham gia bộ môn này."
  - `E3 (MSG-178)`: "Lịch học của câu lạc bộ bị trùng khung giờ với lớp năng khiếu khác trẻ đã đăng ký."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/academic/controller/ExtracurricularClassController.java` (Định tuyến `/api/academic/extracurricular`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/academic/service/ExtracurricularClassService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/academic/repository/ExtracurricularClassRepository.java`
  - `src/main/java/com/kidpro/domain/academic/repository/StudentExtracurricularRegisterRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/academic/entity/ExtracurricularClass.java`
  - `src/main/java/com/kidpro/domain/academic/entity/StudentExtracurricularRegister.java`
- **DTOs:**
  - `src/main/java/com/kidpro/domain/academic/dto/request/ExtracurricularRegisterDto.java`
  - `src/main/java/com/kidpro/domain/academic/dto/response/ExtracurricularClassResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/parent/tabs/ExtracurricularRegistrationTab.tsx` (Thẻ danh sách môn năng khiếu, bộ lọc độ tuổi, nút đăng ký nhanh)
  - `kidpro-fe/src/pages/parent/ParentPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/extracurricularApi.ts`
- **Type Definitions:**
  - `kidpro-fe/src/types/classroom.types.ts`
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G9-UC-03] CLB Năng Khiếu*, path: `/parent?tab=extracurricular`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/api/academic/extracurricular` | Danh sách lớp câu lạc bộ đang mở | Query: `academicYear`, `gradeLevel` | `List<ExtracurricularClassResponseDto>` |
| `POST` | `/api/academic/extracurricular/register` | Đăng ký học sinh vào lớp CLB (BR-045, BR-047) | `ExtracurricularRegisterDto` (classId, studentId) | `ApiResponse` (`MSG-175`) |
| `DELETE` | `/api/academic/extracurricular/register/{id}` | Hủy đăng ký rút khỏi lớp CLB | Path: `id` | `ApiResponse` |

---

## G10-UC-01: Tạo Đơn Dặn Uống Thuốc Trực tuyến

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Phụ huynh Học sinh (`PARENT` / `PHU_HUYNH`)
- **Tác nhân phụ / Hệ thống:** Giáo viên chủ nhiệm
- **Sự kiện kích hoạt:** Trẻ bị ốm cần uống thuốc theo đơn bác sĩ trong giờ học tại trường (`/parent?tab=medication-request`).
- **Mô tả (User Story):** Là Phụ huynh học sinh, tôi muốn tạo đơn dặn uống thuốc trực tuyến với đầy đủ thông tin chỉ định y khoa (tên thuốc, liều lượng, giờ uống, ảnh chụp đơn thuốc của bác sĩ), để giáo viên chủ nhiệm tiếp nhận và cho con uống thuốc đúng quy định an toàn y tế học đường.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Thuốc có đơn kê toa của bác sĩ chuyên khoa.
- **Hậu điều kiện:**
  - **POST-1:** Đơn dặn thuốc được tạo ở trạng thái [Chờ Tiếp Nhận] (`PENDING`) trong bảng `health.medication_request`.
  - **POST-2:** Giáo viên chủ nhiệm nhận được thông báo nhắc nhở tiếp nhận thuốc vào đầu ngày.

### 2. Luồng sự kiện chính
1. Phụ huynh mở ứng dụng, chọn chức năng **Gửi Đơn Dặn Uống Thuốc**.
2. Phụ huynh chọn học sinh cần gửi thuốc.
3. Phụ huynh nhập các loại thuốc cần cho uống:
   - Tên thuốc (ví dụ: Kháng sinh Cefixim 100mg, Siro ho Prospan).
   - Liều lượng mỗi lần (ví dụ: 1 gói hoặc 5ml).
   - Khung giờ uống tại trường (ví dụ: Sau ăn trưa 11:30).
   - Hướng dẫn pha thuốc hoặc uống cùng nước ấm.
4. Phụ huynh chụp ảnh toa thuốc có chữ ký/con dấu của bác sĩ đính kèm đơn dặn thuốc.
5. Phụ huynh cam kết đã dán nhãn tên và lớp của con trên hộp thuốc.
6. Phụ huynh nhấn nút **Gửi Đơn Dặn Thuốc**.
7. Hệ thống kiểm tra quy tắc an toàn thuốc theo quy tắc **BR-029** và **BR-030** (Bắt ngoại lệ E1, E2, E3).
8. Hệ thống lưu đơn dặn thuốc, hiển thị thông báo **MSG-195**.
9. Hệ thống gửi thông báo cho giáo viên chủ nhiệm sẵn sàng tiếp nhận thuốc đầu giờ sáng.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Theo dõi tiến trình uống thuốc của con trong ngày:**
  - Sau khi giáo viên cho trẻ uống thuốc và chụp ảnh (`G10-UC-03`), phụ huynh nhận được thông báo tức thì kèm ảnh chụp minh chứng lúc con uống thuốc.
- **BR-029 & BR-030 (Điều kiện Tiếp nhận Thuốc Kê đơn & Giãn cách Liều):**
  - Chỉ tiếp nhận thuốc có đơn bác sĩ kê toa; khoảng cách giữa 2 liều cùng loại tối thiểu phải đủ 4 giờ.
  - Phụ huynh bắt buộc dán nhãn định danh và bàn giao tận tay giáo viên tại cửa lớp.
- **Thông báo & Ngoại lệ:**
  - `MSG-195`: "Gửi đơn dặn thuốc trực tuyến thành công. Vui lòng bàn giao thuốc tận tay cô giáo."
  - `E1 (MSG-196)`: "Bắt buộc chụp ảnh đơn thuốc của bác sĩ chuyên khoa theo quy định BR-029."
  - `E2 (MSG-197)`: "Khoảng cách giữa hai cữ uống trong ngày chưa đủ 4 giờ."

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
  - `src/main/java/com/kidpro/domain/healthmedical/dto/request/MedicationSubmitRequestDto.java`
  - `src/main/java/com/kidpro/domain/healthmedical/dto/response/MedicationResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/parent/tabs/MedicationRequestTab.tsx` (Biểu mẫu gửi đơn dặn thuốc, tải ảnh đơn bác sĩ, thẻ theo dõi trạng thái uống thuốc)
  - `kidpro-fe/src/pages/parent/ParentPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/parentApi.ts` (`submitMedicationRequest`, `getStudentMedications`)
  - `kidpro-fe/src/api/healthApi.ts` (`submitMedication`)
- **Type Definitions:**
  - `kidpro-fe/src/types/parent.types.ts` (`SubmitMedicationPayload`, `ParentMedicationItem`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G10-UC-01] Dặn Uống Thuốc*, path: `/parent?tab=medications`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/health/medications` | Tạo đơn dặn uống thuốc trực tuyến (BR-029, BR-030) | `SubmitMedicationPayload` (studentId, medicationName, dosage, administrationTime, notes, prescriptionPhotoUrl) | `ParentMedicationItem` (`MSG-195`) |
| `GET` | `/api/health/medications/student/{studentId}` | Lấy lịch sử các đơn dặn thuốc của con | Path: `studentId` | `List<ParentMedicationItem>` |

---

## G10-UC-05: Trao đổi Tin nhắn Trực tiếp giữa Phụ huynh và Giáo viên (1-1)

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Phụ huynh Học sinh (`PARENT` / `PHU_HUYNH`)
- **Tác nhân phụ / Hệ thống:** Giáo viên Chủ nhiệm
- **Sự kiện kích hoạt:** Phụ huynh mở mục "Nhắn Tin Cho Cô Giáo" trên sổ liên lạc điện tử (`/parent?tab=chat-teacher`).
- **Mô tả (User Story):** Là Phụ huynh học sinh, tôi muốn nhắn tin trao đổi trực tiếp và gửi hình ảnh riêng tư 1-1 với cô giáo chủ nhiệm, để cập nhật kịp thời thói quen, tâm lý, sinh hoạt hoặc vấn đề sức khỏe của con một cách bảo mật mà không làm phiền nhóm phụ huynh chung.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Trẻ đang theo học tại lớp và có giáo viên chủ nhiệm phụ trách.
- **Hậu điều kiện:**
  - **POST-1:** Tin nhắn được gửi theo thời gian thực và lưu vào bảng `comms.daily_messages` (`MESSAGE_TYPE = DIRECT_1_ON_1`).
  - **POST-2:** Cô giáo nhận được thông báo tin nhắn mới trên thiết bị.

### 2. Luồng sự kiện chính
1. Phụ huynh chọn Cô giáo chủ nhiệm cần nhắn tin.
2. Hệ thống tải toàn bộ lịch sử tin nhắn trò chuyện giữa gia đình và giáo viên.
3. Phụ huynh nhập nội dung tin nhắn hoặc chọn ảnh đính kèm (ảnh đơn thuốc, ảnh bài tập con làm ở nhà...).
4. Phụ huynh nhấn nút **Gửi Tin Nhắn**.
5. Hệ thống kiểm tra khung giờ liên lạc sư phạm theo quy tắc **BR-058** (Bắt ngoại lệ E1).
6. Hệ thống gửi tin nhắn qua WebSocket, lưu vào cơ sở dữ liệu và hiển thị trạng thái [Đã gửi].
7. Khi giáo viên mở xem, trạng thái chuyển thành [Đã xem].

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Thu hồi tin nhắn đã gửi:**
  - Phụ huynh có thể bấm giữ tin nhắn và chọn *Thu hồi tin nhắn* trong vòng 15 phút kể từ lúc gửi theo quy tắc **BR-058**.
- **BR-058 (Khung giờ Liên lạc Sư phạm & Thu hồi Tin nhắn):**
  - Khung giờ gửi tin nhắn trực tiếp từ 07:00 đến 21:30 hàng ngày; tin nhắn sau 21:30 tự động chuyển sang chế độ im lặng; cho phép thu hồi tin nhắn trong vòng 15 phút.
- **Thông báo & Ngoại lệ:**
  - `MSG-211`: "Gửi tin nhắn trao đổi tới cô giáo thành công."
  - `E1 (MSG-212)`: "Đã quá thời hạn 15 phút, không thể thu hồi tin nhắn đã gửi (BR-058)."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/comms/controller/DirectMessageController.java` (Định tuyến `/api/comms/messages/direct`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/comms/service/DirectMessageService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/comms/repository/DailyMessageRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/comms/entity/DailyMessage.java` (Bảng `comms.daily_messages`)
- **DTOs:**
  - `src/main/java/com/kidpro/domain/comms/dto/request/DirectMessageSendDto.java`
  - `src/main/java/com/kidpro/domain/comms/dto/response/DirectMessageDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/parent/tabs/TeacherDirectChatTab.tsx` (Khung chat thời gian thực 1-1, gửi ảnh, hiển thị trạng thái đã xem, nút thu hồi)
  - `kidpro-fe/src/pages/parent/ParentPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/commsApi.ts`
- **Type Definitions:**
  - `kidpro-fe/src/types/comms.types.ts`
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G10-UC-05] Nhắn Tin Với Cô*, path: `/parent?tab=chat`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/comms/messages/direct` | Gửi tin nhắn trực tiếp 1-1 tới giáo viên (BR-058) | `DirectMessageSendDto` (recipientStaffId, content, attachmentUrls) | `DirectMessageDto` (`MSG-211`) |
| `GET` | `/api/comms/messages/direct/{staffId}` | Lấy lịch sử trò chuyện 1-1 | Path: `staffId` | `List<DirectMessageDto>` |
| `DELETE` | `/api/comms/messages/direct/{id}/recall` | Thu hồi tin nhắn trong vòng 15 phút | Path: `id` | `ApiResponse` |

---

## G10-UC-06: Xem Dòng Thời Gian Nhật ký & Album Ảnh của Con

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Phụ huynh Học sinh (`PARENT` / `PHU_HUYNH`)
- **Tác nhân phụ / Hệ thống:** Giáo viên đứng lớp
- **Sự kiện kích hoạt:** Phụ huynh mở ứng dụng xem dòng thời gian (Timeline) hoạt động ngày của con (`/parent?tab=timeline`).
- **Mô tả (User Story):** Là Phụ huynh học sinh, tôi muốn xem dòng thời gian trực quan ghi nhận toàn bộ hoạt động trong ngày của con (điểm danh đến lớp lúc mấy giờ kèm ảnh, lượng ăn các bữa, giấc ngủ trưa, nhật ký vệ sinh, các bài học và album ảnh sinh hoạt vui vẻ), để thả tim, để lại bình luận và tải ảnh chất lượng cao về máy lưu giữ kỷ niệm tuổi thơ.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Giáo viên đã cập nhật điểm danh và nhật ký sinh hoạt của lớp (`G5-UC-01`, `G10-UC-04`, `G11-UC-05`).
- **Hậu điều kiện:**
  - **POST-1:** Phụ huynh tải được ảnh có mặt con về máy hoặc lưu vào bộ sưu tập gia đình.

### 2. Luồng sự kiện chính
1. Phụ huynh mở tab "Nhật Ký & Hoạt Động Của Con".
2. Hệ thống tải Dòng thời gian (Timeline) theo thứ tự thời gian từ sáng đến chiều:
   - **07:35:** Điểm danh đến lớp thành công (Kèm ảnh chụp snapshot tại cổng).
   - **08:15:** Ăn sáng - Ăn hết suất cháo sườn.
   - **09:00:** Hoạt động học có chủ đích: Bé tập hát và vận động múa.
   - **10:15:** Album ảnh: "Giờ chơi góc xây dựng của các con" (Bé được gắn thẻ trong 3 bức ảnh).
   - **11:30:** Ăn trưa - Ăn 2/3 suất cơm.
   - **12:00 - 14:00:** Giấc ngủ trưa: Ngủ sâu giấc, không quấy khóc.
   - **14:30:** Ăn xế: Uống hết 1 ly sữa tươi.
   - **16:45:** Đã đón về tận tay mẹ.
3. Phụ huynh bấm vào từng ảnh trong album để xem ảnh phóng to độ phân giải cao.
4. Phụ huynh có thể bấm "Thả tim", bình luận khen ngợi cô và con.
5. Phụ huynh nhấn nút **Tải Ảnh Về Máy** theo quy tắc **BR-060**.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Phụ huynh chỉ tải ảnh có mặt con mình:**
  - Hệ thống sử dụng cờ nhận diện gắn thẻ (`student_id`), cho phép phụ huynh lọc nhanh "Chỉ ảnh có mặt bé" để tải hàng loạt.
- **BR-060 (Quyền Riêng tư Hình ảnh Trẻ em):**
  - Phụ huynh chỉ có quyền tải ảnh có mặt con mình; nghiêm cấm sử dụng hình ảnh học sinh khác vào mục đích thương mại; bản quyền hình ảnh thuộc về nhà trường.
- **Thông báo & Ngoại lệ:**
  - `MSG-218`: "Tải dữ liệu nhật ký sinh hoạt của con thành công."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/student/controller/DailyActivityController.java`
  - `src/main/java/com/kidpro/domain/academic/controller/ClassroomJournalController.java`
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/student/service/DailyActivityService.java`
  - `src/main/java/com/kidpro/domain/academic/service/ClassroomJournalService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/student/repository/DailyActivityRepository.java`
  - `src/main/java/com/kidpro/domain/academic/repository/ClassroomJournalPostRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/student/entity/DailyActivity.java`
  - `src/main/java/com/kidpro/domain/academic/entity/ClassroomJournalPost.java`
- **DTOs:**
  - `src/main/java/com/kidpro/domain/student/dto/response/DailyActivityResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/parent/tabs/ChildDailyJournalTab.tsx` (Timeline sinh hoạt cả ngày, thư viện ảnh phóng to, bộ lọc chỉ ảnh có con)
  - `kidpro-fe/src/pages/parent/ParentPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/healthApi.ts` (`getJournalPosts`, `getMealRecordsByStudent`, `getNapRecordsByStudent`)
- **Type Definitions:**
  - `kidpro-fe/src/types/health.types.ts`
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G10-UC-06] Nhật Ký Hoạt Động Của Con*, path: `/parent?tab=timeline`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/api/health/journal-posts/student/{studentId}` | Lấy bài đăng nhật ký và album ảnh gắn thẻ con | Path: `studentId`, Query: `date` | `List<ClassroomJournalPost>` |
| `GET` | `/api/health/daily-summary/{studentId}` | Lấy tổng hợp ăn ngủ vệ sinh trong ngày | Path: `studentId`, Query: `date` | `DailyActivityResponseDto` |

---

## G10-UC-07: Xem Phiếu Đánh giá Sự Phát triển của Trẻ (5 Lĩnh vực)

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Phụ huynh Học sinh (`PARENT` / `PHU_HUYNH`)
- **Tác nhân phụ / Hệ thống:** Không có
- **Sự kiện kích hoạt:** Ban Giám hiệu phê duyệt và công bố phiếu đánh giá định kỳ trên Sổ liên lạc điện tử (`/parent?tab=development-report`).
- **Mô tả (User Story):** Là Phụ huynh học sinh, tôi muốn xem chi tiết phiếu đánh giá định kỳ 5 lĩnh vực phát triển (Thể chất, Nhận thức, Ngôn ngữ, Tình cảm - Kỹ năng xã hội, Thẩm mỹ) và đọc lời nhận xét sư phạm tâm huyết của cô giáo về con, để hiểu rõ thế mạnh cũng như các kỹ năng cần phối hợp rèn luyện thêm cho con tại nhà.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Phiếu đánh giá đã được Ban Giám hiệu phê duyệt chính thức (`STATUS = APPROVED`).
- **Hậu điều kiện:**
  - **POST-1:** Phụ huynh xem được bảng điểm chi tiết, biểu đồ radar mạng nhện và lời nhận xét sư phạm của cô giáo.

### 2. Luồng sự kiện chính
1. Phụ huynh chọn kỳ đánh giá cần xem (Cuối Học kỳ I hoặc Cuối Năm học).
2. Hệ thống tải chi tiết phiếu đánh giá phát triển của con gồm:
   - **Biểu đồ Radar 5 Trục (Mạng nhện):** Trực quan hóa điểm số từng lĩnh vực so với chuẩn độ tuổi.
   - **Chi tiết từng lĩnh vực:** Danh sách các tiêu chí thành phần (Đạt / Chưa đạt).
   - **Lời nhận xét sư phạm của Giáo viên chủ nhiệm:** Đánh giá tính cách, sự hòa nhập, thói quen tự phục vụ và các điểm nổi bật của bé.
   - **Chữ ký phê duyệt của Ban Giám hiệu.**
3. Phụ huynh đọc kỹ đánh giá theo quy tắc **BR-063**.
4. Phụ huynh có thể nhập phản hồi hoặc để lại lời cảm ơn gửi tới giáo viên chủ nhiệm.
5. Phụ huynh có thể xuất tệp PDF Phiếu đánh giá sự phát triển có mộc điện tử của trường để lưu giữ.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Phụ huynh có băn khoăn về kết quả đánh giá:**
  - Phụ huynh có thể bấm nút *Trao đổi thêm với cô giáo* để chuyển sang màn hình nhắn tin 1-1 (`G10-UC-05`).
- **BR-063 (Quyền Riêng tư Tra cứu Phiếu Đánh giá Cá nhân):**
  - Phụ huynh chỉ có quyền xem phiếu đánh giá định kỳ của con mình; hệ thống tuyệt đối không công khai bảng xếp loại hoặc điểm số của trẻ này cho phụ huynh trẻ khác để bảo vệ tâm lý học sinh.
- **Thông báo & Ngoại lệ:**
  - `MSG-221`: "Tải phiếu đánh giá sự phát triển của trẻ thành công."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/student/controller/DevelopmentEvaluationApprovalController.java` (Định tuyến `/api/health/evaluations/student/{studentId}`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/student/service/DevelopmentEvaluationApprovalService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/student/repository/DevelopmentEvaluationRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/student/entity/DevelopmentEvaluation.java`
- **DTOs:**
  - `src/main/java/com/kidpro/domain/student/dto/response/DevelopmentEvaluationApprovalDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/parent/tabs/ChildDevelopmentReportTab.tsx` (Biểu đồ Radar ngũ giác 5 trục, bảng tiêu chí chi tiết, hộp nhận xét giáo viên)
  - `kidpro-fe/src/pages/parent/ParentPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/healthApi.ts` (`getEvaluationsByStudent`)
- **Type Definitions:**
  - `kidpro-fe/src/types/health.types.ts` (`DevelopmentEvaluation`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G10-UC-07] Đánh Giá Phát Triển*, path: `/parent?tab=evaluation`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/api/health/evaluations/student/{studentId}` | Lấy chi tiết phiếu đánh giá 5 lĩnh vực của con (BR-063) | Path: `studentId`, Query: `term`, `academicYear` | `List<DevelopmentEvaluation>` |

---

## G10-UC-08: Nộp Đơn Xin Nghỉ Học Trực Tuyến

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Phụ huynh Học sinh (`PARENT` / `PHU_HUYNH`)
- **Tác nhân phụ / Hệ thống:** Giáo viên chủ nhiệm, Nhà bếp bán trú, Kế toán
- **Sự kiện kích hoạt:** Con bị ốm hoặc gia đình có việc bận cần cho con nghỉ học ở nhà (`/parent?tab=leave-request`).
- **Mô tả (User Story):** Là Phụ huynh học sinh, tôi muốn nộp đơn xin nghỉ học trực tuyến trên ứng dụng kèm lý do và số ngày nghỉ dự kiến trước 08:00 sáng, để giáo viên chủ nhiệm nắm bắt quân số và nhà trường tự động tính giảm trừ tiền ăn bán trú hợp lệ vào kỳ học phí tiếp theo.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Học sinh đang học chính thức tại trường.
- **Hậu điều kiện:**
  - **POST-1:** Đơn xin nghỉ được tạo trong bảng `student.leave_requests` ở trạng thái [Chờ Duyệt] (`PENDING`).
  - **POST-2:** Khi được duyệt đúng hạn, hệ thống tự động ghi nhận ngày nghỉ có phép và đánh dấu cờ hoàn trả tiền ăn bán trú (`mealRefundApplied = true`).

### 2. Luồng sự kiện chính
1. Phụ huynh chọn chức năng **Nộp Đơn Xin Nghỉ Học**.
2. Phụ huynh chọn học sinh cần xin nghỉ.
3. Phụ huynh chọn Khoảng thời gian xin nghỉ: Từ ngày đến Ngày.
4. Phụ huynh chọn Lý do xin nghỉ: Con bị ốm/sốt, Đi du lịch/về quê cùng gia đình, Gia đình có việc riêng, hoặc Lý do khác.
5. Phụ huynh nhập mô tả dặn dò cô giáo và đính kèm tệp giấy khám bệnh (nếu có).
6. Hệ thống hiển thị thông tin chính sách hoàn tiền ăn theo thời điểm nộp theo quy tắc **BR-018**, **BR-036** và **BR-064**:
   - Nộp trước 07:00 sáng: Được hoàn tiền toàn bộ các bữa ăn (Sáng, Trưa, Xế).
   - Nộp trước 08:00 sáng: Được hoàn tiền ăn bữa Trưa và Xế (35.000 VNĐ/ngày).
   - Nộp sau 08:30 sáng: Không được hoàn tiền ăn do Bếp đã khóa sổ và xuất thực phẩm nấu.
7. Phụ huynh nhấn **Gửi Đơn Xin Nghỉ**.
8. Hệ thống kiểm tra tính hợp lệ của ngày xin nghỉ (Bắt ngoại lệ E1, E2, E3).
9. Hệ thống lưu đơn xin nghỉ, hiển thị thông báo **MSG-225**.
10. Hệ thống gửi thông báo cho giáo viên chủ nhiệm phê duyệt.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Hủy đơn xin nghỉ đã nộp:**
  - Nếu gia đình thu xếp cho con đi học lại bình thường được, phụ huynh có thể bấm *Hủy đơn xin nghỉ* trước 08:00 sáng.
- **BR-018, BR-036 & BR-064 (Khung giờ Chốt Nghỉ & Điều kiện Hoàn Tiền Ăn):**
  - Đơn xin nghỉ học bắt buộc nộp trước 08:00 sáng của ngày bắt đầu nghỉ; thời gian xin nghỉ không được nằm trong quá khứ.
  - Tiền hoàn ăn = Số ngày nghỉ phép hợp lệ được duyệt trước hạn $	imes$ 35.000 VNĐ/ngày; được đối trừ tự động vào hóa đơn kỳ tới.
- **Thông báo & Ngoại lệ:**
  - `MSG-225`: "Nộp đơn xin nghỉ học thành công. Đơn đã được chuyển tới cô giáo chủ nhiệm."
  - `E1 (MSG-226)`: "Ngày xin nghỉ học không được nằm trong quá khứ."
  - `E2 (MSG-227)`: "Học sinh đã có một đơn xin nghỉ khác đang có hiệu lực trong khoảng thời gian này."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/student/controller/LeaveRequestController.java` (Định tuyến `/api/parents/leave-requests`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/student/service/LeaveRequestService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/student/repository/LeaveRequestRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/student/entity/LeaveRequest.java` (Bảng `student.leave_requests`)
- **DTOs:**
  - `src/main/java/com/kidpro/domain/student/dto/request/CreateLeaveRequestDto.java`
  - `src/main/java/com/kidpro/domain/student/dto/response/LeaveRequestResponseDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/parent/tabs/LeaveRequestTab.tsx` (Biểu mẫu nộp đơn nghỉ học, đồng hồ cảnh báo giờ chốt 08:00, thẻ tính tiền hoàn ăn, danh sách đơn đã nộp)
  - `kidpro-fe/src/pages/parent/ParentPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/parentApi.ts` (`submitLeaveRequest`, `getLeaveRequests`, `getDailyRefundRate`)
  - `kidpro-fe/src/api/attendanceApi.ts` (`submitLeaveRequest`, `getMyLeaveRequests`, `deleteLeaveRequest`)
- **Type Definitions:**
  - `kidpro-fe/src/types/parent.types.ts` (`SubmitLeaveRequestPayload`, `ParentLeaveItem`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G10-UC-08] Xin Nghỉ Học*, path: `/parent?tab=leave-request`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/parents/leave-requests` | Nộp đơn xin nghỉ học trực tuyến (BR-018, BR-064) | `SubmitLeaveRequestPayload` (studentId, startDate, endDate, reason, notes, isHalfDay) | `ParentLeaveItem` (`MSG-225`) |
| `GET` | `/api/parents/leave-requests` | Lấy danh sách đơn xin nghỉ của gia đình | Query: `studentId` | `List<ParentLeaveItem>` |
| `DELETE` | `/api/parents/leave-requests/{id}` | Hủy đơn xin nghỉ trước giờ chốt | Path: `id` | `ApiResponse` |

---

## G11-UC-07: Làm Phiếu Khảo sát Đánh giá Trường học

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Phụ huynh Học sinh (`PARENT` / `PHU_HUYNH`)
- **Tác nhân phụ / Hệ thống:** Ban Giám hiệu
- **Sự kiện kích hoạt:** Nhà trường phát động chiến dịch khảo sát chất lượng định kỳ (Quý hoặc Cuối kỳ) (`/parent?tab=survey`).
- **Mô tả (User Story):** Là Phụ huynh học sinh, tôi muốn trả lời các câu hỏi đánh giá chất lượng (chất lượng bữa ăn, sự tận tâm của giáo viên, an toàn cơ sở vật chất, tính kịp thời của thông tin) và gửi đóng góp ý kiến trực tuyến (hỗ trợ tùy chọn ẩn danh), để bày tỏ nguyện vọng và giúp nhà trường không ngừng nâng cao chất lượng chăm sóc, nuôi dưỡng con.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Đợt khảo sát đang trong thời gian mở tiếp nhận ý kiến.
  - **PRE-2:** Phụ huynh chưa từng nộp bài khảo sát trong đợt này.
- **Hậu điều kiện:**
  - **POST-1:** Bài khảo sát được lưu vào bảng dữ liệu khảo sát và tự động đánh cờ đã hoàn thành cho tài khoản phụ huynh.
  - **POST-2:** Dữ liệu điểm số được tổng hợp vào bảng phân tích chất lượng của Ban Giám hiệu.

### 2. Luồng sự kiện chính
1. Phụ huynh nhận được thông báo mời tham gia khảo sát chất lượng.
2. Phụ huynh mở tab "Khảo Sát Ý Kiến Phụ Huynh".
3. Hệ thống hiển thị chiến dịch khảo sát hiện tại (ví dụ: "Khảo sát Ý kiến Đánh giá Chất lượng Chăm sóc Quý IV/2026").
4. Phụ huynh chấm điểm sao (từ 1 đến 5 sao) cho 4 tiêu chí cốt lõi:
   - **Chất lượng Bữa ăn Bán trú:** Vệ sinh, độ ngon miệng, tính phong phú của thực đơn.
   - **Sự Tận tâm & Sư phạm của Giáo viên:** Thái độ chăm sóc, tình yêu thương, sự tương tác với gia đình.
   - **An toàn & Cơ sở Vật chất:** Phòng học sạch sẽ, trang thiết bị an toàn, camera giám sát.
   - **Kênh Liên lạc & Cổng Thông tin:** Sự kịp thời, minh bạch của sổ liên lạc điện tử.
5. Phụ huynh nhập ý kiến đóng góp / đề xuất cải tiến bằng văn bản.
6. Phụ huynh tùy chọn: [Gửi Dưới Dạng Ẩn Danh] hoặc [Gửi Kèm Danh Tính] và [Chỉ Gửi Cho Ban Giám Hiệu].
7. Phụ huynh nhấn **Gửi Phiếu Khảo Sát**.
8. Hệ thống kiểm tra quy tắc nộp duy nhất theo quy tắc **BR-061** (Bắt ngoại lệ E1, E2).
9. Hệ thống ghi nhận kết quả, hiển thị thông báo cảm ơn **MSG-245**.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Chống nộp lặp bài khảo sát:**
  - Nếu phụ huynh đã nộp bài trong chiến dịch này, hệ thống hiển thị thông báo: "Quý phụ huynh đã hoàn tất khảo sát này. Cảm ơn sự đóng góp quý báu!" và khóa nút gửi.
- **BR-061 (Tính Duy nhất, Bất biến & Nguyên tắc Ẩn danh trong Khảo sát):**
  - Mỗi phụ huynh chỉ được làm phiếu khảo sát đúng 01 lần trong mỗi đợt; câu trả lời sau khi nộp là bất biến; hệ thống bảo đảm tuyệt đối tính ẩn danh khi phụ huynh chọn chế độ ẩn danh.
- **Thông báo & Ngoại lệ:**
  - `MSG-245`: "Cảm ơn Quý Phụ huynh đã đóng góp ý kiến quý báu! Đánh giá của Quý vị giúp nhà trường ngày càng hoàn thiện hơn."
  - `E1 (MSG-246)`: "Quý phụ huynh đã gửi đánh giá cho đợt khảo sát này trước đó (BR-061)."
  - `E2 (MSG-247)`: "Đợt khảo sát đã kết thúc thời hạn tiếp nhận ý kiến."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/comms/controller/ServiceSurveyController.java` (Định tuyến `/api/comms/surveys`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/comms/service/ServiceSurveyService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/comms/repository/SurveySubmissionRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/comms/entity/SurveySubmission.java`
- **DTOs:**
  - `src/main/java/com/kidpro/domain/comms/dto/request/SurveySubmissionDto.java`
  - `src/main/java/com/kidpro/domain/comms/dto/response/SurveyCampaignDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/parent/tabs/ServiceSurveyTab.tsx` (Thang điểm 5 sao, chuyển đổi ẩn danh, gửi góp ý, màn hình cảm ơn)
  - `kidpro-fe/src/pages/parent/ParentPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/parentApi.ts` (`getActiveSurveyCampaign`, `checkSurveySubmissionStatus`, `submitServiceSurvey`)
- **Type Definitions:**
  - `kidpro-fe/src/types/parent.types.ts` (`SurveyCampaign`, `ServiceRatings`, `ServiceSurveySubmission`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[G11-UC-07] Khảo Sát Ý Kiến*, path: `/parent?tab=survey`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `GET` | `/api/comms/surveys/active` | Lấy thông tin đợt khảo sát đang kích hoạt | Không có | `SurveyCampaign` |
| `GET` | `/api/comms/surveys/{id}/check-submission` | Kiểm tra trạng thái đã nộp khảo sát hay chưa | Path: `id`, Query: `studentId` | `{ hasSubmitted: boolean }` |
| `POST` | `/api/comms/surveys/submissions` | Gửi bài đánh giá khảo sát dịch vụ (BR-061) | `{ surveyId, studentId, ratings, feedback, isAnonymous, sendToPrincipalOnly }` | `{ success: boolean, message: string }` (`MSG-245`) |

---

## UC-Decree13: Yêu cầu Xóa Dữ liệu Sinh trắc học theo Nghị định 13/2023/NĐ-CP

### 1. Thông tin nghiệp vụ
- **Tác nhân chính:** Phụ huynh Học sinh (`PARENT` / `PHU_HUYNH`)
- **Tác nhân phụ / Hệ thống:** Microservice AI Vision, Ban Giám hiệu
- **Sự kiện kích hoạt:** Phụ huynh muốn thực thi quyền được xóa dữ liệu cá nhân sinh trắc học của con khi chuyển trường hoặc tốt nghiệp (`/parent?tab=biometric-purge`).
- **Mô tả (User Story):** Là Phụ huynh học sinh, tôi muốn thực hiện quyền yêu cầu nhà trường xóa vĩnh viễn toàn bộ hình ảnh khuôn mặt và vector đặc trưng sinh trắc học AI 512 chiều của con theo quy định tại Nghị định 13/2023/NĐ-CP qua xác thực bảo mật 2 lớp (Mật khẩu tài khoản + Mã OTP SMS), và nhận Biên bản số chứng thực đã tiêu hủy dữ liệu để bảo vệ quyền riêng tư tuyệt đối cho con.
- **Điều kiện tiên quyết:**
  - **PRE-1:** Học sinh có dữ liệu sinh trắc học đang lưu trữ tại trường.
  - **PRE-2:** Hồ sơ của học sinh không có tranh chấp pháp lý về quyền nuôi con.
- **Hậu điều kiện:**
  - **POST-1:** Bản ghi vector 512 chiều trong bảng `student.face_encoding_file` bị xóa vĩnh viễn (Hard Delete) và toàn bộ ảnh chụp mẫu trên Cloud Storage bị xóa sạch.
  - **POST-2:** Hệ thống cấp Chứng thư số Tiêu hủy Dữ liệu Sinh trắc học (Biometric Purge Certificate) định dạng PDF có mã băm bất biến cho phụ huynh.

### 2. Luồng sự kiện chính
1. Phụ huynh chọn tính năng **Thực Thi Quyền Xóa Dữ Liệu Sinh Trắc Học (Nghị định 13/2023/NĐ-CP)**.
2. Hệ thống hiển thị cảnh báo hậu quả: "Sau khi xóa dữ liệu, tính năng nhận diện khuôn mặt tự động tại cổng và lớp học sẽ bị vô hiệu hóa hoàn toàn. Con sẽ chuyển sang chế độ điểm danh thủ công".
3. Phụ huynh nhập Mật khẩu tài khoản để xác thực danh tính bước 1.
4. Phụ huynh bấm **Yêu Cầu Gửi Mã Xác Thực OTP (Bước 1)**.
5. Hệ thống gửi mã OTP 6 chữ số tới số điện thoại/email chính của phụ huynh.
6. Phụ huynh nhập mã OTP 6 chữ số, chọn lý do xóa dữ liệu (Tốt nghiệp, Chuyển trường, Nguyện vọng riêng) và bấm **Xác Nhận Tiêu Hủy Dữ Liệu Vĩnh Viễn**.
7. Hệ thống kiểm tra tính hợp lệ của mã OTP và cờ tranh chấp quyền giám hộ (Bắt ngoại lệ E1, E2, E3).
8. Hệ thống thực thi lệnh tiêu hủy vĩnh viễn dữ liệu vector và ảnh mẫu, giải phóng chỉ mục HNSW trên `pgvector`.
9. Hệ thống tạo Chứng thư Tiêu hủy Dữ liệu Điện tử (kèm mã Hash SHA-256 xác thực), hiển thị thông báo **MSG-251**.
10. Phụ huynh có thể tải Chứng thư số tiêu hủy dữ liệu định dạng PDF về máy để lưu trữ pháp lý.

### 3. Luồng rẽ nhánh & Quy tắc nghiệp vụ
- **Rẽ nhánh A1 — Hồ sơ có tranh chấp quyền nuôi con:**
  - Nếu học sinh đang có cờ cảnh báo tranh chấp giám hộ pháp lý, hệ thống từ chối xóa dữ liệu tự động và yêu cầu phụ huynh liên hệ trực tiếp Ban Giám hiệu.
- **Quy chuẩn Pháp lý (Nghị định 13/2023/NĐ-CP về Bảo vệ Dữ liệu Cá nhân):**
  - Người dùng có toàn quyền rút lại sự đồng ý và yêu cầu xóa vĩnh viễn dữ liệu sinh trắc học; nhà trường bắt buộc xóa bỏ hoàn toàn trong vòng 72 giờ và cấp biên bản xác nhận cho gia đình.
- **Thông báo & Ngoại lệ:**
  - `MSG-251`: "Đã tiêu hủy vĩnh viễn toàn bộ dữ liệu sinh trắc học khuôn mặt của học sinh theo Nghị định 13/2023/NĐ-CP. Chứng thư số tiêu hủy dữ liệu đã được cấp."
  - `E1 (MSG-252)`: "Mã xác thực OTP không chính xác hoặc đã hết hạn hiệu lực."
  - `E2 (MSG-253)`: "Mật khẩu tài khoản phụ huynh không đúng."
  - `E3 (MSG-254)`: "Tạm dừng yêu cầu xóa dữ liệu do hồ sơ đang có tranh chấp quyền giám hộ pháp lý."

### 4. Các file Backend (BE) liên quan
- **Controller:**
  - `src/main/java/com/kidpro/domain/student/controller/BiometricPurgeController.java` (Định tuyến `/api/academic/students/{studentId}/biometric-purge`)
- **Service Layer:**
  - `src/main/java/com/kidpro/domain/student/service/BiometricPurgeService.java`
- **Repository:**
  - `src/main/java/com/kidpro/domain/student/repository/FaceEncodingFileRepository.java`
- **Entity:**
  - `src/main/java/com/kidpro/domain/student/entity/FaceEncodingFile.java`
- **DTOs:**
  - `src/main/java/com/kidpro/domain/student/dto/request/BiometricPurgeConfirmDto.java`
  - `src/main/java/com/kidpro/domain/student/dto/response/BiometricPurgeCertificateDto.java`

### 5. Các file Frontend (FE) liên quan
- **Giao diện trang (Page Component / Tab):**
  - `kidpro-fe/src/pages/parent/tabs/BiometricPurgeDecree13Tab.tsx` (Quy trình xác thực 2FA OTP, cảnh báo pháp lý, cấp chứng thư tiêu hủy PDF)
  - `kidpro-fe/src/pages/parent/ParentPage.tsx`
- **API Service Client:**
  - `kidpro-fe/src/api/parentApi.ts` (`requestBiometricPurgeOtp`, `confirmBiometricPurge`, `getPurgeCertificate`)
- **Type Definitions:**
  - `kidpro-fe/src/types/parent.types.ts` (`BiometricPurgeRequestPayload`, `BiometricPurgeCertificate`)
- **Định tuyến & Menu:**
  - `kidpro-fe/src/config/navigation.config.ts` (Menu: *[Nghị định 13] Xóa Dữ Liệu Sinh Trắc Học*, path: `/parent?tab=biometric-purge`)

### 6. Danh sách API kết nối
| HTTP Method | Endpoint | Chức năng | Request Body / Params | Response |
| :--- | :--- | :--- | :--- | :--- |
| `POST` | `/api/academic/students/{studentId}/biometric-purge/request-otp` | Yêu cầu cấp mã OTP xác thực hủy sinh trắc học | Path: `studentId`, Body: `{ accountPassword }` | `{ success: boolean, message: string }` |
| `POST` | `/api/academic/students/{studentId}/biometric-purge/confirm` | Xác nhận xóa vĩnh viễn dữ liệu theo Nghị định 13 | Path: `studentId`, Body: `BiometricPurgeRequestPayload` (otpCode, reason) | `BiometricPurgeCertificate` (`MSG-251`) |
| `GET` | `/api/academic/students/{studentId}/biometric-purge/certificate` | Tải chứng thư số tiêu hủy dữ liệu PDF | Path: `studentId` | `BiometricPurgeCertificate` |
