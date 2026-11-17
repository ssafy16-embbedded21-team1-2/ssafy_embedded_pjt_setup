# STM32 보드 등록 기록: `NUCLEO-F103RB` (`066CFF535551836687112626`)

> [!IMPORTANT]
> 본 문서의 SWD/pyOCD/st-info 수치는 **2026-11-06T10:33:49+09:00 `pi32` 핫플러그 수집본**([collection.json](collection.json), [commander.txt](commander.txt)) 기준입니다. CAN(`0x100` 100 ms)·UART(`/dev/ttyACM0`) 동작 항목은 **2026-11-17** `hw_test CAN normal v1` 플래시 보드 기준 실측 결과이며, CAN 펌웨어 적용 이후의 SWD 레지스터 재스냅샷은 `미수집`입니다.

---

## 기본 정보

| 항목 | 값 |
| --- | --- |
| 등록 ID / 수집 시각 | `20261106_066CFF535551836687112626` / `2026-11-06T10:33:49.723961+09:00` |
| 보드 / 타깃 MCU | `NUCLEO-F103RB` / `stm32f103rb` (`STM32F1xx_MD`, `chipid: 0x410`) |
| ST-LINK Probe UID | `066CFF535551836687112626` |
| 수집 호스트 환경 | `pi32` (`aarch64`, `Debian GNU/Linux 13 (trixie)`, `python 3.13.5`, `uid=1000(pi)`) |
| 팀 내 역할 매핑 (보드 A / B) | `미확인` (2026-11-16 Jira `PJT-15`/`PJT-16` 기준 보드 A·B 중 개별 시리얼 할당 대기) |
| 원시 증적 파일 | [collection.json](collection.json), [commander.txt](commander.txt) |

---

## 진단 검증 기준 자료

| 구분 | 기준 자료 및 식별 |
| --- | --- |
| pyOCD 수집 메타 | `pyOCD 0.46.0`, `connect_mode: attach`, `frequency: 1000000`, `auto_unlock: false`, `resume_on_disconnect: false` |
| ST-LINK CLI 확인 | `st-info v1.8.0` (`--probe --hot-plug`) |
| CMSIS-Pack (DFP) | `/home/pi/.local/share/cmsis-pack-manager/Keil/STM32F1xx_DFP/2.4.1.pack` |
| CMSIS-Pack SHA-256 | `807ea15da5b172b916bbc47b2b87f1e621240ad208d38e82a417a2ef8191e9d1` |
| SVD 정의 | `STM32F103xx` v`1.3` (`peripheral_count: 53`) |
| 2026-11-17 실측 증적 (원격 `pi32`) | `/var/backups/rpi5-can/recheck-20261117/can0-stm32-rx.json`, `stm32-uart-rx.json`, `can0-bidirectional-test.json` |

---

## MCU 식별 및 메모리

| 항목 | 2026-11-06 측정 값 |
| --- | --- |
| `CPUID` | `0x411FC231` |
| `DBGMCU_IDCODE` | `0x20036410` |
| `FLASH_SIZE_KIB` / `st-info flash` | `0x0080` / `131072` bytes (`pagesize: 1024`) |
| `st-info sram` | `20480` bytes |
| `UID_WORD0` / `UID_WORD1` / `UID_WORD2` | `0x066BFF50` / `0x52498366` / `0x87091724` |
| `INITIAL_SP` / `RESET_VECTOR` | `0x20005000` / `0x080007C5` (2026-11-06 플래시 상태 기준) |
| 코어 상태 (`state_before` / `state_after`) | `RUNNING` / `RUNNING` (비정지 `attach` 확인) |

---

## 전용 타깃과 DFP

- **`pyocd list`**: `stm32f103rb` (`NUCLEO-F103RB`) 지원 확인.
- **`pyocd pack show` 설치 팩**: `Keil.STM32F1xx_DFP 2.4.1` (본 보드 매핑), `Keil.STM32F4xx_DFP 3.1.1`, `Keil.STM32G4xx_DFP 2.2.0`.
- **타깃 오버라이드**: `--target stm32f103rb`로 실행해 `cortex_m` 일반 타깃이 아닌 전용 F103RB DFP·메모리 맵·SVD가 로드됨.

---

## 메모리 맵

| Region | Type | Start | Size | Access |
| --- | --- | --- | --- | --- |
| `IROM1` | `FLASH` | `0x08000000` | `131072` (`0x20000`) | `rx` |
| `IRAM1` | `RAM` | `0x20000000` | `20480` (`0x5000`) | `rwx` |

---

## SVD와 주변장치 정의

- **SVD 모델**: `STM32F103xx` (version `1.3`)
- **주변장치 수**: `53`개

---

## 주변장치 레지스터 조회

> [!NOTE]
> 아래 값은 **2026-11-06T10:33:53+09:00** SWD `attach` 스냅샷이며, 2026-11-13 `hw_test CAN normal v1` 펌웨어 플래시 **이전** 상태입니다. CAN 펌웨어 적용 후 레지스터 재수집은 `미수집`입니다.

| 레지스터 | 2026-11-06 값 |
| --- | --- |
| `RCC_CR` | `0x03076083` |
| `RCC_CFGR` | `0x001D040A` |
| `RCC_APB2ENR` | `0x0000083D` |
| `RCC_APB1ENR` | `0x10020000` |
| `AFIO_MAPR` | `0x02000000` |
| `CAN_MCR` | `0x00010002` |
| `CAN_MSR` | `0x00000C0A` |
| `CAN_ESR` | `0x00000000` |
| `CAN_BTR` | `0x01230000` |
| `SCB_CFSR` | `0x00000000` |
| `SCB_HFSR` | `0x00000000` |

---

## ST-LINK와 USB

| 항목 | 확인 값 |
| --- | --- |
| `lsusb` VID:PID | `0483:374b` |
| `st-info` 펌웨어 / `board_details` | `V2J46S32` / `V2J46M32` (`Mar 11 2025 14:03:24`) |
| VCP 고정 심볼릭 링크 | `/dev/serial/by-id/usb-STMicroelectronics_STM32_STLink_066CFF535551836687112626-if02 -> ../../ttyACM0` |
| 대용량 저장장치 (`lsblk`) | `NODE_F103RB` (`/media/pi/NODE_F103RB`) |

---

## 펌웨어와 주변장치

- **2026-11-17 실측 펌웨어**: `hw_test CAN normal v1` (2026-11-13 플래시 후 2026-11-17 교체 RPi 5 `can0`와 첫 통신 확인).
- **CAN 송신**: `500 kbit/s`, ID `0x100`, DLC `4`, 약 `100.0 ms` 주기 송신(`A5 5A 00 3F`\~`A1` 10초 `candump` 99프레임, `bus-errors 0`).
- **CAN 수신 및 NVIC**: `cansend can0 123#11223344` 송신 시 UART 로그가 `rx=0`에서 `rx=1 last=0x123 dlc=4`로 갱신됨. 실 탑재 바이너리는 `USB_HP_CAN1_TX_IRQn` 및 `USB_LP_CAN1_RX0_IRQn` 인터럽트가 활성 동작함.
- **보조 UART (`/dev/ttyACM0`, `115200 8N1`)**: 매초 `txreq`/`txok` `+10/s` 증가, 과거 미연결 이력인 `errcb=1086` / `errcode=0x00001000` 유지 확인.
- **미확인 항목**: 물리 CAN 핀 리매핑(`PB8`/`PB9` 등 실배선) 대조 및 CAN 트랜시버 세부 배선 기록은 본 레코드 범위에서 `미확인`.

---

## 도구 및 수집 절차

- **2026-11-06 SWD/USB 수집**: `pyocd` (`0.46.0`, `attach` 모드, `1 MHz`), `st-info --probe --hot-plug`, `lsusb`, `lsblk`, `/dev/serial/by-id` 조회를 비파괴 읽기 전용으로 수행([collection.json](collection.json), [commander.txt](commander.txt)).
- **2026-11-17 CAN/UART 연동 검증**: 교체 RPi 5 (`serial: 6f1e588610c80344`) `can0` (`500 kbit/s` `ERROR-ACTIVE`)에서 `candump`, `/dev/ttyACM0` 5초 캡처, `cansend can0 123#11223344` 실행.

---

## 수행 범위와 제약

- 2026-11-06 수집은 `auto_unlock: false`, `resume_on_disconnect: false`, `attach` 모드로 코어를 정지시키지 않고 수행했다.
- 2026-11-17 실측은 시험 펌웨어(`hw_test CAN normal v1`) 기준 단일 노드 연동 결과이며, 보드 A(열관리 제어기)·보드 B(스마트 냉각팬 ECU) 정식 통신 프로토콜 ID 및 임계치는 아직 합의 대기(`TBD`, `PJT-16`)다.
- CAN 펌웨어 적용 이후 상태의 SWD 레지스터 재스냅샷(`CAN_MCR`/`CAN_BTR`/`AFIO_MAPR` 등)은 `미수집` 상태다.

---

## 변경 이력

| 날짜 | 내용 |
| --- | --- |
| 2026-11-06 | `pi32`에서 `NUCLEO-F103RB` (`066CFF535551836687112626`) 최초 SWD/DFP/USB/레지스터 수집([collection.json](collection.json), [commander.txt](commander.txt)) |
| 2026-11-17 | 보드 등록 문서(`README.md`) 생성 및 2026-11-17 교체 RPi 5 기준 `hw_test CAN normal v1` CAN(`0x100`, `0x123`)·UART(`/dev/ttyACM0`) 실측 결과 반영 |
