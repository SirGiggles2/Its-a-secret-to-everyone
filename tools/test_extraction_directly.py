#!/usr/bin/env python3
"""Inspect RoomAttrsOW_D extraction from an explicit NES reference ROM.

This script is a manual probe. It never writes outside the repo and it does
not assume a developer-specific checkout path. Set REFERENCE_ROM or
ZELDA_NES_ROM to run it against a local ROM.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "builds/reports/extraction_direct"
OUT_FILE = OUT_DIR / "test_attrs_d.inc"
REFERENCE_ROM = os.environ.get("REFERENCE_ROM") or os.environ.get("ZELDA_NES_ROM")


def read_ines_rom(rom_path: Path) -> bytes:
    with rom_path.open("rb") as f:
        f.seek(16)
        return f.read(0x20000)


def data_to_inc_bytes(data: bytes, label: str, bytes_per_line: int = 16) -> str:
    lines = [f"; {label} - {len(data)} bytes", f"{label}:"]
    for i in range(0, len(data), bytes_per_line):
        chunk = data[i:i + bytes_per_line]
        lines.append("    dc.b " + ",".join(f"${byte:02X}" for byte in chunk))
    return "\n".join(lines) + "\n"


def main() -> int:
    if not REFERENCE_ROM:
        print("SKIP: set REFERENCE_ROM or ZELDA_NES_ROM to run extraction probe")
        return 0

    rom_path = Path(REFERENCE_ROM)
    if not rom_path.is_file():
        print(f"ERROR: reference ROM not found: {rom_path}", file=sys.stderr)
        return 1

    prg_data = read_ines_rom(rom_path)

    level_block_size = 0x0300
    bank6_offset = 6 * 0x4000
    level_block_start = 0x0400
    rom_offset = bank6_offset + level_block_start
    ow_block = prg_data[rom_offset:rom_offset + level_block_size]

    print(f"Reading LevelBlockOW from ROM offset 0x{rom_offset:05X}")
    print(f"Block size: {len(ow_block)} bytes")
    print()

    attrs_d = ow_block[0x180:0x200]
    print("RoomAttrsOW_D (offset 0x180):")
    print(f"  First 16 bytes: {' '.join(f'{b:02X}' for b in attrs_d[:16])}")
    print(f"  Room 0x37: 0x{attrs_d[0x37]:02X}")
    print()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    output = data_to_inc_bytes(attrs_d, "RoomAttrsOW_D")
    OUT_FILE.write_text(output, encoding="utf-8")

    print(f"Wrote test file: {OUT_FILE}")
    print("First few lines:")
    for line in output.splitlines()[:5]:
        print(f"  {line}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
