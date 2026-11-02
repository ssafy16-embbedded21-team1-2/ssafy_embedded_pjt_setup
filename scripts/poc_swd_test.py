#!/usr/bin/env python3
"""
STM32 SWD 연결 및 레지스터 덤프 PoC 스크립트 (tool_swd.py 프로토타입)
- st-info 및 pyocd를 활용하여 연결된 보드의 시리얼 번호와 레지스터를 실시간 조회
"""

import subprocess


def check_stlink_probes():
    print("=== [1] ST-LINK USB 프로브 탐색 (st-info) ===")
    try:
        res = subprocess.run(["st-info", "--probe"], capture_output=True, text=True)
        if res.stdout.strip():
            print(res.stdout)
        else:
            print(
                "[안내] 현재 연결된 ST-LINK 보드가 없습니다. (STM32 Nucleo 보드를 USB에 연결해 주세요)"
            )
    except Exception as e:
        print(f"[오류] st-info 실행 실패: {e}")


def check_pyocd_targets():
    print("\n=== [2] PyOCD 타겟 탐색 (pyocd list) ===")
    try:
        res = subprocess.run(["pyocd", "list"], capture_output=True, text=True)
        print(res.stdout if res.stdout else res.stderr)
    except Exception as e:
        print(f"[오류] pyocd list 실패: {e}")


def print_openocd_cmd_guide():
    print("\n=== [3] OpenOCD CLI 명령어 가이드 (경고 방지 최적화 구문) ===")
    print("# [STM32F1 계열 (Nucleo-F103 등)]:")
    print(
        "openocd -f interface/stlink.cfg -c 'transport select swd' -f target/stm32f1x.cfg \\"
    )
    print("        -c 'init; reset halt; reg; resume; exit'")
    print()
    print("# [STM32F4 계열 (Nucleo-F401, F411, F446 등)]:")
    print(
        "openocd -f interface/stlink.cfg -c 'transport select swd' -f target/stm32f4x.cfg \\"
    )
    print("        -c 'init; reset halt; reg; resume; exit'")
    print()
    print(
        "# [특정 시리얼 번호(Cell 1~4) 지정 및 HardFault CFSR(0xE000ED28) 확인 예시]:"
    )
    print(
        "openocd -f interface/stlink.cfg -c 'adapter serial <시리얼>' -c 'transport select swd' \\"
    )
    print(
        "        -f target/stm32f1x.cfg -c 'init; reset halt; mdw 0xE000ED28; resume; exit'"
    )


if __name__ == "__main__":
    check_stlink_probes()
    check_pyocd_targets()
    print_openocd_cmd_guide()
