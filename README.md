# SSAFY 임베디드 프로젝트 환경 구축 패키지

## Raspberry Pi 5 기반 STM32 진단 Agent & On-Device SLM 테스트베드

본 저장소는 SSAFY 임베디드 특화 프로젝트를 위한 **Raspberry Pi 5 - STM32 진단 Agent 및 원격 개발 벤치**의 환경 설정 스크립트, 문서, 벤치마크 결과를 독립적으로 관리하는 전용 작업 공간입니다.

**STM32 개발을 바로 시작하려면** [STM32 빠른 시작 가이드](docs/guides/STM32_빠른_시작.md)를 참고하세요. Windows 도구 설치, `NUCLEO-F103RB` 예제 빌드, VS Code 및 CubeIDE 사용법이 포함되어 있습니다.

**현재 우선 목표**는 장비·펌웨어·통신 명세·정상 기준을 충분히 확보한 환경의 진단 검증입니다.
[장비 정보 기반 검증 계획](docs/architecture/장비_정보_기반_검증_계획.md)에 준비 자료·첫 범위·계층별 완료 기준과 검증 케이스 양식을 정리했습니다.
정보가 부족한 장비의 규약 추정·범용 로그 분석은 후속 검토 범위입니다.

임베디드 팀과 구현할 첫 현장 사례는 [CAN 통신 불량 진단 시나리오](docs/architecture/CAN_현장_통신불량_진단_시나리오_설계.md)를 참고하세요.
2대→3대의 시험 구성, CAN 텔레메트리·보조 UART 초안, 종단 측정·루프백 한계, 고장 주입과 복구 확인 기준을 담았습니다.

**제품 운용 진단 설계**는 [CAN 아키텍처 v3.4](docs/architecture/차량용_CAN_통신_도입_및_아키텍처_설계.md)와 [Agent Tool 인터페이스 v3.4](docs/architecture/설계_장비별기능_및_AgentTool인터페이스.md)를 기준으로 합니다. 2026-11-16\~17 결정(`PJT-15`, `PJT-16`)으로 `NUCLEO-G474RE` 및 CAN FD 게이트웨이는 배제하고 **보드 A(열관리 제어기, F103RB) + 보드 B(스마트 냉각팬 ECU, F103RB) + RPi 5(`can0`)** 단일 Classic CAN 버스로 일원화했으며, RPi 5 실측 기반 즉시 연동 설계는 `RPI5_Agent_Docker/docs/실측_CAN_UART_연동_설계.md`에 정리되어 있습니다. ECU 상태·DTC·부팅/크래시 기록은 CAN(및 벤치 보조 UART)으로 조회하며 SWD는 개발·벤치에서 선택적으로 사용합니다. DID·메시지 ID·임계치는 [CAN 통신 규약 합의 회의 템플릿](docs/meetings/CAN_통신규약_합의_회의_템플릿.md) 및 임베디드 팀(`PJT-16`) 합의로 확정합니다.

**프로젝트와 함께 CAN을 학습하려면** [CAN 학습 자료](docs/학습자료/README.md)를 참고하세요. 물리 버스·프레임·오류, STM32 비트 타이밍, SocketCAN/vcan 실습, 신호 규약·DBC, ISO-TP/UDS와 SWD 없는 제품 진단을 순서대로 다룹니다.

**확장 보드와 F103의 실제 통신을 확인하려면** [RPi5–F103 첫 CAN 시험](docs/hardware/RPi5_F103_CAN_첫_통신_테스트.md)을 따릅니다.
2026-11-17 보드 교차 시험을 통해 기존 RPi 5의 RP1 GPIO/SPI 하드웨어 불량을 분리한 뒤, 교체 RPi 5(`serial: 6f1e588610c80344`)에서 `can0`/`can1` `500 kbit/s` `ERROR-ACTIVE`, Active Cooler 이식 냉각 검증, STM32F103 `0x100` 수신·`/dev/ttyACM0` 보조 UART·`cansend` 양방향 통신까지 완료했습니다.

---

## 1. 폴더 구조 (Directory Structure)

```text
ssafy_embedded_pjt_setup/
├── README.md                      # 프로젝트 소개 및 빠른 시작 가이드 (본 문서)
│
├── scripts/                       # RPi 5 환경 구축 및 구동 스크립트
│   ├── setup_rpi5_env.sh          # [핵심] RPi5 전체 자동 구축 스크립트
│   │                              #  (시스템 패키지 + llama.cpp + Qwen 2.5 3B + OpenOCD/GDB/pyocd + udev)
│   ├── poc_swd_test.py            # ST-Link/PyOCD 프로브 탐색 및 레지스터 덤프 PoC
│   ├── run_qwen3b_chat.sh         # Qwen 2.5 3B 터미널 대화 스크립트
│   ├── run_qwen3b_server.sh       # Qwen 2.5 3B OpenAI 호환 API 서버 (Port 8080)
│   ├── run_qwen3_4b_chat.sh       # Qwen 3 4B 터미널 대화 스크립트
│   ├── run_qwen3_4b_server.sh     # Qwen 3 4B API 서버
│   ├── prompt_robot_qwen.txt      # 진단 Agent용 시스템 프롬프트 (Qwen 2.5용)
│   └── prompt_robot_qwen3.txt     # 진단 Agent용 시스템 프롬프트 (Qwen 3용)
│
├── docs/                          # 상세 기술 문서 및 벤치마크 리포트 (전체 목차: docs/README.md)
│   ├── architecture/              # 아키텍처 v3.4 · Agent Tool 설계 · 진단 시나리오 · 검증 계획
│   ├── guides/                    # STM32 · RPi 5 · Tailscale 구축, 운영 및 실물 보드 등록 가이드
│   ├── hardware/                  # RPi 5 CAN HAT 핀·전압·통신 실측 기록, CLI 명령어, 부품 목록
│   ├── benchmarks/                # Qwen 2.5 3B · Qwen 3 4B · Gemma 3 1B 온디바이스 SLM 벤치마크
│   ├── meetings/                  # CAN 통신 규약 합의 회의 템플릿 · 아키텍처 호환성 검토
│   ├── 학습자료/                  # CAN · STM32 · SocketCAN · DBC · ISO-TP/UDS 학습 자료
│   ├── board_records/             # 실물 보드 수집 이력 및 보드별 README
│   └── archive/                   # 이전 v2 USB/SWD 직결 설계 보관본
│
└── utils/                         # PC(Windows) 측 보조 유틸리티
    ├── ssh_rpi.ps1                # 기기별 Tailscale IP(100.x.y.z) 또는 USB(10.12.194.1) 원격 SSH 접속기
    └── scp_to_rpi.ps1             # 펌웨어/파일 RPi5 원격 전송기 (SCP)
```

---

## 2. 신규 Raspberry Pi 5 초간단 1줄 자동 설치

새 라즈베리파이 5에 접속한 후, 아래 명령어를 실행하면 모든 개발 도구와 추천 모델이 한 번에 설치됩니다:

```bash
# 1) 작업 폴더 진입 (저장소 복사본)
cd ~/ssafy_embedded_pjt_setup/scripts
chmod +x setup_rpi5_env.sh

# 2) 전체 자동 설치 실행 (~5-8분 소요)
./setup_rpi5_env.sh --all
```

> [!TIP]
> 설치 완료 후 USB 시리얼 및 디버거 접근 권한(`dialout`, `plugdev`)을 시스템에 적용하기 위해 **1회 터미널 로그아웃 후 재접속(`exit`)**해 주세요.

---

## 3. 설치 상태 점검 및 검증

RPi 5에서 언제든지 아래 명령어를 실행하여 설치 상태를 종합 진단할 수 있습니다:

```bash
~/ssafy_embedded_pjt_setup/scripts/setup_rpi5_env.sh --verify
```

**정상 출력 예시:**

```text
▶ 1. CLI 바이너리 확인:
  [✔] llama-cli : /usr/local/bin/llama-cli
  [✔] llama-server : /usr/local/bin/llama-server
  [✔] openocd : /usr/bin/openocd
  [✔] gdb-multiarch : /usr/bin/gdb-multiarch
  [✔] st-info : /usr/bin/st-info
  [✔] pyocd : /usr/local/bin/pyocd
  [✔] arm-none-eabi-addr2line : /usr/bin/arm-none-eabi-addr2line

▶ 2. 모델 파일 확인 (/home/pi/models):
  - qwen2.5-3b-instruct-q4_k_m.gguf (2.0 GB)

▶ 3. 사용자 그룹 권한: dialout, plugdev 포함 확인
▶ 4. ST-LINK USB 연결 상태: STM32 STLink 프로브 감지
```

---

## 4. 임베디드 진단 툴체인 기본 명령어 요약

### 1) ST-LINK 프로브 및 연결된 STM32 칩 감지

```bash
st-info --probe
```

### 2) OpenOCD 경고 없는 레지스터 덤프 및 정지

- **STM32F1 계열 (Nucleo-F103RB 등, Cortex-M3)**:

  ```bash
  openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f1x.cfg \
          -c "init; reset halt; reg; resume; exit"
  ```

- **STM32F4 계열 (Nucleo-F401, F411, F446 등, Cortex-M4)**:

  ```bash
  openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f4x.cfg \
          -c "init; reset halt; reg; resume; exit"
  ```

### 3) Python SWD PoC 스크립트 실행

```bash
python3 ~/ssafy_embedded_pjt_setup/scripts/poc_swd_test.py
```

---

## 5. 온디바이스 SLM 실행 요약

- **터미널 대화**:

  ```bash
  ~/ssafy_embedded_pjt_setup/scripts/run_qwen3b_chat.sh
  ```

- **OpenAI 호환 API 서버 (포트 8080)**:

  ```bash
  ~/ssafy_embedded_pjt_setup/scripts/run_qwen3b_server.sh
  # API Endpoint: http://<RPi_IP>:8080/v1/chat/completions
  ```

---

## 6. 네트워크 연결 및 기기별 Tailscale IP 설정 안내

> [!TIP]
> **아직 RPi 5에 Tailscale을 설치하지 않은 팀원**은 단계별 쉬운 설치 매뉴얼인 **[`docs/guides/tailscale_초간단_설치_가이드.md`](docs/guides/tailscale_초간단_설치_가이드.md)**를 먼저 확인해 주세요! (USB-C 케이블 직결을 통한 초기 설정부터 로그인까지 3분 완성)

<!-- 별개의 안내 블록 -->

> [!WARNING]
> **⚠️ Tailscale IP는 기기마다 완전히 다릅니다! 본인의 IP를 꼭 확인 후 입력하세요.**
>
> - 본 문서와 스크립트에 등장하는 `100.x.y.z`는 **단순 예시**입니다.
> - 팀원별로 지급된 라즈베리파이나 개별 보드마다 서로 다른 고유 IP가 부여되므로, **반드시 본인이 직접 사용 중인 라즈베리파이에서 `tailscale ip -4`를 실행하여 확인한 본인 기기 IP**를 사용해야 합니다.
> - 다른 사람의 IP를 그대로 사용할 경우 타인의 라즈베리파이에 오접속되거나 타인의 하드웨어를 제어하게 될 수 있습니다.

### 1) 라즈베리파이에서 자신의 Tailscale IP 확인

라즈베리파이 로컬 터미널(모니터 직결 또는 USB Gadget 연결 상태)에서 다음 명령어로 본인의 IP를 확인합니다:

```bash
tailscale ip -4
# 기기마다 고유한 100.x.y.z IP가 출력됩니다. (예: 100.115.20.30 등)
```

_(참고: 웹 브라우저의 [Tailscale 관리자 콘솔](https://login.tailscale.com/admin/machines)에서도 연결된 장비 이름과 IP를 한눈에 볼 수 있습니다.)_

### 2) 호스트 PC(Windows)에서 접속 방법

호스트 PC에도 Tailscale 클라이언트가 실행 중이어야 동일 가상망으로 연결됩니다.

#### 방법 A: PowerShell 원격 스크립트 활용 (`utils/ssh_rpi.ps1`)

- **현재 세션에서 IP 변경 후 접속**:

  ```powershell
  $env:RPI_HOST = "100.x.y.z"
  .\utils\ssh_rpi.ps1
  ```

- **원격 명령 1회성 즉시 실행**:

  ```powershell
  $env:RPI_HOST = "100.x.y.z"; .\utils\ssh_rpi.ps1 "st-info --probe"
  ```

- **기본 IP 영구 변경**:
  `utils/ssh_rpi.ps1` 파일을 열어 상단의 `$DEFAULT_HOST = "100.x.y.z"` 값을 본인 보드의 IP로 수정합니다.

#### 방법 B: 일반 SSH 터미널 직접 접속

```bash
ssh pi@100.x.y.z
# 기본 패스워드: 1
```

### 3) Tailscale 미사용 / 오프라인 환경 대체 접속 방법

- **동일 Wi-Fi / 공유기(LAN) 접속 (표준 권장)**: `ssh pi@raspberrypi.local` 또는 `hostname -I`로 확인한 사설 IP (예: `192.168.0.x`)
- **모니터(Micro HDMI) + USB 키보드 직결**: 직접 화면을 보고 로컬 터미널에서 작업
- **USB-C 케이블 직결 (`10.12.194.1`)**: `g_ether` USB 가젯 모드가 사전에 구성된 교육용 기기에서만 작동
