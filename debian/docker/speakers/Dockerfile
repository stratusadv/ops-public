FROM python:3.12-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ffmpeg \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir \
    fastapi==0.142.2 \
    pyannote.audio==4.0.7 \
    python-multipart==0.0.32 \
    uvicorn==0.54.0

WORKDIR /app

COPY app.py .

EXPOSE 8001

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8001"]
