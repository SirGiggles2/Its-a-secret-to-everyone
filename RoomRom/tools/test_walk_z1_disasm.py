#!/usr/bin/env python3
"""Tests for RoomRom/tools/walk_z1_disasm.py.

Run: python RoomRom/tools/test_walk_z1_disasm.py
Prints OK if all tests pass; raises AssertionError with details on failure.

Test coverage:
  1. Dispatch classifier boundary cases per Z_01.asm:5279-5306.
  2. ItemFrameOffsets parser: 37 entries, first == 0x00.
  3. ItemFrameTiles parser: >= 48 entries, first three == [0x20, 0x82, 0x3C].
"""

from __future__ import annotations

import sys
import traceback
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "RoomRom" / "tools"))

from walk_z1_disasm import classify_dispatch, _parse_byte_table

DISASM_Z01 = ROOT / "reference" / "aldonunez" / "Z_01.asm"


# ---------------------------------------------------------------------------
# Test runner
# ---------------------------------------------------------------------------

_failures: list[str] = []


def check(name: str, condition: bool, detail: str = "") -> None:
    if condition:
        print(f"  PASS  {name}")
    else:
        msg = f"  FAIL  {name}" + (f": {detail}" if detail else "")
        print(msg)
        _failures.append(msg)


# ---------------------------------------------------------------------------
# Section 1: dispatch classifier boundary cases
# ---------------------------------------------------------------------------

def test_dispatch_classifier() -> None:
    print("--- Section 1: dispatch classifier ---")

    # tile == 0xF3 -> Narrow
    check("tile=0xF3 -> Narrow", classify_dispatch(0xF3) == "Narrow",
          f"got {classify_dispatch(0xF3)!r}")

    # tile == 0x00 -> Wide_Slim  (in [0x00, 0x20))
    check("tile=0x00 -> Wide_Slim", classify_dispatch(0x00) == "Wide_Slim",
          f"got {classify_dispatch(0x00)!r}")

    # tile == 0x1F -> Wide_Slim  (last in [0x00, 0x20))
    check("tile=0x1F -> Wide_Slim", classify_dispatch(0x1F) == "Wide_Slim",
          f"got {classify_dispatch(0x1F)!r}")

    # tile == 0x20 -> Narrow  (first in [0x20, 0x62))
    check("tile=0x20 -> Narrow", classify_dispatch(0x20) == "Narrow",
          f"got {classify_dispatch(0x20)!r}")

    # tile == 0x61 -> Narrow  (last in [0x20, 0x62))
    check("tile=0x61 -> Narrow", classify_dispatch(0x61) == "Narrow",
          f"got {classify_dispatch(0x61)!r}")

    # tile == 0x62 -> Wide_Slim  (first in [0x62, 0x6C))
    check("tile=0x62 -> Wide_Slim", classify_dispatch(0x62) == "Wide_Slim",
          f"got {classify_dispatch(0x62)!r}")

    # tile == 0x6B -> Wide_Slim  (last in [0x62, 0x6C))
    check("tile=0x6B -> Wide_Slim", classify_dispatch(0x6B) == "Wide_Slim",
          f"got {classify_dispatch(0x6B)!r}")

    # tile == 0x6C -> Wide_Mirrored  (first in [0x6C, 0x7C))
    check("tile=0x6C -> Wide_Mirrored", classify_dispatch(0x6C) == "Wide_Mirrored",
          f"got {classify_dispatch(0x6C)!r}")

    # tile == 0x7B -> Wide_Mirrored  (last in [0x6C, 0x7C))
    check("tile=0x7B -> Wide_Mirrored", classify_dispatch(0x7B) == "Wide_Mirrored",
          f"got {classify_dispatch(0x7B)!r}")

    # tile == 0x7C -> Wide_Flippable  (first in [0x7C, 0xF3))
    check("tile=0x7C -> Wide_Flippable", classify_dispatch(0x7C) == "Wide_Flippable",
          f"got {classify_dispatch(0x7C)!r}")

    # tile == 0xF2 -> Wide_Flippable  (just below 0xF3)
    check("tile=0xF2 -> Wide_Flippable", classify_dispatch(0xF2) == "Wide_Flippable",
          f"got {classify_dispatch(0xF2)!r}")

    # tile == 0xF4 -> Wide_Flippable  (just above 0xF3)
    check("tile=0xF4 -> Wide_Flippable", classify_dispatch(0xF4) == "Wide_Flippable",
          f"got {classify_dispatch(0xF4)!r}")

    # tile == 0xFF -> Wide_Flippable
    check("tile=0xFF -> Wide_Flippable", classify_dispatch(0xFF) == "Wide_Flippable",
          f"got {classify_dispatch(0xFF)!r}")

    # Known item tiles from ITEM_DEFS:
    # sword_vert 0x20 -> Narrow
    check("sword_vert 0x20 -> Narrow", classify_dispatch(0x20) == "Narrow",
          f"got {classify_dispatch(0x20)!r}")
    # sword_horz 0x82 -> Wide_Flippable
    check("sword_horz 0x82 -> Wide_Flippable", classify_dispatch(0x82) == "Wide_Flippable",
          f"got {classify_dispatch(0x82)!r}")
    # boomerang 0x36 -> Narrow
    check("boomerang 0x36 -> Narrow", classify_dispatch(0x36) == "Narrow",
          f"got {classify_dispatch(0x36)!r}")
    # explosion 0x70 -> Wide_Mirrored
    check("explosion 0x70 -> Wide_Mirrored", classify_dispatch(0x70) == "Wide_Mirrored",
          f"got {classify_dispatch(0x70)!r}")
    # sword_diag 0x48 -> Narrow
    check("sword_diag 0x48 -> Narrow", classify_dispatch(0x48) == "Narrow",
          f"got {classify_dispatch(0x48)!r}")


# ---------------------------------------------------------------------------
# Section 2: Anim_ItemFrameOffsets parser
# ---------------------------------------------------------------------------

def test_offsets_parser() -> None:
    print("--- Section 2: Anim_ItemFrameOffsets parser ---")

    if not DISASM_Z01.exists():
        check("disasm file exists", False, f"not found: {DISASM_Z01}")
        return

    lines = DISASM_Z01.read_text(encoding="utf-8", errors="replace").splitlines()
    try:
        offsets, _ = _parse_byte_table(lines, "Anim_ItemFrameOffsets")
    except ValueError as e:
        check("parse succeeds", False, str(e))
        return

    check("37 entries", len(offsets) == 37,
          f"got {len(offsets)} entries: {[hex(v) for v in offsets]}")
    check("first entry == 0x00", offsets[0] == 0x00,
          f"first entry = 0x{offsets[0]:02X}")

    # Verify a few known values from the disasm
    # .BYTE $00, $03, $07, $0A, $0B, $0C, $0D, $0E
    expected_first_8 = [0x00, 0x03, 0x07, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E]
    for i, (got, want) in enumerate(zip(offsets[:8], expected_first_8)):
        check(
            f"offsets[{i}] == 0x{want:02X}",
            got == want,
            f"got 0x{got:02X}",
        )


# ---------------------------------------------------------------------------
# Section 3: Anim_ItemFrameTiles parser
# ---------------------------------------------------------------------------

def test_tiles_parser() -> None:
    print("--- Section 3: Anim_ItemFrameTiles parser ---")

    if not DISASM_Z01.exists():
        check("disasm file exists", False, f"not found: {DISASM_Z01}")
        return

    lines = DISASM_Z01.read_text(encoding="utf-8", errors="replace").splitlines()
    try:
        tiles, _ = _parse_byte_table(lines, "Anim_ItemFrameTiles")
    except ValueError as e:
        check("parse succeeds", False, str(e))
        return

    check(">= 48 entries", len(tiles) >= 48,
          f"got {len(tiles)} entries")
    check("tiles[0] == 0x20", tiles[0] == 0x20,
          f"got 0x{tiles[0]:02X}")
    check("tiles[1] == 0x82", tiles[1] == 0x82,
          f"got 0x{tiles[1]:02X}")
    check("tiles[2] == 0x3C", tiles[2] == 0x3C,
          f"got 0x{tiles[2]:02X}")

    # Verify full first row from disasm: $20,$82,$3C,$34,$70,$72,$74,$28
    expected_row0 = [0x20, 0x82, 0x3C, 0x34, 0x70, 0x72, 0x74, 0x28]
    for i, (got, want) in enumerate(zip(tiles[:8], expected_row0)):
        check(
            f"tiles[{i}] == 0x{want:02X}",
            got == want,
            f"got 0x{got:02X}",
        )


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    print("=== test_walk_z1_disasm.py ===\n")
    try:
        test_dispatch_classifier()
        test_offsets_parser()
        test_tiles_parser()
    except Exception:
        traceback.print_exc()
        return 1

    print()
    if _failures:
        print(f"RESULT: FAILED ({len(_failures)} failure(s))")
        for f in _failures:
            print(f"  {f}")
        return 1
    else:
        print("RESULT: OK")
        return 0


if __name__ == "__main__":
    sys.exit(main())
