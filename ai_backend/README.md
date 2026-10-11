# HƯỚNG DẪN CHẠY DEMO ĐIỂM DANH KHUÔN MẶT AI (KIDPRO POC)

Hệ thống PoC gồm 2 thành phần chính:
1. **AI Backend Server (Python FastAPI + InsightFace `buffalo_sc`)**: Chạy trực tiếp trên Laptop (tối ưu CPU).
2. **Mobile Client (Flutter / Android CameraX)**: Cài đặt trên điện thoại Android, kết nối qua mạng Wi-Fi LAN nội bộ với Laptop.

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
```bash
python main.py
# Hoặc chạy trực tiếp với uvicorn:
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```
*Lưu ý:* Tham số `--host 0.0.0.0` là bắt buộc để điện thoại Android cùng mạng Wi-Fi có thể gọi được vào Laptop.

Lần đầu chạy, InsightFace sẽ tự động tải model `buffalo_sc` (~150MB) từ CDN về thư mục `~/.insightface/models/`.

### 3. Kiểm tra Server hoạt động
- Mở trình duyệt trên Laptop truy cập: [http://localhost:8000/docs](http://localhost:8000/docs) (Swagger UI)
- Hoặc mở trực tiếp file `web_demo.html` trên trình duyệt để thử nghiệm quét khuôn mặt qua Webcam Laptop ngay lập tức.

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
3. Như vậy, địa chỉ Base URL cho điện thoại Android sẽ là:
   `http://192.168.1.15:8000`

*(Lưu ý: Nếu không kết nối được từ điện thoại, tạm thời tắt Windows Defender Firewall cho mạng Private hoặc mở port 8000 inbound).*

---

## BƯỚC 3: ĐĂNG KÝ KHUÔN MẶT HỌC SINH MẪU

Bạn có thể đăng ký khuôn mặt học sinh bằng 1 trong 3 cách:

### Cách A: Dùng Web Demo trên Laptop (Nhanh nhất)
Mở file `D:\kidpro_dt\ai_backend\web_demo.html` trên trình duyệt:
1. Nhập Mã học sinh (`HS001`), Tên (`Bé Nguyễn Minh An`), Lớp (`Mầm 1`).
2. Bấm nút **"📸 Chụp từ Camera hiện tại"** hoặc tải file ảnh chân dung.
3. Bấm **"Lưu & Trích xuất Vector AI (512-dim)"**.

### Cách B: Dùng Swagger UI
Truy cập `http://localhost:8000/docs` -> Chọn endpoint `POST /api/v1/register` -> Bấm *Try it out* -> Điền thông tin và chọn file ảnh -> Bấm *Execute*.

### Cách C: Dùng script Python test
```bash
python test_client.py --mode register --id "HS001" --name "Bé Nguyễn Minh An" --class "Mầm 1" --image "sample_face.jpg"
```

---

## BƯỚC 4: CHẠY MOBILE CLIENT TRÊN ĐIỆN THOẠI ANDROID

### Lựa chọn 1: Dùng Flutter App (`kidpro_mobile`)
1. Cấu hình IP LAN trong file hoặc bấm icon bánh răng cấu hình góc trên màn hình:
   - Điền URL: `http://192.168.1.15:8000` (hoặc `http://10.0.2.2:8000` nếu chạy Android Emulator).
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
