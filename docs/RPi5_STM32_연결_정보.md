# RPi5에 연결된 STM32 보드 수집 기록

수집 시각: 2026-11-05 15:44 KST. `pi@100.92.169.70`에 SSH로 접속해 확인한 시점의 정보입니다. 이후 보드나 USB 포트를 바꾸면 연결 정보가 달라질 수 있습니다.

## 확인 결과

USB에서 ST-LINK 한 대를 확인했고, 해당 프로브를 통해 NUCLEO-F103RB의 MCU 식별 정보와 메모리를 읽었습니다. 펌웨어 쓰기·삭제, MCU 리셋·정지 명령은 실행하지 않았습니다. SWD 조회 전후 실행 상태는 모두 `RUNNING`이었습니다.

| 항목                  | 수집 결과                            | 확인 방법                                       |
| --------------------- | ------------------------------------ | ----------------------------------------------- |
| RPi 호스트            | `pi32`, `aarch64`                    | `hostname`, `uname -m`                          |
| SSH 주소              | `pi@100.92.169.70`                   | 실제 SSH 접속                                   |
| 보드                  | `NUCLEO-F103RB`                      | PyOCD 보드 식별, ST-LINK 볼륨 이름              |
| MCU                   | `STM32F103RB`                        | 보드 식별 정보와 아래 MCU 조회 결과를 함께 확인 |
| CPU                   | Arm Cortex-M3, r1p1                  | CPUID `0x411FC231`                              |
| Flash                 | 128 KiB, 131,072 바이트              | `st-info`, Flash 크기 레지스터                  |
| Flash 페이지          | 1,024 바이트                         | `st-info`                                       |
| SRAM                  | 20 KiB, 20,480 바이트                | `st-info`                                       |
| Device ID             | `0x410`                              | `st-info`, DBGMCU_IDCODE 하위 12비트            |
| Revision ID           | `0x2003`                             | DBGMCU_IDCODE 상위 16비트                       |
| DBGMCU_IDCODE 전체 값 | `0x20036410`                         | SWD 메모리 읽기                                 |
| MCU 실행 상태         | 조회 전 `RUNNING`, 조회 후 `RUNNING` | PyOCD attach 접속                               |
| 조회 시 SWD 주파수    | 1 MHz                                | 이번 접속에 지정한 값                           |

STM32F103RB의 Cortex-M3, Flash 128 KiB, SRAM 20 KiB 사양은 [ST 제품 정보](https://www.st.com/en/microcontrollers-microprocessors/stm32f103rb.html)와도 일치합니다. MCU의 실제 동작 클록은 이번에 측정하지 않았습니다.

## ST-LINK 및 USB 연결

| 항목                            | 수집 결과                                                                             |
| ------------------------------- | ------------------------------------------------------------------------------------- |
| 디버거                          | ST-LINK/V2.1                                                                          |
| USB VID:PID                     | `0483:374b`                                                                           |
| ST-LINK 시리얼 번호             | `066AFF545052836687064157`                                                            |
| USB 경로                        | `/sys/bus/usb/devices/1-1`                                                            |
| USB 버스·장치 번호              | Bus 001, Device 002                                                                   |
| USB 인터페이스                  | Debug, Mass Storage, Virtual COM Port                                                 |
| 펌웨어 버전: `st-info` 출력     | `V2J49S36`                                                                            |
| 펌웨어 버전: `DETAILS.TXT` 출력 | `V2J49M36`                                                                            |
| `DETAILS.TXT` 빌드 문자열       | `Sep 11 2026 09:12:02`                                                                |
| 가상 시리얼 포트                | `/dev/ttyACM0`                                                                        |
| 시리얼 번호 기반 포트 경로      | `/dev/serial/by-id/usb-STMicroelectronics_STM32_STLink_066AFF545052836687064157-if02` |
| ST-LINK 가상 저장장치           | `/dev/sda`, 볼륨 `NODE_F103RB`                                                        |
| 저장장치 마운트 경로            | `/media/pi/NODE_F103RB`                                                               |

장치 번호와 `/dev/ttyACM0` 이름은 재연결 시 바뀔 수 있습니다. 시리얼 통신 설정에는 시리얼 번호 기반 경로를 사용할 수 있습니다. UART의 보드 측 배선, 통신 속도와 송수신 동작은 확인하지 않았습니다. ST-LINK 가상 저장장치의 용량은 MCU Flash 용량과 별개입니다.

## MCU에서 읽은 값

MCU 고유 ID와 ST-LINK 시리얼 번호는 서로 다른 식별자입니다. 아래 UID는 주소가 증가하는 순서의 32비트 워드로 기록했습니다.

| 주소         | 내용                                    | 값           |
| ------------ | --------------------------------------- | ------------ |
| `0xE000ED00` | CPUID                                   | `0x411FC231` |
| `0xE0042000` | DBGMCU_IDCODE                           | `0x20036410` |
| `0x1FFFF7E0` | Flash 크기, 16비트, KiB 단위            | `128`        |
| `0x1FFFF7E8` | 96비트 UID의 첫 번째 워드               | `0x066EFF50` |
| `0x1FFFF7EC` | 96비트 UID의 두 번째 워드               | `0x52498366` |
| `0x1FFFF7F0` | 96비트 UID의 세 번째 워드               | `0x87104206` |
| `0x08000000` | Flash 벡터 테이블의 초기 스택 포인터 값 | `0x20005000` |
| `0x08000004` | Flash 벡터 테이블의 Reset 벡터 값       | `0x0800361D` |

Flash 크기와 UID 레지스터의 정의는 [ST RM0008 레퍼런스 매뉴얼](https://www.st.com/resource/en/reference_manual/cd00171190.pdf)을 참고했습니다. 벡터 값만으로 현재 펌웨어의 이름·버전이나 정상 동작 여부를 판단할 수는 없습니다. 펌웨어 전체 덤프는 수행하지 않았습니다.

## 디버깅 도구 상태와 수집 방법

| 도구                  | 확인 결과                                                                      |
| --------------------- | ------------------------------------------------------------------------------ |
| stlink `st-info`      | v1.8.0, MCU 정보 조회 성공                                                     |
| PyOCD                 | 0.46.0, 보드 탐색 및 일반 Cortex-M 타깃으로 메모리 읽기 성공                   |
| OpenOCD               | `/usr/bin/openocd`에 설치됨. 이번 수집에는 실행하지 않음                       |
| 실행 중인 디버그 서버 | 수집 전후 OpenOCD, PyOCD GDB server, ST-LINK GDB server, st-util 프로세스 없음 |
| 사용자 권한           | `pi` 계정에 `dialout`, `plugdev` 그룹 있음. 이번 조회는 sudo 없이 성공         |

주요 조회 명령은 다음과 같습니다. 이 환경의 `st-info`는 `--hot-plug`를 지원함을 확인한 뒤 실행했습니다.

```bash
lsusb
pyocd list
st-info --probe --hot-plug
ls -l /dev/serial/by-id/
cat /media/pi/NODE_F103RB/DETAILS.TXT
```

추가 레지스터 조회에는 PyOCD 세션에 `target_override=cortex_m`, `connect_mode=attach`, `auto_unlock=false`, `resume_on_disconnect=false`, `no_config=true`, `frequency=1000000`을 지정했습니다. 리셋·정지와 자동 잠금 해제를 피하도록 [PyOCD 세션 옵션](https://pyocd.io/docs/options.html)을 설정했습니다.

최초 수집 시에는 보드가 `NUCLEO-F103RB`로 표시되지만 `stm32f103rb` 타깃에 사용 불가 표시가 있었고, `pyocd list --targets`에도 해당 타깃이 없었습니다. 최초 수집은 일반 Cortex-M 타깃으로 진행했으며, 아래 후속 작업에서 전용 타깃 팩을 설치했습니다.

## 후속 작업: F103RB / G474RE 전용 타깃 설치

2026-11-05 15:57 KST에 RPi의 `pi` 사용자 환경에서 다음 팩과 타깃을 확인했습니다. 기존 `Keil.STM32F4xx_DFP` 3.1.1도 유지했습니다.

| 보드          | 설치된 팩                  | PyOCD 타깃 이름 | 검증 범위                                                      |
| ------------- | -------------------------- | --------------- | -------------------------------------------------------------- |
| NUCLEO-F103RB | `Keil.STM32F1xx_DFP` 2.4.1 | `stm32f103rb`   | 타깃 등록, 보드 자동 인식, 전용 타깃 SWD 접속·메모리 읽기 성공 |
| NUCLEO-G474RE | `Keil.STM32G4xx_DFP` 2.2.0 | `stm32g474retx` | 타깃 등록 및 팩 메모리 맵·SVD 정의 존재 확인. 실물 보드 미연결 |

```bash
pyocd pack install stm32f103rb
pyocd pack install stm32g474re
```

설치 후 `pyocd list`에서 기존 F103RB 프로브가 `✔︎ stm32f103rb`로 자동 인식됩니다. 타깃은 보드별로 선택하며, 모든 보드에 하나의 타깃을 강제하는 전역 설정은 추가하지 않았습니다.

F103RB 전용 타깃으로 확인한 결과는 다음과 같습니다.

- 메모리 맵: `IROM1` Flash `0x08000000`부터 128 KiB, `IRAM1` RAM `0x20000000`부터 20 KiB.
- Flash 알고리즘 정의 존재 확인. 실제 쓰기·삭제 동작은 검증하지 않음.
- SVD: `STM32F103xx`, 주변장치 정의 53개. `RCC`, `GPIOA`, `USART2`, `CAN` 정의 포함.
- CPUID `0x411FC231`, DBGMCU_IDCODE `0x20036410`, Flash 크기 128 KiB로 최초 수집 결과와 일치.
- attach 조회 전후 모두 `RUNNING`. 펌웨어 쓰기·삭제·리셋·정지 명령 없이 종료했으며 디버그 서버를 남기지 않음.

SVD 목록은 STM32F103 계열의 정의를 포함하므로 모든 항목이 F103RB 실물에 존재한다는 의미는 아닙니다. 실제 주변장치 지원 여부는 해당 MCU 데이터시트와 대조해야 합니다. 이번 후속 검증은 메모리 맵과 정의 목록 조회까지이며, CAN·UART의 실시간 상태나 송수신 동작은 검사하지 않았습니다.

새 RPi에서 재현하는 설치 옵션과 보드별 접속 예시는 [환경 구축 가이드](setup_guide_rpi5_diagnosis_agent.md)의 PyOCD 설치 절차를 참고하세요.
