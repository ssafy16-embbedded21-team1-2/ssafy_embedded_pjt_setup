# Raspberry Pi 5 진단 Agent 및 온디바이스 SLM 자동 환경 구축 가이드

본 문서는 다른 새로운 **Raspberry Pi 5 (4GB / 8GB)** 환경에서 다음 소프트웨어 스택을 빠르고 간편하게 구축할 수 있도록 제작된 설치 가이드입니다:

1. **llama.cpp**: ARM Cortex-A76 최적화 네이티브 빌드 및 전역 바이너리 설치 (`llama-cli`, `llama-server`)
2. **온디바이스 SLM 모델**: 추천 1순위 **Qwen 2.5 3B Instruct** (2.0GB) 및 **Qwen 3 4B** (2.4GB)
3. **임베디드 진단 툴체인**: OpenOCD (SWD 최적화), GDB Multiarch, stlink-tools, addr2line
4. **Python 임베디드 툴**: PyOCD (NUCLEO-F103RB / NUCLEO-G474RE 및 기존 STM32F4 예제용 타깃 팩), pyserial, udev 권한 자동 설정
5. **Docker 실행 환경**: Docker Engine, Compose 및 Buildx 플러그인, 서비스 자동 시작 및 `docker` 그룹 설정

Docker는 진단 Agent 컨테이너 실행용이며, `llama.cpp`와 모델은 기존처럼 RPi 호스트에 설치합니다. 이 스크립트는 Docker 실행 환경까지 준비하며, Agent 저장소의 클론과 `docker compose up`은 해당 저장소의 안내에 따라 별도로 수행합니다.

---

## 1. 사전 준비 사항 (Prerequisites)

- **하드웨어**: Raspberry Pi 5 (4GB 또는 8GB 권장)
- **운영체제**: Raspberry Pi OS 64-bit / Debian 12 Bookworm 또는 13 Trixie (`aarch64` / `arm64`), systemd 사용 환경
- **디스크 여유 공간**: **12GB 이상 권장** (SLM 모델, 빌드 도구, Docker 이미지·빌드 캐시 저장 공간 포함)
- **인터넷 연결**: GitHub, APT 레포지토리, `download.docker.com`, Docker Hub 및 Hugging Face 모델 다운로드 가능 환경
- **계정 권한**: `sudo` 사용이 가능한 일반 사용자 계정으로 실행합니다. `sudo ./setup_rpi5_env.sh --all`로 전체 스크립트를 실행하면 모델·스크립트가 root 홈에 설치될 수 있습니다.

---

## 2. 초간단 1줄 자동 설치 (One-Line Quick Setup)

신규 라즈베리파이 5 터미널에서 다음 명령어를 실행하면 모든 환경이 전자동으로 구축됩니다:

```bash
# 1) 작업 폴더 및 스크립트 복사 (저장소 클론 또는 파일 복사)
git clone <저장소_URL> ~/ssafy_embedded_pjt_setup
cd ~/ssafy_embedded_pjt_setup/scripts

# 2) 전체 자동 설치 실행 (Docker + 시스템 도구 + 툴체인 + llama.cpp + Qwen 2.5 3B + 권한 설정)
chmod +x setup_rpi5_env.sh
./setup_rpi5_env.sh --all
```

> [!TIP]
> 설치 완료 후 그룹 권한(`docker`, `dialout`, `plugdev`)을 적용하려면 **로그아웃 후 SSH로 재접속**하세요. 재접속 전 Docker 확인은 `sudo docker info`로 할 수 있습니다. `docker` 그룹은 root 수준 권한을 제공합니다.

---

## 3. `setup_rpi5_env.sh` 옵션별 개별 실행

필요에 따라 특정 컴포넌트만 선택하여 설치할 수 있습니다:

| 실행 옵션                              | 설명                                                                                        |        소요 시간        |
| :------------------------------------- | :------------------------------------------------------------------------------------------ | :---------------------: |
| `./setup_rpi5_env.sh --all`            | Docker, 시스템 패키지, 임베디드 툴, llama.cpp, Qwen 2.5 3B 모델, 스크립트 배포 및 검증      | 빌드·네트워크 속도 의존 |
| `./setup_rpi5_env.sh --docker`         | Docker 공식 APT 저장소를 통한 Engine, Compose / Buildx 설치, 서비스 시작, 그룹 설정 및 점검 |   네트워크 속도 의존    |
| `./setup_rpi5_env.sh --tools`          | OpenOCD, GDB-multiarch, stlink-tools, PyOCD, DFP 타깃 팩, udev 권한 설정만 설치             |        약 1\~2분        |
| `./setup_rpi5_env.sh --targets`        | 기존 PyOCD에 NUCLEO-F103RB / NUCLEO-G474RE 전용 타깃 팩만 설치하고 인식 여부 검증           |   네트워크 속도 의존    |
| `./setup_rpi5_env.sh --llama`          | llama.cpp 소스 클론, Cortex-A76 멀티코어 최적화 컴파일, `/usr/local/bin` 전역 설치          |        약 3\~4분        |
| `./setup_rpi5_env.sh --model qwen3b`   | **Qwen 2.5 3B Instruct** (`Q4_K_M`, ~2.0GB) 다운로드 (추천 1순위)                           |   네트워크 속도 의존    |
| `./setup_rpi5_env.sh --model qwen3_4b` | **Qwen 3 4B** (`Q4_K_M`, ~2.4GB) 다운로드 (심층 추론 모드)                                  |   네트워크 속도 의존    |
| `./setup_rpi5_env.sh --model all`      | 3B 및 4B 모델 2종 모두 다운로드 (~4.4GB)                                                    |   네트워크 속도 의존    |
| `./setup_rpi5_env.sh --scripts`        | `~/scripts` 폴더에 대화/서버/SWD 검증 헬퍼 스크립트 배포                                    |           1초           |
| `./setup_rpi5_env.sh --verify`         | 바이너리, 모델, USB 권한, ST-Link 및 Docker 데몬·플러그인·메모리 제한 지원 점검             |    환경에 따라 다름     |

기존 환경에 Docker만 추가하려면 `./setup_rpi5_env.sh --docker`를 실행하세요. `--tools`, `--llama`, `--model`, `--scripts`는 Docker를 설치하지 않습니다. 공식 Docker 패키지 5종이 모두 설치되어 있으면 기존 버전을 재사용합니다. 충돌 패키지는 자동 삭제하지 않으며, 발견 시 패키지명을 출력하고 중단합니다.

---

## 4. 수동 설치 절차 상세 안내 (Manual Setup Breakdown)

스크립트 대신 각 단계를 수동으로 직접 수행하고자 할 경우의 상세 명령어입니다.

### 단계 1: Docker Engine 및 Compose 설치

아래 명령은 **공식 Docker APT 저장소가 아직 없는 신규 arm64 환경** 기준입니다. 기존 Docker 또는 APT 저장소 설정이 있으면 중복 등록을 피하도록 `./scripts/setup_rpi5_env.sh --docker`를 사용하는 편이 간편합니다.

먼저 충돌 패키지 설치 여부를 확인합니다. 출력에 `install ok installed`가 있으면 기존 컨테이너 및 의존 서비스의 사용 여부를 확인하고 해당 패키지를 수동 정리한 후 진행하세요. 무조건 일괄 삭제하지 않습니다.

```bash
dpkg-query -W -f='${binary:Package}: ${Status}\n' \
    docker.io docker-compose docker-doc docker-buildx podman-docker containerd runc 2>/dev/null
```

이후 Docker 공식 Debian 저장소에서 설치합니다. 다음 코드 블록은 Bash에서 한 번에 실행하세요. 아키텍처·배포판 검사 실패 시 괄호 안의 설치만 종료됩니다.

```bash
(
set -e
. /etc/os-release
case "${ID:-}:${VERSION_CODENAME:-}:$(dpkg --print-architecture)" in
    debian:bookworm:arm64|debian:trixie:arm64|raspbian:bookworm:arm64|raspbian:trixie:arm64) ;;
    *) echo "Debian / Raspberry Pi OS 12·13 arm64 환경에서 실행하세요."; exit 1 ;;
esac

sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: ${VERSION_CODENAME}
Components: stable
Architectures: arm64
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt-get update
sudo apt-get install -y --no-remove \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker.service containerd.service
sudo usermod -aG docker "$(id -un)"
sudo docker info
)
```

로그아웃 후 재접속하여 아래의 Docker 정상 동작 확인 절차를 실행하세요.

설치 절차는 [Docker 공식 Debian 설치 문서](https://docs.docker.com/engine/install/debian/)와 [사용자 권한 설정 문서](https://docs.docker.com/engine/install/linux-postinstall/)를 기준으로 합니다. `docker-compose` 대신 플러그인 명령인 `docker compose`를 사용합니다.

### 단계 2: 시스템 필수 패키지 및 임베디드 툴체인 설치

```bash
sudo apt-get update -y
sudo apt-get install -y \
    build-essential cmake ccache git curl wget pkg-config libssl-dev \
    python3 python3-pip python3-venv python3-serial \
    openocd gdb-multiarch stlink-tools binutils-arm-none-eabi udev

# 시리얼 및 USB 프로브 접근 권한 추가
sudo usermod -aG dialout,plugdev $USER
```

### 단계 3: PyOCD 및 STM32 Device Family Pack (DFP) 설치

```bash
sudo pip3 install --break-system-packages pyocd pyserial requests fastapi uvicorn

# 팩 설치는 sudo 없이 PyOCD를 실제 사용할 계정에서 실행합니다.
# 검색 인자는 팩 이름이 아닌 MCU 부품명입니다.
pyocd pack update
pyocd pack install stm32f103rb
pyocd pack install stm32g474re
# 기존 STM32F4 예제를 사용할 경우
pyocd pack install stm32f401re

pyocd pack show
pyocd list --targets
pyocd list

# udev 규칙 새로고침
sudo udevadm control --reload-rules
sudo udevadm trigger
```

`stm32f1xx` / `stm32f4xx`는 부품명 검색 패턴으로 적합하지 않아 팩이 설치되지 않을 수 있습니다. 자동 스크립트는 필요한 타깃이 실제 목록에 등록되는지 검사하며 설치 실패를 숨기지 않습니다.

| 보드          | 팩 검색·설치 인자 | PyOCD `--target` 값 | 2026-11-05 RPi 설치 확인   |
| ------------- | ----------------- | ------------------- | -------------------------- |
| NUCLEO-F103RB | `stm32f103rb`     | `stm32f103rb`       | `Keil.STM32F1xx_DFP` 2.4.1 |
| NUCLEO-G474RE | `stm32g474re`     | `stm32g474retx`     | `Keil.STM32G4xx_DFP` 2.2.0 |

팩 버전은 설치 시점에 따라 바뀔 수 있습니다. 두 팩은 같은 사용자 환경에 함께 설치할 수 있으며, 연결한 보드에 맞는 타깃을 선택합니다. 이번 RPi에서는 F103RB가 `pyocd list`에서 `✔︎ stm32f103rb`로 자동 인식되었습니다. G474RE는 타깃 등록까지 확인했으며 실물 접속은 검증하지 않았습니다. 검색·설치와 타깃 선택 방식은 [PyOCD 공식 문서](https://pyocd.io/docs/target_support.html)를 참고하세요.

기존 RPi에 두 팩만 추가하는 명령은 다음과 같습니다.

```bash
bash scripts/setup_rpi5_env.sh --targets
```

보드를 연결한 뒤 다음 명령으로 전용 타깃의 메모리 맵과 주변장치 정의를 조회할 수 있습니다. 각각 해당 보드를 연결했을 때 실행하세요. 여러 프로브가 연결되어 있으면 `pyocd list`의 Unique ID를 `--uid`로 추가합니다.

```bash
# NUCLEO-F103RB
pyocd commander --no-config --target stm32f103rb --connect attach --frequency 1000000 \
    -O auto_unlock=false -O resume_on_disconnect=false \
    -c "show map; show peripherals; exit"

# NUCLEO-G474RE
pyocd commander --no-config --target stm32g474retx --connect attach --frequency 1000000 \
    -O auto_unlock=false -O resume_on_disconnect=false \
    -c "show map; show peripherals; exit"
```

이 예시는 펌웨어 쓰기·삭제·리셋·정지 명령을 실행하지 않습니다. SVD 주변장치 목록은 팩의 레지스터 정의이며, 목록을 표시하는 것만으로 해당 주변장치의 실시간 상태까지 수집되는 것은 아닙니다.

### 단계 4: llama.cpp 빌드 및 전역 설치

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

### 단계 5: 추천 경량 모델 다운로드 (`~/models`)

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
cd ~/ssafy_embedded_pjt_setup
./scripts/setup_rpi5_env.sh --verify
```

바이너리 경로, 모델 파일, 그룹 권한, ST-Link 인식 상태와 Docker 점검 결과를 확인합니다. 필요한 항목에 오류·경고가 없는지 살펴보세요. `--verify`는 종합 상태를 출력하는 용도이며, 종료 코드만으로 전체 설치 성공 여부를 판단하지 않습니다.

### 2) Docker Engine / Compose 정상 동작 확인

로그아웃 후 재접속한 터미널에서 실행합니다.

```bash
docker --version
docker compose version
docker buildx version
systemctl is-active docker
docker info
docker run --rm hello-world
```

Docker 서비스가 `active`이고 `hello-world`가 `Hello from Docker!`를 출력하면 기본 컨테이너 실행까지 확인된 것입니다. 첫 실행은 Docker Hub에서 이미지를 다운로드하므로 인터넷 연결이 필요합니다. 자동 설치는 데몬·플러그인 확인까지 수행하며, `hello-world` 실행은 위 명령으로 별도 확인합니다.

메모리 제한 지원도 확인하세요.

```bash
docker info --format 'memory={{.MemoryLimit}} swap={{.SwapLimit}}'
```

`memory=false`이면 Docker가 설치되어 있어도 Agent의 `mem_limit`이 적용되지 않을 수 있습니다. 아래 Q6의 커널 점검이 필요합니다. Docker 설치와 메모리 제한 활성화는 별개의 작업입니다.

### 3) ST-LINK 프로브 및 STM32 보드 인식 확인

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

### 4) OpenOCD 경고 없는 레지스터 덤프 테스트

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

### 5) 온디바이스 SLM 구동 테스트 (터미널 대화)

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

### Q5. Docker에서 `permission denied` 또는 `Cannot connect to the Docker daemon`이 발생합니다.

```bash
id -nG
sudo systemctl status docker --no-pager
sudo docker info
```

`sudo docker info`만 성공하면 `docker` 그룹 반영 여부를 확인하고 재접속하세요. 그룹이 없다면 `sudo usermod -aG docker "$(id -un)"` 후 재접속합니다. 서비스가 꺼져 있다면 `sudo systemctl enable --now docker`를 실행합니다. `docker.sock`에 `chmod 666`을 적용하지 않습니다.

### Q6. `No memory limit support` / `No swap limit support` 경고가 나옵니다.

```bash
docker info --format 'memory={{.MemoryLimit}} swap={{.SwapLimit}}'
cat /proc/cmdline
cat /sys/fs/cgroup/cgroup.controllers
```

마지막 명령은 cgroup v2 환경용입니다. 컨트롤러 목록에 `memory`가 없거나 Docker가 `memory=false`이면 커널 설정을 확인해야 합니다. RPi 펌웨어가 넣는 `cgroup_disable=memory` 뒤에 `cgroup_enable=memory`가 적용되면 활성화될 수 있으므로, 비활성화 문자열의 존재만으로 판단하지 않습니다. 메모리 제한 미지원 상태에서는 Compose에 제한을 적어도 적용되지 않을 수 있습니다. `docker stats`의 `0B / 0B`도 실제 메모리 사용량이 0이라는 뜻으로 해석하면 안 됩니다.

부팅 설정 파일의 위치와 활성화 방법은 사용하는 OS·커널에 맞게 확인한 뒤 적용하고 재부팅해야 합니다. 이 설치 스크립트는 경고만 출력하며 부팅 설정 변경이나 재부팅을 수행하지 않습니다. 호스트에서 직접 실행하는 `llama-server`는 Agent 컨테이너의 메모리 제한 대상에 포함되지 않습니다. 자세한 내용은 [Docker 리소스 제한 문서](https://docs.docker.com/engine/containers/resource_constraints/)를 참고하세요.

현재 RPi에 적용한 부팅 인자, 컨테이너 제한 확인, Qwen의 부팅 시 자동 시작 설정은 [RPi5 런타임 운영 설정](RPi5_런타임_운영_설정.md)을 참고하세요. `cmdline.txt`가 비어 있으면 루트 파일시스템 인자부터 보존해야 합니다.

---

## 7. 네트워크 연결 및 기기별 Tailscale IP 가이드

> [!TIP]
> **아직 RPi 5에 Tailscale을 설정하지 않은 팀원**은 초기 USB 연결부터 계정 인증까지 쉽게 설명된 **[`tailscale_초간단_설치_가이드.md`](tailscale_초간단_설치_가이드.md)**를 참고하세요.

> [!WARNING]
> **⚠️ Tailscale IP는 기기마다 완전히 다릅니다! 본인의 IP를 꼭 확인 후 입력하세요.**
>
> - 본 문서와 유틸리티 스크립트에 등장하는 `100.x.y.z` 또는 `<본인의_RPi_IP>`는 **단순 예시**입니다.
> - 팀원별로 지급된 라즈베리파이나 개별 보드마다 서로 다른 고유 IP가 부여되므로, **반드시 본인이 직접 사용 중인 라즈베리파이에서 `tailscale ip -4`를 실행하여 확인한 본인 기기 IP**를 사용해야 합니다.
> - 다른 사람의 IP를 그대로 사용할 경우 타인의 라즈베리파이에 오접속되거나 타인의 하드웨어를 제어하게 될 수 있습니다.

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

라즈베리파이 터미널에서 다음 명령어로 본인 기기의 고유 IP를 확인합니다:

```bash
tailscale ip -4
# 기기마다 고유한 100.x.y.z IP가 출력됩니다. (예: 100.115.20.30 등)
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

- **동일 Wi-Fi / 공유기(LAN) 접속 (표준 권장)**:
  - RPi와 PC가 같은 공유기에 물려 있는 경우 `ssh pi@raspberrypi.local` 또는 `hostname -I`로 확인한 사설 IP(예: `192.168.0.x`)로 접속합니다.
- **모니터(Micro-HDMI) + 키보드 직결**:
  - 네트워크 없이 직접 화면과 키보드를 연결하여 로컬 콘솔에서 작업합니다.
- **USB-C 케이블 직결 (사전 설정된 키트 전용)**:
  - `g_ether` USB 가젯 모드가 사전 설정된 교육용 기기인 경우에 한해 `10.12.194.1`로 접속 가능합니다:

    ```powershell
    $env:RPI_HOST = "10.12.194.1"
    .\utils\ssh_rpi.ps1
    ```
