#!/usr/bin/env python3
"""Overworld room reference generator.

Mirrors the decode logic in src/game/room/ow_room_render.c exactly.
Reads data/rooms/overworld.c, decodes one or all rooms into expected
{col,row: [tile, pal]} grids in Genesis Plane A coordinate space.

Coordinate space: col 0..31, row 2..23 (rows 0-1 = HUD, not written
by the room renderer).  Same keys as normalize_gen.py bg_tile/bg_palette.

Usage:
    python tools/probes/gen_room_reference.py [room_id_hex]
    python tools/probes/gen_room_reference.py 0x77   # single room
    python tools/probes/gen_room_reference.py         # all 128 rooms
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

_REPO_ROOT = Path(__file__).resolve().parents[2]
_OVERWORLD_C = _REPO_ROOT / "data" / "rooms" / "overworld.c"

OW_ATTRS_A_OFFSET   = 0
OW_ATTRS_B_OFFSET   = 128
OW_ATTRS_D_OFFSET   = 384
OW_LAYOUTS_OFFSET   = 1166
OW_HEAP_BLOB_OFFSET = 2126

_PRIMARY_SQUARES = [
    0x24,0x6F,0xF3,0xFA,0x98,0x90,0x8F,0x95,
    0x8E,0x90,0x74,0x76,0xF3,0x24,0x26,0x89,
    0x03,0x04,0x70,0xC8,0xBC,0x8D,0x8F,0x93,
    0x95,0xC4,0xCE,0xD8,0xB0,0xB4,0xAA,0xAC,
    0xB8,0x9C,0xA6,0x9A,0xA2,0xA0,0xE5,0xE6,
    0xE7,0xE8,0xE9,0xEA,0xC0,0xE0,0x78,0x7A,
    0x7E,0x80,0xCC,0xD0,0xD4,0xDC,0x89,0x84,
    0x24,0x24,0x24,0x24,0x6F,0x6F,0x6F,0x6F,  # SecondarySquaresOW[0..7]
]

_SECONDARY_SQUARES = [
    0x24,0x24,0x24,0x24,0x6F,0x6F,0x6F,0x6F,
    0xF3,0xF3,0xF3,0xF3,0xFA,0xFA,0xFA,0xFA,
    0x98,0x95,0x26,0x26,0x90,0x95,0x90,0x95,
    0x8F,0x90,0x8F,0x90,0x95,0x96,0x95,0x96,
    0x8E,0x93,0x90,0x95,0x90,0x95,0x92,0x97,
    0x74,0x74,0x75,0x75,0x76,0x77,0x76,0x77,
    0xF3,0x24,0xF3,0x24,0x24,0x24,0x24,0x24,
    0x26,0x26,0x26,0x26,0x89,0x88,0x8B,0x88,
]

_HEAP_OFFSETS = [0,53,102,168,236,286,346,405,464,526,591,660,721,775,841,893]


def load_overworld_data(c_file: Path = _OVERWORLD_C) -> bytes:
    text = c_file.read_text(encoding="ascii")
    # Extract all 0xXX byte literals from the C array initialiser.
    values = re.findall(r'0x([0-9a-fA-F]{2})\b', text)
    return bytes(int(v, 16) for v in values)


def _ow_room_palette(col: int, row: int, outer_pal: int, inner_pal: int) -> int:
    attr_col = col >> 1
    attr_row = row >> 1
    if attr_col == 0 or attr_col == 7:
        return outer_pal
    if attr_row < 3:
        return outer_pal
    return inner_pal


def decode_room(rooms: bytes, room_id: int) -> dict[str, list[int]]:
    """Decode one room into expected Genesis Plane A cells.

    Returns {"col,row": [tile, pal]} in Genesis plane-A coordinate space.
    Rows 2..23 match what ow_room_render_fill_plane_a writes (write_square
    offsets by pr = row*2+2 to leave rows 0-1 for the HUD).
    Tile values >= 130 are clamped to 0 (matches write_square).
    """
    outer_pal     = rooms[OW_ATTRS_A_OFFSET + room_id] & 0x03
    inner_pal     = rooms[OW_ATTRS_B_OFFSET + room_id] & 0x03
    unique_id     = rooms[OW_ATTRS_D_OFFSET + room_id] & 0x3F
    col_dirs_base = OW_LAYOUTS_OFFSET + unique_id * 16

    grid: dict[str, list[int]] = {}

    for col in range(16):
        desc        = rooms[col_dirs_base + col]
        heap_idx    = (desc >> 4) & 0x0F
        col_in_heap = desc & 0x0F
        heap_ptr    = OW_HEAP_BLOB_OFFSET + _HEAP_OFFSETS[heap_idx]

        # Walk to the col_in_heap-th column-start byte (bit 7 set).
        cols_found = col_in_heap
        while True:
            if rooms[heap_ptr] & 0x80:
                if cols_found == 0:
                    break
                cols_found -= 1
            heap_ptr += 1

        row = 0
        repeat_state = 0
        while row < 11:
            sq_byte = rooms[heap_ptr]
            sq_idx  = sq_byte & 0x3F

            if sq_idx >= 0x10:
                p = _PRIMARY_SQUARES[sq_idx]
                tile_tl, tile_bl, tile_tr, tile_br = p, p+1, p+2, p+3
            else:
                b = sq_idx * 4
                tile_tl = _SECONDARY_SQUARES[b]
                tile_bl = _SECONDARY_SQUARES[b + 1]
                tile_tr = _SECONDARY_SQUARES[b + 2]
                tile_br = _SECONDARY_SQUARES[b + 3]

            if tile_tl >= 130: tile_tl = 0
            if tile_bl >= 130: tile_bl = 0
            if tile_tr >= 130: tile_tr = 0
            if tile_br >= 130: tile_br = 0

            pal = _ow_room_palette(col, row, outer_pal, inner_pal)
            pc  = col * 2
            pr  = row * 2 + 2

            grid[f"{pc},{pr}"]     = [tile_tl, pal]
            grid[f"{pc},{pr+1}"]   = [tile_bl, pal]
            grid[f"{pc+1},{pr}"]   = [tile_tr, pal]
            grid[f"{pc+1},{pr+1}"] = [tile_br, pal]

            row += 1

            if sq_byte & 0x40:
                repeat_state ^= 0x40
                if repeat_state != 0:
                    continue
            heap_ptr += 1

    return grid


def main(argv: list[str]) -> int:
    rooms = load_overworld_data()
    if argv:
        room_id = int(argv[0], 0)
        out = {room_id: decode_room(rooms, room_id)}
    else:
        out = {i: decode_room(rooms, i) for i in range(128)}
    json.dump(out, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
