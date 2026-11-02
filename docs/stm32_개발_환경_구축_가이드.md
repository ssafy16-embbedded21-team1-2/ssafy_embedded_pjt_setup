# STM32 펌웨어 개발 환경 구축 가이드 (NUCLEO-G474RE & F103RB / CAN·CAN-FD / CubeIDE / VS Code)

본 문서는 SSAFY 임베디드 프로젝트에서 **NUCLEO-G474RE(메인 DCU / VCU)** 및 **NUCLEO-F103RB(분산 ECU)** 펌웨어를 차량 표준인 **CAN 및 CAN FD 통신** 환경에 맞춰 개발, 빌드, 디버깅하기 위한 **PC 측 통합 개발 환경 구축 매뉴얼**입니다.

---

## 1. 하드웨어 보드별 스펙 및 개발 타깃 요약

| 구분 | **NUCLEO-G474RE (메인 DCU / VCU)** ⭐ | **NUCLEO-F103RB (분산 ECU x3)** |
|:---|:---|:---|
| **차량 역할** | **Main 도메인 제어기 & FOC 모터 인버터** | **BMS, 바디 BCM, 계기판 클러스터** |
| **코어 / 클록** | **ARM Cortex-M4F @ 170 MHz (FPU/DSP)** | **ARM Cortex-M3 @ 72 MHz** |
| **Flash / RAM** | **512 KB (Dual-Bank) / 128 KB (ECC)** | **128 KB / 20 KB** |
| **통신 규격** | **FDCAN x 3 (최대 5 Mbps CAN FD, 64B)** | **bxCAN (최대 1 Mbps Classic CAN, 8B)** |
| **온보드 디버거** | **ST-LINK V3E** (고속) | **ST-LINK V2-1** |
| **OpenOCD 타깃** | `target/stm32g4x.cfg` | `target/stm32f1x.cfg` |

---

## 2. 필수 공통 소프트웨어 및 드라이버 설치

어떤 IDE를 선택하든 **Windows PC에 반드시 설치해야 하는 필수 도구**입니다:

### 1) ST-LINK USB 공식 드라이버 (STSW-LINK009)
NUCLEO 보드의 ST-LINK(V2-1 및 V3E) 가상 COM 포트(VCP)와 디버그 인터페이스를 인식시킵니다.
* **다운로드**: [ST 공식 STSW-LINK009 페이지](https://www.st.com/en/development-tools/stsw-link009.html)

### 2) ST-LINK 펌웨어 최신 업데이트 (STSW-LINK007)
신규 G474RE(V3E) 및 F103RB(V2-1)의 온보드 ST-Link 펌웨어를 최신으로 유지해야 OpenOCD 통신 오류가 발생하지 않습니다.
* **다운로드**: [ST-LINK Firmware Upgrade](https://www.st.com/en/development-tools/stsw-link007.html)
* 실행 방법: 보드 USB 연결 ➡️ `Device Connect` ➡️ `Upgrade` 클릭

### 3) STM32CubeProgrammer
Dual-Bank 옵션 바이트(BFB2) 설정, 칩 풀 이레이즈, 플래시 직접 쓰기용 공식 툴.
* **다운로드**: [STM32CubeProgrammer 다운로드](https://www.st.com/en/development-tools/stm32cubeprog.html)

### 4) PC용 CAN/CAN-FD 모니터링 소프트웨어 (선택/권장)
PC에 USB-to-CAN(Canable)을 연결하여 차량 버스 트래픽을 GUI로 볼 수 있는 무료 툴:
* **Cangaroo** 또는 **SavvyCAN**: 오픈소스 CAN/CAN-FD 버스 모니터 (DBC 파싱 및 그래프 뷰 지원)
* **Python 라이브러리**:
  ```bash
  pip install python-can cantools
  ```

---

## 3. [옵션 A] STM32CubeIDE 환경 구축 (추천)

### 단계 1: 설치
[STM32CubeIDE 공식 사이트](https://www.st.com/en/development-tools/stm32cubeide.html)에서 Windows 버전 설치 (컴파일러, GDB, CubeMX 일체형).

### 단계 2: 보드별 새 프로젝트 생성
`File` ➡️ `New` ➡️ `STM32 Project` ➡️ **Board Selector**에서 본인 보드 검색:
1. **NUCLEO-G474RE 선택 시**:
   * 기본 클록 170 MHz 자동 구성, CORDIC 및 FDCAN 라이브러리 포함
2. **NUCLEO-F103RB 선택 시**:
   * 기본 클록 72 MHz 자동 구성, bxCAN 라이브러리 포함
* *"Initialize all peripherals with their default Mode?"* 팝업에서 **`Yes`** 선택.

---

## 4. [옵션 B] VS Code + CMake 환경 구축 (모던)

### 단계 1: Arm GNU Toolchain 및 빌드 도구 설치
* **Arm GNU Toolchain**: `arm-none-eabi-gcc` 설치 후 `Path` 환경 변수 등록
* **CMake & Ninja**: 설치 후 `Path` 등록

### 단계 2: 필수 VS Code 확장 설치
1. **C/C++** (`ms-vscode.cpptools`)
2. **Cmake Tools** (`ms-vscode.cmake-tools`)
3. **Cortex-Debug** (`marus25.cortex-debug`)
4. **STM32 VS Code Extension** (`stmicroelectronics.stm32-vscode-extension`)

### 단계 3: VS Code `launch.json` 디버깅 설정 (G474 & F103 듀얼 구성)
`.vscode/launch.json`:
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Debug NUCLEO-G474RE (Cortex-M4)",
      "cwd": "${workspaceFolder}",
      "executable": "${workspaceFolder}/build/firmware_g4.elf",
      "request": "launch",
      "type": "cortex-debug",
      "servertype": "openocd",
      "device": "STM32G474RETx",
      "configFiles": ["interface/stlink.cfg", "target/stm32g4x.cfg"],
      "openOCDPreConfigLaunchCommands": ["transport select swd"],
      "runToEntryPoint": "main"
    },
    {
      "name": "Debug NUCLEO-F103RB (Cortex-M3)",
      "cwd": "${workspaceFolder}",
      "executable": "${workspaceFolder}/build/firmware_f1.elf",
      "request": "launch",
      "type": "cortex-debug",
      "servertype": "openocd",
      "device": "STM32F103RB",
      "configFiles": ["interface/stlink.cfg", "target/stm32f1x.cfg"],
      "openOCDPreConfigLaunchCommands": ["transport select swd"],
      "runToEntryPoint": "main"
    }
  ]
}
```

---

## 5. ⚠️ [핵심] 보드별 CubeMX 핀맵 및 CAN/CAN-FD 설정 가이드

### 1) SWD 디버그 핀 잠금 방지 (전 보드 공통 필수 ⭐⭐⭐)
* **경로**: `System Core` ➡️ `SYS` ➡️ `Debug`
* **설정**: 반드시 **`Serial Wire`** 지정! (`No Debug` 시 2번째 다운로드부터 칩 벽돌 현상 발생)

---

### 2) NUCLEO-G474RE FDCAN 설정 (500 kbps Nominal / 2~5 Mbps Data)

#### [FDCAN1 설정: RPi 5 CAN FD 백본 업링크]
* **핀 매핑**: `PA12` ➡️ `FDCAN1_TX`, `PA11` ➡️ `FDCAN1_RX`
* **Connectivity** ➡️ **`FDCAN1`**:
  * **Frame Format**: `FD mode with BitRate Switching (BRS)` (최신 차량 고속 모드)
  * **Mode**: `Normal`
  * **Clock**: PCLK1 (기본 170 MHz)
  * **Nominal Bitrate (중재 구간, 500 kbps)**:
    * Prescaler: `17` (170MHz / 17 = 10 MHz)
    * Sync Jump Width: `1`
    * Time Segment 1: `15`, Time Segment 2: `4` (총 20 TQ ➡️ $10\,\text{MHz} / 20 = 500\,\text{kbps}$, 샘플 포인트 80%)
  * **Data Bitrate (데이터 구간, 2 Mbps 고속)**:
    * Data Prescaler: `17`
    * Data Sync Jump Width: `1`
    * Data Time Segment 1: `3`, Data Time Segment 2: `1` (총 5 TQ ➡️ $10\,\text{MHz} / 5 = 2\,\text{Mbps}$)
  * **Message RAM**:
    * Standard Filter Elements: `2`
    * Rx FIFO0 Elements: `3` (Data Field Size: `64 Bytes`)
    * Tx FIFO/Queue Elements: `3` (Data Field Size: `64 Bytes`)
  * **NVIC Settings**: `FDCAN1 interrupt 0` ➡️ **Enabled**

#### [FDCAN2 설정: 하위 F103 셀 Classic CAN 다운링크]
* **핀 매핑**: `PB6` ➡️ `FDCAN2_TX`, `PB5` ➡️ `FDCAN2_RX`
* **Frame Format**: `Classic mode`
* **Bitrate**: 500 kbps 고정 (하위 F103 셀과 속도 일치)

---

### 3) NUCLEO-F103RB bxCAN 설정 (500 kbps Classic CAN)
* **핀 매핑**: `PA12` ➡️ `CAN_TX`, `PA11` ➡️ `CAN_RX`
* **Connectivity** ➡️ **`CAN`**:
  * APB1 클록 36 MHz 기준:
    * Prescaler: `4`
    * BS1: `12 Times`, BS2: `5 Times` (총 18 TQ ➡️ $36\,\text{MHz} / (4 \times 18) = 500\,\text{kbps}$)
    * ReSynchronization Jump Width (SJW): `1 Time`
    * Automatic Bus-Off Management: `Enable`
    * Automatic Retransmission: `Enable`
  * **NVIC Settings**: `USB low priority or CAN RX0 interrupts` ➡️ **Enabled**

---

### 4) `printf` UART 리디렉션 코드 스니펫 (디버깅용)
`Core/Src/main.c`에 추가:
```c
/* USER CODE BEGIN Includes */
#include <stdio.h>
/* USER CODE END Includes */

/* USER CODE BEGIN PFP */
#ifdef __GNUC__
int __io_putchar(int ch)
#else
int fputc(int ch, FILE *f)
#endif
{
    // G474RE는 huart2 (PA2/PA3), F103RB도 huart2 (PA2/PA3)
    extern UART_HandleTypeDef huart2;
    HAL_UART_Transmit(&huart2, (uint8_t *)&ch, 1, 0xFFFF);
    return ch;
}
/* USER CODE END PFP */
```

---

## 6. 개발자 PC ↔ RPi 5 원격 테스트 연동 가이드

PC에서 빌드한 후 RPi 5에 꽂혀 있는 실물 STM32 보드로 곧바로 플래싱 및 원격 디버깅하는 방법입니다:

### 1) 빌드 바이너리 RPi 5로 전송 및 플래싱
```powershell
# 1) utils/scp_to_rpi.ps1 유틸리티 활용 (본인 RPi IP로 자동 전송)
.\utils\scp_to_rpi.ps1 -Source build/firmware.bin -Destination ~/firmware.bin

# 2) G474RE 보드로 플래싱 (ST-LINK V3E):
.\utils\ssh_rpi.ps1 "st-flash --reset write ~/firmware.bin 0x08000000"

# (참고) G474 Dual-Bank Bank 2에 쓸 경우:
# .\utils\ssh_rpi.ps1 "st-flash write ~/firmware.bin 0x08040000"
```

### 2) PC의 IDE에서 RPi 5 원격 GDB 디버깅
1. **RPi 5에서 타깃에 맞춰 GDB 서버 대기**:
   * **NUCLEO-G474RE 디버깅 시**:
     ```bash
     openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32g4x.cfg
     ```
   * **NUCLEO-F103RB 디버깅 시**:
     ```bash
     openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f1x.cfg
     ```
2. **PC의 CubeIDE / VS Code에서 원격 연결**:
   * GDB 설정 ➡️ `Connect to remote GDB server` ➡️ IP: `<본인의_RPi_Tailscale_IP>`, Port: `3333`
   * PC 에디터 화면에서 RPi 5에 꽂힌 실제 하드웨어의 브레이크포인트와 변수를 실시간 디버깅합니다.
