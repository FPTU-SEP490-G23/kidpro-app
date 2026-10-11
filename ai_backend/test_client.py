"""
Script kiểm tra nhanh API Đăng ký và Điểm danh khuôn mặt.
Cách dùng:
  python test_client.py --mode register --id ST001 --name "Bé Nguyễn Minh An" --class "Mầm 1" --image student1.jpg
  python test_client.py --mode checkin --image checkin_photo.jpg
"""

import argparse
import requests

BASE_URL = "http://localhost:8000"

def register(student_id: str, name: str, class_name: str, image_path: str):
    url = f"{BASE_URL}/api/v1/register"
    with open(image_path, "rb") as f:
        files = {"file": f}
        data = {"student_id": student_id, "name": name, "class_name": class_name}
        resp = requests.post(url, data=data, files=files)
    print("Response Status:", resp.status_code)
    print("Response JSON:", resp.json())

def checkin(image_path: str):
    url = f"{BASE_URL}/api/v1/check-in"
    with open(image_path, "rb") as f:
        files = {"file": f}
        resp = requests.post(url, files=files)
    print("Response Status:", resp.status_code)
    print("Response JSON:", resp.json())

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="KidPro Face Attendance Test Client")
    parser.add_argument("--mode", choices=["register", "checkin"], required=True)
    parser.add_argument("--image", required=True, help="Đường dẫn file ảnh")
    parser.add_argument("--id", default="ST001", help="Mã học sinh")
    parser.add_argument("--name", default="Bé Minh An", help="Tên học sinh")
    parser.add_argument("--class", dest="class_name", default="Lớp Chồi 1", help="Tên lớp")

    args = parser.parse_args()

    if args.mode == "register":
        register(args.id, args.name, args.class_name, args.image)
    else:
        checkin(args.image)
