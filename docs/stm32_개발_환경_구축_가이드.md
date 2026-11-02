# STM32 펌웨어 개발 환경 구축 가이드 (Windows / VS Code / STM32CubeIDE)

본 문서는 SSAFY 임베디드 프로젝트에서 **STM32(Cortex-M3/M4, NUCLEO-F103RB 등)** 펌웨어를 원활하고 안정적으로 개발, 빌드, 디버깅하기 위한 **PC 측 통합 개발 환경(IDE, 툴체인, 드라이버) 구축 매뉴얼**입니다.

---

## 1. 개발 환경 선택 가이드 (A vs B)

프로젝트 성향과 개인 선호에 따라 2가지 개발 환경 중 하나를 선택할 수 있습니다:

| 구분          | **옵션 A: STM32CubeIDE (올인원 공식 환경)** ⭐                                                                             | **옵션 B: VS Code + CMake (모던 경량 환경)**                                                                                      |
| :------------ | :------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------- |
| **적합 대상** | **초·중급자 및 표준 임베디드 개발 권장**                                                                                   | **VS Code 선호자, Git/AI 도구 적극 활용자**                                                                                       |
| **장점**      | • ST 공식 지원으로 세팅이 가장 단순함<br/>• GUI 기반 핀맵/클록 트리 설정 내장<br/>• 빌드, 플래싱, 디버깅이 원클릭으로 작동 | • 가볍고 빠른 에디터 및 강력한 확장 생태계<br/>• GitHub Copilot 등 AI 보조 도구 사용 용이<br/>• CMake 기반 CLI 빌드 자동화에 유리 |
| **단점**      | • Eclipse 기반으로 상대적으로 무겁고 느림                                                                                  | • 초기 환경 변수(Path) 및 확장 설정 단계 필요                                                                                     |

---

## 2. 필수 공통 소프트웨어 및 드라이버 설치 (필수)

어떤 개발 환경을 선택하든 **Windows PC에 반드시 설치해야 하는 3가지**입니다:

### 1) ST-LINK USB 공식 드라이버 (STSW-LINK009)

Windows가 ST-LINK V2-1 가상 COM 포트(VCP) 및 디버거 인터페이스를 정상 인식하도록 합니다.

- **다운로드**: [ST 공식 STSW-LINK009 페이지](https://www.st.com/en/development-tools/stsw-link009.html)
- 설치 후 장치 관리자 확인:
  - `포트 (COM & LPT)` ➡️ `STMicroelectronics STLink Virtual COM Port (COMx)`
  - `범용 직렬 버스 장치` ➡️ `ST-Link Debug`

### 2) ST-LINK 펌웨어 최신 업데이트 (STSW-LINK007)

오래된 온보드 ST-Link 펌웨어는 OpenOCD나 CubeIDE와의 통신 오류를 유발할 수 있습니다.

- **다운로드**: [ST-LINK Firmware Upgrade](https://www.st.com/en/development-tools/stsw-link007.html)
- 실행 방법: Nucleo 보드를 USB 연결 ➡️ `Device Connect` ➡️ `Upgrade` 클릭 (최신 V2J47 이상 유지)

### 3) STM32CubeProgrammer (공식 플래싱 GUI/CLI)

펌웨어 플래싱, 옵션 바이트(Option Byte) 수정, 플래시 메모리 일괄 지우기(Mass Erase)에 가장 신뢰성 높은 도구입니다.

- **다운로드**: [STM32CubeProgrammer 다운로드](https://www.st.com/en/development-tools/stm32cubeprog.html)

---

## 3. [옵션 A] STM32CubeIDE 환경 구축 (추천)

### 단계 1: 설치

1. [STM32CubeIDE 공식 다운로드 페이지](https://www.st.com/en/development-tools/stm32cubeide.html)에서 Windows 버전 다운로드 및 설치.
2. 컴파일러(`arm-none-eabi-gcc`), GDB, OpenOCD, CubeMX가 모두 패키지 내부에 자동 포함되어 있어 추가 설치가 필요 없습니다.

### 단계 2: 새 프로젝트 생성 및 보드 선택

1. `File` ➡️ `New` ➡️ `STM32 Project` 선택.
2. **Board Selector** 탭 클릭 ➡️ 상단 검색창에 **`NUCLEO-F103RB`** 입력 후 선택 ➡️ `Next`.
3. "Initialize all peripherals with their default Mode?" 팝업에서 **`Yes`** 선택:
   - 온보드 LED(`LD2`, PA5), 푸시 버튼(`B1`, PC13), 디버그 USART2(`PA2`/`PA3`)가 자동으로 구성됩니다.

---

## 4. [옵션 B] VS Code + CMake 환경 구축 (모던)

### 단계 1: Arm GNU Toolchain & 빌드 도구 설치

1. **Arm GNU Toolchain (`arm-none-eabi-gcc`)**:
   - [Arm GNU Toolchain 다운로드](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads) (Windows용 zip 또는 exe)
   - 설치 후 환경 변수 `Path`에 `bin` 폴더 등록 (`arm-none-eabi-gcc --version` 확인)
2. **CMake & Ninja (빌드 시스템)**:
   - [CMake 공식 사이트](https://cmake.org/download/) 및 [Ninja](https://ninja-build.org/) 설치 후 `Path` 등록

### 단계 2: 필수 VS Code 확장 설치

VS Code 확장 탭(`Ctrl+Shift+X`)에서 아래 확장을 설치합니다:

1. **C/C++** (`ms-vscode.cpptools`)
2. **Cmake Tools** (`ms-vscode.cmake-tools`)
3. **Cortex-Debug** (`marus25.cortex-debug`) : 실시간 하드웨어 디버깅용
4. **STM32 VS Code Extension** (`stmicroelectronics.stm32-vscode-extension`) : ST 공식 확장

### 단계 3: VS Code `launch.json` 디버깅 설정 예시

`.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Cortex-Debug (ST-Link)",
      "cwd": "${workspaceFolder}",
      "executable": "${workspaceFolder}/build/firmware.elf",
      "request": "launch",
      "type": "cortex-debug",
      "servertype": "openocd",
      "device": "STM32F103RB",
      "configFiles": ["interface/stlink.cfg", "target/stm32f1x.cfg"],
      "openOCDPreConfigLaunchCommands": ["transport select swd"],
      "runToEntryPoint": "main",
      "svdFile": "${workspaceFolder}/STM32F103.svd"
    }
  ]
}
```

---

## 5. ⚠️ [핵심] 우리 프로젝트 특화 STM32CubeMX 설정 규칙

RPi 5 진단 벤치와 연동할 때 **반드시 준수해야 하는 펌웨어 설정 체크리스트**입니다:

### 1) SWD 디버그 핀 잠금 방지 (가장 중요 ⭐⭐⭐)

- **경로**: `Pinout & Configuration` ➡️ `System Core` ➡️ `SYS` ➡️ `Debug`
- **설정**: 반드시 **`Serial Wire`**로 지정!
  > **주의**: 기본값 `No Debug`로 둘 경우 부팅 직후 `PA13`, `PA14` SWD 핀이 일반 GPIO로 풀려버려, **두 번째 펌웨어 다운로드부터 OpenOCD/ST-Link가 칩을 인식하지 못하는 현상**이 발생합니다.

### 2) RPi 5 진단용 시리얼 포트 고정 (USART2)

- **경로**: `Connectivity` ➡️ `USART2`
- **설정**:
  - Mode: `Asynchronous`
  - Baud Rate: `115200 Bits/s`
  - Word Length: `8 Bits`, Parity: `None`, Stop Bits: `1`
- 온보드 ST-Link VCP(Virtual COM Port)를 통해 USB 케이블 하나로 RPi 5의 `/dev/ttyACM*` 또는 Windows COM 포트로 디버그 로그(`printf`)가 전송됩니다.

### 3) `printf` 리디렉션 코드 추가 (`main.c`)

UART로 `printf` 출력을 보내기 위해 `Core/Src/main.c` 상단에 아래 코드를 추가합니다:

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
    extern UART_HandleTypeDef huart2;
    HAL_UART_Transmit(&huart2, (uint8_t *)&ch, 1, 0xFFFF);
    return ch;
}
/* USER CODE END PFP */
```

---

## 6. 개발자 PC ↔ RPi 5 원격 테스트 연동 꿀팁

개발자 PC에서 펌웨어를 빌드한 후, RPi 5에 꽂혀 있는 실물 STM32 보드로 곧바로 검증하는 워크플로우입니다:

### 1) 빌드 바이너리 RPi 5로 초고속 전송

Windows PowerShell에서 빌드 결과물(`.bin` 또는 `.elf`)을 RPi 5로 전송:

```powershell
# utils/scp_to_rpi.ps1 유틸리티 활용 (본인 RPi IP로 자동 전송)
.\utils\scp_to_rpi.ps1 -Source build/firmware.bin -Destination ~/firmware.bin

# RPi 5에서 st-flash로 즉시 플래싱 실행
.\utils\ssh_rpi.ps1 "st-flash --reset write ~/firmware.bin 0x08000000"
```

### 2) PC의 IDE에서 RPi 5 원격 GDB 서버 연결

> [!NOTE]
> 아래 IP는 본인의 라즈베리파이 터미널에서 `tailscale ip -4`를 실행해 확인한 **본인 기기의 고유 IP**를 입력해야 합니다.

1. **RPi 5에서 GDB 서버 대기**:

   ```bash
   openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f1x.cfg
   # 포트 3333 대기
   ```

2. **PC의 CubeIDE / VS Code에서 원격 연결**:
   - Debug Configuration ➡️ GDB 설정 ➡️ `Connect to remote GDB server` 체크 ➡️ IP: `<본인의_RPi_Tailscale_IP>`, Port: `3333` 지정.
   - 내 PC 화면에서 RPi5에 꽂힌 실제 STM32 보드의 브레이크포인트와 변수를 실시간 디버깅할 수 있습니다.
