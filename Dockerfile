FROM python:3.11-slim

# OpenCV/YOLO가 필요로 하는 OS 라이브러리
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 파이썬 의존성 설치
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# 앱 소스(필요 최소만)
COPY main.py .

# Cloudtype이 주입하는 포트 사용(없으면 8000)
ENV PORT=8000
EXPOSE 8000

# FastAPI 실행 (Cloudtype Health Check 경로는 아래에서 / 로 설정)
CMD sh -lc 'uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}'
