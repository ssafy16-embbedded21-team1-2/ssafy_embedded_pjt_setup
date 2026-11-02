# STM32 임베디드 디버깅 작업 가이드 및 명령어 매뉴얼

본 문서는 Raspberry Pi 5 진단 벤치에 설치된 도구군(`OpenOCD`, `GDB-multiarch`, `pyocd`, `stlink-tools`, `binutils-arm-none-eabi`, `pyserial`, `Qwen 2.5 3B`)을 활용하여 **STM32(Cortex-M3/M4) 마이크로컨트롤러를 디버깅할 수 있는 작업 목록과 실전 CLI 명령어**를 집대성한 가이드입니다.

---

## 1. 디버깅 도구 및 역할 매핑 요약

| 디버깅 계층              | 담당 도구                              | 주요 디버깅 대상                                                    |
| :----------------------- | :------------------------------------- | :------------------------------------------------------------------ |
| **CPU 코어 / 크래시**    | `openocd`, `pyocd`, `gdb-multiarch`    | CPU 실행 제어, Core 레지스터, HardFault 원인 분석 (CFSR, BFAR)      |
| **소스코드 심볼 역추적** | `arm-none-eabi-addr2line`, `gdb`       | 크래시 주소(PC) ➡️ C 파일명/라인 번호 매핑, 콜 스택 복원            |
| **메모리 & 주변장치**    | `openocd (mdw/mww)`, `pyocd`           | SRAM 변수/버퍼 실시간 덤프, GPIO/TIM/UART/I2C/SPI SFR 레지스터 점검 |
| **펌웨어 수명주기**      | `st-info`, `st-flash`, `openocd`       | 칩 ID/Flash 검증, 펌웨어 덤프/원격 플래싱, 읽기보호(RDP) 해제       |
| **런타임 시리얼 로그**   | `pyserial`, Linux `/dev/serial/by-id/` | UART printf 로그 스트림, Heartbeat 타임아웃 감시, CLI 명령 송수신   |
| **AI 자율 분석**         | `Qwen 2.5 3B` (llama.cpp)              | 16진수 레지스터 및 로그를 기반으로 자연어 고장 원인 리포트 생성     |

---

## 2. 작업별 상세 디버깅 시나리오 및 명령어

### [작업 1] HardFault 및 크래시(Crash) 원인 분석

MCU가 무응답이거나 HardFault 핸들러에서 무한 루프를 돌고 있을 때, 코어 레지스터를 조회하여 원인을 즉각 규명합니다.

1. **CPU 정지 및 코어 레지스터 일괄 확인**:

   ```bash
   openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f1x.cfg \
           -c "init; halt; reg; resume; exit"
   ```

   - 확인 대상: `PC` (정지된 주소), `LR` (함수 복귀 주소), `SP` (스택 포인터)

2. **HardFault 상태 레지스터 (SCB CFSR) 정밀 판독**:

   ```bash
   # CFSR(0xE000ED28) 및 HFSR(0xE000ED2C) 레지스터 읽기 (32비트 워드 2개)
   openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f1x.cfg \
           -c "init; halt; mdw 0xE000ED28 2; resume; exit"
   ```

   - **비트 해석 가이드**:
     - `0x00010000` (`UNDEFINSTR`): 정의되지 않은 기계어 명령어 실행
     - `0x00020000` (`INVSTATE`): 잘못된 EPSR 상태 (Thumb 모드 위반)
     - `0x00040000` (`INVPC`): 잘못된 EXC_RETURN으로 복귀 시도
     - `0x01000000` (`UNALIGNED`): 비정렬 메모리 접근 오류
     - `0x02000000` (`DIVBYZERO`): 0으로 나누기 연산 발생
     - `0x00000082` (`PRECISERR`): 정확한 메모리 버스 오류 ➡️ **BFAR(0xE000ED38) 주소 확인 필수**

3. **잘못 접근한 메모리 번지(BFAR) 확인**:

   ```bash
   openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f1x.cfg \
           -c "init; halt; mdw 0xE000ED38 1; resume; exit"
   ```

   - 예: `0x00000004`가 출력되면 "구조체 널 포인터 역참조(`ptr->member`)" 버그임이 확정됩니다.

---

### [작업 2] 소스코드 파일 및 라인 번호 역추적 (addr2line)

HardFault가 발생했을 때 확인한 `PC` 주소를 소스코드 라인으로 변환합니다.

```bash
# 형식: arm-none-eabi-addr2line -e <컴파일된_ELF파일> -a <PC_주소> -f -C
arm-none-eabi-addr2line -e build/firmware.elf -a 0x08000494 -f -C
```

- **출력 결과 예시**:

  ```text
  0x08000494
  calculate_motor_speed
  /home/pi/firmware/src/motor_ctrl.c:142
  ```

  ➡️ 개발자는 142번째 라인을 열어 즉시 디버깅할 수 있습니다.

---

### [작업 3] 실시간 메모리(SRAM) 및 전역 변수 모니터링

MCU 펌웨어가 실행 중이거나 정지된 상태에서 전역 변수나 수신 버퍼 데이터를 실시간으로 읽거나 강제 조작합니다.

1. **SRAM 시작 번지 덤프 (16워드 / 64바이트)**:

   ```bash
   openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f1x.cfg \
           -c "init; halt; mdw 0x20000000 16; resume; exit"
   ```

2. **특정 전역 변수 메모리 강제 수정 (테스트 목적)**:

   ```bash
   # 0x20000100 번지에 32비트 값 0x00000001 쓰기
   openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f1x.cfg \
           -c "init; halt; mww 0x20000100 0x00000001; resume; exit"
   ```

---

### [작업 4] 하드웨어 주변장치(Peripheral SFR) 실사

하드웨어(모터, 센서)가 돌지 않거나 통신이 안 될 때, 해당 주변장치의 하드웨어 레지스터를 직접 열람합니다.

1. **주변장치 클록(RCC) 인에이블 여부 확인**:

   ```bash
   # RCC_APB2ENR (0x40021018): GPIOA~E, TIM1 클록 활성화 비트 확인
   openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f1x.cfg \
           -c "init; halt; mdw 0x40021018 1; resume; exit"
   ```

   - 클록 비트가 0이면 펌웨어에서 `__HAL_RCC_GPIOA_CLK_ENABLE()` 호출을 누락한 것입니다.

2. **타이머 PWM 출력 듀티비(CCR) 확인 (모터 구동 셀)**:

   ```bash
   # TIM1 CCR1~CCR4 레지스터(0x40012C34) 읽기
   openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f1x.cfg \
           -c "init; halt; mdw 0x40012C34 4; resume; exit"
   ```

   - `CCR1` 값이 `0`이면 PWM 듀티가 0%로 모터가 정지해 있는 원인입니다.

3. **I2C 버스 멈춤(Busy Lock) 확인 (센서 셀)**:

   ```bash
   # I2C1 SR2 레지스터(0x40005418): BUSY 비트(Bit 1) 확인
   openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f1x.cfg \
           -c "init; halt; mdw 0x40005418 1; resume; exit"
   ```

   - BUSY 비트가 1로 고정되어 있으면 SCL/SDA 라인이 물리적으로 그라운드에 쇼트되었거나 슬레이브 센서가 SDA를 잡고 있는 상태입니다.

---

### [작업 5] 원격 펌웨어 플래싱, 백업 및 검증

PC에서 빌드된 펌웨어 바이너리를 RPi 5를 통해 STM32에 즉시 다운로드하거나 기존 플래시를 백업합니다.

1. **연결된 칩 정보 및 플래시 용량 프로브**:

   ```bash
   st-info --probe
   ```

2. **펌웨어 바이너리 즉시 플래싱 (st-flash)**:

   ```bash
   st-flash --reset write firmware.bin 0x08000000
   ```

3. **기존 플래시 메모리 덤프 (백업)**:

   ```bash
   # 128KB(0x20000 바이트) 플래시 전체 덤프
   st-flash read backup_firmware.bin 0x08000000 0x20000
   ```

---

### [작업 6] 4대 멀티 보드 타깃 지정 디버깅 (Cell 1\~4)

4대의 STM32 보드가 연결되어 있을 때, ST-LINK 고유 시리얼 번호로 특정 셀만 지정하여 디버깅합니다.

```bash
# Cell 1 (시리얼: 066AFF545052836687064157) 보드만 정지 후 레지스터 확인
openocd -f interface/stlink.cfg -c "adapter serial 066AFF545052836687064157" \
        -c "transport select swd" -f target/stm32f1x.cfg \
        -c "init; reset halt; reg; resume; exit"
```

---

### [작업 7] GDB 원격 대화형 디버깅 (PC 또는 RPi 콘솔)

IDE(VS Code, CubeIDE)나 터미널에서 C 소스코드 브레이크포인트를 걸고 스텝 실행합니다.

1. **RPi 5에서 GDB 서버 실행**:

   ```bash
   openocd -f interface/stlink.cfg -c "transport select swd" -f target/stm32f1x.cfg
   # 3333 포트 오픈 대기
   ```

2. **GDB 클라이언트 접속 (PC 또는 RPi5 로컬 터미널)**:

   ```bash
   gdb-multiarch build/firmware.elf
   (gdb) target remote localhost:3333
   (gdb) monitor reset halt
   (gdb) break main
   (gdb) continue
   (gdb) print motor_speed
   (gdb) step
   ```

---

### [작업 8] AI 진단 에이전트 연동 (Qwen 2.5 3B 자동 분석)

위 작업 1~4에서 수집된 덤프 텍스트를 파이프라인으로 로컬 SLM에 전달하면 원인과 처방을 한국어로 자동 도출합니다.

```bash
# 레지스터 덤프 결과를 프롬프트와 함께 Qwen 2.5 3B에 입력
echo "아래 HardFault 레지스터 덤프를 분석하고 원인과 수정 가이드를 한글로 보고해줘:
PC: 0x08000494, CFSR: 0x00008200 (PRECISERR), BFAR: 0x00000004, LR: 0x080005B1" | \
llama-cli -m ~/models/qwen2.5-3b-instruct-q4_k_m.gguf -t 4 -c 2048 --temp 0.2
```
