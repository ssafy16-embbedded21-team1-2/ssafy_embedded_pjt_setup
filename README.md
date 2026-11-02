# SSAFY 임베디드 프로젝트 환경 구축 패키지

## Raspberry Pi 5 기반 STM32 진단 Agent & On-Device SLM 테스트베드

본 저장소는 SSAFY 임베디드 특화 프로젝트를 위한 **Raspberry Pi 5 - STM32 진단 Agent 및 원격 개발 벤치**의 환경 설정 스크립트, 문서, 벤치마크 결과를 독립적으로 관리하는 전용 작업 공간입니다.

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
├── docs/                          # 상세 기술 문서 및 벤치마크 리포트
│   ├── stm32_개발_환경_구축_가이드.md          # [가이드] PC 측 STM32 개발 환경 구축 (CubeIDE / VS Code / 드라이버) ⭐
│   ├── stm32_디버깅_작업_가이드.md          # [가이드] STM32 실전 디버깅 작업 및 CLI 명령어 매뉴얼 ⭐
│   ├── setup_guide_rpi5_diagnosis_agent.md  # [매뉴얼] RPi5 신규 보드 환경 구축 가이드
│   ├── 아키텍처_v2_RPi-STM32_진단Agent.md   # [설계] RPi5-STM32 진단 Agent 시스템 아키텍처
│   ├── 설계_장비별기능_및_AgentTool인터페이스.md # [설계] 셀별 장비 기능 및 Agent Tool 인터페이스
│   ├── qwen2.5_3b_rpi5.md                   # [벤치마크] Qwen 2.5 3B 실측 성능 보고서 (추천 1순위)
│   ├── qwen3_4b_rpi5.md                     # [벤치마크] Qwen 3 4B 실측 성능 보고서
│   ├── gemma3_1b_rpi5.md                    # [참고] Gemma 3 1B 실측 보고서
│   └── gemma3_1b_jetson_vs_rpi5.md          # [참고] Jetson Nano vs RPi 5 비교 보고서
│
└── utils/                         # PC(Windows) 측 보조 유틸리티
    └── ssh_rpi.ps1                # Tailscale(100.92.169.70) 및 USB(10.12.194.1) 원격 SSH 접속기
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

Tailscale VPN 망에 접속하면 라즈베리파이 기기마다 고유한 **`100.x.y.z`** 형태의 가상 사설 IP가 각각 다르게 부여됩니다. 다른 팀원의 라즈베리파이나 신규 보드에 접속할 때는 아래 절차를 참고하세요.

### 1) 라즈베리파이에서 자신의 Tailscale IP 확인

라즈베리파이 로컬 터미널(모니터 직결 또는 USB Gadget 연결 상태)에서 다음 명령어로 IP를 확인합니다:

```bash
tailscale ip -4
# 출력 예시: 100.92.169.70 또는 100.115.x.y
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
