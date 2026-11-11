# 02. STM32 CAN과 비트 타이밍

[학습 순서](README.md) · 이전: [버스 기초](01_CAN_버스와_프레임_기초.md) · 다음: [SocketCAN](03_SocketCAN_수집_실습.md)

## 1. 보드별 컨트롤러를 구분한다

| 대상                    | 컨트롤러                      | 먼저 확인할 것                                               |
| ----------------------- | ----------------------------- | ------------------------------------------------------------ |
| NUCLEO-F103RB           | bxCAN, Classic CAN            | APB1 입력 클록·핀/리맵·필터·수신 FIFO·송신 mailbox           |
| NUCLEO-G474RE           | FDCAN, Classic/FD 모드        | FDCAN kernel clock·분주·nominal/data timing·필터·message RAM |
| RPi MCP2515 보드인 경우 | SPI 외부 Classic CAN 컨트롤러 | 실제 발진자·SPI CS/IRQ·device tree·드라이버                  |

CPU 주파수를 그대로 CAN 입력 클록으로 사용하지 않는다. bxCAN의 APB1 클록에 타이머용 배수 규칙을 적용하지 않는다. G474의 FDCAN도 실제 kernel clock 경로와 컨트롤러의 분주를 확인한다. [ST bxCAN normal mode 설명](https://community.st.com/stm32-mcus-60/using-can-bxcan-in-normal-mode-with-stm32-microcontrollers-part-2-152668), [ST G474 데이터시트](https://www.st.com/resource/en/datasheet/stm32g474re.pdf)

## 2. bitrate를 계산한다

Classical/nominal 타이밍의 기본 계산은 다음과 같다. 수치는 실제 시간 구간 수이며 레지스터의 N-1 인코딩과 구분한다.

```text
tq = prescaler / CAN 입력 클록
1 bit = (1 + TSEG1 + TSEG2) × tq
bitrate = CAN 입력 클록 / [prescaler × (1 + TSEG1 + TSEG2)]
sample point = (1 + TSEG1) / (1 + TSEG1 + TSEG2)
```

| 항목              | 뜻                                                       |
| ----------------- | -------------------------------------------------------- |
| Sync segment      | 비트 시작 동기 구간, 1 tq                                |
| TSEG1 / bxCAN BS1 | 샘플 지점 앞의 전파·위상 구간                            |
| TSEG2 / bxCAN BS2 | 샘플 지점 뒤의 위상 구간                                 |
| SJW               | 재동기화 시 조정할 수 있는 폭. 컨트롤러의 허용 범위 확인 |

**계산 연습**: CAN 입력 클록이 실제 36 MHz인 F103 bxCAN을 가정한다.

```text
prescaler = 4, BS1 = 14 tq, BS2 = 3 tq, SJW = 1 tq
총 구간 = 18 tq
bitrate = 36,000,000 / (4 × 18) = 500,000 bit/s
sample point = 15 / 18 ≈ 83.3%
```

이는 계산 예제이며 보드 설정의 확정값이 아니다. HAL 입력과 레지스터 값의 차이, 케이블 지연·발진자 오차·SJW 제약을 확인한다. 상대 노드가 같은 bitrate를 써도 모든 노드가 같은 prescaler를 쓸 필요는 없다. FD의 data timing은 별도로 계산하고 필요 시 지연 보상 조건도 검토한다. [ST RM0008](https://www.st.com/resource/en/reference_manual/rm0008-stm32f101xx-stm32f102xx-stm32f103xx-stm32f105xx-and-stm32f107xx-advanced-armbased-32bit-mcus-stmicroelectronics.pdf), [ST RM0440](https://www.st.com/resource/en/reference_manual/dm00355726-stm32g4-series-advanced-armbased-32bit-mcus-stmicroelectronics.pdf)

## 3. 핀·초기화·수신 경로를 확인한다

1. CubeMX에서 MCU/보드와 CAN 인스턴스를 선택하고 실제 커넥터·핀 충돌·리맵을 대조한다. F103의 기본 CAN PA11/PA12는 USB 등 다른 기능과 충돌할 수 있다.
2. 외부 트랜시버 전원·TXD/RXD·CANH/L·모드 핀을 확인한다. MCU 내부 loopback은 외부 배선 시험을 대체하지 않는다.
3. ID 형식·데이터/RTR·필터·FIFO 배정을 정한다. 초기 수신 성공 후 필요한 ID만 받도록 좁힌다.
4. 컨트롤러 시작, 수신 알림/인터럽트, 오류 알림, 큐·버퍼 크기를 확인한다. bxCAN 필터 설정과 FDCAN 필터 설정을 그대로 복사하지 않는다.
5. ISR은 프레임·시각·오류를 상한이 있는 큐로 전달한다. 긴 로그·블로킹 통신·LLM 추론을 ISR에서 수행하지 않는다. 큐 초과도 별도 카운터로 기록한다.
6. 송신 큐 등록과 실제 송신 완료를 구분하고 mailbox/FIFO 부족·재전송·오류 상태를 기록한다.

구체 핀과 도구 설정은 [개발 환경 가이드](../stm32_개발_환경_구축_가이드.md), [CAN 아키텍처](../차량용_CAN_통신_도입_및_아키텍처_설계.md)를 확인한다. SVD의 계열 공통 주변장치 목록이 실물 MCU의 기능 목록과 같다고 가정하지 않는다.

## 4. 모드별로 검증할 수 있는 범위

| 단계                  | 목표                             | 아직 증명하지 못한 것         |
| --------------------- | -------------------------------- | ----------------------------- |
| 내부 loopback         | 초기화·송수신 코드·필터 확인     | 핀·트랜시버·배선·상대 ACK     |
| MCU ↔ RPi normal mode | 증가 카운터를 양쪽 로그로 대조   | 센서·응용 처리 정확성         |
| STM32 두 대 + RPi     | 송신 책임·주기·필터·누락 관찰    | 최악 부하의 지연·복구 시간    |
| 제어된 실패·부하 시험 | 수신 큐 초과·통신 중단·복귀 정책 | 실제 제품 안전·보안 요구 충족 |

listen-only는 버스를 관찰하지만 ACK를 제공하지 않는다. 검증 환경에서 ACK를 기대한다면 별도의 normal 수신 노드가 필요하다. loopback과 normal+loopback 등의 정확한 모드는 컨트롤러 매뉴얼로 확인한다.

## 5. 버스 부하와 실시간성

8 byte payload만으로 전송 시간을 계산하지 않는다. 헤더·CRC·ACK·프레임 간 간격·스터핑·재전송을 포함해야 한다. 낮은 우선순위 프레임은 중재 대기로 지연되며 프레임 송신 주기와 최악 도착 지연은 다르다.

초기에는 노드별 송신 주기·최대 프레임 수·우선순위·수신 처리량을 표로 만들고, 실제 버스 사용률·최대 수신 간격·큐 초과를 측정한다. 임의의 사용률 한 숫자를 모든 부하에서 안전한 기준으로 단정하지 않는다.

## 6. 실습 기록

| 항목                                 | 기록값 |
| ------------------------------------ | ------ |
| 보드·인스턴스·핀·트랜시버            | 미실습 |
| 실제 입력 클록과 근거                | 미실습 |
| prescaler·TSEG1/2·SJW·계산 bitrate   | 미실습 |
| 모드·필터·FIFO/큐 크기               | 미실습 |
| 실제 수신 로그·송신 완료·오류 카운터 | 미실습 |
| 시험 범위와 남은 미확인 사항         | 미실습 |
