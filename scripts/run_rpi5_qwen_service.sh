#!/usr/bin/env bash
# systemd 전용: 로컬 호스트와 Docker 기본 브리지에서만 Qwen API를 제공합니다.
set -euo pipefail

model_path="${LLAMA_MODEL:-${HOME}/models/qwen2.5-3b-instruct-q4_k_m.gguf}"
llama_binary="${LLAMA_BINARY:-/usr/local/bin/llama-server}"

if [[ ! -r "$model_path" || ! -x "$llama_binary" ]]; then
    echo "Qwen 모델 또는 llama-server를 읽거나 실행할 수 없습니다." >&2
    exit 1
fi

docker_gateway=$(docker --host unix:///var/run/docker.sock network inspect bridge \
    --format '{{(index .IPAM.Config 0).Gateway}}')
if [[ ! "$docker_gateway" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    echo "Docker 기본 브리지의 IPv4 게이트웨이를 확인할 수 없습니다: ${docker_gateway}" >&2
    exit 1
fi

echo "Qwen API listen addresses: 127.0.0.1,${docker_gateway}:8080"
exec "$llama_binary" \
    -m "$model_path" \
    --host "127.0.0.1,${docker_gateway}" \
    --port 8080 \
    --alias local-qwen \
    -t 4 -c 2048 --parallel 1 --temp 0.2
