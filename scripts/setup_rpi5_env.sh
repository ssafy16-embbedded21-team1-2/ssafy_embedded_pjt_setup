#!/usr/bin/env bash
# ==============================================================================
# Raspberry Pi 5 - STM32 진단 Agent 환경 자동 구축 스크립트
#
# 설치 항목:
# 1. 시스템 필수 패키지 (build-essential, cmake, git, curl, wget 등)
# 2. 임베디드 디버깅 툴체인 (openocd, gdb-multiarch, stlink-tools, pyocd, udev)
# 3. llama.cpp 빌드 및 시스템 전역 설치 (/usr/local/bin)
# 4. 온디바이스 SLM 모델 다운로드 (Qwen 2.5 3B Instruct, Qwen 3 4B)
# 5. 파이썬 진단 라이브러리 및 CMSIS Device Family Pack (DFP) 설치
# 6. Docker Engine, Compose / Buildx 플러그인 및 사용자 권한 설정
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
        log_warn "현재 아키텍처는 ${ARCH} 입니다. (RPi5 64-bit Debian Bookworm / Trixie 대상)"
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
    log_info "시스템 패키지 및 임베디드 디버깅 툴체인 설치 시작..."

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
    log_info "PyOCD 설치 및 CMSIS Device Family Pack (DFP) 설치 중..."
    sudo pip3 install --break-system-packages pyocd pyserial requests fastapi uvicorn

    install_pyocd_targets
    # 기존 STM32F4 예제용 지원도 유지합니다. 검색 인자는 팩 이름이 아닌 MCU 부품명입니다.
    pyocd pack install stm32f401re

    # Udev 규칙 리로드
    sudo udevadm control --reload-rules || true
    sudo udevadm trigger || true

    log_success "임베디드 툴체인(OpenOCD/GDB/pyocd) 및 권한 설정 완료."
}

# ------------------------------------------------------------------------------
# NUCLEO-F103RB / NUCLEO-G474RE 전용 PyOCD 타깃
# ------------------------------------------------------------------------------
install_pyocd_targets() {
    if ! command -v pyocd >/dev/null 2>&1; then
        log_error "PyOCD가 없습니다. 먼저 --tools로 설치하세요."
        return 1
    fi
    log_info "STM32F103RB / STM32G474RE용 PyOCD 타깃 팩 설치 중..."
    # pack install은 MCU 부품명을 검색합니다. stm32f1xx 같은 팩 이름은 사용하지 않습니다.
    pyocd pack install stm32f103rb
    pyocd pack install stm32g474re
    verify_pyocd_targets
}

verify_pyocd_targets() {
    if ! command -v pyocd >/dev/null 2>&1; then
        log_error "PyOCD가 없습니다. --tools로 설치하세요."
        return 1
    fi
    local target_list
    target_list=$(pyocd list --targets) || return 1
    local target
    local missing=0
    # G474RE의 현재 DFP 타깃 이름에는 패키지 접미사 tx가 붙습니다.
    for target in stm32f103rb stm32g474retx; do
        if awk -v target="$target" '$1 == target {found=1} END {exit !found}' <<< "$target_list"; then
            log_success "PyOCD 전용 타깃 사용 가능: ${target}"
        else
            log_error "PyOCD 전용 타깃 없음: ${target}. --targets로 설치하세요."
            missing=1
        fi
    done
    return "$missing"
}

# ------------------------------------------------------------------------------
# Docker Engine 및 Compose 설치 (Debian 기반 Raspberry Pi OS 64-bit)
# ------------------------------------------------------------------------------
package_installed() {
    [[ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" == "install ok installed" ]]
}

install_docker() {
    log_info "Docker Engine / Compose / Buildx 설치 시작..."

    local ID VERSION_CODENAME
    # shellcheck source=/dev/null
    . /etc/os-release
    local docker_arch
    docker_arch=$(dpkg --print-architecture)
    if [[ "${ID:-}" != "debian" && "${ID:-}" != "raspbian" ]] || \
       [[ "$docker_arch" != "arm64" ]] || \
       [[ "${VERSION_CODENAME:-}" != "bookworm" && "${VERSION_CODENAME:-}" != "trixie" ]]; then
        log_error "Docker 자동 설치 대상은 Debian / Raspberry Pi OS 12·13 (bookworm·trixie), arm64입니다."
        return 1
    fi
    if [[ ! -d /run/systemd/system ]]; then
        log_error "systemd로 부팅한 Raspberry Pi OS에서 실행하세요."
        return 1
    fi

    local package
    local conflicts=()
    for package in docker.io docker-compose docker-doc docker-buildx podman-docker containerd runc; do
        if package_installed "$package"; then
            conflicts+=("$package")
        fi
    done
    if (( ${#conflicts[@]} > 0 )); then
        log_error "Docker 공식 패키지와 충돌하는 패키지: ${conflicts[*]}"
        log_error "기존 컨테이너와 의존 서비스를 확인한 뒤 충돌 패키지를 수동 정리하고 --docker를 다시 실행하세요."
        return 1
    fi

    local packages=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
    local missing=()
    for package in "${packages[@]}"; do
        if ! package_installed "$package"; then
            missing+=("$package")
        fi
    done

    if (( ${#missing[@]} == 0 )); then
        log_info "공식 Docker 패키지가 모두 설치되어 있어 기존 버전을 사용합니다."
    else
        sudo apt-get update -y
        sudo apt-get install -y ca-certificates curl

        # 기존 공식 저장소(.list / .sources)가 있으면 중복 등록하지 않습니다.
        if grep -qsE '^[[:space:]]*(deb[[:space:]]|URIs:).*https://download\.docker\.com/linux/debian' \
            /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; then
            log_info "기존 Docker 공식 APT 저장소 설정을 사용합니다."
        else
            if [[ -e /etc/apt/sources.list.d/docker.sources ]]; then
                log_error "/etc/apt/sources.list.d/docker.sources의 기존 설정을 확인하세요. 자동으로 덮어쓰지 않습니다."
                return 1
            fi
            sudo install -m 0755 -d /etc/apt/keyrings
            sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
            sudo chmod a+r /etc/apt/keyrings/docker.asc
            sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: ${VERSION_CODENAME}
Components: stable
Architectures: ${docker_arch}
Signed-By: /etc/apt/keyrings/docker.asc
EOF
        fi
        sudo apt-get update -y
        # 누락된 패키지만 설치하여 기존 Engine의 불필요한 업그레이드를 피합니다.
        sudo apt-get install -y --no-remove "${missing[@]}"
    fi

    sudo systemctl enable --now docker.service containerd.service
    local docker_user="${SUDO_USER:-$(id -un)}"
    if ! getent group docker >/dev/null; then
        sudo groupadd docker
    fi
    if [[ "$docker_user" != "root" ]]; then
        sudo usermod -aG docker "$docker_user"
        log_warn "docker 그룹은 root 수준 권한을 제공합니다. ${docker_user} 사용자는 로그아웃 후 재접속하세요."
    fi

    # 현재 세션에는 새 그룹이 반영되지 않으므로 설치 직후 확인은 sudo로 수행합니다.
    verify_docker_installation sudo
    log_success "Docker 설치 완료. 재접속 후 'docker run --rm hello-world'로 컨테이너 실행을 확인하세요."
}

verify_docker_installation() {
    local docker_cmd=(docker --host unix:///var/run/docker.sock)
    if [[ "${1:-}" == "sudo" ]]; then
        docker_cmd=(sudo "${docker_cmd[@]}")
    fi
    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker가 없습니다. --docker로 설치하세요."
        return 1
    fi
    "${docker_cmd[@]}" --version || return 1
    "${docker_cmd[@]}" compose version || return 1
    "${docker_cmd[@]}" buildx version || return 1
    if ! systemctl is-active --quiet docker.service; then
        log_error "Docker 서비스가 실행 중이 아닙니다. sudo systemctl start docker를 확인하세요."
        return 1
    fi
    local docker_capabilities
    if ! docker_capabilities=$("${docker_cmd[@]}" info --format 'memory={{.MemoryLimit}} swap={{.SwapLimit}}'); then
        log_error "로컬 Docker 데몬에 접근할 수 없습니다. 재로그인 후 권한과 docker 서비스 상태를 확인하세요."
        return 1
    fi
    log_success "Docker 데몬 연결 정상: ${docker_capabilities}"
    if [[ "$docker_capabilities" == *"memory=false"* ]]; then
        log_warn "커널이 Docker 메모리 제한을 지원하지 않습니다. Compose의 mem_limit이 적용되지 않을 수 있습니다."
        log_warn "가이드의 cgroup 점검 절차를 확인하세요. 부팅 설정 변경이나 재부팅은 자동 수행하지 않습니다."
    fi
    if [[ "$docker_capabilities" == *"swap=false"* ]]; then
        log_warn "커널이 컨테이너 swap 제한을 지원하지 않습니다."
    fi
}

# ------------------------------------------------------------------------------
# 2. llama.cpp 소스 빌드 및 전역 설치
# ------------------------------------------------------------------------------
build_llama_cpp() {
    log_info "llama.cpp 빌드 및 설치 시작..."

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
        log_info "Qwen 2.5 3B Instruct 다운로드 중 (~2.0 GB)..."
        if [ -f "${MODELS_DIR}/${QWEN3B_FILE}" ]; then
            log_success "${QWEN3B_FILE} 이미 존재함. 다운로드를 건너뜁니다."
        else
            curl -L -C - --progress-bar -o "${MODELS_DIR}/${QWEN3B_FILE}" "$QWEN3B_URL"
            log_success "Qwen 2.5 3B 다운로드 완료!"
        fi
    fi

    if [[ "$target_model" == "qwen3_4b" || "$target_model" == "all" ]]; then
        log_info "Qwen 3 4B 다운로드 중 (~2.4 GB)..."
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
    log_info "실행 헬퍼 스크립트 생성 (${SCRIPTS_DIR})..."
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
    echo "▶ 5. Docker Engine / Compose / Buildx 및 리소스 제한 지원:"
    verify_docker_installation || log_warn "Docker 점검 실패. 위 오류를 해결한 후 --verify를 다시 실행하세요."

    echo ""
    echo "▶ 6. NUCLEO-F103RB / NUCLEO-G474RE 전용 PyOCD 타깃:"
    verify_pyocd_targets || log_warn "PyOCD 타깃 점검 실패. --targets로 팩 설치 후 다시 확인하세요."

    echo ""
    log_info "점검 종료. 위 오류·경고를 확인하고, 그룹 권한 변경 후에는 재로그인하세요."
}

# ------------------------------------------------------------------------------
# CLI 옵션 파싱
# ------------------------------------------------------------------------------
usage() {
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  --all              전체 설치 (Docker + 도구 + llama.cpp + Qwen 2.5 3B 모델 + 스크립트 + 검증)"
    echo "  --docker           Docker Engine + Compose / Buildx + docker 그룹 설정"
    echo "  --tools            임베디드 툴체인만 설치 (OpenOCD, GDB, stlink, pyocd, udev)"
    echo "  --targets          기존 PyOCD에 F103RB / G474RE 타깃 팩만 설치·검증"
    echo "  --llama            llama.cpp만 빌드 및 전역 설치 (/usr/local/bin)"
    echo "  --model [TYPE]     모델 다운로드 ('qwen3b'(기본값), 'qwen3_4b', 'all')"
    echo "  --scripts          헬퍼 스크립트만 배포 (~/scripts)"
    echo "  --verify           현재 설치 상태 검증"
    echo "  -h, --help         도움말 출력"
    exit 0
}

case "${1:-}" in
    --all)
        check_prerequisites
        install_docker
        install_system_and_embedded_tools
        build_llama_cpp
        download_models "qwen3b"
        setup_helper_scripts
        verify_installation
        ;;
    --docker)
        check_prerequisites
        install_docker
        ;;
    --tools)
        check_prerequisites
        install_system_and_embedded_tools
        ;;
    --targets)
        install_pyocd_targets
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
