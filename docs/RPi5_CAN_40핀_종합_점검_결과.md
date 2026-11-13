# RPi5 CAN HAT 40핀 종합 점검 결과

점검일: 2026-11-13 KST. 대상: `pi32` / Raspberry Pi 5 / Seengreat RS485 Dual CAN I.

**결과: 현재 40핀 장착 상태에서 CAN0·CAN1 모두 유효한 MCP2515 응답을 확보하지 못했다.**
RPi 내부 SPI 루프백은 통과했지만, 하드웨어 SPI와 독립적인 GPIO 직접 제어에서도 두 채널의 응답이 없었다.
소프트웨어에서 바꿀 수 있는 CS·모드·속도·리셋 경로를 비교했으며, 다음 원인 분리는 실제 전압·파형 측정 또는 정상 장비와의 교차 시험이 필요하다.
이 결과만으로 HAT나 RPi의 특정 부품 불량을 확정하지 않는다.

## 1. 범위와 기준 상태

- 사용자가 HAT를40핀에 다시 장착했다고 확인했다. 이 점검 중 물리 탈착·점퍼 변경은 하지 않았다.
- boot ID: `07694307-f288-4da4-8e2b-b42e58f3dc68`. RPi 표시 시각은 약17:09~17:20 KST다.
- OS: Debian13 / Raspberry Pi 커널 `6.18.60+rpt-rpi-2712`, aarch64.
- 사용자 확인 DIP: `P11 ON / P10 OFF / P6 ON / P23 OFF / P0 ON / P1 OFF / P3 OFF / P5 ON`.
- 사용자 확인 로직 선택:3.3V. 실제 `V-IO` 전압을 측정한 것은 아니다.
- 외부 CAN 송신·STM32 플래싱·재부팅·패키지/커널 업그레이드·부팅 파일 변경은 하지 않았다.

기존 CAN0 설정은 다음과 같다.

```ini
dtoverlay=mcp2515,spi0-1,oscillator=16000000,interrupt=25,speed=1000000
```

## 2. 수행 결과

| 점검 | 실제 수행 | 결과와 한계 |
| --- | --- | --- |
| 장치 트리 | CS·IRQ·클록 공급자·최대 SPI 속도 확인 | CS1, RP1 GPIO25,16MHz 설정,1MHz 설정과 일치. 실제 신호·발진자 측정은 아님 |
| 핀 점유 | GPIO 이름·consumer·alternate function 확인 | SPI0는 해당 컨트롤러가 점유. SPI1 시험용 핀은 사용 전 비점유 확인 |
| CAN0 드라이버 | 새 재바인딩과 컨트롤러 재등록 후 probe | 모두 conf mode 진입 시간 초과, errno110 |
| SPI0 하드웨어 경로 | CS0·CS1 × mode0·3 ×10kHz·100kHz·1MHz·3MHz × 레지스터2종 ×3회 | 총96회, 레지스터 데이터 모두00 |
| CAN1 드라이버 | SPI1과 CAN1 overlay를 임시 적용, probe 완료 대기 | SPI1 CS1·IRQ24에서도 같은 errno110 |
| SPI1 하드웨어 경로 | CS0·CS1 × mode0·3 ×10kHz·100kHz·1MHz × 상태/제어 읽기3회 | 총36회, 레지스터 데이터 모두00 |
| 명시적 칩 리셋 | 각 경로에서 SPI RESET 명령 후 대기·읽기 | 리셋 완료를 증명할 응답 없음. RESET 전송 자체에 slave ACK가 있는 것은 아님 |
| RP1 내부 SPI 루프백 | 두 패턴을 각각3회, 요청 속도100kHz | **6회 모두 송수신 일치**. 외부 SCLK·CS·HAT 전원·접점 정상의 보장은 아님 |
| GPIO 직접 제어 SPI0 | 하드웨어 컨트롤러를 잠시 해제하고 GPIO7/8·9·10·11을 커널 GPIO API로 요청 | 총24회. MISO는 pull-down에서00, pull-up에서FF |
| GPIO 직접 제어 SPI1 | 비점유 GPIO17/18·19·20·21을 커널 GPIO API로 요청 | 총24회. MISO는 pull-down에서00, pull-up에서FF |
| 전원·온도 플래그 | 시작·종료 시 `vcgencmd` 확인 | `throttled=0x0`,47.7→47.2°C. HAT 내부 전압 측정은 아님 |
| 서비스 | 종료 후 상태 확인 | Qwen active, Agent 컨테이너 healthy |

하드웨어 전송의 mode0·3은 CPOL/CPHA가 각각0/0·1/1인 MCP2515 지원 모드다.
SPI0은 CANSTAT/CANCTRL(`0x0E`부터2바이트), CNF3/2/1(`0x28`부터3바이트)을 비교했다.
SPI1은 CANSTAT/CANCTRL을 비교했다. 명령·주소 구간에서 수신되는 바이트와 실제 레지스터 데이터는 구분했다.
[MCP2515 데이터시트](https://ww1.microchip.com/downloads/en/DeviceDoc/MCP2515-Stand-Alone-CAN-Controller-with-SPI-20001801J.pdf).

GPIO 직접 제어 시험은 하드웨어 SPI 주변장치와 `spidev` 데이터 전송을 사용하지 않았다.
CS를 직접 LOW/HIGH로 제어하며 MSB부터 전송했고, GPIO 전환 사이에500µs 대기를 두었다.
실효 SCLK 속도·전압·파형을 계측한 것은 아니다.
각 채널에서 CS 후보2개 × 모드2개 × MISO bias2개 ×3회를 비교했다.

## 3. 결과 해석

### 3-1. 확인된 사실

1. MCP2515용 커널 드라이버와 SPI 장치 등록 경로는 존재하며, 실패 지점은 리셋 후 Configuration mode 확인이다.
2. RPi의 내부 SPI 송수신 시험은 통과했다.
3. HAT 두 채널에서 속도·CS·지원 모드를 바꿔도 MCP2515의 유효한 응답을 얻지 못했다.
4. 하드웨어 SPI 대신 GPIO를 직접 제어해도 MISO 값은 약한 bias를 따라갔다.
5. 현재 `can0`는 없고 CAN 송수신 시험은 시작하지 않았다.

커널은 리셋 후 CANSTAT의 mode 비트가 Configuration 상태인지 확인한다.
현재 오류는 CAN 비트레이트나 상대 장치의 ACK를 검사하다 발생한 것이 아니다.
[현재 커널 계열의 MCP251x 리셋·probe 코드](https://raw.githubusercontent.com/raspberrypi/linux/rpi-6.18.y/drivers/net/can/spi/mcp251x.c).

### 3-2. 가능한 추론

GPIO 직접 제어 결과까지 같으므로 하드웨어 SPI 드라이버의 CS 타이밍이나 고속 전송 조건만으로 발생한 문제일 가능성은 낮아졌다.
현재 관측은 MCP2515가 RPi의 MISO 입력을 유효하게 구동하지 못하는 상태와 일치한다.
우선 확인할 경로는 다음과 같다.

- 두 MCP2515가 공유하는 논리 전원 `V-IO`와3.3V 선택 스위치의 실제 접점.
- 40핀 헤더의 전원·GND·SPI 접점과 연결 경로.
- 각 MCP2515의 RESET·CS·SCLK·SI/SO·발진자 회로.

실제 핀 전압·파형을 측정하지 않았으므로 단선·접촉·리셋 유지·클록 정지·칩 불량 중 하나로 확정하지 않는다.
공통 전원 문제가 두 채널의 동일 증상을 설명할 수 있지만, 이는 측정 전의 가설이다.

### 3-3. 현재 원인 판별에 직접 사용하지 않는 항목

| 항목 | 이번 실패와의 관계 |
| --- | --- |
| WiringPi 설치 | 제조사 사용자 예제용. SocketCAN 커널 드라이버와 이번 `spidev/libgpiod` 시험에는 불필요 |
| UART 콘솔·KGDB·13번 RS485 UART 선택 | UART 경로 설정. 현재 SPI 초기화 실패를 해결한 것으로 취급하지 않음 |
| CANH/CANL·종단·STM32 펌웨어 | SPI probe 이후 검증할 항목. 외부 버스가 없어도 MCP2515 초기화와 네트워크 장치 등록은 가능해야 함 |
| PWR LED | 점등만으로 MCP2515 논리측 `V-IO` 정상 전압을 증명하지 않음 |

제조사 회로도에서 PWR LED D7은 절연측 `3V3-T/GND-T`에, MCP2515 VDD·RESET 풀업은 논리측 `V-IO`에 연결돼 있다.
측정 시 CAN 단자의 `G`인 `PGND`, 절연측 `GND-T`, 논리측 `GND`를 구분해야 한다.
[제조사 V1.2 회로도](https://seengreat.com/upload/file/83/RS485-Dual-CAN-I-V1.2.pdf),
[제조사 핀·DIP 설명](https://seengreat.com/wiki/83/rs485-dual-can-i).

## 4. 미수행 항목과 다음 측정

정상 SPI 응답이 선행되지 않아 다음 검증은 수행하지 않았다.

- MCP2515 레지스터 쓰기·읽기 일치 시험.
- MCP2515 내부 CAN 루프백과 IRQ 발생·해제 검증.
- 외부 CAN 송수신과 STM32 ID `0x100` 수신.

하드웨어를 그대로 둔 원격 소프트웨어 점검만으로 남은 전기적 원인을 구분할 수는 없다.
멀티미터·오실로스코프를 사용할 수 있는 팀원에게 아래 순서로 확인을 요청한다.

| 순서 | 확인 대상 | 기대 또는 판별 기준 |
| --- | --- | --- |
| 1 | HAT 논리측5V·3.3V·`V-IO` | 3.3V 선택 시 MCP2515에 실제3.3V가 공급되는지 확인 |
| 2 | MCP2515 RESET | 논리측 GND 기준 HIGH로 해제되는지 확인 |
| 3 | 칩 핀에서 CS·SCLK·SI/SO | RPi에서 발생시킨 신호가 실제 칩까지 도달하고 SO 응답이 나오는지 확인 |
| 4 | 16MHz 발진자 | 실제 발진 여부 확인. 측정 프로브의 부하에 유의 |
| 5 | 정상 장비와 교차 연결 | 정상 HAT↔현재 RPi 또는 현재 HAT↔정상 RPi로 고장 범위 구분 |

V1.2 회로도의18핀 MCP2515 U4/U5 기준 VDD=18번, VSS=9번, RESET=17번이다.
실물 부품·핀1 방향·리비전을 먼저 대조하고, 좁은 핀을 잘못 접촉해 단락시키지 않도록 측정한다.
전원을 끈 도통 시험과 전원을 켠 전압·파형 시험을 구분한다.

## 5. 원복 확인

- 부팅 설정 SHA-256은 전후 동일하다.
  `7bb441f8fa1fbca69162da0b0c90be223f477b5ca20da9246910c4d5c1bed73d`
- 임시 `spi1-2cs`, CAN1 `mcp2515` runtime overlay를 역순으로 제거했다.
- SPI master는 원래의 `spi0`만 남았다.
- SPI0 컨트롤러를 `dw_spi_mmio`에 다시 바인딩했다.
- `spi0.0=spidev`, `spi0.1=초기화 실패로 미바인딩`인 시작 상태로 돌아왔다. override는 모두 비웠다.
- GPIO9~11의 SPI 기능·no-pull, GPIO7/8 pull-up, GPIO17~21·24의 원래 none/pull-down을 복원했다.
- 시험용 GPIO consumer가 남지 않았고 Qwen·Agent의 실행 상태를 재확인했다.

SPI1 runtime overlay의 적용·제거 시 커널의 속성 제거 관련 경고가 남았으나,
runtime overlay와 SPI1 장치가 제거된 상태를 확인했다. 로그 원문은 원본 JSON에 포함된다.

## 6. 원본 증거

RPi의 다음 디렉터리에 root 전용으로 보관했다.

```text
/var/backups/rpi5-can/full-40pin-20261113T081250Z/
```

| 파일 | 내용 |
| --- | --- |
| `baseline.json` | OS·드라이버·GPIO 점유·부팅 설정 해시·장치 트리·서비스 시작 상태 |
| `hardware-spi0-matrix.json` | SPI0의96회 읽기·명시적 RESET·드라이버 복귀 결과 |
| `hardware-spi1-matrix.json` | CAN1 probe·SPI1의36회 읽기·overlay 제거 결과 |
| `rp1-internal-loopback.json` | 별도 Linux ioctl로 수행한 내부 루프백6회 통과 |
| `software-spi0.json` | 하드웨어 SPI0 해제·GPIO 직접 제어24회·컨트롤러 복귀 |
| `software-spi1.json` | GPIO 직접 제어24회·핀 원복 |
| `final-state.json` | 최종 해시·장치·GPIO consumer·서비스·온도·장치 트리 확인 |

SPI0 원본의 선택적 내부 루프백 항목에는 Python `spidev.mode` setter가0~3만 허용해 거부한 오류가 포함돼 있다.
이는 내부 루프백의 하드웨어 실패 판정이 아니다. 이후 Linux ioctl 경로로 별도 수행해6회 통과했고 해당 JSON에 보관했다.

이전 진행: [초기 연결 점검 기록](RPi5_CAN_초기_연결_점검_기록.md).
