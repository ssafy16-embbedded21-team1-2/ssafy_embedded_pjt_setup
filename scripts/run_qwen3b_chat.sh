#!/usr/bin/env bash
# Raspberry Pi 5 Qwen 2.5 3B 터미널 대화 스크립트

MODEL_PATH="${HOME}/models/qwen2.5-3b-instruct-q4_k_m.gguf"

if [ ! -f "$MODEL_PATH" ]; then
    echo "[!] Model not found at $MODEL_PATH"
    exit 1
fi

echo "=== Alibaba Qwen 2.5 3B Instruct 대화 모드 시작 (Raspberry Pi 5) ==="
echo "종료하려면 /exit 또는 Ctrl+C를 누르세요."
echo ""

llama-cli \
    -m "$MODEL_PATH" \
    -t 4 \
    -c 2048 \
    --temp 0.3 \
    --color auto
