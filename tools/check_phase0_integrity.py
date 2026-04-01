#!/usr/bin/env python3
"""
check_phase0_integrity.py

Guardrails for the WHAT IF phase 0 diagnostic ROM.

This checker exists to catch exactly the kinds of drift that can waste time:
- Plane A base register silently changing away from $8000
- Plane A VRAM write command drifting away from $40000002
- Docs claiming one CRAM table while the assembled ROM contains another
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REQUIRED_LISTING_SNIPPETS = [
    "33FC822000C00004",
    "23FC4000000200C0",
]

SOURCE_ROOT = Path(__file__).resolve().parents[1]
PALETTE_SOURCE = SOURCE_ROOT / "src" / "scenes" / "palette_diagnostic.asm"
PALETTE_LABEL = "PaletteDiagnosticCRAM:"
EXPECTED_CRAM_WORDS = 16


def fail(message: str) -> None:
    print(f"FAIL: {message}")
    sys.exit(1)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def load_expected_cram(path: Path) -> list[int]:
    if not path.is_file():
        fail(f"missing palette source: {path}")

    words: list[int] = []
    in_table = False

    for raw_line in read_text(path).splitlines():
        line = raw_line.split(";", 1)[0].strip()
        if not in_table:
            if line == PALETTE_LABEL:
                in_table = True
            continue

        if not line:
            continue

        match = re.match(r"dc\.w\s+\$([0-9A-Fa-f]{4})\b", line)
        if match:
            words.append(int(match.group(1), 16))
            if len(words) == EXPECTED_CRAM_WORDS:
                return words
            continue

        break

    fail(f"unable to parse {EXPECTED_CRAM_WORDS} CRAM words from {path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lst", required=True)
    parser.add_argument("--rom", required=True)
    args = parser.parse_args()

    lst_path = Path(args.lst)
    rom_path = Path(args.rom)

    if not lst_path.is_file():
        fail(f"missing listing: {lst_path}")
    if not rom_path.is_file():
        fail(f"missing rom: {rom_path}")

    expected_cram = load_expected_cram(PALETTE_SOURCE)
    listing = read_text(lst_path).upper()
    rom = rom_path.read_bytes().hex().upper()

    for snippet in REQUIRED_LISTING_SNIPPETS:
        if snippet not in listing:
            fail(f"required listing sequence missing: {snippet}")

    expected_words = [f"{value:04X}" for value in expected_cram]
    for word in expected_words:
        if word not in listing:
            fail(f"expected CRAM word not found in listing: {word}")

    cram_hex = "".join(expected_words)
    if cram_hex not in rom:
        fail("expected CRAM table not found in ROM image")

    print("PASS: phase 0 integrity")
    print("  Plane A register write: $8220 verified in listing")
    print("  Plane A VRAM write cmd: $40000002 verified in listing")
    print(f"  Expected CRAM source: {PALETTE_SOURCE}")
    print("  Expected CRAM table verified in listing and ROM")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
