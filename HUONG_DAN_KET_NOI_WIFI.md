# HƯỚNG DẪN KẾT NỐI MOBILE APP VỚI BACKEND QUA WI-FI (MÁY THẬT)

Tài liệu hướng dẫn kết nối máy thật (điện thoại Android vật lý) với hệ thống **Spring Boot Backend** (cổng 8080) và **Python AI Face Attendance Engine** (cổng 8000) đang chạy trên laptop qua mạng Wi-Fi cục bộ (LAN).

---

## 1. THÔNG SỐ MẠNG HIỆN TẠI

- **Địa chỉ IP Wi-Fi của máy tính (Laptop/PC):** `192.168.10.51`
- **Spring Boot Backend:** `http://192.168.10.51:8080`
- **Python AI Server (FastAPI):** `http://192.168.10.51:8000`

> ⚠️ **LƯU Ý QUAN TRỌNG:**
> Địa chỉ IP Wi-Fi có thể thay đổi sau mỗi lần máy tính kết nối lại mạng Wi-Fi (trước đó là `.125`, sau đó là `.131`, và hiện tại là **`.51`**).
> Để kiểm tra IP hiện tại bất kỳ lúc nào, mở CMD và gõ: `ipconfig` (xem dòng `IPv4 Address` của `Wireless LAN adapter Wi-Fi`).

---

## 2. NGUYÊN NHÂN GÂY LỖI `connectionError` TRÊN ĐIỆN THOẠI

Khi bấm **"Kiểm tra kết nối"** báo lỗi đỏ:
* `Backend (8080): Không thể kết nối (connectionError)`
* `AI Server (8000): Chưa chạy hoặc bị chặn (connectionError)`

Điều này xuất phát từ **3 nguyên nhân chính**:
1. **Server trên máy tính chưa được khởi động:** Chưa có cửa sổ Spring Boot hay Python AI nào đang chạy để lắng nghe cổng 8080 và 8000.
2. **Sai IP Wi-Fi:** App trên điện thoại đang trỏ vào IP cũ (`.131` hoặc `.125`), trong khi IP hiện tại của máy tính là **`192.168.10.51`**.
3. **Chưa mở Windows Firewall:** Windows Firewall đang chặn các kết nối bên ngoài vào cổng 8080 và 8000.
4. **Điện thoại đang bật 4G hoặc USB Tethering:** Điện thoại không thể gửi dữ liệu đến IP Wi-Fi LAN nếu đang ưu tiên dữ liệu di động hoặc chia sẻ mạng qua cáp.

---

## 3. CÁC BƯỚC KHẮC PHỤC TRIỆT ĐỂ (THỰC HIỆN THEO THỨ TỰ)

### Bước 1: Mở Firewall Windows trên Laptop (Bắt buộc)
1. Vào thư mục `d:\kidpro_app\kidpro-app\`.
2. Nhấp chuột phải vào file **`open-firewall-rules.bat`** -> chọn **"Run as administrator"**.
3. Script sẽ tự động tạo Inbound Rule cho TCP Port 8080 và 8000.

### Bước 2: Khởi động 2 Server trên Laptop
1. Vào thư mục `d:\kidpro_app\kidpro-app\`.
2. Nhấp đúp chuột vào file **`start-all-servers.bat`**.
3. Nhập phím **`1`** và bấm Enter.
4. Hai cửa sổ dòng lệnh màu đen sẽ xuất hiện:
   * **Cửa sổ 1 (Spring Boot Backend):** Chờ khoảng 15-20 giây cho đến khi hiện dòng chữ:
     `Started KidProBackendApplication on port 8080`
   * **Cửa sổ 2 (Python AI Engine):** Chờ cho đến khi hiện dòng chữ:
     `Uvicorn running on http://0.0.0.0:8000`
5. **Giữ nguyên 2 cửa sổ này không được tắt!**

*(Bạn có thể chọn phím `5` trong file `start-all-servers.bat` để kiểm tra xem 2 port 8080 và 8000 đã thực sự ở trạng thái LISTENING chưa)*.

### Bước 3: Cấu hình trên Điện thoại thật
1. Đảm bảo điện thoại **kết nối cùng mạng Wi-Fi** với laptop.
2. **Tắt dữ liệu di động 4G/5G** trên điện thoại (để điện thoại bắt buộc đi qua mạng Wi-Fi).
3. Tắt tính năng "Chia sẻ mạng qua USB / USB Tethering" nếu đang cắm cáp.
4. Mở ứng dụng **KidPro** trên điện thoại:
   * Tại màn hình Đăng nhập, bấm vào dòng: **"Cấu hình IP máy chủ"**.
   * Bấm vào nút chip: **`Wi-Fi LAN (192.168.10.51:8080)`** (hoặc gõ `http://192.168.10.51:8080`).
   * Bấm nút **"Kiểm tra kết nối"**:
     * Cả 2 dòng **Backend (8080)** và **AI Server (8000)** sẽ chuyển sang **MÀU XANH LÁ (OK / ONLINE)**!
   * Bấm nút **"Lưu & Áp dụng"**.
5. Bấm nút **"Giáo Viên"** hoặc **"Phụ Huynh"** để đăng nhập ngay vào app.

---

## 4. GIẢI PHÁP THAY THẾ KHI WI-FI BỊ CÔ LẬP (AP ISOLATION)

Nếu mạng Wi-Fi của bạn (ở trường học, văn phòng hoặc quán cafe) bật chế độ *AP Isolation* (cấm các thiết bị Wi-Fi giao tiếp với nhau):
* **Cách 1: Phát Wi-Fi Hotspot từ điện thoại cho Laptop kết nối vào:**
  * Bật Hotspot trên điện thoại, dùng laptop kết nối vào mạng Hotspot đó.
  * Mở CMD gõ `ipconfig` lấy IP mới và nhập vào app.
* **Cách 2: Dùng Cáp USB (Ổn định 100%, không phụ thuộc Wi-Fi):**
  * Cắm cáp nối điện thoại vào laptop (đã bật USB Debugging).
  * Chạy file `setup-usb-reverse.bat`.
  * Trên màn hình Đăng nhập của App, chọn chip **`USB Cáp (127.0.0.1:8080)`**.
