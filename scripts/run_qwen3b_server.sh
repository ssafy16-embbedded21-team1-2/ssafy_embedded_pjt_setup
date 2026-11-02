#!/usr/bin/env bash
# Raspberry Pi 5 Qwen 2.5 3B Web UI 및 OpenAI 호환 API 서버 스크립트

MODEL_PATH="${HOME}/models/qwen2.5-3b-instruct-q4_k_m.gguf"
PORT=8080

if [ ! -f "$MODEL_PATH" ]; then
    echo "[!] Model not found at $MODEL_PATH"
    exit 1
fi

echo "=== Alibaba Qwen 2.5 3B Web 서버 시작 ==="
echo "접속 URL: http://$(hostname -I | awk '{print $1}'):${PORT}"
echo "API 엔드포인트: http://$(hostname -I | awk '{print $1}'):${PORT}/v1/chat/completions"
echo ""

llama-server \
    -m "$MODEL_PATH" \
    --host 0.0.0.0 \
    --port "$PORT" \
    -t 4 \
    -c 2048 \
    --temp 0.3
