# STM32 임베디드 디버깅 작업 가이드 및 명령어 매뉴얼 (NUCLEO-G474RE & F103RB / CAN·CAN-FD 전장 특화)

본 문서는 Raspberry Pi 5 진단 벤치에 설치된 도구군(`OpenOCD`, `GDB-multiarch`, `pyocd`, `stlink-tools`, `binutils-arm-none-eabi`, `can-utils`, `pyserial`, `Qwen 2.5 3B`)을 활용하여 **NUCLEO-G474RE(메인 DCU / Cortex-M4F)** 및 **NUCLEO-F103RB(분산 ECU / Cortex-M3)** 보드의 **실리콘 코어 레벨부터 CAN/CAN-FD 차량 버스 레벨까지 전 계층을 디버깅**하기 위한 실전 CLI 가이드입니다.

---

## 1. 디버깅 도구 및 보드별 매핑 요약

| 디버깅 계층 | 담당 도구 | 주요 디버깅 대상 | G474RE (Cortex-M4) | F103RB (Cortex-M3) |
|:---|:---|:---|:---:|:---:|
| **CPU 코어 / 크래시** | `openocd`, `gdb-multiarch` | CPU 실행 제어, Core 레지스터, HardFault (CFSR, BFAR, FPU) | `target/stm32g4x.cfg` | `target/stm32f1x.cfg` |
| **소스코드 심볼 역추적** | `arm-none-eabi-addr2line` | 크래시 주소(PC) ➡️ C 소스 파일명/라인 번호 매핑 | `firmware_g4.elf` | `firmware_f1.elf` |
| **차량 버스 레벨** ⭐ | `can-utils`, `ip link`, `python-can` | CAN FD(5Mbps) / CAN(500k) 버스 에러, Bus-Off, DTC 모니터링 | `can0` 소켓 | `can0` 소켓 |
| **차량 진단 (UDS)** ⭐ | `tool_can.py`, `cansend` | ISO 14229 UDS 요청/응답, DTC 고장코드, Freeze Frame 덤프 | UDS 테스터 | UDS 테스터 |
| **메모리 & 주변장치** | `openocd (mdw/mww)` | SRAM 덤프, FDCAN/bxCAN 에러 레지스터, CORDIC/TIM SFR 실사 | 128KB SRAM, FDCAN | 20KB SRAM, bxCAN |
| **펌웨어 수명주기** | `st-flash`, `openocd` | Dual-Bank Flash 롤백(BFB2 뱅크스왑), 펌웨어 플래싱 | 512KB Dual-Bank | 128KB Flash |
| **AI 자율 분석** | `Qwen 2.5 3B` (llama.cpp) | CAN DTC 코드 + SWD 레지스터를 결합한 자연어 종합 정비 리포트 | 로컬 SLM | 로컬 SLM |

---

## 2. 작업별 상세 디버깅 시나리오 및 실전 명령어

### [작업 1] HardFault 및 CPU 크래시 원인 분석 (G474 & F103)
MCU가 멈추거나 HardFault 핸들러에서 루프를 돌 때 코어 레지스터를 조회하여 원인을 즉각 규명합니다.

1. **CPU 정지 및 코어 레지스터 일괄 확인**:
   * **NUCLEO-G474RE (Cortex-M4F)**:
     ```bash
     openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32g4x.cfg \
             -c "init; halt; reg; resume; exit"
     ```
   * **NUCLEO-F103RB (Cortex-M3)**:
     ```bash
     openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f1x.cfg \
             -c "init; halt; reg; resume; exit"
     ```
   * 확인 대상: `PC` (정지 주소), `LR` (복귀 주소), `SP` (스택 포인터)

2. **HardFault 상태 레지스터 (SCB CFSR) 정밀 판독**:
   ```bash
   # CFSR(0xE000ED28) 및 HFSR(0xE000ED2C) 읽기
   openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32g4x.cfg \
           -c "init; halt; mdw 0xE000ED28 2; resume; exit"
   ```
   * **주요 비트 해석**:
     * `0x00010000` (`UNDEFINSTR`): 정의되지 않은 기계어 실행
     * `0x01000000` (`UNALIGNED`): 비정렬 메모리 접근
     * `0x02000000` (`DIVBYZERO`): 0으로 나누기 연산
     * `0x00000082` (`PRECISERR`): 잘못된 메모리 번지 참조 ➡️ **BFAR(0xE000ED38) 확인 필수!**

3. **잘못 접근한 메모리 번지(BFAR) 확인**:
   ```bash
   openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32g4x.cfg \
           -c "init; halt; mdw 0xE000ED38 1; resume; exit"
   ```
   * 예: `0x00000004` 출력 ➡️ "구조체 널 포인터 역참조(`ptr->member`)" 확정.

---

### [작업 2] C 소스코드 라인 번호 역추적 (addr2line)
HardFault가 발생했을 때 확인한 `PC` 주소를 소스코드 라인으로 즉시 변환합니다.

```bash
# NUCLEO-G474RE 크래시 주소 역추적
arm-none-eabi-addr2line -e build/firmware_g4.elf -a 0x08001234 -f -C

# NUCLEO-F103RB 크래시 주소 역추적
arm-none-eabi-addr2line -e build/firmware_f1.elf -a 0x08000494 -f -C
```
* **출력 결과**:
  ```text
  CORDIC_Calculate_FOC_Vector
  /home/pi/firmware/src/motor_foc.c:89
  ```

---

### [작업 3] 실시간 메모리(SRAM) 및 CORDIC/FOC 변수 모니터링
MCU 실행 중 런타임 변수와 버퍼를 실시간 덤프하거나 강제 조작합니다.

1. **SRAM 덤프 (16워드 / 64바이트)**:
   * G474RE (128KB SRAM: `0x20000000`\~`0x2001FFFF`)
   * F103RB (20KB SRAM: `0x20000000`\~`0x20004FFF`)
   ```bash
   openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32g4x.cfg \
           -c "init; halt; mdw 0x20000000 16; resume; exit"
   ```

2. **특정 전역 변수 강제 조작 (테스트 목적)**:
   ```bash
   # 0x20000100 번지에 32비트 값 0x00000001 쓰기
   openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32g4x.cfg \
           -c "init; halt; mww 0x20000100 0x00000001; resume; exit"
   ```

---

### [작업 4] CAN & CAN-FD 하드웨어 컨트롤러 상태 실사 (Error Counters)
통신이 안 되거나 노드가 뻗었을 때, MCU 내부 CAN 컨트롤러의 하드웨어 레지스터를 직접 열람하여 버스 상태를 진단합니다.

#### 1) NUCLEO-G474RE FDCAN 프로토콜 상태 레지스터 (`FDCAN_PSR`)
* **주소**: FDCAN1 기저번지(`0x40006400`) + 오프셋 `0x44` = **`0x40006444`**
```bash
openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32g4x.cfg \
        -c "init; halt; mdw 0x40006444 1; resume; exit"
```
* **비트 판독 가이드**:
  * `Bit 3 (BO)`: **1이면 Bus-Off 상태** (버스 과부하 또는 심각한 전기적 결함으로 송신 차단됨)
  * `Bit 4 (EP)`: **1이면 Error Passive 상태** (에러 누적 상태)
  * `Bit 0-2 (LEC)`: Last Error Code
    * `3` (`0b011`): **ACK Error** (상대방 수신 노드가 없거나 120Ω 종단 저항 누락!)
    * `1` (`0b001`): **Stuff Error** (비트 스터핑 에러, 노이즈 유입)
    * `6` (`0b110`): **CRC Error** (통신 패킷 손상)

#### 2) NUCLEO-F103RB bxCAN 에러 상태 레지스터 (`CAN_ESR`)
* **주소**: **`0x40006418`**
```bash
openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f1x.cfg \
        -c "init; halt; mdw 0x40006418 1; resume; exit"
```
* **비트 판독 가이드**:
  * `Bit 2 (BOFF)`: Bus-Off 플래그
  * `Bit 16~23 (TEC)`: Transmit Error Counter (송신 에러 카운터, 255 초과 시 Bus-Off)
  * `Bit 24~31 (REC)`: Receive Error Counter (수신 에러 카운터)

---

### [작업 5] 차량 CAN / CAN-FD 버스 레벨 실시간 스니핑 & 에러 프레임 포착
RPi 5 리눅스 터미널에서 차량 버스 전체 트래픽을 관찰합니다.

1. **실시간 트래픽 타임스탬프 스니핑**:
   ```bash
   candump -tz can0
   # 출력: (1730538900.123456)  can0  100   [8]  0B B8 32 19 00 00 00 00
   ```

2. **CAN 버스 에러 프레임 전용 캡처 (물리 계층 트러블슈팅)**:
   ```bash
   candump -e can0,0:0,#FFFFFFFF
   # 종단 저항 불량, 선로 단선, 보레이트 불일치 시 Error Frame 실시간 출력
   ```

3. **소켓 에러 통계 및 Bus-Off 확인**:
   ```bash
   ip -details -statistics link show can0
   ```
   * `bus-off`, `restart-ms`, `RX/TX errors`, `CRC errors` 통계 조회

4. **Bus-Off 상태 강제 리셋 및 복구**:
   ```bash
   sudo ip link set can0 type can restart
   ```

---

### [작업 6] UDS (ISO 14229) 진단 질의 및 DTC 고장코드 판독
차량 표준 진단 프로토콜을 사용해 각 ECU의 고장코드와 센서 스냅샷(Freeze Frame)을 요청합니다.

1. **표준 OBD-II / UDS 브로드캐스트 질의 송신 (`0x7DF`)**:
   ```bash
   # Service 01, PID 01 (DTC 상태 질의)
   cansend can0 7DF#0201010000000000
   ```

2. **UDS 부정 응답 코드(NRC) 디코딩**:
   * 만약 응답으로 `0x7E8 [8] 03 7F 22 31 ...` 이 수신된 경우:
     * `0x7F`: Negative Response
     * `0x22`: 요청했던 서비스 ID
     * `0x31` (`NRC`): **Request Out Of Range** (요청한 파라미터 범위를 벗어남)
     * *(참고: `0x11` = Service Not Supported, `0x22` = Conditions Not Correct)*

---

### [작업 7] NUCLEO-G474RE Dual-Bank Flash 무중단 OTA 및 1초 롤백
G474RE의 512KB 플래시를 활용하여 주행 중 무중단 뱅크 스왑을 테스트합니다.

1. **현재 부팅 뱅크(Option Byte) 확인**:
   ```bash
   # FLASH_OPTR 레지스터 (0x40022020) 읽기
   openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32g4x.cfg \
           -c "init; halt; mdw 0x40022020 1; resume; exit"
   ```
   * `Bit 22 (BFB2)`: 0이면 Bank 1 부팅, 1이면 Bank 2 부팅

2. **Bank 2에 새 펌웨어 플래싱 (Bank 1 주행 중)**:
   ```bash
   st-flash write firmware_v2.bin 0x08040000
   ```

3. **고장 발생 시 1초 안전 롤백 (Bank Swap 실행)**:
   STM32CubeProgrammer CLI로 옵션 바이트를 토글하여 이전 Bank 1으로 즉시 롤백:
   ```bash
   STM32_Programmer_CLI -c port=SWD -ob BFB2=0
   ```

---

### [작업 8] 이종 멀티 보드 타깃 지정 디버깅 (G474 1대 + F103 3대)
4대의 STM32 보드가 동시에 꽂혀 있을 때, ST-LINK 고유 시리얼 번호로 타깃을 분리 제어합니다:

1. **Main DCU (NUCLEO-G474RE, ST-LINK V3E)**:
   ```bash
   openocd -f interface/stlink.cfg -c "adapter serial <G474_시리얼>" \
           -c "transport select swd" -f target/stm32g4x.cfg \
           -c "init; reset halt; reg; resume; exit"
   ```

2. **Cell 2 BMS ECU (NUCLEO-F103RB, ST-LINK V2-1)**:
   ```bash
   openocd -f interface/stlink.cfg -c "adapter serial <F103_시리얼>" \
           -c "transport select swd" -f target/stm32f1x.cfg \
           -c "init; reset halt; reg; resume; exit"
   ```

---

### [작업 9] GDB 원격 대화형 디버깅 (PC ↔ RPi 5)
IDE(VS Code, CubeIDE)나 터미널에서 C 소스코드 브레이크포인트를 걸고 스텝 실행합니다.

1. **RPi 5에서 타깃 칩에 맞춰 GDB 서버 실행**:
   ```bash
   # G474RE 디버깅 대기
   openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32g4x.cfg
   # 포트 3333 오픈 대기
   ```

2. **PC 터미널에서 GDB 클라이언트 접속**:
   ```bash
   gdb-multiarch build/firmware_g4.elf
   (gdb) target remote <본인_RPi_IP>:3333
   (gdb) monitor reset halt
   (gdb) break motor_foc.c:89
   (gdb) continue
   (gdb) print foc_vars.iq_current
   (gdb) step
   ```

---

### [작업 10] AI 진단 에이전트 연동 (Qwen 2.5 3B 자동 차량 리포트)
CAN 버스에서 수신한 **DTC 고장코드**와 SWD로 덤프한 **CFSR / FDCAN_PSR 레지스터**를 결합하여 온디바이스 SLM에 입력하면 전문가 수준의 정비 보고서를 작성합니다:

```bash
echo "아래 차량 CAN 고장 로그 및 G474RE 레지스터 덤프를 분석하고 원인과 조치 가이드를 한글로 보고해줘:
[CAN 버스] ID: 0x050, DTC: 0xE101 (Motor Overcurrent)
[FDCAN_PSR] 0x00000003 (LEC=3, ACK Error)
[CPU 레지스터] PC: 0x08001234, CFSR: 0x00008200 (PRECISERR), BFAR: 0x00000004
[소프트웨어] CORDIC FOC 인버터 제어 루프" | \
llama-cli -m ~/models/qwen2.5-3b-instruct-q4_k_m.gguf -t 4 -c 2048 --temp 0.2
```
