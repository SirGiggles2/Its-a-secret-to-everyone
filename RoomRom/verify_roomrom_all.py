#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]

ROOM_ROWS = 22
ROOM_COLS = 32

LEVEL_INFO_OW_OFFSET = 768
OW_ATTRS_A_OFFSET = 0
OW_ATTRS_B_OFFSET = 128
OW_ATTRS_D_OFFSET = 384
OW_LAYOUTS_OFFSET = 1166
OW_HEAP_BLOB_OFFSET = 3150

COMMON_BG_TILE_OFFSET = 112
COMMON_MISC_TILE_OFFSET = 224
COMMON_BG_TILES = 112
OW_BG_TILES = 130
COMMON_MISC_TILES = 14

PRIMARY_SQUARES = [
    0x24,0x6F,0xF3,0xFA,0x98,0x90,0x8F,0x95,
    0x8E,0x90,0x74,0x76,0xF3,0x24,0x26,0x89,
    0x03,0x04,0x70,0xC8,0xBC,0x8D,0x8F,0x93,
    0x95,0xC4,0xCE,0xD8,0xB0,0xB4,0xAA,0xAC,
    0xB8,0x9C,0xA6,0x9A,0xA2,0xA0,0xE5,0xE6,
    0xE7,0xE8,0xE9,0xEA,0xC0,0xE0,0x78,0x7A,
    0x7E,0x80,0xCC,0xD0,0xD4,0xDC,0x89,0x84,
    0x24,0x24,0x24,0x24,0x6F,0x6F,0x6F,0x6F,
]

SECONDARY_SQUARES = [
    0x24,0x24,0x24,0x24,0x6F,0x6F,0x6F,0x6F,
    0xF3,0xF3,0xF3,0xF3,0xFA,0xFA,0xFA,0xFA,
    0x98,0x95,0x26,0x26,0x90,0x95,0x90,0x95,
    0x8F,0x90,0x8F,0x90,0x95,0x96,0x95,0x96,
    0x8E,0x93,0x90,0x95,0x90,0x95,0x92,0x97,
    0x74,0x74,0x75,0x75,0x76,0x77,0x76,0x77,
    0xF3,0x24,0xF3,0x24,0x24,0x24,0x24,0x24,
    0x26,0x26,0x26,0x26,0x89,0x88,0x8B,0x88,
]

SECONDARY_SQUARES_REDUX = [
    0x24,0x24,0x24,0x24,0x6F,0x6F,0x6F,0x6F,
    0xF3,0xF3,0xF3,0xF3,0xFA,0xFA,0xFA,0xFA,
    0xF3,0x24,0xF3,0x24,0x90,0x95,0x90,0x95,
    0x8F,0x90,0x8F,0x90,0x95,0x96,0x95,0x96,
    0x8E,0x93,0x90,0x95,0x90,0x95,0x92,0x97,
    0x74,0x74,0x75,0x75,0x76,0x77,0x76,0x77,
    0x54,0x24,0x56,0x24,0x24,0x24,0x24,0x24,
    0x26,0x26,0x26,0x26,0x89,0x88,0x8B,0x88,
]

TILE_OBJECT_PRIMARY_SQUARES_OW = [0xC8, 0xD8, 0xC4, 0xBC, 0xC0, 0xC0]
TILE_OBJECT_PRIMARY_SQUARES_OW_REDUX = [0xC8, 0x58, 0x5C, 0xBC, 0xC0, 0xC0]
HEAP_OFFSETS = [0,53,102,168,236,286,346,405,464,526,591,660,721,775,841,893]
PAL_TO_ATTR = [0x00, 0x55, 0xAA, 0xFF]


def c_bytes(path: Path) -> list[int]:
    text = path.read_text(encoding="ascii")
    return [int(x, 16) for x in re.findall(r"0x([0-9a-fA-F]{2})", text)]


def c_words_from_bytes(path: Path) -> list[int]:
    vals = c_bytes(path)
    return [vals[i] | (vals[i + 1] << 8) for i in range(0, len(vals), 2)]


def c_u16_array(path: Path, name: str) -> list[int]:
    text = path.read_text(encoding="ascii")
    match = re.search(rf"{name}\[[^\]]+\]\s*=\s*\{{(.*?)\}};", text, re.S)
    if not match:
        raise ValueError(f"missing C array {name} in {path}")
    return [int(x, 0) for x in re.findall(r"0x[0-9a-fA-F]+|\d+", match.group(1))]


def palette_selector(tile_col: int, tile_row: int, outer: int, inner: int) -> int:
    attr_index = (tile_row // 4) * 8 + (tile_col // 4)
    attr_col = attr_index & 0x07
    attr = PAL_TO_ATTR[outer]
    inner_attr = PAL_TO_ATTR[inner]

    if 9 <= attr_index < 0x27 and attr_col not in (0, 7):
        if attr_index >= 0x21:
            attr = (inner_attr & 0x0F) | (attr & 0xF0)
        else:
            attr = inner_attr

    shift = 0
    if tile_col & 0x02:
        shift += 2
    if tile_row & 0x02:
        shift += 4
    return (attr >> shift) & 0x03


def normalize_primary_tile(raw: int, tile_object_primary: list[int]) -> int:
    if 0xE5 <= raw <= 0xEA:
        return tile_object_primary[raw - 0xE5]
    return raw


def expected_room(
    rooms: list[int],
    room_id: int,
    heap_offsets: list[int] = HEAP_OFFSETS,
    secondary_squares: list[int] = SECONDARY_SQUARES,
    tile_object_primary: list[int] = TILE_OBJECT_PRIMARY_SQUARES_OW,
) -> list[list[int]]:
    outer = rooms[OW_ATTRS_A_OFFSET + room_id] & 0x03
    inner = rooms[OW_ATTRS_B_OFFSET + room_id] & 0x03
    unique = rooms[OW_ATTRS_D_OFFSET + room_id] & 0x7F
    layout_base = OW_LAYOUTS_OFFSET + unique * 16
    grid = [[0 for _ in range(ROOM_COLS)] for _ in range(ROOM_ROWS)]

    for square_col in range(16):
        desc = rooms[layout_base + square_col]
        heap_idx = (desc >> 4) & 0x0F
        col_in_heap = desc & 0x0F
        ptr = OW_HEAP_BLOB_OFFSET + heap_offsets[heap_idx]
        while True:
            if rooms[ptr] & 0x80:
                if col_in_heap == 0:
                    break
                col_in_heap -= 1
            ptr += 1

        repeat_state = 0
        for square_row in range(11):
            sq_byte = rooms[ptr]
            sq_idx = sq_byte & 0x3F
            if sq_idx >= 0x10:
                p = normalize_primary_tile(PRIMARY_SQUARES[sq_idx], tile_object_primary)
                raw_tiles = [p, p + 2, p + 1, p + 3]
            else:
                b = sq_idx * 4
                raw_tiles = [
                    secondary_squares[b],
                    secondary_squares[b + 2],
                    secondary_squares[b + 1],
                    secondary_squares[b + 3],
                ]

            tile_col = square_col * 2
            tile_row = square_row * 2
            positions = [
                (tile_col, tile_row, raw_tiles[0]),
                (tile_col + 1, tile_row, raw_tiles[1]),
                (tile_col, tile_row + 1, raw_tiles[2]),
                (tile_col + 1, tile_row + 1, raw_tiles[3]),
            ]
            for col, row, raw_tile in positions:
                pal = palette_selector(col, row, outer, inner)
                grid[row][col] = (pal << 13) | (raw_tile + 1)

            if sq_byte & 0x40:
                repeat_state ^= 0x40
                if repeat_state != 0:
                    continue
            ptr += 1

    return grid


def expected_cram(rooms: list[int], misc_words: list[int]) -> list[int]:
    out = [0] * 64
    for slot in range(4):
        for i in range(4):
            nes_color = rooms[LEVEL_INFO_OW_OFFSET + 3 + slot * 4 + i]
            out[slot * 16 + i] = misc_words[nes_color]
    return out


def check_chr_contract() -> None:
    common = c_bytes(REPO_ROOT / "data" / "chr" / "common.c")
    ow = c_bytes(REPO_ROOT / "data" / "chr" / "overworld_bg.c")
    assert len(common) >= (COMMON_MISC_TILE_OFFSET + COMMON_MISC_TILES) * 32
    assert len(ow) == OW_BG_TILES * 32


def verify_dump(dump_path: Path) -> int:
    rooms = c_bytes(REPO_ROOT / "data" / "rooms" / "overworld.c")
    rooms_redux = c_bytes(REPO_ROOT / "RoomRom" / "src" / "redux_overworld.c")
    redux_heap_offsets = c_u16_array(
        REPO_ROOT / "RoomRom" / "src" / "redux_overworld.c",
        "rooms_overworld_redux_heap_offsets",
    )
    misc_words = c_words_from_bytes(REPO_ROOT / "data" / "misc" / "palettes.c")
    check_chr_contract()

    dump = json.loads(dump_path.read_text(encoding="utf-8"))
    map_entries = dump.get("maps")
    if map_entries is None:
        map_entries = [{"map_id": 0, "rooms": dump["rooms"]}]

    total_tile = 0
    first: list[str] = []
    for map_entry in map_entries:
        map_id = int(map_entry.get("map_id", 0))
        if map_id == 1:
            expected_rooms = rooms_redux
            expected_heap_offsets = redux_heap_offsets
            expected_secondary = SECONDARY_SQUARES_REDUX
            expected_tile_objects = TILE_OBJECT_PRIMARY_SQUARES_OW_REDUX
            map_name = "redux"
        else:
            expected_rooms = rooms
            expected_heap_offsets = HEAP_OFFSETS
            expected_secondary = SECONDARY_SQUARES
            expected_tile_objects = TILE_OBJECT_PRIMARY_SQUARES_OW
            map_name = "original"
        actual_rooms = {int(r["room_id"]): r["plane_a"] for r in map_entry["rooms"]}
        for room_id in range(128):
            expected = expected_room(
                expected_rooms,
                room_id,
                expected_heap_offsets,
                expected_secondary,
                expected_tile_objects,
            )
            actual = actual_rooms.get(room_id)
            if actual is None:
                total_tile += ROOM_ROWS * ROOM_COLS
                first.append(f"{map_name} room {room_id:02X}: missing dump")
                continue
            for row in range(ROOM_ROWS):
                for col in range(ROOM_COLS):
                    if actual[row][col] != expected[row][col]:
                        total_tile += 1
                        if len(first) < 24:
                            first.append(
                                f"{map_name} room {room_id:02X} ({col},{row}): "
                                f"expected=0x{expected[row][col]:04X} got=0x{actual[row][col]:04X}"
                            )

    expected_palette = expected_cram(rooms, misc_words)
    actual_palette = dump.get("cram", [])
    cram_mismatch = []
    for i, expected in enumerate(expected_palette):
        got = actual_palette[i] if i < len(actual_palette) else None
        if got != expected:
            cram_mismatch.append((i, expected, got))

    for line in first:
        print(line)
    if len(first) == 24 and total_tile > 24:
        print(f"... +{total_tile - 24} more tile word mismatches")
    for i, expected, got in cram_mismatch[:16]:
        print(f"cram[{i}]: expected=0x{expected:04X} got={got if got is None else f'0x{got:04X}'}")
    if len(cram_mismatch) > 16:
        print(f"... +{len(cram_mismatch) - 16} more CRAM mismatches")

    print(f"tile_word_mismatches={total_tile}")
    print(f"cram_mismatches={len(cram_mismatch)}")
    return 0 if total_tile == 0 and not cram_mismatch else 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dump", type=Path, required=True)
    args = parser.parse_args()
    return verify_dump(args.dump)


if __name__ == "__main__":
    sys.exit(main())
