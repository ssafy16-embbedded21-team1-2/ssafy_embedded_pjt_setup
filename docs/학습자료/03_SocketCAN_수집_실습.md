# 03. SocketCAN 수집 실습

[학습 순서](README.md) · 이전: [STM32](02_STM32_CAN과_비트타이밍.md) · 다음: [신호·DBC](04_신호규약_DBC와_최신여부.md)

## 1. SocketCAN의 역할

Linux는 CAN을 네트워크 인터페이스로 제공한다. `can0`는 실제 CAN 장치, `vcanlearn0` 같은 vcan 장치는 가상 버스 실습에 사용할 수 있다. 같은 버스를 여러 프로세스가 수집할 수 있고 소켓별로 필터를 설정한다. [Linux SocketCAN 문서](https://docs.kernel.org/networking/can.html)

이 문서의 명령은 **Linux의 분리된 학습 환경**에서 실행한다. Windows PowerShell에서는 그대로 동작하지 않는다. WSL2/VM도 커널의 vcan/CAN 지원을 먼저 확인한다. 여기서는 RPi의 실행 중 설정을 바꾸지 않는다.

## 2. 장비 없이 vcan 버스 만들기

Debian/Raspberry Pi OS 계열의 설치 예시다. 기존에 같은 인터페이스가 있으면 용도를 확인하고 새 이름을 고른다. 기존 인터페이스를 삭제해 재사용하지 않는다.

```bash
sudo apt update
sudo apt install -y can-utils iproute2 python3-venv
sudo modprobe vcan
sudo ip link add dev vcanlearn0 type vcan
sudo ip link set dev vcanlearn0 up
ip -details -statistics link show vcanlearn0
```

터미널 A에서 수신한다.

```bash
candump -tz -e vcanlearn0
```

터미널 B에서 학습용 프레임을 전송한다.

```bash
cansend vcanlearn0 200#C05D960050190001
cansend vcanlearn0 200#C05D6AFF50190002
cansend vcanlearn0 200#FFFF960050190403
```

`200`은 16진수 표준 ID `0x200`, `#` 뒤는 payload다. 마지막 벡터는 전압 invalid를 뜻하는 학습용 값이다. 이 의미는 CAN이 정하는 것이 아니라 [신호 규약](04_신호규약_DBC와_최신여부.md)이 정한다.

다른 수신 터미널에서 표준 데이터 프레임 ID `0x200`만 필터링한다.

```bash
candump -tz 'vcanlearn0,200:C00007FF'
```

mask에는 11-bit ID뿐 아니라 EFF/RTR 플래그도 포함했다. 단순 `7FF` mask는 하위 ID 비트만 비교하므로 프레임 형식까지 제한한 것과 다르다. 도구 사용법은 설치한 `candump -h`, `cansend -h`로 확인한다. [can-utils 원본](https://github.com/linux-can/can-utils)

학습이 끝나면 자신이 만든 가상 인터페이스만 정리한다.

```bash
sudo ip link delete dev vcanlearn0
```

vcan은 프레임 수집·파서·소켓 필터·시간 초과 로직 검증용이다. 물리 중재·실제 전송 속도·트랜시버·ACK·스터핑·배선 오류·Bus-Off의 실물 동작을 재현한 것으로 보지 않는다.

## 3. Python 수집기

같은 Linux 환경에서 별도 가상환경을 사용한다. 실습 후 패키지 버전도 기록한다.

```bash
python3 -m venv .venv-can-learning
. .venv-can-learning/bin/activate
python -m pip install python-can
python -m pip show python-can
```

다음 코드를 `receive_learning_can.py`로 저장한다. 실행한 후 다른 터미널에서 2절의 프레임을 보내면 된다. 필터가 있어도 형식·길이를 검증하며, 1초 무수신은 이 학습 관측창의 결과일 뿐 프로젝트 ECU 타임아웃의 확정값이 아니다.

```python
import time

import can

filters = [{"can_id": 0x200, "can_mask": 0x7FF, "extended": False}]
with can.Bus(interface="socketcan", channel="vcanlearn0",
             can_filters=filters) as bus:
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        msg = bus.recv(timeout=1.0)
        if msg is None:
            print("No frame in the last observation window")
            continue
        if (msg.is_error_frame or msg.is_remote_frame or msg.is_fd
                or msg.is_extended_id or msg.arbitration_id != 0x200
                or len(msg.data) != 8):
            print("Rejected frame", msg)
            continue
        print(msg.timestamp, f"{msg.arbitration_id:03X}",
              msg.data.hex(" "), "host_monotonic", time.monotonic())
```

```bash
python receive_learning_can.py
```

예제는 수신과 기본 프레임 검증만 수행한다. 값 디코딩·유효성·최신 여부는 다음 장에서 연결한다. [python-can SocketCAN API](https://python-can.readthedocs.io/en/stable/interfaces/socketcan.html)

## 4. 실제 can0로 옮기기

실물 확인은 다음 순서로 진행한다.

1. RPi CAN 보드의 정확한 모델·컨트롤러·발진자 주파수·CS/IRQ와 RPi5/커널 지원을 확인한다. 다른 제품의 `oscillator=` 예시를 복사하지 않는다.
2. 제조사 절차로 드라이버·SPI/device tree를 설정한 뒤 `can0` 생성과 커널 로그를 확인한다. 이 문서는 미확인 보드의 overlay 값을 확정하지 않는다.
3. 별도의 정상 수신 노드와 종단·기준 GND를 연결하고 동일 bitrate로 맞춘다.
4. 수신 카운터·실제 상대 응답·양쪽 원본 로그를 대조한다. 로컬 echo만으로 성공 판정하지 않는다.

아래는 **학습용 전용 버스이고 인터페이스를 내려도 되는 경우**의 설정 예시다. 실행 중인 공용 진단 버스에 그대로 적용하지 않는다.

```bash
sudo ip link set dev can0 down
sudo ip link set dev can0 type can bitrate 500000 restart-ms 0
sudo ip link set dev can0 up
ip -details -statistics link show can0
candump -tz -e can0
```

자동 재시작은 끈 예시다. 오류가 발생하면 먼저 배선·상대 ACK·타이밍·원인을 확인한다. 오류 프레임/카운터 제공은 드라이버에 따라 다르며 미지원은 0이 아니다. Bus-Off 복귀 명령을 LLM이 무제한 반복하는 흐름으로 만들지 않는다.

## 5. 수집기와 Docker Agent의 경계

물리 `can0`는 호스트 네트워크에 있다. 일반 bridge 네트워크 컨테이너에서 같은 인터페이스가 자동으로 보인다고 가정하지 않는다. 첫 구현은 **호스트 수집기 → 버전 있는 정규화 JSON → Docker Agent**를 권장 설계로 둔다. 전달 API/파일·버퍼·접근 권한은 별도 구현한다. CAN 사용을 이유로 컨테이너 전체를 `privileged`로 바꾸지 않는다.

수집기는 원본 frame·호스트 수집 시각·인터페이스·디코더 버전을 보존한다. 최신 여부의 경과시간은 같은 프로세스/부팅의 monotonic 시각으로 계산하고, 보고용 벽시계 시각과 구분한다. LLM에는 전체 트래픽 대신 도구가 판정한 요약과 근거를 전달한다. [python-can SocketCAN API](https://python-can.readthedocs.io/en/stable/interfaces/socketcan.html)

## 6. 완료 확인

- [ ] 세 프레임의 ID·길이·바이트를 원본 그대로 확보했다.
- [ ] 필터에서 ID와 표준/확장 형식의 의미를 설명할 수 있다.
- [ ] 수신기 실행 종료·무수신과 ECU 고장을 구분했다.
- [ ] vcan에서 확인한 범위와 실제 CAN에서 남은 검증을 기록했다.
