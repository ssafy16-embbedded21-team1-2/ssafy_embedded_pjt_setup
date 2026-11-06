"""Read selected identification/configuration registers without halt/reset/flash operations."""

import hashlib
import json
import os
import platform
import subprocess
from datetime import datetime
from pathlib import Path

from pyocd import __version__
from pyocd.core.helpers import ConnectHelper


def now():
    return datetime.now().astimezone().isoformat()


def command(*args):
    result = subprocess.run(args, capture_output=True, text=True, check=False)
    return {
        "argv": list(args),
        "exit_code": result.returncode,
        "stdout": result.stdout,
        "stderr": result.stderr,
    }


uid = "066CFF535551836687112626"
options = {
    "target_override": "stm32f103rb",
    "connect_mode": "attach",
    "frequency": 1000000,
    "auto_unlock": False,
    "resume_on_disconnect": False,
    "config_file": None,
    "no_config": True,
    "load_svd": True,
}
pack = Path("/home/pi/.local/share/cmsis-pack-manager/Keil/STM32F1xx_DFP/2.4.1.pack")
result = {
    "started_at": now(),
    "hostname": platform.node(),
    "architecture": platform.machine(),
    "os_release": Path("/etc/os-release").read_text(),
    "python": platform.python_version(),
    "python_executable": os.sys.executable,
    "pyocd_version": __version__,
    "probe_uid": uid,
    "options": options,
    "pack_file": str(pack),
    "pack_sha256": hashlib.sha256(pack.read_bytes()).hexdigest(),
    "commands": [
        command(*args)
        for args in [
            ["id"],
            ["pyocd", "list"],
            ["pyocd", "pack", "show"],
            ["st-info", "--version"],
            ["st-info", "--probe", "--hot-plug"],
            ["lsusb"],
            ["lsusb", "-t"],
            ["ls", "-l", "/dev/serial/by-id/"],
            ["lsblk", "-o", "NAME,TRAN,VENDOR,MODEL,SERIAL,LABEL,MOUNTPOINTS"],
            ["pgrep", "-af", "openocd|ST-LINK_gdbserver|pyocd.*gdbserver"],
        ]
    ],
    "board_details": Path("/media/pi/NODE_F103RB/DETAILS.TXT").read_text(),
    "registers": [],
}
session = ConnectHelper.session_with_chosen_probe(
    unique_id=uid, blocking=False, auto_open=False, options=options
)
if session is None:
    raise RuntimeError("Expected probe not found")
with session:
    session.open()
    target = session.target
    result["connected_at"] = now()
    result["part_number"] = target.part_number
    result["state_before"] = target.get_state().name
    result["core_type"] = str(target.selected_core.core_type)
    result["memory_map"] = [
        {
            "name": region.name,
            "type": region.type.name,
            "start": f"0x{region.start:08X}",
            "length": region.length,
            "access": region.access,
            "blocksize": getattr(region, "blocksize", None),
            "page_size": getattr(region, "page_size", None),
            "flm": str(getattr(region, "flm", None)),
            "flash_algorithm_loaded": bool(getattr(region, "algo", None)),
        }
        for region in target.memory_map
    ]
    svd = target.svd_device
    result["svd"] = {
        "name": svd.name,
        "version": svd.version,
        "peripheral_count": len(svd.peripherals),
        "peripherals": [
            {"name": p.name, "address": f"0x{p.base_address:08X}"}
            for p in svd.peripherals
        ],
    }
    # No FIFO/data/status-clear read sequences. All accesses below are explicit reads.
    registers = [
        ("CPUID", 0xE000ED00, 32),
        ("DBGMCU_IDCODE", 0xE0042000, 32),
        ("FLASH_SIZE_KIB", 0x1FFFF7E0, 16),
        ("UID_WORD0", 0x1FFFF7E8, 32),
        ("UID_WORD1", 0x1FFFF7EC, 32),
        ("UID_WORD2", 0x1FFFF7F0, 32),
        ("INITIAL_SP", 0x08000000, 32),
        ("RESET_VECTOR", 0x08000004, 32),
        ("RCC_CR", 0x40021000, 32),
        ("RCC_CFGR", 0x40021004, 32),
        ("RCC_APB2ENR", 0x40021018, 32),
        ("RCC_APB1ENR", 0x4002101C, 32),
        ("AFIO_MAPR", 0x40010004, 32),
        ("GPIOA_CRL", 0x40010800, 32),
        ("GPIOA_CRH", 0x40010804, 32),
        ("GPIOB_CRL", 0x40010C00, 32),
        ("GPIOB_CRH", 0x40010C04, 32),
        ("USART2_BRR", 0x40004408, 32),
        ("USART2_CR1", 0x4000440C, 32),
        ("USART2_CR2", 0x40004410, 32),
        ("USART2_CR3", 0x40004414, 32),
        ("CAN_MCR", 0x40006400, 32),
        ("CAN_MSR", 0x40006404, 32),
        ("CAN_ESR", 0x40006418, 32),
        ("CAN_BTR", 0x4000641C, 32),
        ("SCB_CFSR", 0xE000ED28, 32),
        ("SCB_HFSR", 0xE000ED2C, 32),
    ]
    for name, address, width in registers:
        entry = {
            "name": name,
            "address": f"0x{address:08X}",
            "width_bits": width,
            "read_at": now(),
        }
        try:
            entry["raw"] = f"0x{target.read_memory(address, width):0{width // 4}X}"
        except Exception as exc:
            entry["error"] = str(exc)
        result["registers"].append(entry)
    result["state_after"] = target.get_state().name
    result["before_disconnect_at"] = now()
result["finished_at"] = now()
result["debug_servers_after"] = command(
    "pgrep", "-af", "openocd|ST-LINK_gdbserver|pyocd.*gdbserver"
)
print(json.dumps(result, ensure_ascii=False, indent=2))
