# Raspberry Pi 5 진단 Agent 및 온디바이스 SLM 자동 환경 구축 가이드

본 문서는 다른 새로운 **Raspberry Pi 5 (4GB / 8GB)** 환경에서 다음 소프트웨어 스택을 빠르고 간편하게 구축할 수 있도록 제작된 설치 가이드입니다:
1. **llama.cpp**: ARM Cortex-A76 최적화 네이티브 빌드 및 전역 바이너리 설치 (`llama-cli`, `llama-server`)
2. **온디바이스 SLM 모델**: 추천 1순위 **Qwen 2.5 3B Instruct** (2.0GB) 및 **Qwen 3 4B** (2.4GB)
3. **임베디드 진단 툴체인**: OpenOCD (SWD 최적화), GDB Multiarch, stlink-tools, addr2line
4. **Python 임베디드 툴**: PyOCD (STM32F1/F4 타깃 팩 포함), pyserial, udev 권한 자동 설정

---

## 1. 사전 준비 사항 (Prerequisites)

- **하드웨어**: Raspberry Pi 5 (4GB 또는 8GB 권장)
- **운영체제**: Raspberry Pi OS 64-bit (Debian 12 Bookworm, aarch64)
- **디스크 여유 공간**: 최소 **6GB 이상** (SLM 모델 약 2.0\~2.4GB + 빌드 도구)
- **인터넷 연결**: GitHub, APT 레포지토리 및 Hugging Face 모델 다운로드 가능 환경

---

## 2. 초간단 1줄 자동 설치 (One-Line Quick Setup)

신규 라즈베리파이 5 터미널에서 다음 명령어를 실행하면 모든 환경이 전자동으로 구축됩니다:

```bash
# 1) 작업 폴더 및 스크립트 복사 (저장소 클론 또는 파일 복사)
git clone <저장소_URL> ~/ssafy_embedded_pjt_setup
cd ~/ssafy_embedded_pjt_setup/scripts

# 2) 전체 자동 설치 실행 (시스템 도구 + 툴체인 + llama.cpp + Qwen 2.5 3B + udev 설정)
chmod +x setup_rpi5_env.sh
./setup_rpi5_env.sh --all
```

> [!TIP]
> 설치 완료 후 `udev` 및 시리얼 포트 접근 권한(`dialout`, `plugdev`)을 시스템에 완전히 적용하기 위해 **1회 로그아웃 후 재접속(`exit`)**하는 것을 권장합니다.

---

## 3. `setup_rpi5_env.sh` 옵션별 개별 실행

필요에 따라 특정 컴포넌트만 선택하여 설치할 수 있습니다:

| 실행 옵션 | 설명 | 소요 시간 |
|:---|:---|:---:|
| `./setup_rpi5_env.sh --all` | 시스템 패키지, 임베디드 툴, llama.cpp, Qwen 2.5 3B 모델, 스크립트 배포 및 검증 | 약 5\~8분 |
| `./setup_rpi5_env.sh --tools` | OpenOCD, GDB-multiarch, stlink-tools, PyOCD, CMSIS-DAP 팩, udev 권한 설정만 설치 | 약 1\~2분 |
| `./setup_rpi5_env.sh --llama` | llama.cpp 소스 클론, Cortex-A76 멀티코어 최적화 컴파일, `/usr/local/bin` 전역 설치 | 약 3\~4분 |
| `./setup_rpi5_env.sh --model qwen3b` | **Qwen 2.5 3B Instruct** (`Q4_K_M`, ~2.0GB) 다운로드 (추천 1순위) | 네트워크 속도 의존 |
| `./setup_rpi5_env.sh --model qwen3_4b` | **Qwen 3 4B** (`Q4_K_M`, ~2.4GB) 다운로드 (심층 추론 모드) | 네트워크 속도 의존 |
| `./setup_rpi5_env.sh --model all` | 3B 및 4B 모델 2종 모두 다운로드 (~4.4GB) | 네트워크 속도 의존 |
| `./setup_rpi5_env.sh --scripts` | `~/scripts` 폴더에 대화/서버/SWD 검증 헬퍼 스크립트 배포 | 1초 |
| `./setup_rpi5_env.sh --verify` | 현재 시스템의 바이너리, 모델, udev 권한, ST-Link USB 인식 상태를 종합 진단 | 2초 |

---

## 4. 수동 설치 절차 상세 안내 (Manual Setup Breakdown)

스크립트 대신 각 단계를 수동으로 직접 수행하고자 할 경우의 상세 명령어입니다.

### 단계 1: 시스템 필수 패키지 및 임베디드 툴체인 설치
```bash
sudo apt-get update -y
sudo apt-get install -y \
    build-essential cmake ccache git curl wget pkg-config libssl-dev \
    python3 python3-pip python3-venv python3-serial \
    openocd gdb-multiarch stlink-tools binutils-arm-none-eabi udev

# 시리얼 및 USB 프로브 접근 권한 추가
sudo usermod -aG dialout,plugdev $USER
```

### 단계 2: PyOCD 및 STM32 CMSIS-DAP 팩 설치
```bash
sudo pip3 install --break-system-packages pyocd pyserial requests fastapi uvicorn

# STM32F1 (Nucleo-F103) 및 STM32F4 (Nucleo-F401/F411/F446) 타깃 팩 설치
pyocd pack update
pyocd pack install stm32f1xx
pyocd pack install stm32f4xx

# udev 규칙 새로고침
sudo udevadm control --reload-rules
sudo udevadm trigger
```

### 단계 3: llama.cpp 빌드 및 전역 설치
```bash
cd ~
git clone https://github.com/ggerganov/llama.cpp.git
cd llama.cpp

# Cortex-A76 ARMv8.2-A 멀티스레드 최적화 빌드
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -j$(nproc)

# 시스템 전역(/usr/local/bin) 설치 (llama-cli, llama-server 등록)
sudo cmake --install build
```

### 단계 4: 추천 경량 모델 다운로드 (`~/models`)
```bash
mkdir -p ~/models
cd ~/models

# [추천 1순위] Qwen 2.5 3B Instruct (4.8 t/s, 1.8초 Tool Call 응답, 일상 대화 및 진단 Agent 최적)
curl -L -C - --progress-bar -o qwen2.5-3b-instruct-q4_k_m.gguf \
    https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf
```

---

## 5. 설치 후 정상 동작 검증 방법

### 1) 통합 환경 자동 진단
```bash
~/scripts/setup_rpi5_env.sh --verify
```
정상적인 경우 모든 항목에 `[✔]` 표시가 출력되고, USB에 ST-Link 보드가 연결되어 있으면 인식된 칩 정보가 표시됩니다.

### 2) ST-LINK 프로브 및 STM32 보드 인식 확인
```bash
st-info --probe
```
**출력 예시:**
```text
Found 1 stlink programmers
  version:    V2J47S34
  serial:     066AFF545052836687064157
  flash:      131072 (pagesize: 1024)
  sram:       20480
  chipid:     0x410
  dev-type:   STM32F1xx_MD
```

### 3) OpenOCD 경고 없는 레지스터 덤프 테스트
타깃 MCU의 종류에 따라 스크립트를 구분하여 실행합니다:

- **STM32F1 계열 (예: Nucleo-F103RB, Cortex-M3)**:
  ```bash
  openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f1x.cfg \
          -c "init; reset halt; reg; resume; exit"
  ```
- **STM32F4 계열 (예: Nucleo-F401RE, Nucleo-F446RE, Cortex-M4)**:
  ```bash
  openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f4x.cfg \
          -c "init; reset halt; reg; resume; exit"
  ```

### 4) 온디바이스 SLM 구동 테스트 (터미널 대화)
```bash
~/scripts/run_qwen3b_chat.sh
```
또는 백그라운드 API 서버 모드로 실행:
```bash
~/scripts/run_qwen3b_server.sh
# 포트 8080에서 OpenAI 호환 /v1/chat/completions API 및 Web UI 제공
```

---

## 6. 트러블슈팅 (자주 발생하는 문제 및 해결책)

### Q1. `Warn : DEPRECATED: auto-selecting transport "swd (dapdirect)"` 경고가 뜹니다.
- **해결책**: OpenOCD v0.12 이상에서는 `interface/stlink.cfg` 뒤에 명시적으로 `-c "transport select swd"`를 선언해야 합니다.

### Q2. `Warn : target was in unknown state when halt was requested` 경고가 뜹니다.
- **해결책**: MCU가 런타임에 자유 실행 중일 때 강제 `halt`하면 발생하는 일반적인 경고입니다. 리셋 신호와 연동하여 멈추는 `init; reset halt;` 명령어를 사용하면 경고 없이 즉각 정지됩니다.

### Q3. `[stm32f4x.cpu] Cortex-M3 r1p1 processor detected` 메시지가 뜹니다.
- **해결책**: 실제 연결된 보드가 STM32F4가 아니라 **STM32F1 계열(Cortex-M3)**입니다. `target/stm32f4x.cfg` 대신 **`target/stm32f1x.cfg`**를 지정해 주세요.

### Q4. `st-info --probe` 또는 `openocd` 실행 시 권한 오류(`Permission denied`)가 발생합니다.
- **해결책**:
  ```bash
  sudo usermod -aG dialout,plugdev $USER
  sudo udevadm control --reload-rules && sudo udevadm trigger
  ```
  명령 후 터미널 세션을 닫고 다시 로그인(`exit`)해야 새 그룹 권한이 적용됩니다.

---

## 7. 네트워크 연결 및 기기별 Tailscale IP 가이드

Tailscale을 사용하면 별도의 포트포워딩이나 공유기 설정 없이 전 세계 어디서든 안전하게 RPi5에 접속할 수 있습니다. 단, **각 라즈베리파이마다 고유한 `100.x.y.z` 가상 사설 IP가 각각 다르게 부여**됩니다.

### 1) RPi5에 Tailscale 설치 및 로그인 (신규 보드인 경우)
```bash
# Tailscale 간편 설치
curl -fsSL https://tailscale.com/install.sh | sh

# Tailscale 시작 및 계정 인증 (콘솔에 출력되는 웹 링크를 브라우저에서 열어 로그인)
sudo tailscale up

# 부팅 시 자동 실행 활성화
sudo systemctl enable --now tailscaled
```

### 2) 내 라즈베리파이의 고유 Tailscale IP 확인
```bash
tailscale ip -4
# 예: 100.92.169.70 (기기마다 숫자가 다릅니다)
```

### 3) 호스트 PC(개발자 PC)에서 접속하기
호스트 PC에도 Tailscale이 켜져 있어야 합니다.

- **PowerShell 유틸리티(`utils/ssh_rpi.ps1`) 활용**:
  - 임시 지정 접속:
    ```powershell
    $env:RPI_HOST = "100.x.y.z"
    .\utils\ssh_rpi.ps1
    ```
  - 기본 IP로 고정: `utils/ssh_rpi.ps1` 상단의 `$DEFAULT_HOST`를 해당 RPi의 IP로 수정
- **표준 SSH 접속**:
  ```bash
  ssh pi@100.x.y.z
  ```

### 4) Tailscale 미사용 / 오프라인 환경 대체 접속법
- **USB-C 케이블 직결 (USB Gadget 이더넷)**: PC와 RPi를 USB-C 케이블로 직접 연결했을 때의 고정 IP는 `10.12.194.1`입니다.
  ```powershell
  $env:RPI_HOST = "10.12.194.1"
  .\utils\ssh_rpi.ps1
  ```
- **로컬 Wi-Fi 공유기 접속**: 같은 공유기에 접속된 경우 `hostname -I`로 확인한 사설 IP(예: `192.168.0.x`)나 mDNS 주소(`raspberrypi.local`)로 접속 가능합니다.

