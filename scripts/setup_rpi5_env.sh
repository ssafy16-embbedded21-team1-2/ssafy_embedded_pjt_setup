#!/usr/bin/env bash
# ==============================================================================
# Raspberry Pi 5 - STM32 진단 Agent 환경 자동 구축 스크립트
#
# 설치 항목:
# 1. 시스템 필수 패키지 (build-essential, cmake, git, curl, wget 등)
# 2. 임베디드 디버깅 툴체인 (openocd, gdb-multiarch, stlink-tools, pyocd, udev)
# 3. llama.cpp 빌드 및 시스템 전역 설치 (/usr/local/bin)
# 4. 온디바이스 SLM 모델 다운로드 (Qwen 2.5 3B Instruct, Qwen 3 4B)
# 5. 파이썬 진단 라이브러리 및 CMSIS-DAP 팩 설치
# ==============================================================================

set -eo pipefail

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 기본 설정 디렉터리
MODELS_DIR="${HOME}/models"
SCRIPTS_DIR="${HOME}/scripts"
LLAMA_SRC_DIR="${HOME}/llama.cpp"

# ------------------------------------------------------------------------------
# 0. 사전 점검 (OS, 아키텍처, 용량)
# ------------------------------------------------------------------------------
check_prerequisites() {
    log_info "시스템 사전 환경 점검 중..."
    
    # 아키텍처 확인
    ARCH=$(uname -m)
    if [[ "$ARCH" != "aarch64" ]]; then
        log_warn "현재 아키텍처는 ${ARCH} 입니다. (RPi5 64-bit Debian Bookworm 권장)"
    else
        log_success "64-bit ARM 아키텍처 확인 완료 (${ARCH})"
    fi

    # 디스크 여유 공간 확인 (최소 6GB 권장)
    FREE_KB=$(df -k "$HOME" | awk 'NR==2 {print $4}')
    FREE_GB=$((FREE_KB / 1024 / 1024))
    log_info "홈 디렉터리 여유 공간: 약 ${FREE_GB} GB"
    if (( FREE_GB < 5 )); then
        log_warn "여유 공간이 5GB 미만입니다. 대형 모델 다운로드 시 용량 부족이 발생할 수 있습니다."
    fi
}

# ------------------------------------------------------------------------------
# 1. 시스템 패키지 및 임베디드 툴체인 설치
# ------------------------------------------------------------------------------
install_system_and_embedded_tools() {
    log_info "1/4. 시스템 패키지 및 임베디드 디버깅 툴체인 설치 시작..."

    sudo apt-get update -y
    sudo apt-get install -y \
        build-essential \
        cmake \
        ccache \
        git \
        curl \
        wget \
        pkg-config \
        libssl-dev \
        python3 \
        python3-pip \
        python3-venv \
        python3-serial \
        openocd \
        gdb-multiarch \
        stlink-tools \
        binutils-arm-none-eabi \
        udev

    log_success "APT 패키지 설치 완료."

    # USB 시리얼 및 디버거 권한 설정 (dialout, plugdev)
    log_info "사용자(${USER}) 그룹 권한(dialout, plugdev) 설정 중..."
    sudo usermod -aG dialout,plugdev "$USER"

    # PyOCD 설치
    log_info "PyOCD 설치 및 CMSIS-DAP 팩 설치 중..."
    sudo pip3 install --break-system-packages pyocd pyserial requests fastapi uvicorn

    # PyOCD 타깃 팩 설치 (STM32F1, STM32F4)
    log_info "STM32F1 / STM32F4용 PyOCD DFP 팩 다운로드 중..."
    pyocd pack update || true
    pyocd pack install stm32f1xx || true
    pyocd pack install stm32f4xx || true

    # Udev 규칙 리로드
    sudo udevadm control --reload-rules || true
    sudo udevadm trigger || true

    log_success "임베디드 툴체인(OpenOCD/GDB/pyocd) 및 권한 설정 완료."
}

# ------------------------------------------------------------------------------
# 2. llama.cpp 소스 빌드 및 전역 설치
# ------------------------------------------------------------------------------
build_llama_cpp() {
    log_info "2/4. llama.cpp 빌드 및 설치 시작..."

    if [ -d "$LLAMA_SRC_DIR" ]; then
        log_info "기존 llama.cpp 저장소 업데이트 ($LLAMA_SRC_DIR)..."
        cd "$LLAMA_SRC_DIR"
        git fetch --all
        git checkout master
        git pull || true
    else
        log_info "llama.cpp 저장소 클론 ($LLAMA_SRC_DIR)..."
        git clone https://github.com/ggerganov/llama.cpp.git "$LLAMA_SRC_DIR"
        cd "$LLAMA_SRC_DIR"
    fi

    # RPi5 (Cortex-A76 ARMv8.2-A) 최적화 빌드
    log_info "CMake 설정 및 멀티코어($(nproc) 스레드) 컴파일 진행..."
    cmake -B build -DCMAKE_BUILD_TYPE=Release
    cmake --build build --config Release -j"$(nproc)"

    log_info "시스템 전역 설치 (/usr/local/bin)..."
    sudo cmake --install build

    log_success "llama.cpp 빌드 및 설치 완료: $(llama-cli --version 2>&1 | head -n 1)"
}

# ------------------------------------------------------------------------------
# 3. 온디바이스 SLM 모델 다운로드
# ------------------------------------------------------------------------------
download_models() {
    local target_model="${1:-qwen3b}"
    mkdir -p "$MODELS_DIR"

    # Qwen 2.5 3B Instruct (추천 1순위: 빠른 속도 4.8 t/s, 1.8초 Tool Call 레이턴시)
    local QWEN3B_FILE="qwen2.5-3b-instruct-q4_k_m.gguf"
    local QWEN3B_URL="https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf"

    # Qwen 3 4B (심층 추론 모드 내장 모델: 3.5 t/s)
    local QWEN3_4B_FILE="Qwen3-4B-Q4_K_M.gguf"
    local QWEN3_4B_URL="https://huggingface.co/Qwen/Qwen3-4B-GGUF/resolve/main/Qwen3-4B-Q4_K_M.gguf"

    if [[ "$target_model" == "qwen3b" || "$target_model" == "all" ]]; then
        log_info "3/4. Qwen 2.5 3B Instruct 다운로드 중 (~2.0 GB)..."
        if [ -f "${MODELS_DIR}/${QWEN3B_FILE}" ]; then
            log_success "${QWEN3B_FILE} 이미 존재함. 다운로드를 건너뜁니다."
        else
            curl -L -C - --progress-bar -o "${MODELS_DIR}/${QWEN3B_FILE}" "$QWEN3B_URL"
            log_success "Qwen 2.5 3B 다운로드 완료!"
        fi
    fi

    if [[ "$target_model" == "qwen3_4b" || "$target_model" == "all" ]]; then
        log_info "3/4. Qwen 3 4B 다운로드 중 (~2.4 GB)..."
        if [ -f "${MODELS_DIR}/${QWEN3_4B_FILE}" ]; then
            log_success "${QWEN3_4B_FILE} 이미 존재함. 다운로드를 건너뜁니다."
        else
            curl -L -C - --progress-bar -o "${MODELS_DIR}/${QWEN3_4B_FILE}" "$QWEN3_4B_URL"
            log_success "Qwen 3 4B 다운로드 완료!"
        fi
    fi
}

# ------------------------------------------------------------------------------
# 4. 실행 헬퍼 스크립트 배포
# ------------------------------------------------------------------------------
setup_helper_scripts() {
    log_info "4/4. 실행 헬퍼 스크립트 생성 (${SCRIPTS_DIR})..."
    mkdir -p "$SCRIPTS_DIR"

    # 1) Qwen 2.5 3B CLI 대화 실행기
    cat << 'EOF' > "${SCRIPTS_DIR}/run_qwen3b_chat.sh"
#!/usr/bin/env bash
MODEL_PATH="${HOME}/models/qwen2.5-3b-instruct-q4_k_m.gguf"
if [ ! -f "$MODEL_PATH" ]; then
    echo "[!] 모델 파일이 없습니다: $MODEL_PATH"
    exit 1
fi
echo "=== Alibaba Qwen 2.5 3B Instruct 대화 모드 시작 (RPi5) ==="
echo "종료: /exit 또는 Ctrl+C"
llama-cli -m "$MODEL_PATH" -t 4 -c 2048 --temp 0.3 --color auto
EOF
    chmod +x "${SCRIPTS_DIR}/run_qwen3b_chat.sh"

    # 2) Qwen 2.5 3B OpenAI 호환 API 서버
    cat << 'EOF' > "${SCRIPTS_DIR}/run_qwen3b_server.sh"
#!/usr/bin/env bash
MODEL_PATH="${HOME}/models/qwen2.5-3b-instruct-q4_k_m.gguf"
PORT=8080
if [ ! -f "$MODEL_PATH" ]; then
    echo "[!] 모델 파일이 없습니다: $MODEL_PATH"
    exit 1
fi
echo "=== Qwen 2.5 3B OpenAI 호환 API 서버 시작 ==="
echo "접속 주소: http://$(hostname -I | awk '{print $1}'):${PORT}"
echo "API 엔드포인트: http://$(hostname -I | awk '{print $1}'):${PORT}/v1/chat/completions"
llama-server -m "$MODEL_PATH" --host 0.0.0.0 --port "$PORT" -t 4 -c 2048 --temp 0.3
EOF
    chmod +x "${SCRIPTS_DIR}/run_qwen3b_server.sh"

    # 3) STM32 SWD PoC 검증 스크립트
    cat << 'EOF' > "${SCRIPTS_DIR}/poc_swd_test.py"
#!/usr/bin/env python3
import subprocess

def check():
    print("=== [1] ST-LINK USB 프로브 탐색 (st-info) ===")
    try:
        res = subprocess.run(["st-info", "--probe"], capture_output=True, text=True)
        print(res.stdout if res.stdout.strip() else "[안내] 연결된 ST-LINK 보드가 없습니다.")
    except Exception as e:
        print(f"[오류] st-info 실행 실패: {e}")

    print("\n=== [2] PyOCD 타겟 탐색 (pyocd list) ===")
    try:
        res = subprocess.run(["pyocd", "list"], capture_output=True, text=True)
        print(res.stdout if res.stdout else res.stderr)
    except Exception as e:
        print(f"[오류] pyocd list 실패: {e}")

    print("\n=== [3] OpenOCD 레지스터 덤프 권장 명령어 ===")
    print("# STM32F1 (Nucleo-F103):")
    print("openocd -f interface/stlink.cfg -c 'transport select swd' -f target/stm32f1x.cfg -c 'init; reset halt; reg; resume; exit'")
    print("# STM32F4 (Nucleo-F401/F411/F446):")
    print("openocd -f interface/stlink.cfg -c 'transport select swd' -f target/stm32f4x.cfg -c 'init; reset halt; reg; resume; exit'")

if __name__ == "__main__":
    check()
EOF
    chmod +x "${SCRIPTS_DIR}/poc_swd_test.py"

    log_success "헬퍼 스크립트 배포 완료 (${SCRIPTS_DIR})"
}

# ------------------------------------------------------------------------------
# 5. 설치 검증 (Verify)
# ------------------------------------------------------------------------------
verify_installation() {
    echo ""
    log_info "=========================================================="
    log_info "               설치 상태 종합 검증 결과                   "
    log_info "=========================================================="

    check_cmd() {
        if command -v "$1" >/dev/null 2>&1; then
            echo -e "  [✔] $1 : $(which $1)"
        else
            echo -e "  [✘] $1 : 설치되지 않음"
        fi
    }

    echo "▶ 1. CLI 바이너리 확인:"
    check_cmd llama-cli
    check_cmd llama-server
    check_cmd openocd
    check_cmd gdb-multiarch
    check_cmd st-info
    check_cmd pyocd
    check_cmd arm-none-eabi-addr2line

    echo ""
    echo "▶ 2. 모델 파일 확인 (${MODELS_DIR}):"
    ls -lh "$MODELS_DIR" 2>/dev/null || echo "  모델 디렉터리가 비어있습니다."

    echo ""
    echo "▶ 3. 사용자 그룹 권한 (plugdev / dialout):"
    id | grep -E 'plugdev|dialout' --color=always || log_warn "재로그인해야 dialout/plugdev 그룹 권한이 반영됩니다."

    echo ""
    echo "▶ 4. ST-LINK USB 연결 상태:"
    st-info --probe 2>/dev/null || echo "  (연결된 ST-LINK 없음 또는 권한 필요)"

    echo ""
    log_success "검증 완료! 필요 시 1회 재로그인('exit' 후 재접속)하여 그룹 권한을 갱신하세요."
}

# ------------------------------------------------------------------------------
# CLI 옵션 파싱
# ------------------------------------------------------------------------------
usage() {
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  --all              전체 설치 (도구 + llama.cpp + Qwen 2.5 3B 모델 + 스크립트 + 검증)"
    echo "  --tools            임베디드 툴체인만 설치 (OpenOCD, GDB, stlink, pyocd, udev)"
    echo "  --llama            llama.cpp만 빌드 및 전역 설치 (/usr/local/bin)"
    echo "  --model [TYPE]     모델 다운로드 ('qwen3b'(기본값), 'qwen3_4b', 'all')"
    echo "  --scripts          헬퍼 스크립트만 배포 (~/scripts)"
    echo "  --verify           현재 설치 상태 검증"
    echo "  -h, --help         도움말 출력"
    exit 0
}

case "$1" in
    --all)
        check_prerequisites
        install_system_and_embedded_tools
        build_llama_cpp
        download_models "qwen3b"
        setup_helper_scripts
        verify_installation
        ;;
    --tools)
        check_prerequisites
        install_system_and_embedded_tools
        ;;
    --llama)
        build_llama_cpp
        ;;
    --model)
        download_models "${2:-qwen3b}"
        ;;
    --scripts)
        setup_helper_scripts
        ;;
    --verify)
        verify_installation
        ;;
    -h|--help|"")
        usage
        ;;
    *)
        log_error "알 수 없는 옵션: $1"
        usage
        ;;
esac
