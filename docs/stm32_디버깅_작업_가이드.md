# STM32 임베디드 디버깅 작업 가이드 및 명령어 매뉴얼 (NUCLEO-F103RB / Classic CAN 특화)

> **이 저장소의 빌드와 VS Code/CubeIDE 디버깅 설정은 [STM32 빠른 시작 가이드](STM32_빠른_시작.md)를 사용하세요.** 예제 ELF 이름은 `build/debug/firmware_f103.elf`입니다. 크래시 수집 전에 reset하거나 자동 resume하지 않습니다.
>
> **운용 구분**: 아래 SWD·정지·플래싱 명령은 접근이 허용된 개발·벤치용입니다. 제품 운용에서는 CAN(및 벤치 보조 UART)으로 ECU의 상태·DTC·부팅/크래시 기록을 조회하며, SWD 없이 진단을 완료합니다. 해당 기록·UDS 기능은 합의·구현 범위에 따르며 설치된 도구만으로 제공되지 않습니다.

본 문서는 Raspberry Pi 5 진단 벤치에 설치된 도구군(`OpenOCD`, `GDB-multiarch`, `pyocd`, `stlink-tools`, `binutils-arm-none-eabi`, `can-utils`, `pyserial`, `Qwen 2.5 3B`)을 활용하여 **`NUCLEO-F103RB` (Cortex-M3, 보드 A · 보드 B 분산 ECU)** 의 **실리콘 코어 레벨부터 Classic CAN 차량 버스 레벨까지 전 계층을 디버깅**하기 위한 실전 CLI 가이드입니다.

---

## 0. SWD가 없는 제품 운용에서의 조사 순서

1. RPi의 CAN 원본 로그·수신 시각과 마지막 정상 데이터, 로컬 어댑터 상태(및 사용 가능한 경우 보조 UART 스냅샷)를 보존한다. 무응답만으로 원격 ECU의 크래시나 Bus-Off를 확정하지 않는다.
2. ECU가 응답하면 펌웨어/Build ID·지원 기능·boot ID·리셋 기록, DTC/snapshot, 저장된 크래시 요약을 허용된 CAN 진단 서비스로 조회한다. 요청 ID·DID·기한은 합의 후 구현한다.
3. 멈춘 ECU에는 즉시 질의할 수 없다. 설계된 워치독/통신 복귀 후 기록을 재조회하거나 전원·리셋·CAN 파형을 계측한다. 기록이 없거나 손상/미지원이면 그 사실과 다음 점검을 보고한다.
4. 크래시 기록의 `record_build_id`에 대응하는 ELF로 유효한 stacked PC 등을 분석한다. 최신 실행 파일을 무조건 사용하지 않는다. 심벌 부재·빌드 불일치·프레임 손상 시 소스 위치를 확정하지 않는다.
5. 추가 조사가 필요하면 동일 빌드의 개발 장비에서 재현하고 SWD 대조를 선택한다. 접근 불가는 `debug_access_unavailable`로 남기며 보호 해제·대량 삭제·halt/reset/플래싱을 자동 실행하지 않는다.

Fault 처리·리셋 보존 RAM·비휘발성 저장·전원 차단·기록 전송 계약은 [CAN 아키텍처 6절](차량용_CAN_통신_도입_및_아키텍처_설계.md#6-swd-없이-진단하는-제품-운용-설계), 제안 API는 [Agent Tool 설계](설계_장비별기능_및_AgentTool인터페이스.md)를 따른다. 실제 RDP를 변경하지 않고 SWD 도구 비활성화/접근 거부 모의로 이 흐름을 먼저 검증한다.

---

## 1. 디버깅 도구 및 보드별 매핑 요약

| 디버깅 계층              | 담당 도구                            | 주요 디버깅 대상                                             | F103RB (Cortex-M3)   |
| :----------------------- | :----------------------------------- | :----------------------------------------------------------- | :------------------- |
| **선택 벤치 CPU / 크래시** | `openocd`, `gdb-multiarch`         | 접근 허용 시 CPU 실행 제어·Fault 문맥 대조                   | `target/stm32f1x.cfg` |
| **소스코드 심볼 역추적** | `arm-none-eabi-addr2line`            | 크래시 주소를 일치하는 ELF의 소스 위치와 대조                | `firmware_f103.elf`  |
| **차량 버스 레벨** ⭐    | `can-utils`, `ip link`, `python-can` | Classic CAN (`500 kbps`) 모니터링 및 `cansend` 송수신        | `can0` 직접 연결     |
| **보조 UART 진단**       | `pyserial`, `/dev/serial/by-id/*`    | ST-LINK VCP (`115200 8N1`) 송수신·오류 카운터 교차 검증       | `USART2` (`/dev/ttyACM*`) |
| **차량 진단 (UDS)**      | 향후 `tool_can.py`, 진단 클라이언트  | ECU가 지원하는 UDS 요청/응답, DTC, Freeze Frame              | 구현 및 주소 합의 필요 |
| **제품 부팅 / 크래시 기록** | 향후 `can.get_identity`, `can.read_boot_record`, `can.read_crash_record` | ECU 펌웨어에 저장한 기록을 CAN으로 조회 | DID·메모리 예산(128KB/20KB) 확인 필요 |
| **메모리 & 주변장치**    | `openocd (mdw/mww)`                  | SRAM 덤프, `bxCAN` 에러 레지스터(`CAN_ESR`) 실사             | `20KB SRAM`, `bxCAN` |
| **펌웨어 수명주기**      | `st-flash`, `openocd`                | 벤치 플래싱 및 검증                                          | `128KB Flash`        |
| **AI 근거 설명**         | `Qwen 2.5 3B` (llama.cpp)            | 도구가 해석한 CAN/UART 상태·DTC·저장 기록 설명               | 로컬 SLM             |

---

## 2. 작업별 상세 디버깅 시나리오 및 실전 명령어

### [작업 1] HardFault 및 CPU 크래시 원인 분석 (`NUCLEO-F103RB`)

MCU가 멈추거나 HardFault 핸들러에서 루프를 돌 때 코어 레지스터와 예외 문맥을 수집해 원인을 조사합니다.

아래 `halt` 명령은 코어를 정지시킵니다. 현재 PC가 Fault 핸들러에 있으면 저장된 예외 프레임의 PC를 확인하고, 스택 오류·비정밀 BusFault에서는 이 주소도 정확하지 않을 수 있음을 고려합니다. 디버거 종료 후 대상 상태는 장비와 설정에 따라 확인하고 필요할 때 별도로 재개합니다.

1. **CPU 정지 및 코어 레지스터 일괄 확인 (`NUCLEO-F103RB`, Cortex-M3)**:

   ```bash
   openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f1x.cfg \
           -c "init; halt; reg; shutdown"
   ```

   - 확인 대상: `PC` (정지 주소), `LR` (복귀 주소), `SP` (스택 포인터)

2. **HardFault 상태 레지스터 (SCB CFSR) 정밀 판독**:

   ```bash
   # CFSR(0xE000ED28) 및 HFSR(0xE000ED2C) 읽기
   openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f1x.cfg \
           -c "init; halt; mdw 0xE000ED28 2; shutdown"
   ```

   - **주요 비트 해석**:
     - `0x00010000` (`UNDEFINSTR`): 정의되지 않은 기계어 실행
     - `0x01000000` (`UNALIGNED`): 비정렬 메모리 접근
     - `0x02000000` (`DIVBYZERO`): 0으로 나누기 연산
     - `0x00000200` (`PRECISERR`): 정밀 데이터 버스 오류. `0x00008000` (`BFARVALID`)도 설정된 경우 BFAR 주소를 해석할 수 있다.

3. **잘못 접근한 메모리 번지(BFAR) 확인**:

   ```bash
   openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f1x.cfg \
           -c "init; halt; mdw 0xE000ED38 1; shutdown"
   ```

   - 예: BFAR가 유효하고 `0x00000004`이면 널 포인터 인근 접근이 원인 후보이다. 예외 프레임과 해당 빌드의 명령어를 확인해야 한다. 비정밀 BusFault나 스택 오류에서는 stacked PC도 원인 명령을 가리킨다고 보장할 수 없다. [ST HardFault 가이드](https://community.st.com/stm32-mcus-60/how-to-debug-a-hardfault-on-an-arm-cortex-m-stm32-132895)

---

### [작업 2] C 소스코드 라인 번호 역추적 (`addr2line`)

HardFault가 발생했을 때 확인한 `PC` 주소를 일치하는 빌드의 ELF를 사용해 소스코드 라인으로 변환합니다.

```bash
# NUCLEO-F103RB 크래시 주소 역추적
arm-none-eabi-addr2line -e <실제_일치하는_ELF_경로> -a 0x08000494 -f -C
```

- **출력 형식 예시 (실제 수집 결과 아님)**:

  ```text
  0x08000494
  <함수명>
  <프로젝트_경로>/Core/Src/<파일명>:<줄번호>
  ```

---

### [작업 3] 실시간 메모리(SRAM) 덤프 및 변수 모니터링

MCU 실행 중 런타임 변수와 버퍼를 실시간 덤프하거나 테스트 목적으로 조작합니다.

1. **SRAM 덤프 (16워드 / 64바이트)**:
   - `NUCLEO-F103RB` (20KB SRAM: `0x20000000`\~`0x20004FFF`)

   ```bash
   openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f1x.cfg \
           -c "init; halt; mdw 0x20000000 16; shutdown"
   ```

2. **특정 전역 변수 강제 조작 (테스트 목적)**:

   ```bash
   # 0x20000100 번지에 32비트 값 0x00000001 쓰기 (실제 변수 주소 확인 후 사용)
   openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f1x.cfg \
           -c "init; halt; mww 0x20000100 0x00000001; shutdown"
   ```

---

### [작업 4] Classic CAN 하드웨어 컨트롤러 상태 실사 (`CAN_ESR`)

통신이 안 되거나 노드가 응답하지 않을 때, `NUCLEO-F103RB`의 `bxCAN` 에러 상태 레지스터를 직접 열람하여 버스 상태를 진단합니다.

#### `NUCLEO-F103RB` `bxCAN` 에러 상태 레지스터 (`CAN_ESR`)

- **주소**: **`0x40006418`**

```bash
openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f1x.cfg \
        -c "init; halt; mdw 0x40006418 1; shutdown"
```

- **비트 판독 가이드**:
  - `Bit 2 (BOFF)`: Bus-Off 플래그
  - `Bit 1 (EPVF)`: Error Passive 플래그
  - `Bit 0 (EWGF)`: Error Warning 플래그
  - `Bit 4~6 (LEC)`: Last Error Code (`0b001` Stuff, `0b010` Form, `0b011` ACK, `0b100` Bit recessive, `0b101` Bit dominant, `0b110` CRC)
  - `Bit 16~23 (TEC)`: Transmit Error Counter (송신 에러 카운터, 255 초과 시 Bus-Off)
  - `Bit 24~31 (REC)`: Receive Error Counter (수신 에러 카운터)

---

### [작업 5] 차량 Classic CAN 버스 레벨 실시간 스니핑 & 에러 프레임 포착

RPi 5 리눅스 터미널(`can0`, Seengreat MCP2515 HAT)에서 차량 버스 전체 트래픽을 관찰합니다.

1. **실시간 트래픽 타임스탬프 스니핑**:

   ```bash
   candump -tz can0
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

   - `can state`, `restart-ms`, `RX/TX errors`, `bus-errors` 통계 조회

4. **Bus-Off 상태 강제 리셋 및 복구**:

   ```bash
   sudo ip link set can0 type can restart
   ```

---

### [작업 6] UDS (ISO 14229) 진단 질의 및 DTC 고장코드 판독

차량 표준 진단 프로토콜을 사용해 각 ECU의 고장코드와 센서 스냅샷(Freeze Frame)을 요청합니다.

1. **OBD-II 예시 요청 (`0x7DF`)**:

   ```bash
   # OBD-II Service 01, PID 01 예시. 대상이 해당 서비스를 구현한 경우에만 응답.
   cansend can0 7DF#0201010000000000
   ```

   위 요청은 UDS `ReadDTCInformation`이 아닙니다. 이 프로젝트의 UDS 주소·서비스·ISO-TP 설정은 통신 규약을 확정한 뒤 적용합니다.

2. **UDS 부정 응답 코드(NRC) 디코딩**:
   - 만약 응답으로 `0x7E8 [8] 03 7F 22 31 ...` 이 수신된 경우:
     - `0x7F`: Negative Response
     - `0x22`: 요청했던 서비스 ID
     - `0x31` (`NRC`): **Request Out Of Range** (요청한 파라미터 범위를 벗어남)
     - _(참고: `0x11` = Service Not Supported, `0x22` = Conditions Not Correct)_

---

### [작업 7] 다중 `NUCLEO-F103RB` 보드 타깃 지정 디버깅 (보드 A + 보드 B)

두 대의 `NUCLEO-F103RB` 보드가 RPi 5에 동시에 연결되어 있을 때, `st-info --probe`로 확인한 ST-LINK 고유 시리얼 번호로 대상을 분리 제어합니다:

1. **보드 A: 열관리 제어기 (`NUCLEO-F103RB`, ST-LINK V2-1)**:

   ```bash
   openocd -f interface/stlink.cfg -c "adapter serial <보드A_STLINK_시리얼>" \
           -c "transport select swd" -f target/stm32f1x.cfg \
           -c "init; halt; reg; shutdown"
   ```

2. **보드 B: 스마트 냉각팬 ECU (`NUCLEO-F103RB`, ST-LINK V2-1)**:

   ```bash
   openocd -f interface/stlink.cfg -c "adapter serial <보드B_STLINK_시리얼>" \
           -c "transport select swd" -f target/stm32f1x.cfg \
           -c "init; halt; reg; shutdown"
   ```

---

### [작업 8] GDB 원격 대화형 디버깅 (PC ↔ RPi 5)

IDE(VS Code, CubeIDE)나 터미널에서 C 소스코드 브레이크포인트를 걸고 스텝 실행합니다.

1. **RPi 5에서 `NUCLEO-F103RB`용 GDB 서버 실행**:

   ```bash
   openocd -f interface/stlink.cfg -c "adapter serial <F103_STLINK_시리얼>" \
           -c "transport select swd" -f target/stm32f1x.cfg
   # 포트 3333 오픈 대기
   ```

2. **PC 터미널에서 GDB 클라이언트 접속**:

   ```bash
   gdb-multiarch <실제_빌드된_F103_ELF_경로>
   (gdb) target remote <본인_RPi_IP>:3333
   # 크래시 분석은 reset하지 않고 기존 상태를 보존한다.
   (gdb) break <파일명>:<줄번호>
   (gdb) continue
   (gdb) print <변수명>
   (gdb) step
   ```

---

### [작업 9] AI 진단 에이전트 연동 예시 (`Qwen 2.5 3B`)

아래는 **실제 수집 결과가 아닌 입력 예시**입니다. 제품 운용에서는 CAN(및 벤치 UART)으로 조회한 DTC·부팅/크래시 기록을 먼저 도구로 검증·해석한 뒤 SLM에 전달합니다. SWD 덤프가 없어도 설명을 생성하며, 모델 응답은 실제 원인을 확정하지 않습니다. 과거 크래시를 분석할 때는 기록 당시 Build ID의 ELF가 필요합니다.

```bash
echo "다음은 모의 진단 증거다. 확인된 사실, 원인 후보, 미확인 항목, 다음 점검을 구분해줘:
[출처] board_a의 CAN 저장 기록, record_id=demo-001, capture_boot_id=demo-boot-7
[펌웨어] record_build_id=demo-build-a, running_build_id=demo-build-b
[크래시] CFSR=0x00008200, BFAR=0x00000004. 도구 해석: PRECISERR와 BFARVALID 설정
[문맥] stacked PC=0x08000494. 프레임 유효성 확인은 필요하며 일치하는 ELF가 없어 소스 위치 미확인
[접근] 제품 운용 프로필에서 SWD 미사용. 추가 메모리 조회나 보호 해제 없이 근거 범위에서 설명" | \
llama-cli -m ~/models/qwen2.5-3b-instruct-q4_k_m.gguf -t 4 -c 2048 --temp 0.2
```
