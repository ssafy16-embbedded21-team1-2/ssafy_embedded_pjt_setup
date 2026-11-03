# STM32 개발 환경 빠른 시작

이 저장소의 시작 예제는 NUCLEO-G474RE와 NUCLEO-F103RB의 온보드 사용자 LED(LD2, PA5)를 점멸하는 **최소 CMake 프로젝트**입니다. 두 예제를 한 번에 빌드할 수 있고, VS Code 및 STM32CubeIDE 2.x에서 같은 소스를 사용할 수 있습니다. CAN 트랜시버는 필요하지 않습니다.

> 이 예제는 초기 연결·빌드·디버그 확인용입니다. CubeMX 프로젝트나 HAL 예제가 아니며 CAN, UART, FOC, OTA를 구현하지 않습니다. 표준 라이브러리 없이 링크하고(`-nostdlib`), G474의 FPU를 활성화하지 않으며 두 타깃 모두 soft-float ABI를 사용합니다. HAL·`printf`·실수 연산 등을 추가할 때는 런타임·ABI와 해당 MCU의 클록·주변장치·링커·부트 정책을 별도로 구성하세요.

## 1. Windows에서 도구 준비

필요한 도구는 VS Code, CMake 3.22 이상, Ninja입니다. [CMake](https://cmake.org/download/)와 [Ninja](https://ninja-build.org/)가 PATH에 없다면 먼저 설치하고 터미널을 다시 여세요. ST-LINK USB 드라이버는 보드 인식이 안 될 때 [ST 공식 드라이버](https://www.st.com/en/development-tools/stsw-link009.html)를 설치합니다.

저장소 루트에서 PowerShell을 실행합니다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup_stm32_windows.ps1
```

스크립트는 SHA-256을 확인한 고정 버전의 Arm GNU Toolchain과 OpenOCD를 `.tools/stm32/`에 설치하고, C/C++, CMake Tools, Cortex-Debug, STM32CubeIDE for VS Code 확장을 설치합니다. `.tools/`는 Git에 포함되지 않으며 다른 팀원은 같은 스크립트를 실행하면 됩니다. 기존 시스템 PATH는 수정하지 않습니다.

설치 여부만 확인하려면:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup_stm32_windows.ps1 -CheckOnly
```

확장 설치를 건너뛰려면 `-SkipExtensions`를 추가합니다. Linux/macOS에서는 Arm GNU Toolchain, CMake, Ninja, OpenOCD를 시스템 PATH에 설치하고 아래 CMake 명령을 그대로 사용할 수 있습니다. VS Code 원격·로컬 디버깅도 해당 시스템의 `arm-none-eabi-gdb`와 `openocd`가 필요합니다.

## 2. 공통 빌드와 결과물

```powershell
cmake --preset debug
cmake --build --preset debug
```

| 대상 | 디버깅용 ELF | 바이너리 |
| :--- | :--- | :--- |
| NUCLEO-G474RE | `build/debug/firmware_g474.elf` | `build/debug/firmware_g474.bin` |
| NUCLEO-F103RB | `build/debug/firmware_f103.elf` | `build/debug/firmware_f103.bin` |

`firmware/starter/main.c`가 공통 예제이고 보드별 매크로가 GPIO 설정을 선택합니다. ST의 보드별 startup 파일은 `firmware/vendor/`에 출처·라이선스와 함께 들어 있습니다. 링커 스크립트는 `firmware/linker/`에 있으며 G474는 시작 예제에서 일반 SRAM 96KB만 사용합니다. 해당 링커 구성은 Dual-Bank 부트로더나 OTA 배치를 정의하지 않습니다.

LED 주기는 기본 클록과 빌드에 따라 달라지는 바쁜 대기 방식입니다. 보드의 LD2가 PA5에 연결된 기본 점퍼/솔더브리지 구성을 확인하세요. 보드에 다른 펌웨어가 있다면 아래 디버그 실행이 플래시 내용을 덮어씁니다.

## 3. VS Code에서 빌드와 로컬 디버그

1. 저장소 루트를 VS Code에서 열고 추천 확장을 설치합니다.
2. 명령 팔레트에서 `CMake: Select Configure Preset` → `STM32 starters (Debug)`를 선택합니다.
3. `Ctrl+Shift+B` 또는 `Terminal: Run Build Task` → `STM32: Build`를 실행합니다. CMake Tools의 Build 버튼도 사용할 수 있습니다.
4. **해당 보드 하나만** PC에 연결합니다. 외부 전력단을 사용 중이면 출력 상태를 먼저 확인합니다.
5. Run and Debug에서 보드에 맞는 `local ST-LINK (flash)` 구성을 고르고 `F5`를 누릅니다. 이 구성은 빌드한 ELF를 플래시에 쓰고 `main`에서 멈춥니다. Continue 후 LD2를 확인합니다.

`.vscode/launch.json`과 `tasks.json`은 저장소에 공유되며 개인 경로를 포함하지 않습니다. 여러 ST-LINK를 연결한 경우에는 오대상 플래싱을 피하기 위해 사용하지 않을 프로브를 분리하거나, 각 디버그 구성에 OpenOCD의 `adapter serial <시리얼>` 사전 설정을 추가해 보드와 일치하는지 확인하세요.

ST 확장을 이미 사용한다면 해당 확장의 Bundle Manager에서 툴체인을 관리하거나 CubeMX 프로젝트를 열 수도 있습니다. 이 저장소의 제공된 `F5` 구성은 **Cortex-Debug + OpenOCD** 경로이며 ST 확장의 별도 디버거 구성을 자동 생성하지는 않습니다.

## 4. STM32CubeIDE에서 같은 CMake 소스 사용

### CubeIDE 2.x

1. [STM32CubeIDE](https://www.st.com/en/development-tools/stm32cubeide.html)를 설치하고 실행합니다. 이 워크스페이스에서는 설치 여부를 별도로 확인해야 합니다.
2. `File` → `New` → `STM32 Project` → `STM32 Project Create/Import`에서 **STM32 CMake Project / Project with existing CMake sources**를 선택합니다. 메뉴 명칭은 버전에 따라 다를 수 있습니다.
3. Source directory에 **이 저장소 루트**를 선택하고 MCU/보드에서 디버깅할 `STM32G474RETx` 또는 `STM32F103RBTx`를 고릅니다. GCC 툴체인을 선택합니다.
4. CMake 프로젝트의 toolchain file을 `cmake/arm-none-eabi.cmake`로 지정하고 Ninja/Debug로 구성합니다. CubeIDE가 기본 툴체인 설정을 덮어쓰면 해당 CMake 설정에서 이 파일을 명시하고 재구성합니다.
5. 빌드 후 디버그 구성에서 연결된 보드와 일치하는 ELF(`firmware_g474.elf` 또는 `firmware_f103.elf`)를 선택하고 ST-LINK로 실행합니다. CubeIDE의 빌드 출력 위치는 VS Code의 `build/debug`와 다를 수 있으므로 해당 빌드 폴더의 ELF를 선택합니다.

이 경로는 [ST의 기존 CMake 소스 가져오기 안내](https://www.st.com/resource/en/application_note/an5952-how-to-use-cmake-in-stm32cubeide-stmicroelectronics.pdf)를 기반으로 합니다. CubeIDE GUI 가져오기와 실제 보드 디버깅은 이 저장소의 자동 빌드 검증 범위에 포함되지 않습니다.

### 새 CubeMX/HAL 프로젝트를 만드는 경우

CubeIDE 2.x는 CubeMX가 분리되어 있습니다. [STM32CubeMX](https://www.st.com/en/development-tools/stm32cubemx.html)를 별도 설치한 후 Board Selector에서 보드를 선택하고, 프로젝트 생성 형식에서 IDE 버전에 맞게 STM32CubeIDE 또는 CMake를 선택하세요. CubeMX2의 CMake 프로젝트는 CubeIDE 2.1.1 이상의 CMake 가져오기 절차를 사용할 수 있습니다. [ST CubeIDE 2.x 안내](https://community.st.com/stm32-mcus-60/stm32cubeide-2-0-0-workflow-tutorial-160701), [ST CMake 가져오기 예시](https://community.st.com/stm32-mcus-60/how-to-import-a-stm32cubemx2-cmake-project-into-stm32cubeide-164166)

생성 프로젝트는 `firmware/cube-projects/<프로젝트명>/` 같은 별도 폴더에 두세요. 이 폴더는 기본적으로 Git에서 제외됩니다. 팀에서 공유할 프로젝트라면 ignore 정책을 검토하고 `.ioc`, 사용자 코드, 필요한 빌드 설정을 명시적으로 관리해야 합니다. 기존 LED 예제는 CubeMX가 재생성하지 않습니다. CubeMX의 생성 코드 수정은 해당 프로젝트의 `USER CODE` 영역을 사용하고, 자동 생성 전 실제 클록·핀·CAN 설정을 직접 확인하세요.

## 5. RPi에 연결된 보드 원격 디버깅

RPi에 SSH로 접속해, 안전한 상태에서 대상 보드에 맞는 OpenOCD를 실행합니다. 여러 프로브를 연결했다면 실제 ST-LINK 시리얼을 지정하세요.

```bash
# RPi에서 G474RE 예시. F103RB는 target/stm32f1x.cfg 사용.
openocd -c 'bindto 127.0.0.1' -f interface/stlink.cfg \
  -c 'adapter serial <ST-LINK-시리얼>' \
  -f target/stm32g4x.cfg
```

위 명령은 RPi의 로컬 인터페이스에서만 GDB 포트 `3333`을 수신합니다. PC의 다른 터미널에서 SSH 터널을 만드세요.

```powershell
ssh -L 3333:127.0.0.1:3333 pi@<RPi_IP>
```

VS Code에서 대상 보드의 `remote OpenOCD (attach)`를 선택하고 주소에 `127.0.0.1:3333`을 입력합니다. **원격 attach는 펌웨어를 다운로드하지 않으며 연결 중 타깃을 정지할 수 있습니다.** 로컬 ELF는 실제 보드에 실행 중인 펌웨어와 동일한 빌드여야 합니다. 별도 OpenOCD 인스턴스를 동시에 띄운다면 포트도 구분하세요.

## 6. 문제 해결

| 증상 | 확인할 항목 |
| :--- | :--- |
| `arm-none-eabi-gcc` 또는 `openocd` 없음 | Windows에서는 설치 스크립트를 다시 실행. 다른 OS에서는 PATH 확인 |
| CMake가 예전 컴파일러를 사용 | `build/debug/CMakeCache.txt`의 경로를 확인하고 해당 빌드 디렉터리를 정리한 뒤 재구성 |
| ST-LINK 연결 실패 | USB 데이터 케이블·전원·Windows 드라이버·다른 디버거의 점유 확인 |
| 엉뚱한 보드가 동작 | 디버그 대상·ELF·ST-LINK 시리얼 확인. 단일 프로브로 먼저 검증 |
| LED가 켜지지 않음 | 보드 종류·LD2/PA5 기본 연결·플래시 실행 여부 확인 |
| 원격 접속 실패 | RPi의 OpenOCD 실행 상태·포트·SSH 터널 확인 |

상세 오류 분석과 CAN 진단은 [STM32 디버깅 가이드](stm32_디버깅_작업_가이드.md)를 참고하세요. 실습 벤치의 CAN 규약은 [CAN 아키텍처](차량용_CAN_통신_도입_및_아키텍처_설계.md)와 별도 합의가 기준입니다.
