#!/usr/bin/env bash
# Raspberry Pi 5 Qwen 3 4B 터미널 대화 스크립트

MODEL_PATH="${HOME}/models/Qwen3-4B-Q4_K_M.gguf"

if [ ! -f "$MODEL_PATH" ]; then
    echo "[!] Model not found at $MODEL_PATH"
    exit 1
fi

echo "=== Alibaba Qwen 3 4B (Thinking Mode) 대화 모드 시작 (Raspberry Pi 5) ==="
echo "종료하려면 /exit 또는 Ctrl+C를 누르세요."
echo ""

llama-cli \
    -m "$MODEL_PATH" \
    -t 4 \
    -c 2048 \
    -n 512 \
    --temp 0.3 \
    --color auto
