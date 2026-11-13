# RPi5 확장 보드와 STM32F103 첫 CAN 통신 시험

기준일: 2026-11-13. 목표는 **F103이 100ms마다 송신한 Classic CAN 프레임을 RPi에서 수신**하는 것이다.
AI·Docker·UDS·UART 진단 서버 없이 먼저 물리 통신을 확인한다.
확장 보드는 구매 목록의 Seengreat RS485 Dual CAN I 기준이며 다른 제품이면 DIP·발진자·IRQ를 그대로 적용하지 않는다.

## 1. 현재 확인한 상태

2026-11-13 11:58 KST, `pi32`의 읽기 점검 결과:

- SPI 활성, `/dev/spidev0.0`, `/dev/spidev0.1` 존재.
- `mcp2515` overlay 파일은 있지만 부팅 설정에 적용하지 않았고 CAN 네트워크 인터페이스가 없다.
- `candump`, `cansend` 명령이 없다.
- 사용자가 STM32에는 아직 CAN 펌웨어가 없다고 확인했다. 이 레포 starter도 LED 점멸용이다.
- RPi USB 목록에는 ST-LINK가 없었다. PC에 연결해 CubeIDE로 플래싱해도 CAN 시험은 가능하다.

위 결과는 확장 보드의 SPI 통신 성공을 뜻하지 않는다. 이 문서 작성 중 설정 변경·패키지 설치·재부팅·플래싱·CAN 송신은 수행하지 않았다.

후속 진행(같은 날 12:10~12:13 KST): `can-utils 2023.03-1+b2` 설치와 CAN0 overlay 적용·재부팅을 수행했다.
사용자는 F103 펌웨어를 이미 올렸으며 **500kbit/s·ID `0x100`·100ms 주기 송신**, 물리 CAN0·출고 DIP 상태라고 확인했다.
하지만 MCP2515 SPI probe가 `-110`으로 실패해 `can0`는 생성되지 않았다. CAN 링크 활성화·추가 플래싱·실제 송수신 검증은 미수행이다.
현재 오류·백업·다음 확인은 [초기 연결 점검 기록](RPi5_CAN_초기_연결_점검_기록.md)을 따른다.
아래 `0x510` 코드는 새 시험 펌웨어 예제이며 현재 사용자 펌웨어와 구분한다.

## 2. 전원을 끄고 연결 확인

첫 시험은 확장 보드의 **물리 CAN0 단자 하나만** 사용한다. CAN1·RS485는 연결하지 않는다.

| 연결 | 확인 내용 |
| --- | --- |
| F103 → 트랜시버 전원 | 구매한 SN65HVD230 모듈이면 3.3V와 GND. 다른 모듈은 해당 사양 확인 |
| F103 CAN_TX → 트랜시버 TXD | 기본 PA12 또는 리맵 PB9 중 실제 펌웨어와 같은 핀 |
| 트랜시버 RXD → F103 CAN_RX | 기본 PA11 또는 리맵 PB8 중 실제 펌웨어와 같은 핀 |
| 트랜시버 CANH → 확장 보드 CAN0-H | TX/RX 논리 핀을 CANH/CANL에 직접 연결하지 않음 |
| 트랜시버 CANL → 확장 보드 CAN0-L | RS485 A/B와 혼동하지 않음 |
| 버스 기준 접지 | 확장 보드의 버스측 접지와 STM32 트랜시버 GND를 회로도·실물 표기로 대조 |
| 확장 보드 로직 스위치 | RPi용 3.3V 선택 |
| 종단 | 버스 양 끝 각각 120Ω, 모듈 내장 저항 포함 총 2개 |

확장 보드는 절연 회로가 있으므로 버스측 접지와 RPi 논리측 접지를 구분한다.
배선·스위치는 실물 표기와 [제조사 회로도](https://seengreat.com/upload/file/83/RS485-Dual-CAN-I-V1.2.pdf)를 대조한다.
CAN0 종단을 ON으로 했다면 RPi쪽에 외부 120Ω을 또 추가하지 않는다.
모든 관련 전원·USB 역급전을 분리한 상태에서 CANH–CANL을 재면 두 종단의 합성값은 약 60Ω이다.
약 40Ω은 종단 3개 가능성, 약 120Ω은 종단 하나 또는 분리된 경로 가능성이며 측정값만으로 원인을 확정하지 않는다.
[종단 측정 방법](https://kvaser.com/developer-blog/how-to-test-your-can-termination-works-correctly/).

## 3. RPi의 물리 CAN0를 SocketCAN에 등록

제조사 출고 DIP 조합의 **CAN0에 해당하는 부분**은 아래와 같다.
실물 조합이 다르면 아래 overlay를 그대로 적용하지 않는다.

| 선택 표기 | 상태 |
| --- | --- |
| P11 / P10 | ON / OFF |
| P6 / P23 | ON / OFF |

주의: P11·P10 등은 WiringPi 핀 이름이며 DIP의 숫자 번호가 아니다.
제조사 V1.2 회로도의 S1은 `8=P11, 7=P10, 6=P6, 5=P23`으로 연결돼 있다.
따라서 이 회로도 기준 CAN0 출고 조합은 `8 ON, 7 OFF, 6 ON, 5 OFF`다.
실물 리비전·인쇄 방향을 대조하고 1~4번을 CAN0로 가정하지 않는다.
[회로도 S1](https://seengreat.com/upload/file/83/RS485-Dual-CAN-I-V1.2.pdf).

이 조합은 CAN0의 SPI0 CS1·IRQ BCM25·발진자 16MHz에 대응한다.
첫 시험은 이 한 채널만 등록하므로 SPI1·CAN1·RS485 UART 설정은 필요하지 않다.
[제조사 설정 표](https://seengreat.com/wiki/83/rs485-dual-can-i).

RPi에 SSH로 접속해서 실행한다.

```bash
sudo apt update
sudo apt install -y can-utils
sudo cp -a /boot/firmware/config.txt /boot/firmware/config.txt.can-backup-$(date +%Y%m%d-%H%M%S)
sudo nano /boot/firmware/config.txt
```

기존 설정을 유지하고 `[all]` 적용 구간에 아래 한 줄을 추가한다. `dtparam=spi=on`은 현재 이미 있다.
같은 컨트롤러를 중복 등록하는 overlay는 추가하지 않는다.

```ini
dtoverlay=mcp2515,spi0-1,oscillator=16000000,interrupt=25
```

저장 후 재부팅한다. 재부팅 중 SSH와 Agent·Qwen 연결은 일시 중단된다.

```bash
sudo reboot
```

재접속 후 확인한다.

```bash
ip -details link show type can
readlink -f /sys/class/net/can0/device
journalctl -k -b --no-pager | grep -i mcp251
```

한 채널만 정상 등록됐다면 보통 `can0`와 `spi0.1`의 대응을 확인할 수 있다.
Linux의 `can0` 이름만으로 실물 CAN0 단자임을 단정하지 않고 장치 경로를 함께 확인한다.
드라이버가 점유하면 기존 `/dev/spidev0.1`이 사라질 수 있다.
CAN 인터페이스가 없거나 probe 실패가 있으면 여기서 멈추고 DIP·장착·전원·CS/IRQ·발진자를 확인한다.

인터페이스가 확인되면 normal 모드로 시작한다.

```bash
sudo ip link set can0 down
sudo ip link set can0 type can bitrate 500000 restart-ms 0
sudo ip link set can0 up
ip -details -statistics link show can0
```

초기에는 자동 재시작을 끄고 오류를 관측한다. loopback·listen-only 모드를 별도로 켜지 않는다.
`UP`이나 `ERROR-ACTIVE`만으로 상대와 통신에 성공한 것은 아니다.

## 4. F103 CAN 송신 펌웨어 준비

### 4-1. 이미 올린 펌웨어의 속도·동작 확인

먼저 플래싱에 사용한 프로젝트의 `.ioc` 파일을 CubeMX로 연다.
`Connectivity → CAN → Parameter Settings`에서 아래 값을 기록한다.

| 확인 항목 | 기록할 값 |
| --- | --- |
| Mode | Normal / Loopback / Silent / Silent Loopback |
| Prescaler | 숫자 |
| Time Segment 1 / BS1 | 실제 TQ 수 |
| Time Segment 2 / BS2 | 실제 TQ 수 |
| SJW | 실제 TQ 수 |
| Clock Configuration → APB1 peripheral clock(PCLK1) | MHz |

`CAN 속도 = PCLK1 / [Prescaler × (1 + BS1 + BS2)]`로 계산한다.
예를 들어 PCLK1=36MHz, Prescaler=4, BS1=13, BS2=4이면 500kbit/s다.
APB1 timer clock이 72MHz로 보이더라도 CAN 계산에는 타이머 클록을 넣지 않는다.

코드에서는 CubeMX의 파일 분리 옵션에 따라 `Core/Src/can.c` 또는 `Core/Src/main.c`의
`MX_CAN_Init()`을 찾는다. 예시:

```c
hcan.Init.Prescaler = 4;
hcan.Init.Mode = CAN_MODE_NORMAL;
hcan.Init.SyncJumpWidth = CAN_SJW_1TQ;
hcan.Init.TimeSeg1 = CAN_BS1_13TQ;
hcan.Init.TimeSeg2 = CAN_BS2_4TQ;
```

코드 검색으로 다음 항목도 확인한다.

- `HAL_CAN_Start`: 초기화한 컨트롤러를 실제로 시작하는가?
- `HAL_CAN_AddTxMessage`: 실제 실행되는 송신 코드가 있는가? CAN 핀 설정·초기화만으로 주기 송신하지 않는다.
- `StdId` / `ExtId`, `IDE`, `DLC`: 어떤 형식·ID·길이를 보내는가?
- `HAL_Delay`, tick 조건, 타이머/RTOS 주기: 얼마나 자주 호출하는가?
- 수신 전용이면 `HAL_CAN_GetRxMessage` 또는 수신 callback과 필터·인터럽트 설정을 확인한다.

`.ioc`의 설정과 실제 플래싱한 빌드가 같은지도 확인한다. 파일을 수정했지만 다시 생성·빌드·플래싱하지 않았다면 실행값과 다를 수 있다.
RPi의 SocketCAN이 아직 등록되지 않은 상태에서 F103의 실제 속도를 자동 추정하지 않는다.
다음 정보를 모으면 RPi 속도와 기대 수신을 정할 수 있다.

```text
PCLK1=__MHz, Prescaler=__, BS1=__, BS2=__, Mode=__
CAN 시작 호출=있음/없음, 송신 ID=__, 주기=__ms 또는 수신 전용
```

### 4-2. 새 최소 송신 펌웨어를 만드는 경우

CubeMX에서 F103RB용 프로젝트를 만들고 Toolchain/IDE를 STM32CubeIDE로 선택해 생성한다.
가져오기 방법은 [STM32 빠른 시작](STM32_빠른_시작.md)을 따른다. 기존 LED starter에 아래 코드를 그대로 붙이지 않는다.

| CubeMX 항목 | 설정 |
| --- | --- |
| CAN 핀 | 현재 연결한 RX/TX에 맞춰 PA11/PA12 또는 PB8/PB9 리맵 선택 |
| Mode | Normal |
| Auto Retransmission | Enable |
| Auto Bus-Off | 첫 시험은 Disable, 오류를 기록하고 수동으로 원복 |
| 속도 | 500 kbit/s |
| CAN peripheral clock | Clock Configuration의 실제 APB1 값 확인 |

**CAN 클록이 36MHz일 때만** prescaler=4, BS1=13TQ, BS2=4TQ, SJW=1TQ를 사용할 수 있다.
`36MHz / (4 × (1 + 13 + 4)) = 500kbit/s`다. 클록이 다르면 다시 계산한다.
외부 장비와 통신할 수 있는 클록 정확도·클록 소스를 확인하고 설정 요청값만 믿지 않는다.

CubeMX가 생성한 `main.c`의 `MX_CAN_Init()` 이후 `USER CODE BEGIN 2` 영역에 다음을 넣는다.
예시는 생성된 핸들이 `hcan`인 STM32CubeF1 HAL용이다. 실제 핸들 이름이 다르면 맞춘다.

```c
CAN_TxHeaderTypeDef can_tx = {0};
uint16_t can_seq = 0;
volatile uint32_t can_enqueue_error_count = 0;

can_tx.StdId = 0x510;
can_tx.IDE = CAN_ID_STD;
can_tx.RTR = CAN_RTR_DATA;
can_tx.DLC = 8;
can_tx.TransmitGlobalTime = DISABLE;

if (HAL_CAN_Start(&hcan) != HAL_OK) {
    Error_Handler();
}
```

생성된 `while (1)`의 USER CODE 영역에 다음을 추가한다. 별도의 무한 루프로 감싸지 않는다.

```c
if (HAL_CAN_GetTxMailboxesFreeLevel(&hcan) > 0U) {
    uint32_t mailbox;
    ++can_seq;
    uint8_t data[8] = {
        1, 1,
        (uint8_t)(can_seq & 0xffU), (uint8_t)(can_seq >> 8),
        100, 0, 1, 0
    };
    if (HAL_CAN_AddTxMessage(&hcan, &can_tx, data, &mailbox) != HAL_OK) {
        ++can_enqueue_error_count;
    }
}
HAL_Delay(100);
```

이 코드는 첫 단방향 송신 확인용으로 UART 진단·수신 응용·필터 설정·오류 이력·현장 시나리오 전체를 구현하지 않는다.
`HAL_CAN_AddTxMessage()` 성공은 큐 등록이며 물리 전송 완료가 아니다.
ACK가 없으면 메일박스가 차고 이후 샘플이 전송되지 않을 수 있으므로 STM32 오류 상태와 RPi 수신을 함께 확인한다.
[STM32F1 HAL CAN API](https://github.com/STMicroelectronics/stm32f1xx-hal-driver/blob/master/Inc/stm32f1xx_hal_can.h).

CubeIDE에서 빌드·플래싱한 뒤 실행을 재개한다. 디버거가 main 진입점·중단점에 정지한 상태로 두지 않는다.
이 문서의 코드는 실제 CubeMX 프로젝트의 핀·클록·빌드로 확인한 뒤 사용하며 아직 이 레포에서 빌드·플래싱 검증하지 않았다.

## 5. 실제 프레임 수신 확인

RPi의 `can0`를 먼저 올리고 수신 대기를 시작한 뒤 F103 펌웨어를 실행한다.

```bash
candump can0
```

기대 출력의 데이터 예:

```text
can0  510   [8]  01 01 01 00 64 00 01 00
can0  510   [8]  01 01 02 00 64 00 01 00
```

약 100ms마다 ID `0x510`, 길이 8B, 증가하는 Sequence와 시험값 100을 확인한다.
10초간 로그와 마지막 인터페이스 상태를 보관할 때:

```bash
timeout 10s candump can0 > can-first-rx.log
ip -details -statistics link show can0
```

`timeout`으로 끝났을 때 종료 코드 124는 시간 만료이며 수신 실패 자체를 뜻하지 않는다.
완료 기준은 기대 프레임의 실제 수신·길이·값·Sequence 진행과 지속 갱신이다.
이 송신 펌웨어에는 RPi 명령을 처리하는 응용 수신 기능이 없으므로 `cansend`만으로 양방향 응용 성공을 주장하지 않는다.

## 6. 안 될 때 확인 순서

| 현상 | 다음 확인 |
| --- | --- |
| `can0` 자체가 없음 | overlay 적용·DIP·CS/IRQ·확장 보드 장착/전원·커널 로그 |
| CAN 등록됨, 아무 프레임도 없음 | CubeIDE 실행 재개·핀/리맵·실제 속도·H/L·로직 스위치·종단 |
| STM32 큐가 차고 완료가 없음 | RPi normal/UP·속도·연결·상대 ACK 가능 여부 |
| 오류나 Bus-Off | 양쪽 상태를 저장하고 정상 배선·타이밍을 원복한 뒤 재시작 |
| `0x510`은 보이는데 UI만 없음 | 디코더·schema·표시 필터. 물리 부품 교체부터 하지 않음 |

첫 수신이 확인되면 수신/응답 펌웨어 → 보조 UART 스냅샷 → 사람의 저항 측정 → 현장 고장 케이스 순으로 확장한다.
세부 설계는 [현장 통신 불량 시나리오](CAN_현장_통신불량_진단_시나리오_설계.md)를 따른다.
