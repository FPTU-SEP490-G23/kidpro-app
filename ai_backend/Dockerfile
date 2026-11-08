# ==============================================================================
# FastAPI AI Service Dockerfile (Face Recognition & ONNX Runtime)
# ==============================================================================
FROM python:3.11-slim

WORKDIR /app

# Cài đặt các gói thư viện C/C++ bắt buộc cho OpenCV, ONNX Runtime và PyTorch
# Ngăn chặn hoàn toàn lỗi crash runtime: libGL.so.1: cannot open shared object file
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 \
    libglib2.0-0 \
    libgomp1 \
    libsm6 \
    libxext6 \
    libxrender1 \
    build-essential \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

ENV PYTHONUNBUFFERED=1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

