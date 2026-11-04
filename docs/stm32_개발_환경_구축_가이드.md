# STM32 펌웨어 개발 환경 구축 가이드 (NUCLEO-G474RE & F103RB / CAN·CAN-FD / CubeIDE / VS Code)

> **이 저장소에서 시작할 때는 [STM32 빠른 시작 가이드](STM32_빠른_시작.md)를 우선 사용하세요.** 아래의 예전 CubeIDE·VS Code 설정은 버전과 생성 프로젝트에 따라 달라질 수 있습니다. CubeIDE 2.x의 CubeMX는 별도 설치이며, 저장소 예제의 실제 ELF 경로는 `build/debug/firmware_g474.elf`, `build/debug/firmware_f103.elf`입니다.

본 문서는 SSAFY 임베디드 프로젝트에서 **NUCLEO-G474RE(메인 DCU / VCU)** 및 **NUCLEO-F103RB(분산 ECU)** 펌웨어를 차량 표준인 **CAN 및 CAN FD 통신** 환경에 맞춰 개발, 빌드, 디버깅하기 위한 **PC 측 통합 개발 환경 구축 매뉴얼**입니다.

---

## 1. 하드웨어 보드별 스펙 및 개발 타깃 요약

| 구분              | **NUCLEO-G474RE (메인 DCU / VCU)** ⭐                              | **NUCLEO-F103RB (분산 ECU x3)**         |
| :---------------- | :----------------------------------------------------------------- | :-------------------------------------- |
| **차량 역할**     | **Main 도메인 제어기 & FOC 모터 인버터**                           | **BMS, 바디 BCM, 계기판 클러스터**      |
| **코어 / 클록**   | **ARM Cortex-M4F @ 170 MHz (FPU/DSP)**                             | **ARM Cortex-M3 @ 72 MHz**              |
| **Flash / RAM**   | **512 KB (Dual-Bank 설정 가능) / 128 KB SRAM (96 KB + 32 KB CCM)** | **128 KB / 20 KB**                      |
| **통신 규격**     | **FDCAN x 3 (최대 5 Mbps CAN FD, 64B)**                            | **bxCAN (최대 1 Mbps Classic CAN, 8B)** |
| **온보드 디버거** | **ST-LINK V3E** (고속)                                             | **ST-LINK V2-1**                        |
| **OpenOCD 타깃**  | `target/stm32g4x.cfg`                                              | `target/stm32f1x.cfg`                   |

---

## 2. 필수 공통 소프트웨어 및 드라이버 설치

어떤 IDE를 선택하든 **Windows PC에 반드시 설치해야 하는 필수 도구**입니다:

### 1) ST-LINK USB 공식 드라이버 (STSW-LINK009)

NUCLEO 보드의 ST-LINK(V2-1 및 V3E) 가상 COM 포트(VCP)와 디버그 인터페이스를 인식시킵니다.

- **다운로드**: [ST 공식 STSW-LINK009 페이지](https://www.st.com/en/development-tools/stsw-link009.html)

### 2) ST-LINK 펌웨어 최신 업데이트 (STSW-LINK007)

신규 G474RE(V3E) 및 F103RB(V2-1)의 온보드 ST-Link 펌웨어를 최신으로 유지해야 OpenOCD 통신 오류가 발생하지 않습니다.

- **다운로드**: [ST-LINK Firmware Upgrade](https://www.st.com/en/development-tools/stsw-link007.html)
- 실행 방법: 보드 USB 연결 ➡️ `Device Connect` ➡️ `Upgrade` 클릭

### 3) STM32CubeProgrammer

Dual-Bank 옵션 바이트(BFB2) 설정, 칩 풀 이레이즈, 플래시 직접 쓰기용 공식 툴.

- **다운로드**: [STM32CubeProgrammer 다운로드](https://www.st.com/en/development-tools/stm32cubeprog.html)

### 4) PC용 CAN/CAN-FD 모니터링 소프트웨어 (선택/권장)

PC에 USB-to-CAN(Canable)을 연결하여 차량 버스 트래픽을 GUI로 볼 수 있는 무료 툴:

- **Cangaroo** 또는 **SavvyCAN**: 오픈소스 CAN/CAN-FD 버스 모니터 (DBC 파싱 및 그래프 뷰 지원)
- **Python 라이브러리**:

  ```bash
  pip install python-can cantools
  ```

---

## 3. [옵션 A] STM32CubeIDE 환경 구축 (추천)

### 단계 1: 설치

[STM32CubeIDE 공식 사이트](https://www.st.com/en/development-tools/stm32cubeide.html)에서 설치합니다. **CubeIDE 2.x는 [CubeMX](https://www.st.com/en/development-tools/stm32cubemx.html)를 별도 설치**해야 합니다. 저장소의 CMake 예제를 가져오는 단계는 [빠른 시작 가이드](STM32_빠른_시작.md)를 따르세요.

### 단계 2: 보드별 새 프로젝트 생성

CubeMX의 **Board Selector**에서 본인 보드를 선택합니다. CubeIDE 2.x에서는 CubeMX로 생성 후 프로젝트를 가져옵니다.

1. **NUCLEO-G474RE 선택 시**:
   - CORDIC 및 FDCAN을 사용할 수 있다. 시스템 클록과 주변장치는 프로젝트에서 직접 구성한다.
2. **NUCLEO-F103RB 선택 시**:
   - bxCAN을 사용할 수 있다. 시스템 클록과 주변장치는 프로젝트에서 직접 구성한다.

- 생성한 설정과 HAL 드라이버 포함 여부를 확인한다. 보드를 선택한 것만으로 170 MHz 또는 72 MHz 설정이 보장되지는 않는다.

### 단계 3: CubeMX에서 CubeIDE용 프로젝트 생성 및 가져오기

**CubeMX의 `Toolchain / IDE`가 기본적으로 `STM32CubeIDE`로 설정되어 있다고 가정하지 마세요.** CubeMX 6.x에서 다음 항목을 직접 확인하고 선택합니다.

1. 핀과 클록을 설정한 후 **Project Manager → Project**를 엽니다.
2. **Project Name**과 **Project Location**을 지정합니다. 기존 프로젝트를 덮어쓰거나 그 안에 같은 이름의 프로젝트를 중첩하지 않도록 **Toolchain Folder Location**도 확인합니다.
3. **Toolchain / IDE** 드롭다운에서 **`STM32CubeIDE`**를 선택합니다. 표시된 다른 기본값을 그대로 사용하면 여기서 설명하는 CubeIDE용 프로젝트 파일이 생성되지 않을 수 있습니다.
4. 프로젝트 파일을 `.ioc`와 같은 프로젝트 루트에 두려면 **Generate Under Root**를 체크합니다. 체크하지 않으면 CubeIDE용 프로젝트 파일이 별도 툴체인 폴더에 생성됩니다.
5. **Generate Code**를 누릅니다. 필요한 STM32Cube 펌웨어 패키지를 요청하면 설치하고 생성을 완료합니다.
6. CubeIDE 2.x에서 **File → STM32 Project Create/Import → Import STM32 Project → STM32CubeMX/STM32CubeIDE Project**를 선택하고 생성된 프로젝트를 가져옵니다. Generate Under Root 사용 시 `.ioc`, `.project`, `.cproject`가 프로젝트 루트에 있는지 확인합니다. 이미 가져온 프로젝트는 중복으로 가져오기보다 새로고침합니다.
7. 프로젝트를 빌드하고 생성된 ELF가 대상 보드와 일치하는지 확인한 후 디버그 구성을 만듭니다. 기존 코드를 수정할 때는 CubeMX가 제공하는 `USER CODE` 영역과 재생성 동작을 확인합니다.

> **CMake를 선택한 경우**: CMake 프로젝트도 CubeIDE의 CMake 프로젝트 가져오기 기능으로 사용할 수 있지만, 위의 `STM32CubeMX/STM32CubeIDE Project` 가져오기 절차와는 다릅니다. CMake 프로젝트는 [빠른 시작 가이드의 CMake 가져오기 절차](STM32_빠른_시작.md)를 참고하세요. CubeMX2는 생성 화면과 선택지가 다를 수 있습니다.

참고: [ST의 CubeIDE 2.x 프로젝트 생성·가져오기 절차](https://community.st.com/stm32-mcus-60/stm32cubeide-2-0-0-workflow-tutorial-160701), [CubeMX Generate Under Root 설명](https://dev.st.com/stm32cube-docs/stm32cubemx/6.18.1/en/docs/markup/CubeMX_UserManual/chapters/04_4_stm32cubemx_user_interface.html).

---

## 4. [옵션 B] VS Code + CMake 환경 구축 (모던)

### 단계 1: Arm GNU Toolchain 및 빌드 도구 설치

- **Arm GNU Toolchain**: `arm-none-eabi-gcc` 설치 후 `Path` 환경 변수 등록
- **CMake & Ninja**: 설치 후 `Path` 등록

### 단계 2: 필수 VS Code 확장 설치

1. **C/C++** (`ms-vscode.cpptools`)
2. **Cmake Tools** (`ms-vscode.cmake-tools`)
3. **Cortex-Debug** (`marus25.cortex-debug`)
4. **STM32 VS Code Extension** (`stmicroelectronics.stm32-vscode-extension`)

### 단계 3: 저장소에 제공된 디버깅 설정 사용

루트의 `.vscode/launch.json`에 G474/F103 로컬 flash 디버깅과 RPi OpenOCD 원격 attach가 준비되어 있습니다. 실행 방법과 ELF 경로는 [빠른 시작 가이드](STM32_빠른_시작.md)를 참조하세요. F5 로컬 실행은 보드의 펌웨어를 덮어씁니다.

---

## 5. ⚠️ [핵심] 보드별 CubeMX 핀맵 및 CAN/CAN-FD 설정 가이드

### 1) SWD 디버그 핀 잠금 방지 (전 보드 공통 필수 ⭐⭐⭐)

- **경로**: `System Core` ➡️ `SYS` ➡️ `Debug`
- **설정**: 디버거를 사용한다면 `Serial Wire`로 지정하고 SWD 핀을 다른 기능과 충돌하지 않게 배치한다. 핀 재설정 등으로 디버깅이 안 되면 보드와 연결 방식에 따라 connect-under-reset 등의 복구 방법을 검토한다.

---

### 2) NUCLEO-G474RE FDCAN 설정 (500 kbps Nominal / 2~5 Mbps Data)

#### [FDCAN1 설정: RPi 5 CAN FD 백본 업링크]

- **핀 매핑**: `PA12` ➡️ `FDCAN1_TX`, `PA11` ➡️ `FDCAN1_RX`
- **Connectivity** ➡️ **`FDCAN1`**:
  - **Frame Format**: `FD mode with BitRate Switching (BRS)` (최신 차량 고속 모드)
  - **Mode**: `Normal`
  - **Clock**: 아래 값은 FDCAN 커널 클록을 실제로 170 MHz로 구성한 경우의 계산 예시. 보드 선택만으로 적용되지 않으며 Clock Configuration과 허용 범위를 확인한다.
  - **Nominal Bitrate (중재 구간, 500 kbps)**:
    - Prescaler: `17` (170MHz / 17 = 10 MHz)
    - Sync Jump Width: `1`
    - Time Segment 1: `15`, Time Segment 2: `4` (총 20 TQ ➡️ $10\,\text{MHz} / 20 = 500\,\text{kbps}$, 샘플 포인트 80%)
  - **Data Bitrate (데이터 구간, 2 Mbps 고속)**:
    - Data Prescaler: `17`
    - Data Sync Jump Width: `1`
    - Data Time Segment 1: `3`, Data Time Segment 2: `1` (총 5 TQ ➡️ $10\,\text{MHz} / 5 = 2\,\text{Mbps}$)
  - **Message RAM / 필터**: G474 HAL과 CubeMX가 제공하는 설정 및 실제 하드웨어 제한을 확인하고 필요한 필터·FIFO를 구성한다. 다른 STM32 계열의 Message RAM 설정을 그대로 적용하지 않는다.
  - **NVIC Settings**: `FDCAN1 interrupt 0` ➡️ **Enabled**

#### [FDCAN2 설정: 하위 F103 셀 Classic CAN 다운링크]

- **핀 매핑**: `PB6` ➡️ `FDCAN2_TX`, `PB5` ➡️ `FDCAN2_RX`
- **Frame Format**: `Classic mode`
- **Bitrate**: 500 kbps 고정 (하위 F103 셀과 속도 일치)

---

### 3) NUCLEO-F103RB bxCAN 설정 (500 kbps Classic CAN)

- **핀 매핑**: `PA12` ➡️ `CAN_TX`, `PA11` ➡️ `CAN_RX`
- **Connectivity** ➡️ **`CAN`**:
  - APB1 클록 36 MHz 기준:
    - Prescaler: `4`
    - BS1: `12 Times`, BS2: `5 Times` (총 18 TQ ➡️ $36\,\text{MHz} / (4 \times 18) = 500\,\text{kbps}$)
    - ReSynchronization Jump Width (SJW): `1 Time`
    - Automatic Bus-Off Management: `Enable`
    - Automatic Retransmission: `Enable`
  - **NVIC Settings**: `USB low priority or CAN RX0 interrupts` ➡️ **Enabled**

---

### 4) `printf` UART 리디렉션 코드 스니펫 (디버깅용)

보드 회로도와 CubeMX에서 VCP에 연결된 UART 인스턴스를 확인하고, 생성된 프로젝트의 라이브러리·syscall 설정에 맞게 `_write` 또는 해당 출력 훅을 구현합니다. G474RE의 기본 VCP는 LPUART1(PA2/PA3), F103RB는 USART2(PA2/PA3)입니다. 이 저장소의 최소 예제에는 HAL/UART 또는 `printf`가 포함되어 있지 않습니다. [ST G4 보드 매뉴얼](https://www.st.com/resource/en/user_manual/um2505-stm32g4-nucleo64-boards-mb1367-stmicroelectronics.pdf)

---

## 6. 개발자 PC ↔ RPi 5 원격 테스트 연동 가이드

PC에서 빌드한 후 RPi 5에 꽂혀 있는 실물 STM32 보드로 곧바로 플래싱 및 원격 디버깅하는 방법입니다:

### 1) 빌드 바이너리 RPi 5로 전송 및 플래싱

```powershell
# 1) 보드에 맞는 바이너리를 전송 (본인 RPi IP 지정)
.\utils\scp_to_rpi.ps1 -Source build/debug/firmware_g474.bin -Destination ~/firmware.bin

# 2) G474RE 보드로 플래싱 (ST-LINK V3E):
.\utils\ssh_rpi.ps1 "st-flash --reset write ~/firmware.bin 0x08000000"

```

플래싱은 기존 펌웨어를 덮어씁니다. 시작 예제는 Bank 2 링크 주소, 부트로더 또는 OTA를 구현하지 않으므로 Bank 2에 그대로 쓰지 않습니다.

### 2) PC의 IDE에서 RPi 5 원격 GDB 디버깅

1. **RPi 5에서 타깃에 맞춰 GDB 서버 대기**:
   - **NUCLEO-G474RE 디버깅 시**:

     ```bash
     openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32g4x.cfg
     ```

   - **NUCLEO-F103RB 디버깅 시**:

     ```bash
     openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f1x.cfg
     ```

2. **PC의 CubeIDE / VS Code에서 원격 연결**:
   - GDB 설정 ➡️ `Connect to remote GDB server` ➡️ IP: `<본인의_RPi_Tailscale_IP>`, Port: `3333`
   - PC 에디터 화면에서 RPi 5에 꽂힌 실제 하드웨어의 브레이크포인트와 변수를 실시간 디버깅합니다.
