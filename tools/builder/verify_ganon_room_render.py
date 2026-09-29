"""Compare the corrected live NES Ganon chamber with the Genesis plane.

Run after the T-004 NES mode-3 and Genesis phase-2 probes. This checks the
captured source blob and every visible play-area tile slot, not boss sprites.
"""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools/builder"))
import gen_uw_room_tiles as rooms  # noqa: E402

NES = ROOT / "builds/reports/recovery/t004-ganon-nt-mode3"
GEN = ROOT / "builds/reports/recovery/t004-gen-ganon-nt"


def rows_of(source: str, name: str) -> list[list[int]]:
    match = re.search(r"\b" + name + r"\b[^\{]*\{", source)
    if not match:
        raise SystemExit(f"missing {name}")
    start = match.end()
    i, depth = start, 1
    while depth:
        depth += (source[i] == "{") - (source[i] == "}")
        i += 1
    return [[int(x, 0) for x in re.findall(r"0x[0-9a-fA-F]+|\b\d+\b", row)]
            for row in re.findall(r"\{([^{}]*)\}", source[start:i - 1])]


def main() -> int:
    nes = (NES / "t004_ganon_nt_combat.bin").read_bytes()
    nes_pal = (NES / "t004_ganon_nt_combat_pal.bin").read_bytes()
    plane = (GEN / "t004_gen_ganon.bin").read_bytes()
    state = (GEN / "t004_gen_ganon.txt").read_text()
    if len(nes) != 2048 or len(nes_pal) != 32 or len(plane) != 8192:
        raise SystemExit("capture size mismatch")
    if "mode=05 level=09 room=42 phase=02" not in state:
        raise SystemExit("Genesis capture is not L9Q1 Ganon combat")
    entry = next(i for i, row in enumerate(rooms.INDEX) if row == [0, 1, 9, 0x42])
    nes_nt = list(nes[8 * 32:30 * 32])
    if rooms.nt_of(entry) != nes_nt:
        raise SystemExit("committed Ganon blob NT differs from live NES")

    source = (ROOT / "RoomRom/src/uw_room_blob.c").read_text()
    attrs = rows_of(source, "g_uw_room_attr")
    palettes = rows_of(source, "g_uw_room_palette")
    if attrs[entry] != list(nes[0x3C0:0x400]) or palettes[entry] != list(nes_pal):
        raise SystemExit("committed Ganon attributes/palette differ from live NES")
    lut = rows_of((ROOT / "RoomRom/src/bg_sparse_chr.c").read_text(),
                  "bg_sparse_tile_lut")
    bad = []
    for row in range(22):
        nt_row = row + 8
        plane_row = (row + 7) & 63
        for col in range(32):
            tile = nes_nt[row * 32 + col]
            ai = ((nt_row >> 2) << 3) | (col >> 2)
            shift = (((nt_row >> 1) & 1) << 2) | (((col >> 1) & 1) << 1)
            subpal = (nes[0x3C0 + (ai & 0x3F)] >> shift) & 3
            slot = lut[tile][subpal]
            want = 0 if slot == 0xFFFF else slot + 1
            offset = (plane_row * 64 + col) * 2
            got = ((plane[offset] << 8) | plane[offset + 1]) & 0x7FF
            if got != want:
                bad.append((row, col, want, got))
    print(f"Ganon blob NT/attr/palette: live NES exact; Genesis plane: {704-len(bad)}/704 tiles")
    if bad:
        print("first mismatches:", bad[:12])
    return 1 if bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
