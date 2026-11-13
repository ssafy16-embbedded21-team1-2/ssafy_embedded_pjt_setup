# RPi5 CAN 확장 보드 초기 연결 점검

점검일: 2026-11-13 KST. 대상: `pi32`, Raspberry Pi 5, Seengreat RS485 Dual CAN I의 CAN0.

**결과: HAT의 MCP2515 초기화 시간 초과로 CAN 수신 시험은 아직 수행하지 못했다. RPi 외부 SPI 루프백은 배선 수정 후 9회 모두 통과했다.**
`can-utils` 설치와 부팅 overlay 적용·재부팅은 완료했다. HAT 장착 상태의 마지막 점검에서 `can0`는 생성되지 않았다.
외부 루프백 이후 HAT를 재장착해도 초기화 실패가 재현됐으며, 임시 CAN1 probe도 같은 오류였다(11·13절).
7선 우회 배선에서도 CS 선 누락을 수정한 뒤 재시도했으나 초기화 실패가 계속됐다(15·16절).
이후40핀 재장착 상태의 종합 점검도 수행했다. [40핀 종합 결과](RPi5_CAN_40핀_종합_점검_결과.md)를 참고한다.
STM32 펌웨어의 속도·ID·주기는 사용자 제공 정보이며 실제 수신으로 확인한 값이 아니다.

## 1. 사용자 확인과 시험 목표

| 항목 | 확인 내용 |
| --- | --- |
| 확장 보드 단자 | 물리 CAN0 사용 |
| DIP | 출고 상태에서 바꾸지 않았다고 사용자 확인 |
| STM32 펌웨어 | 사용자가 배선에 맞춰 이미 플래싱 |
| 기대 송신 | 500kbit/s, ID `0x100`, 주기 100ms |
| 미확인 | 실제 DIP별 상태·로직 전압 선택·전원 LED·장착/접점·payload/길이 |

기존 가이드의 `0x510` 송신 예제를 새로 플래싱하지 않았다.
이번 STM32 펌웨어·핀·내용을 SWD로 읽거나 변경하지 않았다.

## 2. 수행한 작업

1. 초기 상태에서 SPI 활성과 `/dev/spidev0.0`, `/dev/spidev0.1`을 확인했다.
2. `can-utils 2023.03-1+b2`를 설치하고 `/usr/bin/candump`, `/usr/bin/cansend`를 확인했다.
3. 출고 CAN0 매핑에 맞춰 기존 부팅 설정을 백업하고 다음 한 줄을 `[all]` 구간에 추가했다.

   ```ini
   dtoverlay=mcp2515,spi0-1,oscillator=16000000,interrupt=25
   ```

4. 12:10 KST에 재부팅했다. boot ID 변경으로 실제 재부팅을 확인했다.
5. 12:11~12:13 KST에 커널·인터페이스·GPIO·서비스 상태를 확인했다.

위 매핑은 [제조사 출고 DIP 설명](https://seengreat.com/wiki/83/rs485-dual-can-i)에 근거한다.
사용자의 실물 스위치가 이 조합과 같은지는 아직 직접 대조하지 않았다.
CAN1·SPI1·RS485 UART 설정은 추가하지 않았다.

| 항목 | 값 |
| --- | --- |
| 백업 디렉터리 | `/var/backups/rpi5-can/20261113T031041Z` |
| 원본 부팅 설정 | 위 디렉터리의 `config.txt.before` |
| 적용 준비 기록 | 위 디렉터리의 `preparation.json` |
| 재부팅 후 점검 원본 | 위 디렉터리의 `verification.json` |
| 변경 전 boot ID | `48321f56-b2a7-4589-b9a9-83035c5b20fe` |
| 변경 후 boot ID | `07d09d68-d4c4-4cb9-a523-a02a9d4c3ac6` |
| 변경 전 config SHA-256 | `26406794e67dc439053cdca9d415740e04e27f8b2996edfc02ee289454aed014` |
| 변경 후 config SHA-256 | `0f850580657343ed14bb505b720450cfec77093ceb4ebf6520ff699bd9afb0df` |

## 3. 실제 오류와 해석

```text
mcp251x spi0.1: probe with driver mcp251x failed with error -110
mcp251x spi0.1: Probe failed, err=110
mcp251x spi0.1: MCP251x didn't enter in conf mode after reset
```

`ip -details link show type can`은 인터페이스를 반환하지 않았다.
SPI0 MISO/MOSI/SCLK의 핀 기능과 GPIO7 선택 핀·GPIO25 입력은 확인했지만, 이는 실제 신호·배선 정상의 증명이 아니다.
`/dev/spidev0.1`이 사라진 것도 MCP2515 초기화 성공을 뜻하지 않는다.

이번 실패는 RPi→확장 보드 MCP2515의 SPI 초기화 단계다.
따라서 이를 STM32 고장·CAN 속도 불일치·종단 문제·Bus-Off의 증거로 해석하지 않는다.
CAN 인터페이스를 올리지 않았고 RPi가 CAN 프레임을 보내지 않았다. 수신 0건이 아니라 **캡처 미수행**이다.

## 4. 다음 현장 확인

스위치 변경·탈착은 RPi와 연결 장비의 전원을 완전히 분리한 뒤 수행한다.

| 확인 | 필요한 정보 |
| --- | --- |
| 제품 일치 | 실물 제품명·리비전이 RS485 Dual CAN I인지 |
| 전원 | 확장 보드 전원 LED, 40핀 연결·높이·접점 상태 |
| 로직 | 전압 선택 스위치가 RPi용 3.3V인지 |
| 선택 핀 | DIP 1~8 또는 P11/P10/P6/P23 등의 실제 ON/OFF |
| CAN0 출고 매핑 대조 | P11 ON·P10 OFF·P6 ON·P23 OFF에 해당하는지 |

출고 상태라는 설명만으로 다른 CS/IRQ를 번갈아 추측 적용하지 않는다.
실물 대조 후 맞는 설정으로 컨트롤러 probe를 다시 확인한다.
`can0` 생성과 `spi0.1` 대응을 확인한 다음에만 500kbit/s로 올리고 `0x100` 수신을 관측한다.
숫자형 DIP만 있으면 제조사 그림과 대응을 확인하고 위치를 임의로 해석하지 않는다.

## 5. 기존 서비스와 원복

- 재부팅 후 Qwen 시스템 서비스는 `active`로 복구됐다.
- Agent 컨테이너는 `healthy`, `/health`는 HTTP 200이었다.
- Agent 응답의 mode는 계속 `fixture`다. 이번 설정을 실제 CAN 공급자 구현 완료로 기록하지 않는다.
- STM32 플래싱·Agent 소스·Qwen 설정 변경은 수행하지 않았다.
- CAN overlay는 다음 하드웨어 확인을 위해 남겨뒀으며 자동 재시작·CAN 링크 활성화 설정은 추가하지 않았다.

원복이 필요하면 먼저 현재 `config.txt`가 위 변경 후 해시와 같은지 확인한다.
이후 사용자가 변경한 내용이 있으면 전체 백업을 덮어쓰지 말고 이번 CAN0 추가 블록만 검토해 제거한다.
추가 변경이 없다면 백업으로 복원하고 재부팅할 수 있다. 이번 점검에서 실제 원복은 수행하지 않았다.

첫 통신 절차: [RPi5–F103 첫 CAN 시험](RPi5_F103_CAN_첫_통신_테스트.md).

## 6. 배선 수정 후 재점검 — 12:17~12:19 KST

사용자가 배선을 수정했다고 알린 뒤 같은 boot ID에서 `spi0.1`의 MCP251x 드라이버 바인딩을 다시 시도했다.
예전 로그만 확인한 것이 아니라 새 probe를 실행했으며, 12:17:24~25의 새 커널 로그에서도 같은 `-110` 시간 초과가 발생했다.
`can0`는 여전히 없어서 500kbit/s 링크 활성화·ID `0x100` 캡처는 수행하지 않았다.

추가로 노출된 `/dev/spidev0.0`에서 100kHz의 MCP2515 READ 명령으로 상태/제어·타이밍 레지스터만 3회 읽었다.
모두 0으로 반환돼 이 경로에서도 MCP2515의 식별 가능한 응답을 확인하지 못했다.
CS0에는 RESET·레지스터 쓰기를 보내지 않았고 부팅 CS/IRQ 설정도 추가로 바꾸지 않았다.
이 결과만으로 보드 불량·GPIO 단락·다른 CS 연결을 확정하지 않는다.

다음 확인은 STM32 CAN 선보다 RPi↔확장 보드의 40핀 장착·로직 전압·실제 DIP 매핑이다.
Agent 컨테이너 `healthy`, Qwen `active`를 재확인했다.
원본: `/var/backups/rpi5-can/20261113T031041Z/recheck-20261113T031723Z.json`.

## 7. 사용자가 제공한 STM32 파일 검토

`C:\Users\SSAFY\Downloads\main.c`, `test.ioc`를 읽었다. 원본 파일은 수정하지 않았고 빌드·플래싱은 수행하지 않았다.
파일 내용의 확인과 실물의 실행·배선 검증은 구분한다.

| 항목 | 코드·IOC에서 확인한 내용 |
| --- | --- |
| MCU | STM32F103RBT6, NUCLEO-F103RB |
| CAN 핀 | PA11=RX, PA12=TX. 실제 GPIO 초기화는 미제공 MSP 코드 대조 필요 |
| 클록 설정 | HSE bypass 8MHz 가정·PLL×9·SYSCLK72MHz·APB1=36MHz |
| CAN 모드·타이밍 | Normal, prescaler4·BS1=15TQ·BS2=2TQ·SJW1 |
| 계산 속도 | `36MHz / [4 × (1 + 15 + 2)] = 500kbit/s`, sample point 약88.9% |
| 송신 | 표준 ID `0x100`, data frame, DLC4, 목표 주기100ms |
| payload | `A5 5A 00 <uint8 생존 카운터>`, 큐 등록 성공 때 카운터 증가 |
| 재전송·Bus-Off 복귀 | `AutoRetransmission=DISABLE`(NART1), `AutoBusOff=DISABLE` |
| UART | USART2 PA2/PA3, 코드에서115200·8N1·흐름제어 없음 |
| 출력 | 부팅 배너, filter/start/notif 결과·BTR·NART, 1초마다 ESR·송수신 카운터 |

배선은 PA12→트랜시버 TXD, 트랜시버 RXD→PA11을 기준으로 대조한다.
HSE 입력이 실제8MHz인지, 실행 빌드가 첨부 소스와 같은지는 아직 확인하지 않았다.
현재 STM32 펌웨어는 첫 시험 가이드의 ID0x510·8B·자동 재전송 활성 예제와 다르므로 별도로 취급한다.

### 7-1. 우선 확인할 인터럽트 경로

`main.c`는 `CAN_IT_RX_FIFO0_MSG_PENDING | CAN_IT_TX_MAILBOX_EMPTY`를 활성화하고
RX/TX/error callback에서 카운터를 갱신한다. 그러나 제공된 `.ioc`에는 CAN 공유 벡터 활성화 항목이 없다.
파일 상단의 NVIC 활성화 가정 주석만으로 실제 활성화를 확인할 수 없다.

- `can.c` 또는 `stm32f1xx_hal_msp.c`의 `HAL_CAN_MspInit()`에서 CAN 클록·PA11/PA12와 NVIC 설정을 확인한다.
- RX0 벡터 `USB_LP_CAN1_RX0_IRQn`, TX 벡터 `USB_HP_CAN1_TX_IRQn` 활성 여부를 확인한다.
- `stm32f1xx_it.c`의 해당 IRQ handler가 `HAL_CAN_IRQHandler(&hcan)`를 호출하는지 확인한다.
- 버스 오류 자체의 추가 알림이 필요하면 SCE 벡터·에러 notification도 별도로 설계한다.
  현재 코드는 RX0/TX notification을 사용하므로 모든 버스 오류가 항상 error callback으로 집계된다고 보지 않는다.

`HAL_CAN_ActivateNotification()`만으로 NVIC·handler 경로가 자동 완성되지 않는다.
NVIC가 빠졌으면 물리 송신과 별개로 `txok`·`rx` 소프트웨어 카운터가 갱신되지 않을 수 있다.
실제 생성된 `can.c`, `stm32f1xx_it.c`가 없어 수동 설정 여부와 전체 빌드는 미확인이다.
[ST HAL의 초기화·NVIC·handler 요구사항](https://github.com/STMicroelectronics/stm32f1xx-hal-driver/blob/master/Src/stm32f1xx_hal_can.c).

### 7-2. 보조 UART에서 받을 다음 증거

115200·8N1의 터미널에서 다음 출력 원문을 보관한다.

```text
=== hw_test CAN normal v1 ===
filter=... start=... notif=... err=... BTR=... NART=...
t=... TEC=... REC=... LEC=... EWG=... EPV=... BOFF=... | txreq=... txok=... ...
```

`start` 실패와 송신 큐 등록 실패·완료 카운터 미갱신을 분리한다.
NART1이므로 상대 ACK가 없을 때 계속 재전송하는 펌웨어로 해석하지 않는다.
`txreq` 증가만으로 전송 성공을 주장하지 않고 실제 호스트 수신·하드웨어 상태·IRQ 설정을 함께 확인한다.
이 UART 로그는 아직 수집하지 않았다. 현재 PC 열거에는 COM1·COM2만 있었고 ST-LINK VCP는 확인되지 않았다.

### 7-3. 입력 식별값

| 파일 | SHA-256 |
| --- | --- |
| `main.c` | `a2d418e4a01e33242cbb2a87b838656ea50b4edf694df1263af7d5b15b28c2a6` |
| `test.ioc` | `4ac8a3d96ea5bb26bad96d6888c965162c259def83909091360a34fa8c414c9e` |

STM32의 위 설정 검토는 RPi의 `mcp251x spi0.1` probe 시간 초과 원인을 해결한 것이 아니다.
RPi↔확장 보드 SPI 경로가 정상화돼 CAN 인터페이스가 생긴 뒤 위 송신값의 실제 수신을 확인한다.

## 8. 저속 SPI 읽기와 RPi 내부 루프백 — 12:59~13:00 KST

사용자가 같은 증상이라고 알린 뒤 boot ID `7aba4a3f-612f-46b4-9c57-b80afded3efa`에서 추가 조사했다.
새 부팅 로그에서도 `mcp251x spi0.1`의 초기화 시간 초과가 확인됐다.

| 시험 | 결과 | 해석 범위 |
| --- | --- | --- |
| CS0·CS1, SPI mode0, 요청 속도100kHz·1MHz, 조합당3회 | CANSTAT/CANCTRL·CNF 레지스터 읽기 모두00 | 속도를 낮춰도 식별 가능한 MCP 응답을 확보하지 못함 |
| RP1 내부 SPI loopback, CS0, 요청 속도100kHz | 송신 `03 0E 00 00`과 수신 일치 | 이 전송에서 RPi 내부 컨트롤러·사용자 SPI 호출 경로 동작 확인 |
| MCP 드라이버 재바인딩 | errno110, CAN 인터페이스 없음 | CAN 프레임 시험은 여전히 미수행 |

CS1은 실패 상태의 장치에 한해 임시로 spidev를 바인딩해 읽었고, 이후 override를 비우고 MCP 드라이버로 복귀를 시도했다.
내부 loopback의 SPI mode도 원래0으로 복원했다. 부팅 설정 해시는 변경 전후 같았고 재부팅·STM32 플래싱·CAN 송신은 수행하지 않았다.
MCP 명령은 READ만 사용했다. 드라이버 자체 probe의 reset 동작과 이 원시 읽기 시험은 구분한다.

내부 loopback은 외부 GPIO·40핀 접점·HAT 전원·MISO 경로를 검증하지 않는다.
따라서 보드 불량이나 RPi 정상 전체를 확정하지 않고, 다음 단계에서 외부 핀 경로를 분리한다.
SPI 요청 성공만으로 slave 응답 성공을 보장하지 않는다는 점도 함께 적용한다.
[Linux SPI 사용자 API](https://docs.kernel.org/spi/spidev.html).

아래는 외부 루프백의 준비 절차다. 이후 수행 결과는 10절에 기록했다.

1. RPi를 정상 종료하고 전원을 분리한다.
2. 확장 보드를 RPi의 40핀에서 완전히 분리한다.
3. RPi 물리 핀19(GPIO10/MOSI)와21(GPIO9/MISO)을 점퍼로 연결한다. BCM19/21과 혼동하지 않는다.
4. 전원을 켠 뒤 SPI_LOOP 모드를 끈 일반 SPI 전송으로 송수신 일치를 확인한다.
5. 시험 후 다시 종료·전원 분리하고 점퍼를 제거한 뒤 보드를 복원한다.

외부 루프백도 통과하면 RPi의 이 두 핀 경로가 동작한다는 근거를 얻고 HAT의 전원·CS·접점·칩 응답을 집중 조사한다.
실패하면 먼저 점퍼·번호·핀 기능을 대조하고 RPi GPIO 경로를 조사한다. 어느 결과도 단독으로 고장 부품을 확정하지 않는다.

원본 디렉터리: `/var/backups/rpi5-can/spi-isolation-20261113T035932Z/`.
`verification.json`에 원시 읽기·설정 원복, `controller-loopback.json`에 내부 시험 결과를 보관했다.

## 9. MISO 입력 확인과 다음 분리 시험 — 13:07 KST

활성 CAN 장치와 SPI 사용 프로세스가 없는지 확인한 뒤 GPIO9를 잠시 입력으로 바꿔
약한 pull-up/pull-down을 두 번씩 비교했다. 결과는 순서대로 HIGH/LOW/HIGH/LOW였다.
SPI0_MISO의 원래 alternate function과 no-pull 상태로 즉시 복원했다. 출력 구동은 하지 않았다.
이는 GPIO 입력이 이 시험에서 low에 고정되지 않았다는 근거이며 외부 SPI 응답·접점·핀 전체 정상의 보장은 아니다.
원본은 위 증거 디렉터리의 `miso-input-bias.json`이다.

외부 점퍼 시험용 [스크립트](../scripts/poc_rpi_spi_loopback.py)를 준비했다.
HAT를 완전히 분리하고 **RPi 물리 핀19(GPIO10/MOSI)와21(GPIO9/MISO)**를 연결한 뒤에만 실행한다.
그 사이의 짝수 핀20은 GND이며 연결 대상이 아니다. 탈착·점퍼 변경은 전원 분리 상태에서 한다.

```bash
python3 scripts/poc_rpi_spi_loopback.py --jumper-ready
```

RPi에 준비한 사본은 `/home/pi/.local/state/rpi5-can/poc_rpi_spi_loopback.py`다.
스크립트는 내부 SPI_LOOP를 사용하지 않고 일반 mode0에서 요청 속도100kHz로 세 패턴을3회씩 비교한다.
`--jumper-ready`가 없으면 전송하지 않는다. 이 플래그는 사용자의 물리 상태 확인이며 자동 센서 검증이 아니다.
준비 당시 외부 점퍼 시험은 미수행이었다. 이후 실제 실행·배선 수정 후 결과는 10절과 같다.

## 10. 외부 루프백과 점퍼 수정 후 재시험 — 13:10~13:12 KST

사용자가 HAT를 40핀에서 완전히 분리하고 외부 점퍼를 연결했다고 확인한 뒤 시험했다.
최초 시험에서는 9회 모두 수신값이 `00 00 00 00`이었다.
이어서 GPIO9·GPIO10을 모두 입력으로 둔 약한 pull-up/pull-down 시험에서
한쪽 핀의 HIGH가 반대쪽으로 전달되지 않았다. 두 핀의 원래 SPI 기능·no-pull 상태는 복원했다.
출력으로 강제 구동하지 않았으며, 이 결과만으로 RPi 고장을 확정하지 않았다.

사용자가 핀 연결 오류를 수정했다고 알린 뒤 13:12:04 KST에 같은 외부 루프백 스크립트를 재실행했다.

| 항목 | 결과 |
| --- | --- |
| boot ID | `61403518-0e92-40fc-af14-ed100f8015cb` |
| 장치·모드 | `/dev/spidev0.0`, mode0, 내부 SPI_LOOP 비활성 |
| 요청 속도 | 100kHz |
| 패턴 | `03 0E 00 00`, `03 28 00 00`, `03 0E 5A A5` |
| 반복 | 패턴별 3회, 총 9회 |
| 결과 | **9회 모두 TX와 RX 일치, passed** |

수정 후에는 RPi의 MOSI 출력·점퍼·MISO 입력을 거친 실제 데이터 전달을 확인했다.
이 시험은 HAT를 분리한 상태이므로 HAT의 MCP2515·전원·CS·IRQ 경로나 CAN 통신 정상 여부를 증명하지 않는다.
SCLK 신호의 외부 접점도 MOSI–MISO 점퍼만으로 별도 검증된 것은 아니다.
최초 외부 루프백 실패는 핀 연결 수정으로 해소됐지만, HAT 초기화 시간 초과 원인은 아직 미확정이다.

다음 순서로 HAT 시험을 재개한다.

1. RPi를 정상 종료하고 전원을 분리한다.
2. **물리 핀19–21 루프백 점퍼를 반드시 제거한다.**
3. HAT를 40핀에 다시 장착하고 전원을 켠다.
4. 새 부팅 로그의 MCP2515 probe 결과와 `can0` 생성을 확인한다.
5. `can0`가 생성되면 500kbit/s에서 STM32의 ID `0x100` 수신을 관측한다.

이 재시험에서 부팅 설정·STM32 펌웨어·Agent 코드를 변경하지 않았다.
최초 시험과 입력 확인 원본: `/var/backups/rpi5-can/external-loopback-20261113T041023Z/`.
수정 후 통과 원본: `/var/backups/rpi5-can/external-loopback-20261113T041204Z/`의
`spi-loopback.json`, `context.json`.

## 11. HAT 재장착 후 재현 확인

사용자가 HAT를 다시 연결했다고 알린 뒤 boot ID `286121ff-751e-4006-92b1-c4b5230cea33`에서 점검했다.
RPi의 `NTPSynchronized=no` 상태였고, 이 부팅의 표시 시각이 직전 시험보다 이르게 나타났다.
따라서 앞 절과의 순서는 사용자 작업·boot ID로 구분하고 표시 시각만으로 정렬하지 않는다.

| 점검 | 결과 |
| --- | --- |
| 새 부팅의 MCP2515 probe | conf mode 진입 실패, errno110 |
| 재바인딩 probe | 새 커널 로그에서도 같은 실패 재현 |
| CAN 인터페이스 | 없음 |
| CS0·CS1 읽기 | 요청 속도100kHz·1MHz, 레지스터2종·각3회, 총24회 모두00 |
| 부팅 설정 SHA-256 | 기존 변경 후 해시와 동일 |
| 전압 부족·스로틀링 플래그 | `throttled=0x0`. HAT 내부 전압의 직접 측정 결과는 아님 |
| 기존 서비스 | Qwen 서비스 active, Agent 컨테이너 healthy |

CS1 원시 읽기에는 실패 상태의 장치만 임시 spidev로 바인딩했고, 종료 시 해제·override 복원을 수행했다.
드라이버 바인딩 재시도 외의 원시 명령은 READ만 사용했다. 내부·외부 SPI 루프백은 재장착 상태에서 실행하지 않았다.
CAN 링크 활성화·STM32 플래싱·부팅 설정 변경은 수행하지 않았다.
원본: `/var/backups/rpi5-can/hat-reseat-20261113T041137Z/verification.json`.

RPi의 외부 MOSI–MISO 경로 통과와 HAT의 SPI 응답 실패를 분리해 해석한다.
우선 HAT의 로직 전압·CAN0 CS 선택·40핀 접점·MCP2515 전원/RESET/클록 경로를 확인한다.
IRQ 매핑도 대조하되, 현재 오류만으로 IRQ 오류나 HAT 불량을 확정하지 않는다.
CANH/CANL·종단·STM32 속도 조정으로 이 SPI 초기화 성공 여부를 판단하지 않는다.

### 11-1. DIP 숫자 안내 정정

대화 중 CAN0를 DIP 1~4번으로 안내한 부분을 정정한다.
[제조사 V1.2 회로도](https://seengreat.com/upload/file/83/RS485-Dual-CAN-I-V1.2.pdf)의 S1은 아래와 같다.

| S1 번호 | 선택 핀 이름 | CAN0 출고 상태 |
| --- | --- | --- |
| 8 | P11 = BCM7 / SPI0 CS1 | ON |
| 7 | P10 = BCM8 / SPI0 CS0 | OFF |
| 6 | P6 = BCM25 / INT0 | ON |
| 5 | P23 = BCM13 / INT0 | OFF |

실물 리비전과 인쇄를 우선 대조한다. CAN0 선택의 기준은 `P11 ON/P10 OFF/P6 ON/P23 OFF`이며,
숫자 방향이 불명확하면 8개 전체 상태나 실물 사진으로 확인한다.
로직 스위치는 RPi용3.3V인지 확인한다. 실제 스위치·접점·HAT 전원 측정은 아직 미확인이다.

## 12. 사용자 DIP 상태 확인과 다음 전원 점검

사용자가 다음 실제 스위치 상태를 알려줬다.

| 표기 | P11 | P10 | P6 | P23 | P0 | P1 | P3 | P5 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 사용자 확인 | ON | OFF | ON | OFF | ON | OFF | OFF | ON |

CAN0 부분은 현재 overlay의 `spi0-1,interrupt=25`와 일치한다.
따라서 지금은 DIP를 임의로 바꾸지 않고 전원·로직 전압·접점을 확인한다.
CAN1 부분도 제조사 출고 조합과 같지만, CAN1용 SPI1·overlay는 아직 활성화하지 않았다.
원격으로 실제 장치 트리도 읽어 CS1(`reg=1`)·IRQ25·SPI 최대10MHz를 확인했다.
기존 `nospi10` overlay 설명은 Pi5의 SPI10 장치 비활성화이며, SPI0 CS1을 끄는 설정으로 해석하지 않는다.

이후 사용자가 로직 전압 스위치는3.3V이며 멀티미터는 사용할 수 없다고 확인했다.
이는 선택 위치의 확인이며 실제 공급 전압의 측정은 아니다.
회로도에서 MCP2515 U4/U5의 VDD와 RESET 풀업은 `V-IO`에 연결돼 있다.
따라서 RPi 자체의 `throttled=0x0`만으로 MCP2515 전원을 정상이라고 판단하지 않는다.
또한 회로도의 전원 LED D7은 절연측 `3V3-T/GND-T` 회로에 있어,
LED가 켜졌다는 사실만으로 논리측 `V-IO` 전압을 확정할 수 없다.

전압 측정 시 논리측 GND와 절연측 `GND-T`·CAN 단자의 `PGND`를 구분한다.
접점 저항·도통 확인은 RPi와 연결 장비의 전원을 분리한 뒤 수행한다.
위 항목은 다음 점검 계획이며 실제 전압·도통 측정값은 아직 수집하지 않았다.

## 13. CAN1 임시 초기화로 채널 비교 — RPi 표시 시각13:15 KST

멀티미터 없이 가능한 채널 비교를 위해 SPI1을 임시로 활성화했다.
기존 SPI1 장치·런타임 overlay가 없고 GPIO17/18/19/20/21/24의 consumer가 없는지 먼저 확인했다.
런타임 overlay를 아래 순서로 적용하고 역순으로 제거했다. `config.txt`에는 추가하지 않았다.

```text
spi1-2cs
mcp2515 spi1-1 oscillator=16000000 interrupt=24 speed=1000000
```

제조사 출고 CAN1 DIP와 일치하는 SPI1 CS1·IRQ24를 사용했다.
SPI 최대 속도는1MHz로 제한했고 CAN 링크를 올리거나 CAN 프레임을 송신하지 않았다.
커널 로그에서 13:15:27·13:15:51의 두 CAN1 probe 모두 아래 오류로 끝난 것을 확인했다.
probe 도중의 driver symlink만으로 초기화 성공을 판정하지 않았다.

```text
mcp251x spi1.1: MCP251x didn't enter in conf mode after reset
mcp251x spi1.1: Probe failed, err=110
mcp251x spi1.1: probe with driver mcp251x failed with error -110
```

두 채널에서 같은 초기화 오류가 관측됐다. 공통 `V-IO` 전원·40핀 접점 등을 우선 확인할 근거지만,
RPi의 SPI1 신호·각 채널 클록·칩 상태까지 검증된 것은 아니므로 HAT 불량을 확정하지 않는다.
전압 스위치3.3V·DIP 일치만으로 실제 공급 전압과 접점 상태를 증명할 수 없다.
멀티미터가 없어 다음 물리 확인은 보드 장착·핀 정렬·쿨러 간섭 여부의 사진 대조다.

시험 후 런타임 overlay 없음·SPI1 장치 제거를 확인했고 GPIO17~21·24를 원래 `no/pd`로 복원했다.
부팅 설정 해시는 기존과 같고 Qwen active·Agent healthy였다.
overlay 적용 시 커널의 속성 제거 관련 메모리 경고가 기록됐다. 반복 적용은 추가하지 않았다.

원본:

- `/var/backups/rpi5-can/can1-isolation-20261113T041527Z/verification.json`
- `/var/backups/rpi5-can/can1-isolation-wait-20261113T041551Z/verification.json`
- 위 두 번째 디렉터리의 `final-restoration.json`에 완료 오류 로그·핀 복원·서비스 상태를 보관했다.

## 14. 사진 대조와 40핀 경로 우회 시험 준비

사용자가 윗면·옆면 사진을 제공했고 DIP는 앞서 알린 상태가 맞다고 재확인했다.
윗면 사진에서 DIP 조작부가 같은 위치처럼 보인다는 대화상 추정은 설정 오류의 근거로 채택하지 않는다.
옆면에서 보드가 크게 기울어진 모습은 보이지 않지만, 검은색 커넥터 내부의 접점·도통과 쿨러 간섭 유무를 확정할 수 없다.

사용자가 짧은 암–암 점퍼선7개를 사용할 수 있다고 확인해 HAT의 제어 헤더를 통한 우회 시험을 준비했다.
사용자의 후속 부팅 ID `963d115c-fb14-4664-a8da-a027c1ac8a38`에서도 MCP2515 초기화 오류와 CAN 인터페이스 미생성을 확인했다.
다음 부팅의 점퍼선 시험을 위해 CAN0 overlay에만 `speed=1000000`을 추가했다.
이 설정은 SPI 최대 속도이며 CAN 버스의500kbit/s 설정과 별개다.

```ini
dtoverlay=mcp2515,spi0-1,oscillator=16000000,interrupt=25,speed=1000000
```

| 항목 | 값 |
| --- | --- |
| 백업·준비 기록 | `/var/backups/rpi5-can/direct-header-prep-20261113T042222Z/` |
| 변경 전 설정 | 위 디렉터리의 `config.txt.before` |
| 준비 기록 | 위 디렉터리의 `preparation.json` |
| 변경 후 SHA-256 | `7bb441f8fa1fbca69162da0b0c90be223f477b5ca20da9246910c4d5c1bed73d` |
| 재부팅·실제 우회 배선 | 준비 시점에는 미수행 |

### 14-1. 전원 분리 후 연결할 7개 선

정상 종료 후 RPi 전원을 분리한다. HAT는 RPi의40핀과 완전히 분리하고 비전도성 받침 위에 둔다.
HAT 사진 왼쪽의 노란색 **12핀 제어 헤더**에서 아래 인쇄명을 찾아 연결한다.
40핀 헤더·초록색 CAN 단자·DC7–28V 입력 단자와 구분한다.

| RPi 물리 핀 | RPi 기능 | HAT 노란색 제어 헤더 인쇄 |
| --- | --- | --- |
| 2 | 5V | 5V |
| 6 | GND | GND |
| 19 | BCM10 / MOSI | MOSI |
| 21 | BCM9 / MISO | MISO |
| 23 | BCM11 / SCLK | SCLK |
| 26 | BCM7 / SPI0 CS1 | CS0 |
| 22 | BCM25 / IRQ | INT0 |

여기서 **HAT의 `CS0`는 물리 CAN0 컨트롤러의 선택 신호 이름**이다.
RPi의 CS0(GPIO8·물리24번)를 뜻하지 않는다. 기존 `spi0-1` 설정을 유지하므로 RPi 물리26번을 연결한다.
HAT의 `GND`는 이 제어 헤더의 논리측 GND이며 CAN0 단자의 `G`와 구분한다.
3.3V 로직 선택과 DIP는 유지한다. MOSI–MISO 루프백 점퍼는 연결하지 않는다.
[제조사 제어 헤더 P7·S1 회로도](https://seengreat.com/upload/file/83/RS485-Dual-CAN-I-V1.2.pdf).

배선 후 부팅해서 새 로그와 `can0` 생성을 확인한다. 이 시험의 성공 기준은 MCP2515 probe이며,
STM32 프레임 수신·CAN 물리 통신 성공 여부는 이후 별도로 검증한다.
초기화가 성공하면 40핀 경로·접점 또는 속도 조건을 추가로 분리한다.
커넥터 경로와 SPI 최대 속도가 함께 바뀌므로 성공만으로 커넥터 불량을 확정하지 않는다.
실패하면 공통 전원·RESET·클록·실제 SPI 파형 측정이나 정상 장비와의 교차 시험이 필요하다.

## 15. 우회 배선 지시 후 첫 점검과 MISO 바이어스 비교

사용자의 점검 요청 후 boot ID `a011f596-3872-437c-9c94-f2f07fc407cb`에서 확인했다.
SPI 최대1MHz 설정은 장치 트리에도 적용돼 있었지만 CAN 인터페이스는 없었다.
10kHz·100kHz·1MHz의 MCP2515 READ에서00·FF 등의 값이 나왔고 유효하고 일관된 레지스터 응답을 확보하지 못했다.

추가로 SPI alternate function을 유지한 GPIO9에 약한 pull-down/pull-up을 적용해100kHz로 읽었다.
pull-down에서는6회 모두 `00 00 00 00`, pull-up에서는6회 모두 `FF FF FF FF`였다.
이는 전송 중 MCP2515가 RPi MISO 입력을 유효하게 구동하지 못하는 상태와 일치하지만,
어느 선의 단선·미접속 또는 어떤 전원/CS/클록 문제가 원인인지는 이 결과로 구분하지 못한다.
GPIO9는 `a0/pn`으로 복원했고 임시 spidev 바인딩·override도 복원했다.

이후 사용자가 물리26번 CS 선이 빠져 있었다고 확인했다.
따라서 **이 절의 결과로 40핀 커넥터 경로 우회 시험을 정상 배선 상태에서 완료했다고 판단하지 않는다.**
CS 재연결 후 결과는16절에 기록한다.

원본:

- `/var/backups/rpi5-can/direct-header-check-20261113T042614Z/verification.json`
- `/var/backups/rpi5-can/direct-header-miso-bias-20261113T042703Z/verification.json`

## 16. 물리26번 CS 재연결 후 재시험 — RPi 표시 시각13:28 KST

사용자가 빠진26번 선을 다시 연결했다고 알린 뒤 같은 boot ID에서 MCP251x 드라이버를 새로 바인딩했다.
기존 로그만 조회한 것이 아니라13:28:18~19의 새로운 probe 실패를 확인했다.

| 점검 | 결과 |
| --- | --- |
| 드라이버 재바인딩 | errno110, conf mode 진입 실패 |
| CAN 인터페이스 | 없음 |
| 100kHz CANSTAT/CANCTRL 읽기, no-pull | 최초3회·복원 후3회 모두00 |
| 같은 읽기, 약한 pull-down | 3회 모두00 |
| 같은 읽기, 약한 pull-up | 3회 모두FF |
| 시험 후 MISO 기능 | `GPIO9=a0/pn` 복원 |
| CS 재확인 | GPIO7 출력 idle HIGH. HAT까지의 실제 신호 전달을 측정한 것은 아님 |
| HAT 전원 LED | 사용자 확인: 7선 연결 상태에서 PWR 켜짐 |

CS 재연결 후에도 정상 MCP2515 응답은 확인되지 않았다.
LED는 절연측 전원 표시이므로 MCP2515의 `V-IO` 정상 전압을 직접 증명하지 않는다.
다음은 실제7선 양 끝의 연결과 접점을 사진으로 대조한다.
특히 물리21번→`MISO`(`MISO-1` 아님), 물리23번→`SCLK`, 물리26번→`CS0`를 확인한다.
현재 결과만으로 HAT 불량·40핀 커넥터 불량·특정 점퍼선 단선을 확정하지 않는다.
CAN 링크 활성화·송신·STM32 플래싱·추가 부팅 설정 변경은 수행하지 않았다.

원본:

- `/var/backups/rpi5-can/cs-reconnected-20261113T042819Z/initialization.json`
- `/var/backups/rpi5-can/cs-reconnected-read-20261113T042841Z/verification.json`

## 17. MOSI/MISO 수정 후 재시험 — RPi 표시 시각16:52~16:54 KST

사용자가7선 우회 연결에서 MOSI/MISO를 수정했다고 확인했다.
새 boot ID는 `872735f0-2cd3-4cf8-9b55-cb3b4524ad77`다.
사진에서 추정한 선 위치와 사용자의 수정 확인은 전기적 도통 측정 결과와 구분한다.

| 점검 | 결과 |
| --- | --- |
| 부팅 probe 및 새 재바인딩 | MCP2515 conf mode 진입 실패, errno110 |
| 100kHz·1MHz, 레지스터2종·각3회 | 총12회 모두00 |
| 100kHz MISO 약한 pull-down 읽기 | 6회 모두00 |
| 100kHz MISO 약한 pull-up 읽기 | 6회 모두FF |
| CAN 인터페이스 | 없음 |
| RPi 전압 부족·스로틀링 플래그 | `throttled=0x0` |

MOSI/MISO 수정 확인 후에도 MISO 값이 약한 입력 바이어스를 따라가며 유효한 MCP2515 응답은 확보하지 못했다.
이 결과는 수신 경로가 칩에서 구동되지 못하는 상태와 일치하지만,
MISO 단선·CS 미전달·전원/RESET/클록 문제 중 원인을 확정하지 않는다.
GPIO9는 `a0/pn`으로 복원했고 임시 spidev와 override도 원복했다.
부팅 설정·STM32 펌웨어는 추가 변경하지 않았고 CAN 송수신 시험은 수행하지 않았다.

다음에는 정상 동작을 확인한 점퍼선으로 MISO 경로를 교체하거나 정상 HAT/RPi와 교차 시험한다.
전원/RESET·SPI 신호의 확정에는 실제 전압·파형 측정이 필요하며 현재 멀티미터는 사용할 수 없는 상태다.

원본:

- `/var/backups/rpi5-can/latest-can0-retest-20261113T075259Z/verification.json`
- `/var/backups/rpi5-can/mosi-miso-corrected-bias-20261113T075402Z/verification.json`

## 18. 후속 재시험 — boot ID 기준

사용자의 추가 점검 요청 후 새 boot ID `944de974-b1ab-4426-a48f-fd845374dfcf`에서 시험했다.
정확히 어떤 선을 교체했는지는 확인되지 않아 MISO 점퍼선 교체 완료로 기록하지 않는다.
RPi 표시 시각이 직전 절보다 이르게 나타나므로 시험 순서는 boot ID와 요청 순서로 구분한다.

- 설정 해시는 `7bb441f8fa1fbca69162da0b0c90be223f477b5ca20da9246910c4d5c1bed73d`로 유지됐다.
- CS1에서100kHz·1MHz로 레지스터2종을 각3회 읽었고 총12회 모두00이었다.
- 새 재바인딩에서도 conf mode 진입 실패·errno110이 발생했고 CAN 인터페이스는 없었다.
- 임시 spidev와 override를 원복했다. CAN 송수신·플래싱·추가 설정 변경은 수행하지 않았다.
- 이번 시험에서 약한 풀업·풀다운 비교는 반복하지 않았다. 이전 비교 결과를 이번 측정으로 혼동하지 않는다.

원본: `/var/backups/rpi5-can/can0-followup-20261113T075308Z/verification.json`.
현재 결과로 HAT 고장을 확정하지 않는다. 후속 원인 분리는 전원/RESET 전압·SPI 파형 측정 또는 정상 장비와의 교차 시험으로 진행한다.

## 19. 40핀 재장착 상태의 종합 점검

사용자가 HAT를40핀으로 다시 연결하고 가능한 점검을 요청했다.
boot ID `07694307-f288-4da4-8e2b-b42e58f3dc68`에서 하드웨어 SPI0/1의 모드·CS·속도 비교와 RESET,
RP1 내부 루프백, 하드웨어 SPI와 독립적인 GPIO 직접 제어 SPI0/1을 수행했다.
RP1 내부 루프백은6회 통과했지만 칩 읽기는 하드웨어132회·GPIO 직접 제어48회 모두 유효 응답을 확보하지 못했다.
임시 설정을 제거하고 컨트롤러·핀·서비스·부팅 설정 해시를 확인했다.

범위·원본·판별 한계·다음 측정은 [40핀 종합 점검 결과](RPi5_CAN_40핀_종합_점검_결과.md)에 정리했다.
