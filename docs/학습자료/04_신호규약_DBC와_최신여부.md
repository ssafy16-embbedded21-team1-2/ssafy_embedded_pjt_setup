# 04. 신호 규약·DBC와 최신 여부

[학습 순서](README.md) · 이전: [SocketCAN](03_SocketCAN_수집_실습.md) · 다음: [ISO-TP·UDS](05_ISOTP_UDS와_제품진단.md)

## 1. CAN이 정해 주지 않는 것

CAN 프레임이 정상이어도 payload의 전압 단위·부호·고장 의미는 프로젝트가 정해야 한다. 송수신자가 같은 자료형·엔디언·배율·범위·invalid·버전을 구현하는 것이 통신 규약 작업이다.

```text
물리값 = raw × factor + offset
```

DBC는 ID·길이·신호 배치·부호·배율·단위 등의 정의에 사용한다. Intel/little-endian은 DBC `@1`, Motorola/big-endian은 `@0`이며 start bit 표기 규칙도 다르다. Motorola를 단순히 바이트 배열 뒤집기로 구현하지 않는다. [DBC 형식 설명](https://www.csselectronics.com/pages/can-dbc-file-database-intro)

## 2. 기존 회의 예제로 바이트를 해석한다

아래는 [회의 템플릿 부록 A](../CAN_통신규약_합의_회의_템플릿.md)의 **미채택 학습 초안**을 사용한다. ID `0x200`, Classic 8B, 다바이트 정수 little-endian이다.

| 바이트 | 신호           | 자료형 | factor·단위     | invalid raw                                       |
| ------ | -------------- | ------ | --------------- | ------------------------------------------------- |
| 0~1    | PackVoltage    | uint16 | 1 mV            | `0xFFFF`                                          |
| 2~3    | PackCurrent    | int16  | 10 mA           | `0x8000`                                          |
| 4      | SOC            | uint8  | 1%              | `0xFF`                                            |
| 5      | MaxTemperature | int8   | 1 degC          | `0x7F`                                            |
| 6      | BmsFlags       | uint8  | 상태 비트       | bit0 저전압·bit1 과온·bit2 센서 이상, 나머지 예약 |
| 7      | Sequence       | uint8  | 프레임마다 증가 | 255 다음 0 제안                                   |

```text
정상: C0 5D 96 00 50 19 00 01
전압: 0x5DC0 = 24000 mV
전류: int16(0x0096) × 10 = +1500 mA
SOC: 0x50 = 80%, 온도: 0x19 = 25 degC, Sequence: 1

충전: C0 5D 6A FF 50 19 00 02
전류: int16(0xFF6A) = -150 → -1500 mA

전압 invalid: FF FF 96 00 50 19 04 03
전압은 65535 mV가 아니라 미측정/무효로 처리
```

이 배치에는 boot ID·샘플 시각이 없다. 현재 Sequence가 송신마다 증가한다면 프레임 생존은 볼 수 있어도 센서 샘플 갱신을 보장하지 못한다. 기존 바이트에 필드를 조용히 추가하지 말고 별도 메시지/조회 또는 버전 변경을 합의한다.

## 3. DBC 파일로 같은 값을 확인한다

실행 가능한 학습용 파일은 [예제/학습용\_BMS.dbc](예제/학습용_BMS.dbc)다. 프로젝트의 `protocol/vehicle.dbc`가 아니며 확정 규약으로 배포하지 않는다.

저장소 루트에서 Windows 또는 Linux의 Python 가상환경에 `cantools`를 설치한 뒤 아래 코드를 실행한다. `uv`를 사용한다면 `uv run --no-project --with cantools python 파일명.py` 방식으로 실행할 수도 있다.

```bash
python -m pip install cantools
```

```python
import cantools

db = cantools.database.load_file(
    "docs/학습자료/예제/학습용_BMS.dbc", encoding="utf-8")
message = db.get_message_by_name("LEARNING_BMS")
values = {"PackVoltage": 24000, "PackCurrent": 1500, "SOC": 80,
          "MaxTemperature": 25, "BmsFlags": 0, "Sequence": 1}
payload = message.encode(values)
assert payload.hex() == "c05d960050190001"
print(payload.hex(" "))
print(message.decode(payload))

values.update(PackCurrent=-1500, Sequence=2)
assert message.encode(values).hex() == "c05d6aff50190002"

invalid_payload = bytes.fromhex("ff ff 96 00 50 19 04 03")
decoded = message.decode(invalid_payload)
voltage_valid = invalid_payload[0:2] != b"\xff\xff"
print("voltage_mV", decoded["PackVoltage"] if voltage_valid else None)
```

DBC 기본 디코딩만으로 프로젝트의 invalid·예약 비트·측정 신뢰도·시간 초과가 모두 처리되지는 않는다. 위 코드는 **전압 invalid 처리만 보이는 최소 예제**이며 다른 신호의 sentinel·범위·버전·길이 검사는 별도로 구현한다. 바이트를 먼저 검증하고 값·단위·유효성을 나눠 반환한다. [cantools API](https://cantools.readthedocs.io/en/latest/)

## 4. 최신 여부를 세 단계로 나눈다

| 단계            | 확인할 정보                                | 실패 예                           |
| --------------- | ------------------------------------------ | --------------------------------- |
| 프레임 도착     | 마지막 수신 후 경과시간, 프레임 Sequence   | ECU 송신 중단·중계 단절           |
| 원본 샘플 갱신  | 샘플 Sequence·원본 경과시간·측정 플래그    | 프레임은 오지만 센서 읽기 정체    |
| 게이트웨이 전달 | 원본 ECU·캐시 나이·게이트웨이 생존·boot ID | 집계만 새로 오고 원본 값은 오래됨 |

판정 이름은 설계 제안이다. `UNKNOWN`은 최초 미수신, `INVALID`는 측정 무효, `STALE`은 원본 만료처럼 정의하고 충돌할 때 우선순위도 정한다. 마지막 정상값을 UI에 남길 수 있지만 현재 유효값으로 쓰지 않는다. Sequence 누락은 송신·버스·수신 큐·로그 중 어느 구간 문제인지 추가 근거가 필요하다.

### 시간 순서 연습

학습 가정은 송신 100ms·만료 500ms다. 실측된 프로젝트 기준이 아니다.

| 호스트 경과시간 | 게이트웨이 수신 | cell2 원본 상태        | 기대 해석                                   |
| --------------- | --------------- | ---------------------- | ------------------------------------------- |
| 0ms             | 없음            | 없음                   | 원본 미확인                                 |
| 100ms           | 집계 seq=1      | 샘플 seq=10, age=0ms   | 정상 샘플 확보                              |
| 200ms           | 집계 seq=2      | 샘플 seq=10, age=100ms | 게이트웨이는 생존, 원본 샘플은 아직 같은 값 |
| 700ms           | 집계 seq=7      | 샘플 seq=10, age=600ms | 원본 stale. 게이트웨이 무응답이 아님        |

샘플 값이 일정한 것과 샘플 취득이 멈춘 것은 다르다. 온도가 그대로여도 sample Sequence가 증가하면 새 측정일 수 있다. boot ID를 통해 재부팅을 구분하고, 서로 다른 장치·부팅의 uptime을 직접 빼지 않는다.

## 5. 공동 검증 과제

1. Python과 C에서 정상·음수 전류·invalid 프레임을 만들고 미리 정한 hex와 비교한다.
2. 최솟값·최댓값·예약값·범위 초과·틀린 길이·지원하지 않는 버전을 추가한다.
3. 송신 Sequence는 증가하지만 샘플 Sequence는 고정된 상황을 만든다.
4. cell2 송신만 중단하고 게이트웨이 집계는 유지한다.
5. 재부팅·Sequence 롤오버·일부 신호 invalid·정상 복귀의 기대 상태를 합의한다.

인코더와 디코더끼리만 왕복하면 같은 실수를 공유할 수 있다. **독립적인 정답 바이트와 시간 순서 예제**를 함께 관리한다. 확정된 결과만 DBC·진단 설정·테스트 벡터에 같은 버전으로 반영한다.
