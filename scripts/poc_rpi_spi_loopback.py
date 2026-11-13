#!/usr/bin/env python3
"""External GPIO SPI loopback on an isolated Raspberry Pi SPI0 header."""

import argparse
import ctypes
import json
import os
import struct
import sys
from datetime import datetime, timezone


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--jumper-ready",
        action="store_true",
        help="Confirm HAT is removed and physical pins 19 (MOSI) and 21 (MISO) are joined",
    )
    args = parser.parse_args()
    if not args.jumper_ready:
        parser.error(
            "No transfer performed. Power off, remove the HAT, connect physical pins "
            "19 and 21, power on, then pass --jumper-ready."
        )
    if not sys.platform.startswith("linux"):
        parser.error("This diagnostic requires Linux spidev")

    import fcntl

    report = {
        "checked_at": datetime.now(timezone.utc).isoformat(),
        "scope": "rpi_external_gpio_loopback",
        "device": "/dev/spidev0.0",
        "requested_speed_hz": 100000,
        "setup": "operator-confirmed HAT removed; physical pins 19 and 21 joined",
        "internal_spi_loopback": False,
        "samples": [],
    }
    try:
        fd = os.open(report["device"], os.O_RDWR | os.O_CLOEXEC)
        try:
            mode = bytearray(1)
            fcntl.ioctl(fd, 0x80016B01, mode, True)  # SPI_IOC_RD_MODE
            report["spi_mode"] = mode[0]
            if mode[0] != 0:
                raise RuntimeError("Expected normal SPI mode 0, with SPI_LOOP disabled")
            # Valid MCP2515 READ instructions if accidentally observed by that chip.
            # Physical isolation still must be confirmed before using the jumper.
            patterns = [bytes([3, 14, 0, 0]), bytes([3, 40, 0, 0]), bytes([3, 14, 90, 165])]
            for pattern in patterns:
                for _ in range(3):
                    tx = (ctypes.c_ubyte * len(pattern))(*pattern)
                    rx = (ctypes.c_ubyte * len(pattern))()
                    transfer = struct.pack(
                        "=QQIIHBBBBBB",
                        ctypes.addressof(tx),
                        ctypes.addressof(rx),
                        len(pattern),
                        report["requested_speed_hz"],
                        0,
                        8,
                        0,
                        0,
                        0,
                        0,
                        0,
                    )
                    if len(transfer) != 32:
                        raise RuntimeError("Unexpected Linux SPI transfer layout")
                    fcntl.ioctl(fd, 0x40206B00, transfer)  # SPI_IOC_MESSAGE(1)
                    received = bytes(rx)
                    report["samples"].append(
                        {
                            "tx": pattern.hex(" "),
                            "rx": received.hex(" "),
                            "matched": received == pattern,
                        }
                    )
        finally:
            os.close(fd)
    except (OSError, RuntimeError) as exc:
        report["verdict"] = "not_completed"
        report["error"] = str(exc)
    else:
        report["verdict"] = (
            "passed" if all(row["matched"] for row in report["samples"]) else "failed"
        )
    print(json.dumps(report, indent=2))
    return 0 if report["verdict"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
