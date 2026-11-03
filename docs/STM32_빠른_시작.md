# STM32 개발 환경 빠른 시작

이 저장소의 시작 예제는 NUCLEO-G474RE와 NUCLEO-F103RB의 온보드 사용자 LED(LD2, PA5)를 점멸하는 **최소 CMake 프로젝트**입니다. 두 예제를 한 번에 빌드할 수 있고, VS Code 및 STM32CubeIDE 2.x에서 같은 소스를 사용할 수 있습니다. CAN 트랜시버는 필요하지 않습니다.

> 이 예제는 초기 연결·빌드·디버그 확인용입니다. CubeMX 프로젝트나 HAL 예제가 아니며 CAN, UART, FOC, OTA를 구현하지 않습니다. 표준 라이브러리 없이 링크하고(`-nostdlib`), G474의 FPU를 활성화하지 않으며 두 타깃 모두 soft-float ABI를 사용합니다. HAL·`printf`·실수 연산 등을 추가할 때는 런타임·ABI와 해당 MCU의 클록·주변장치·링커·부트 정책을 별도로 구성하세요.

## 1. 공통 준비: 사용할 개발 환경 선택

두 IDE는 같은 `CMakeLists.txt`와 `firmware/starter/main.c`를 사용할 수 있습니다. 필요한 환경을 선택해 해당 절만 따라가세요.

| 항목            | VS Code 경로                                                     | STM32CubeIDE 2.x 경로                                      |
| :-------------- | :--------------------------------------------------------------- | :--------------------------------------------------------- |
| IDE와 확장      | VS Code 및 2절의 확장                                            | CubeIDE. VS Code와 VS Code 확장 불필요                     |
| 컴파일러        | Windows의 제공된 실행 설정은 스크립트로 설치한 xPack 툴체인 사용 | CubeIDE에 포함된 Arm GNU Toolchain 또는 별도 설치한 툴체인 |
| CMake / Ninja   | CMake 3.22 이상과 Ninja를 PATH에서 사용                          | CubeIDE에서 사용할 수 있는 CMake와 Ninja                   |
| 로컬 디버거     | Cortex-Debug + OpenOCD                                           | CubeIDE의 ST-LINK 디버깅 구성                              |
| RPi 원격 디버깅 | 5-1절 공통 준비 후 5-3절                                         | 5-1절 공통 준비 후 5-2절                                   |

두 경로 모두 대상 Nucleo 보드와 데이터 전송이 되는 USB 케이블이 필요합니다. Windows에서 보드가 인식되지 않으면 [ST-LINK USB 드라이버](https://www.st.com/en/development-tools/stsw-link009.html)를 확인합니다. CAN 트랜시버는 LED 예제에 필요하지 않습니다.

LED 주기는 기본 클록과 빌드에 따라 달라집니다. 보드의 LD2가 PA5에 연결된 기본 점퍼/솔더브리지 구성을 확인하세요. **로컬 플래시 디버깅은 기존 보드 펌웨어를 덮어씁니다.**

## 2. 방법 A: STM32CubeIDE 2.x 사용

### 2-1. CubeIDE용 준비

[STM32CubeIDE](https://www.st.com/en/development-tools/stm32cubeide.html)를 설치합니다. CubeIDE에 포함된 CMake·Ninja와 Arm GNU Toolchain을 사용할 수 있습니다.

이 저장소의 CMake 툴체인 파일은 `.tools/stm32/`의 xPack 컴파일러 또는 PATH의 `arm-none-eabi-gcc`, `arm-none-eabi-objcopy`, `arm-none-eabi-size`를 찾습니다. CubeIDE에 포함된 툴체인 경로가 자동으로 검색되지 않으면 2-2절처럼 경로를 지정하세요.

선택적으로 저장소 전용 xPack 툴체인과 OpenOCD를 쓰고 싶다면 Windows PowerShell에서 다음 명령을 실행할 수 있습니다. **`-SkipExtensions`는 VS Code 확장 설치와 `code` 확인을 생략**합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup_stm32_windows.ps1 -SkipExtensions
```

이 스크립트는 CubeIDE 설치 여부와 별개로 PATH의 `cmake`, `ninja`를 확인하며, 없으면 설치가 끝난 뒤에도 누락으로 보고하고 실패 코드를 반환합니다. CubeIDE 내장 CMake·Ninja만 사용하는 경우에는 이 PATH 검사가 IDE 빌드 가능 여부를 판정하지 않습니다. `-CheckOnly -SkipExtensions`로 같은 항목을 설치 없이 확인할 수 있습니다.

### 2-2. 기존 CMake 프로젝트 가져오기와 로컬 디버깅

1. CubeIDE를 실행합니다. `File` → `New` → `STM32 Project` → `STM32 Project Create/Import`에서 **STM32 CMake Project / Project with existing CMake sources**를 선택합니다. 메뉴 명칭은 버전에 따라 다를 수 있습니다.
2. Source directory에 **이 저장소 루트**를 선택하고, MCU/보드는 디버깅할 `STM32G474RETx` 또는 `STM32F103RBTx`를 고릅니다. GCC 툴체인을 선택합니다.
3. CMake 설정에서 toolchain file을 `cmake/arm-none-eabi.cmake`로 지정하고 Ninja/Debug로 구성합니다. 이 프로젝트는 두 보드의 ELF를 빌드하므로 IDE에서 선택한 디버그 대상과 실행할 ELF를 일치시켜야 합니다.
4. 컴파일러를 찾지 못하거나 CubeIDE 내장 GCC를 명시적으로 사용하려면 CMake 캐시 설정에 `ARM_GCC`, `ARM_OBJCOPY`, `ARM_SIZE`를 추가하고 각각 CubeIDE의 `tools/bin` 아래 `arm-none-eabi-gcc.exe`, `arm-none-eabi-objcopy.exe`, `arm-none-eabi-size.exe`의 **전체 경로**로 지정한 뒤 재구성합니다. 설치 버전에 따라 `tools/bin` 경로는 달라집니다. 기존 `.tools/stm32/` xPack이 있어도 이 세 값을 명시하면 해당 경로를 사용합니다.
5. 프로젝트를 빌드합니다. CubeIDE의 빌드 디렉터리는 VS Code의 `build/debug`와 다를 수 있으므로 **CubeIDE가 실제로 사용한 빌드 폴더**에서 결과를 확인합니다.
6. 보드 하나를 PC에 연결하고 CubeIDE 디버그 구성의 ELF로 G474는 `firmware_g474.elf`, F103은 `firmware_f103.elf`를 선택합니다. ST-LINK 디버깅을 시작해 보드에 쓰고 `main`을 지난 뒤 LD2를 확인합니다.

컴파일러를 바꿨는데 이전 경로가 계속 사용된다면 CubeIDE의 CMake 캐시 설정을 확인하거나 별도의 빌드 디렉터리에서 다시 구성합니다. ELF·BIN 이름은 두 경로가 같지만 각 IDE의 빌드 결과물을 혼동하지 마세요.

이 경로는 [ST의 기존 CMake 소스 가져오기 안내](https://www.st.com/resource/en/application_note/an5952-how-to-use-cmake-in-stm32cubeide-stmicroelectronics.pdf)를 기반으로 합니다.

### 2-3. 새 CubeMX/HAL 프로젝트를 만드는 경우

CubeIDE 2.x에서는 [STM32CubeMX](https://www.st.com/en/development-tools/stm32cubemx.html)를 별도 설치합니다. CubeMX의 Board Selector에서 보드를 선택하고, IDE 버전에 맞게 STM32CubeIDE 또는 CMake 프로젝트를 생성한 뒤 CubeIDE에 가져오세요. CubeMX2의 CMake 프로젝트는 CubeIDE 2.1.1 이상의 CMake 가져오기 절차를 사용할 수 있습니다. [ST CubeIDE 2.x 안내](https://community.st.com/stm32-mcus-60/stm32cubeide-2-0-0-workflow-tutorial-160701), [ST CMake 가져오기 예시](https://community.st.com/stm32-mcus-60/how-to-import-a-stm32cubemx2-cmake-project-into-stm32cubeide-164166)

생성 프로젝트는 `firmware/cube-projects/<프로젝트명>/` 같은 별도 폴더에 두세요. 이 폴더는 기본적으로 Git에서 제외됩니다. 팀에서 공유할 프로젝트라면 ignore 정책을 검토하고 `.ioc`, 사용자 코드, 필요한 빌드 설정을 명시적으로 관리해야 합니다. 기존 LED 예제는 CubeMX가 재생성하지 않습니다. CubeMX 생성 코드 수정은 해당 프로젝트의 `USER CODE` 영역을 사용하고, 생성 전 실제 클록·핀·CAN 설정을 확인하세요.

## 3. 방법 B: VS Code와 확장 사용

### 3-1. Windows 도구와 확장 설치

VS Code와 [CMake 3.22 이상](https://cmake.org/download/), [Ninja](https://ninja-build.org/)를 설치하고 `code`, `cmake`, `ninja`가 PATH에 등록된 새 PowerShell을 엽니다. CMake와 Ninja는 아래 스크립트가 설치하지 않습니다.

저장소 루트에서 실행합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup_stm32_windows.ps1
```

이 명령은 SHA-256을 확인한 xPack Arm GNU Toolchain과 OpenOCD를 `.tools/stm32/`에 설치하고, VS Code의 C/C++, CMake Tools, Cortex-Debug, STM32CubeIDE for VS Code 확장을 설치합니다. `.tools/`는 Git에 포함되지 않고 시스템 PATH도 변경하지 않습니다.

설치 여부만 확인하려면 다음 명령을 사용합니다. `-CheckOnly`는 설치하지 않습니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup_stm32_windows.ps1 -CheckOnly
```

Linux/macOS에서는 Arm GNU Toolchain, CMake, Ninja, OpenOCD 및 VS Code 확장을 각 OS 방식으로 설치하고 명령이 PATH에서 검색되는지 확인하세요. 제공된 디버그 구성은 해당 OS의 `arm-none-eabi-gdb`와 `openocd`를 사용합니다.

### 3-2. VS Code에서 빌드 및 로컬 디버그

1. 저장소 **루트 폴더**를 VS Code에서 엽니다.
2. 명령 팔레트에서 `CMake: Select Configure Preset` → `STM32 starters (Debug)`를 선택하고 `CMake: Configure`를 실행합니다.
3. `Ctrl+Shift+B` 또는 `Terminal: Run Build Task` → `STM32: Build`를 실행합니다. CMake Tools의 Build 버튼도 사용할 수 있습니다.
4. **해당 보드 하나만** PC에 연결합니다. 외부 전력단을 사용 중이면 출력 상태를 먼저 확인합니다.
5. Run and Debug에서 보드에 맞는 `local ST-LINK (flash)` 구성을 고르고 `F5`를 누릅니다. 빌드한 ELF를 플래시에 쓰고 `main`에서 멈춥니다. Continue 후 LD2를 확인합니다.

이 저장소의 VS Code 디버그 구성은 `.vscode/launch.json`, 빌드 작업은 `.vscode/tasks.json`에 있습니다. ST 확장의 Bundle Manager도 사용할 수 있지만, 제공된 `F5` 구성은 **Cortex-Debug + OpenOCD**를 사용합니다. 여러 ST-LINK가 연결된 경우 사용하지 않을 프로브를 분리하거나 OpenOCD에서 대상 시리얼을 지정하세요.

### 3-3. VS Code 결과물과 코드 분석

| 대상          | 디버깅용 ELF                    | 바이너리                        |
| :------------ | :------------------------------ | :------------------------------ |
| NUCLEO-G474RE | `build/debug/firmware_g474.elf` | `build/debug/firmware_g474.bin` |
| NUCLEO-F103RB | `build/debug/firmware_f103.elf` | `build/debug/firmware_f103.bin` |

`main.c`에서 보드 매크로 관련 IntelliSense 경고가 보이면 `CMake: Configure` 후 `CMake: Set Build Target`에서 `firmware_f103` 또는 `firmware_g474`를 선택하세요. `F5` 디버그 구성과 편집기 코드 분석에 사용되는 CMake 타깃은 별개일 수 있습니다.

## 4. 공통 소스와 명령줄 빌드

`firmware/starter/main.c`가 공통 예제이고 보드별 매크로가 GPIO 설정을 선택합니다. ST의 보드별 startup 파일은 `firmware/vendor/`에 출처·라이선스와 함께 들어 있습니다. 링커 스크립트는 `firmware/linker/`에 있으며 G474는 시작 예제에서 일반 SRAM 96KB만 사용합니다. 해당 링커 구성은 Dual-Bank 부트로더나 OTA 배치를 정의하지 않습니다.

IDE 없이 명령줄에서 빌드하려면 CMake 3.22 이상과 Ninja가 PATH에 있어야 하고, Arm GNU Toolchain은 `.tools/stm32/`에 설치되어 있거나 PATH에서 검색되어야 합니다.

```powershell
cmake --preset debug
cmake --build --preset debug
```

이 명령은 3-3절의 `build/debug` 경로에 두 보드의 ELF와 BIN을 생성합니다. CubeIDE의 GUI 빌드 폴더와는 별도로 관리됩니다.

## 5. RPi에 연결된 보드 원격 디버깅

CubeIDE와 VS Code 모두 원격 디버깅을 지원합니다. 두 IDE는 PC에서 실행하고, STM32와 ST-LINK는 RPi에 연결합니다.

```text
PC의 CubeIDE 또는 VS Code → SSH 터널 → RPi의 OpenOCD → ST-LINK → STM32
```

### 5-1. 공통 준비: RPi의 OpenOCD와 PC의 SSH 터널

RPi에 SSH로 접속하고 ST-LINK 보드가 연결되었는지 확인합니다.

```bash
st-info --probe
```

RPi에서 **대상 보드 하나에 맞는 명령 하나만** 실행하고, 이 터미널을 계속 열어 둡니다. 다음은 ST-LINK가 한 개 연결된 경우입니다.

```bash
# NUCLEO-F103RB
openocd -c 'bindto 127.0.0.1' -f interface/stlink.cfg \
  -f target/stm32f1x.cfg
```

```bash
# NUCLEO-G474RE
openocd -c 'bindto 127.0.0.1' -f interface/stlink.cfg \
  -f target/stm32g4x.cfg
```

여러 ST-LINK가 연결되었다면 `-f interface/stlink.cfg` 다음에 `-c 'adapter serial 실제시리얼'`을 추가하여 대상을 지정합니다. 예를 들어 `-c 'adapter serial 0123456789ABCDEF'`에서 시리얼은 예시이므로 `st-info --probe`의 실제 값으로 바꿉니다. OpenOCD가 GDB 포트 `3333`에서 대기하는지 로그를 확인하세요.

위 명령은 RPi의 로컬 인터페이스에서만 GDB 포트 `3333`을 수신합니다. **PC의 별도 PowerShell 창**에서 SSH 터널을 만들고, 디버깅 중 이 창도 계속 열어 둡니다.

```powershell
ssh -N -L 127.0.0.1:3333:127.0.0.1:3333 pi@<RPi_IP>
```

`<RPi_IP>`는 실제 주소로 바꿉니다. `-N` 사용 시 명령 프롬프트가 돌아오지 않는 것이 정상입니다. PC 포트 3333이 이미 사용 중이라면 `-L 127.0.0.1:3334:127.0.0.1:3333`으로 바꾸고, IDE에도 포트 `3334`를 입력합니다. 기본 예시는 OpenOCD를 외부 네트워크에 직접 공개하지 않습니다.

### 5-2. STM32CubeIDE 2.x에서 원격 연결

공통 준비를 마친 뒤, PC의 CubeIDE에서 다음을 설정합니다. 메뉴와 항목 명칭은 IDE 버전·프로젝트 종류에 따라 조금 다를 수 있습니다.

1. 3절에 따라 프로젝트를 가져오거나 기존 프로젝트를 엽니다. 해당 MCU에서 **실행 중인 펌웨어와 정확히 같은 빌드의 디버그 심볼이 포함된 ELF**를 준비합니다. 기존 보드 펌웨어가 이 저장소의 시작 예제가 아니라면 `firmware_f103.elf` 또는 `firmware_g474.elf`를 그대로 사용하지 않습니다.
2. `Run` → `Debug Configurations...`를 엽니다. 프로젝트의 기존 **STM32 C/C++ Application** 구성을 복제하거나 새 구성을 만들고, 이름을 `F103 RPi OpenOCD attach`처럼 지정합니다.
3. **Main** 탭에서 프로젝트와 일치하는 ELF를 선택합니다. 실행 이미지가 바뀌지 않도록, 기존 펌웨어의 심볼을 사용하는 경우 자동 빌드가 ELF를 덮어쓰지 않는지도 확인합니다.
4. **Debugger** 탭에서 다음을 설정합니다.
   - `Debug probe`: `ST-LINK (OpenOCD)`. RPi에서 실행한 서버도 OpenOCD여야 합니다.
   - `Connect to remote GDB server` 선택.
   - `Host name or IP address`: `127.0.0.1`, `Port number`: `3333`(SSH 터널의 PC 측 포트).
   - `Reset behaviour` 또는 해당 reset 설정: `None`. 선택 가능한 항목은 구성에 따라 다를 수 있습니다.
5. **Startup** 탭에서 기존 펌웨어를 보존하는 설정을 확인합니다.
   - `Load Image and Symbols`에서 해당 ELF를 선택하고 `Edit...`을 눌러 **Download는 해제**, **Load symbols는 선택**합니다.
   - `Set program counter`와 `Set breakpoint at`은 해제하고 `Resume`도 해제합니다.
   - `Initialization Commands`와 `Run Commands`에 기존 설정이 있다면 `reset`, `load`, `continue`, `set $pc` 등 상태를 바꾸는 명령이 실행되지 않도록 확인합니다.
6. `Apply` → `Debug`를 눌러 연결합니다. 연결 후 레지스터와 소스 위치를 확인하고, 필요한 경우에만 실행을 재개합니다. 연결 과정에서 MCU가 일시 정지할 수 있습니다.

`Download`를 선택하면 선택한 ELF가 원격 보드에 기록될 수 있고, reset 설정이나 시작 명령도 기존 상태를 바꿀 수 있습니다. 새 펌웨어 다운로드가 필요할 때는 별도 디버그 구성을 만들어 대상 MCU·ELF·시작 동작을 확인한 뒤 실행하세요.

이 절차는 [ST CubeIDE 사용자 매뉴얼의 원격 GDB 및 attach 설정](https://www.st.com/content/ccc/resource/technical/document/user_manual/group1/f8/a2/48/77/68/e6/4b/74/DM00629856/files/DM00629856.pdf/jcr%3Acontent/translations/en.DM00629856.pdf)을 기준으로 작성했습니다. CubeIDE GUI와 실제 RPi 간 원격 연결은 아직 실기 검증하지 않았습니다.

### 5-3. VS Code에서 원격 연결

공통 준비 후 대상 보드의 `remote OpenOCD (attach)`를 선택하고 주소에 `127.0.0.1:3333`을 입력합니다. **원격 attach는 펌웨어를 다운로드하지 않으며 연결 중 타깃을 정지할 수 있습니다.** 로컬 ELF는 실제 보드에 실행 중인 펌웨어와 동일한 빌드여야 합니다. 별도 OpenOCD 인스턴스를 동시에 띄운다면 포트도 구분하세요.

## 6. 문제 해결

| 증상                                    | 확인할 항목                                                                            |
| :-------------------------------------- | :------------------------------------------------------------------------------------- |
| `arm-none-eabi-gcc` 또는 `openocd` 없음 | VS Code는 2-1절의 도구 설치·PATH 확인, CubeIDE는 3-2절의 툴체인 경로와 IDE 디버거 확인 |
| CMake가 예전 컴파일러를 사용            | **해당 IDE가 사용하는** 빌드 폴더의 `CMakeCache.txt`에서 경로를 확인하고 재구성        |
| ST-LINK 연결 실패                       | USB 데이터 케이블·전원·Windows 드라이버·다른 디버거의 점유 확인                        |
| 엉뚱한 보드가 동작                      | 디버그 대상·ELF·ST-LINK 시리얼 확인. 단일 프로브로 먼저 검증                           |
| LED가 켜지지 않음                       | 보드 종류·LD2/PA5 기본 연결·플래시 실행 여부 확인                                      |
| 원격 접속 실패                          | RPi의 OpenOCD 실행 상태·포트·SSH 터널 확인                                             |

상세 오류 분석과 CAN 진단은 [STM32 디버깅 가이드](stm32_디버깅_작업_가이드.md)를 참고하세요. 실습 벤치의 CAN 규약은 [CAN 아키텍처](차량용_CAN_통신_도입_및_아키텍처_설계.md)와 별도 합의가 기준입니다.
