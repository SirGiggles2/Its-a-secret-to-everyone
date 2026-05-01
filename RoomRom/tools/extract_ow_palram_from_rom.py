#!/usr/bin/env python3
"""Extract Overworld PALRAM (32 bytes: 16 BG + 16 SPR) from NES Z1 ROMs.

Source-first extraction: pulls bytes directly from the PRG-ROM at the offset
of LevelInfoOW's palette transfer buffer. NES Z_06.asm:403 declares
`LevelInfoOW: .INCBIN "dat/LevelInfoOW.dat"` whose first 36 bytes are the
PPU transfer header `$3F $00 $20` followed by 32 bytes of PALRAM data plus
a `$FF` terminator. After link in Bank 6, the 32 PALRAM bytes land at PRG
file offset 0x19313 in standard 128KB iNES ROM (16-byte header + bank-6
data window). Verified against both vanilla `zelda.nes` and `ZeldaRedux.nes`
with the leading byte assertion below.

Output:
    {"orig":  [32 bytes...],
     "redux": [32 bytes...]}
written to RoomRom/out/nes_ow_palram_static.json.

Per-room sub-pal-3 patches that NES Z_07.asm @ChooseTileObjPalette applies
at runtime (rock/gravestone/armos rooms) are NOT included here; those are
deferred. This file holds the level-default OW PALRAM that applies to most
rooms.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_PATH = ROOT / "out" / "nes_ow_palram_static.json"

ROMS = {
    "orig":  Path("C:/Users/Jake Diggity/Documents/GitHub/VDP rebirth tools and asms/BizHawk-2.11-win-x64/zelda.nes"),
    "redux": Path("C:/Users/Jake Diggity/Documents/GitHub/VDP rebirth tools and asms/BizHawk-2.11-win-x64/ZeldaRedux.nes"),
}

# PRG offset of the 4-byte PPU header that precedes OW PALRAM bytes.
PPU_HEADER_OFFSET = 0x19310
EXPECTED_HEADER = (0x3F, 0x00, 0x20)
PALRAM_OFFSET = PPU_HEADER_OFFSET + 3
PALRAM_LEN = 32


def fail(msg: str) -> None:
    print(f"extract_ow_palram_from_rom: FAIL: {msg}", file=sys.stderr)
    sys.exit(1)


def extract(rom_path: Path) -> list[int]:
    if not rom_path.exists():
        fail(f"missing ROM: {rom_path}")
    blob = rom_path.read_bytes()
    if len(blob) < PALRAM_OFFSET + PALRAM_LEN:
        fail(f"{rom_path.name}: too small ({len(blob)} bytes)")
    header = tuple(blob[PPU_HEADER_OFFSET:PPU_HEADER_OFFSET + 3])
    if header != EXPECTED_HEADER:
        fail(f"{rom_path.name}: unexpected header at 0x{PPU_HEADER_OFFSET:X}: "
             f"got {header}, expected {EXPECTED_HEADER}. ROM layout differs from "
             "vanilla; manual offset audit required.")
    palram = list(blob[PALRAM_OFFSET:PALRAM_OFFSET + PALRAM_LEN])
    if palram[0] != 0x0F:
        fail(f"{rom_path.name}: PALRAM[0] = 0x{palram[0]:02X} != 0x0F (universal "
             "backdrop). Offset wrong or ROM is unusual.")
    return palram


def main() -> None:
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    payload = {label: extract(path) for label, path in ROMS.items()}
    OUT_PATH.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    for label, pr in payload.items():
        print(f"{label}: {' '.join(f'{b:02X}' for b in pr)}")
    print(f"wrote {OUT_PATH}")


if __name__ == "__main__":
    main()
