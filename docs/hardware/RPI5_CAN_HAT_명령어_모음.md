# RPI5 CAN HAT 동작 확인 명령어 모음

> RPi 5 + **Seengreat RS485 Dual CAN I HAT**, `MCP2515`에서 CAN HAT이 정상 동작하는지 단계별로 수동 점검할 수 있는 명령어 모음입니다.

---

## 1. 인터페이스 인식 및 링크·에러 상태 확인 (가장 먼저 볼 것)

```bash
# 1) can0 / can1 인터페이스 존재 여부 및 간단 상태
ip -brief link show type can

# 2) bitrate, CAN 상태(ERROR-ACTIVE/PASSIVE/BUS-OFF), RX/TX 패킷 및 에러 통계 확인
ip -details -statistics link show can0
```

* **정상 기준**: `state UP`, `can state ERROR-ACTIVE`, `restart-ms 100`, `bitrate 500000`, `rx/tx dropped·errors` 미증가.
* 만약 `can0`이 안 보인다면 HAT 전원/장착 또는 SPI 오버레이 문제입니다(아래 3번 확인).

---

## 2. 실시간 CAN 프레임 송수신 확인 (`can-utils`)

```bash
# 1) 버스에서 들어오는 모든 CAN 프레임 실시간 모니터링 (Ctrl+C로 종료)
candump -ta can0
# 예: (1731900000.123456) can0 100 [4] A5 5A 00 3F

# 2) 10초 동안만 최대 20프레임만 빠르게 받아보고 싶을 때
timeout 10 candump -n 20 can0

# 3) RPi5 → 버스(STM32 등)로 테스트 프레임 1건 송신
cansend can0 123#11223344
```

* **주의**: 버스에 다른 활성 CAN 노드(예: STM32 보드 A/B + 트랜시버)가 연결돼 있지 않은 상태에서 `cansend`를 날리면 ACK가 없어 `tx_errors`가 올라갑니다. 혼자 HAT만 점검할 때는 아래 **4번 내부 루프백 테스트**를 사용하세요.

---

## 3. 커널 드라이버(`mcp251x`) 및 SPI/GPIO 인터럽트 확인

`can0`이 아예 안 뜨거나 프레임이 안 들어올 때 하드웨어·드라이버 레벨을 확인합니다.

```bash
# 1) 부팅 로그에서 mcp251x(MCP2515) 초기화 성공/실패(-110 timeout 등) 확인
dmesg | grep -iE 'mcp251|can|spi'

# 2) GPIO 인터럽트(can0=IRQ 25, can1=IRQ 24) 카운트 증가 확인
grep -E 'mcp251|spi0|spi1' /proc/interrupts
```

* **정상 기준**: `dmesg`에 `mcp251x spi0.1 can0: MCP2515 successfully initialized`가 보이고, 프레임이 들어올 때마다 `/proc/interrupts`의 `mcp251x` 카운트가 올라갑니다. (`err=-110`이 뜨면 SPI 통신 실패 또는 HAT 미접촉입니다.)

---

## 4. HAT 단독 자가진단 (외부 보드 없이 `MCP2515` 내부 루프백 테스트)

외부 STM32 보드를 다 떼어낸 상태에서 **RPi 5 ↔ HAT(SPI + MCP2515) 자체만** 정상인지 확인할 때 씁니다.

```bash
# 1) loopback 모드로 전환 후 2개 터미널(또는 백그라운드)로 송수신 확인
sudo ip link set can0 down
sudo ip link set can0 up type can bitrate 500000 loopback on
candump can0 -n 1 &
cansend can0 777#DEADBEEF

# 2) 테스트가 끝나면 반드시 운영 서비스(normal 모드)로 원복!
sudo systemctl restart rpi5-can0.service
ip -details link show can0
```

* **정상 기준**: `candump`에 `can0  777   [4]  DE AD BE EF`가 즉시 찍히고, 원복 후 `ERROR-ACTIVE`가 됩니다.

---

## 5. 서비스(`systemd`) 및 Agent 수집기 연동 상태 확인

```bash
# 1) CAN 자동 기동 서비스 & 호스트 수집기 상태 확인
systemctl status rpi5-can0.service rpi5-hw-collector.service --no-pager

# 2) 호스트 수집기(:8090)가 읽고 있는 실시간 CAN 스냅샷 확인
curl -sS http://172.17.0.1:8090/health | python3 -m json.tool
curl -sS http://172.17.0.1:8090/snapshot/can | python3 -m json.tool
```

---

## 💡 한 번에 빠르게 훑어보는 원라인 점검 명령

```bash
ip -details -statistics link show can0; echo "---"; curl -sS http://172.17.0.1:8090/health; echo ""
```
