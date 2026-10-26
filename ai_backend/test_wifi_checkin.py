import sys
import requests

sys.stdout.reconfigure(encoding='utf-8')

WIFI_URL = "http://192.168.10.125:8000/api/v1/check-in"
with open("sample_student.jpg", "rb") as f:
    files = {"file": f}
    resp = requests.post(WIFI_URL, files=files)
print("Wi-Fi Checkin Status:", resp.status_code)
print("Wi-Fi Checkin JSON:", resp.json())
