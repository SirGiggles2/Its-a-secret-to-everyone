#!/usr/bin/env python3
"""
render_overworld_reference.py - Render the extracted Zelda overworld start room.

Outputs:
  - builds/reports/overworld_start_room_reference.png
  - builds/reports/overworld_start_room_reference.json

The JSON contains the expected room id, converted CRAM words, palette selectors,
and final Genesis tile words for the 32x22 start-room playfield.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError as exc:  # pragma: no cover - environment-specific
    raise SystemExit(f"Pillow is required: {exc}")


ROOM_TILE_COLS = 32
ROOM_TILE_ROWS = 22
ROOM_ATTR_COLS = 8
ROOM_ATTR_ROWS = 6
ROOM_START_ROOM_OFFSET = 0x2F


def parse_bytes(label: str, path: Path) -> list[int]:
    text = path.read_text()
    match = re.search(rf"(?m)^{re.escape(label)}:\n((?:\s*dc\.b [^\n]+\n)+)", text)
    if not match:
        raise ValueError(f"Missing label {label} in {path}")
    values: list[int] = []
    for line in match.group(1).splitlines():
        _, data = line.split("dc.b", 1)
        for token in data.split(","):
            token = token.strip()
            if token:
                values.append(int(token[1:], 16))
    return values


def parse_bytes_span(label: str, path: Path, count: int) -> list[int]:
    text = path.read_text()
    match = re.search(rf"(?ms)^{re.escape(label)}:\n(.*)", text)
    if not match:
        raise ValueError(f"Missing label {label} in {path}")

    values: list[int] = []
    for line in match.group(1).splitlines():
        line = line.strip()
        if not line.startswith("dc.b"):
            continue
        _, data = line.split("dc.b", 1)
        for token in data.split(","):
            token = token.strip()
            if token:
                values.append(int(token[1:], 16))
                if len(values) == count:
                    return values

    raise ValueError(f"Could not parse {count} bytes from {label} in {path}")


def parse_words(label: str, path: Path) -> list[int]:
    text = path.read_text()
    match = re.search(rf"(?m)^{re.escape(label)}:\n((?:\s*dc\.w [^\n]+\n)+)", text)
    if not match:
        raise ValueError(f"Missing label {label} in {path}")
    values: list[int] = []
    for line in match.group(1).splitlines():
        _, data = line.split("dc.w", 1)
        for token in data.split(","):
            token = token.strip()
            if token:
                values.append(int(token[1:], 16))
    return values


def parse_tile_block(label: str, path: Path) -> list[list[list[int]]]:
    text = path.read_text()
    match = re.search(rf"(?ms)^{re.escape(label)}:\n(.*)", text)
    if not match:
        raise ValueError(f"Missing tile block {label} in {path}")

    tiles: list[list[list[int]]] = []
    words: list[int] = []
    for line in match.group(1).splitlines():
        line = line.strip()
        if line.startswith("; tile "):
            if words:
                tiles.append(tile_words_to_pixels(words))
                words = []
        elif line.startswith("dc.w"):
            _, data = line.split("dc.w", 1)
            for token in data.split(","):
                token = token.strip()
                if token:
                    words.append(int(token[1:], 16))
    if words:
        tiles.append(tile_words_to_pixels(words))
    return tiles


def tile_words_to_pixels(words: list[int]) -> list[list[int]]:
    if len(words) != 16:
        raise ValueError(f"Expected 16 words per tile, got {len(words)}")
    pixels: list[list[int]] = []
    for row in range(8):
        word_a = words[row * 2]
        word_b = words[row * 2 + 1]
        packed = [
            (word_a >> 8) & 0xFF,
            word_a & 0xFF,
            (word_b >> 8) & 0xFF,
            word_b & 0xFF,
        ]
        row_pixels: list[int] = []
        for byte in packed:
            row_pixels.append((byte >> 4) & 0x0F)
            row_pixels.append(byte & 0x0F)
        pixels.append(row_pixels)
    return pixels


def cram_to_rgb(word: int) -> tuple[int, int, int]:
    blue = ((word >> 8) & 0x0E) * 18
    green = ((word >> 4) & 0x0E) * 18
    red = (word & 0x0E) * 18
    return red, green, blue


def build_play_area_attrs(room_id: int, attrs_a: list[int], attrs_b: list[int], selector_table: list[int]) -> list[int]:
    outer_selector = attrs_a[room_id] & 0x03
    inner_selector = attrs_b[room_id] & 0x03
    outer_attr = selector_table[outer_selector]
    inner_attr = selector_table[inner_selector]

    attrs = [outer_attr] * (ROOM_ATTR_COLS * ROOM_ATTR_ROWS)
    for index in range(0x09, 0x27):
        column = index & 0x07
        if column == 0 or column == 7:
            continue
        if index >= 0x21:
            attrs[index] = (attrs[index] & 0xF0) | (inner_attr & 0x0F)
        else:
            attrs[index] = inner_attr
    return attrs


def get_tile_palette_selector(tile_col: int, tile_row: int, attrs: list[int]) -> int:
    attr_index = (tile_row // 4) * ROOM_ATTR_COLS + (tile_col // 4)
    attr_byte = attrs[attr_index]
    shift = 0
    if tile_col & 0x02:
        shift += 2
    if tile_row & 0x02:
        shift += 4
    return (attr_byte >> shift) & 0x03


def write_square(
    tile_words: list[list[int]],
    palette_selectors: list[list[int]],
    square_col: int,
    square_row: int,
    square_index: int,
    primary_tile: int,
    secondary_squares: list[int],
    attr_bytes: list[int],
) -> None:
    tile_col = square_col * 2
    tile_row = square_row * 2

    if square_index < 0x10:
        offset = square_index * 4
        raw_tiles = [
            secondary_squares[offset + 0],
            secondary_squares[offset + 2],
            secondary_squares[offset + 1],
            secondary_squares[offset + 3],
        ]
    else:
        raw_tiles = [
            primary_tile,
            primary_tile + 2,
            primary_tile + 1,
            primary_tile + 3,
        ]

    positions = [
        (tile_col + 0, tile_row + 0, raw_tiles[0]),
        (tile_col + 1, tile_row + 0, raw_tiles[1]),
        (tile_col + 0, tile_row + 1, raw_tiles[2]),
        (tile_col + 1, tile_row + 1, raw_tiles[3]),
    ]

    for col, row, raw_tile in positions:
        selector = get_tile_palette_selector(col, row, attr_bytes)
        word = (selector << 13) | (raw_tile + 1)
        tile_words[row][col] = word
        palette_selectors[row][col] = selector


def decode_overworld_room(
    room_id: int,
    layouts: list[int],
    attrs_d: list[int],
    primary_squares: list[int],
    secondary_squares: list[int],
    tile_object_primary: list[int],
    heap_blob: list[int],
    directory_offsets: list[int],
    attr_bytes: list[int],
) -> tuple[list[list[int]], list[list[int]]]:
    unique_room_id = attrs_d[room_id] & 0x3F
    layout = layouts[unique_room_id * 16 : unique_room_id * 16 + 16]

    tile_words = [[0 for _ in range(ROOM_TILE_COLS)] for _ in range(ROOM_TILE_ROWS)]
    palette_selectors = [[0 for _ in range(ROOM_TILE_COLS)] for _ in range(ROOM_TILE_ROWS)]

    repeat_state = 0
    for square_col, descriptor in enumerate(layout):
        heap_index = (descriptor >> 4) & 0x0F
        column_index = descriptor & 0x0F
        offset = directory_offsets[heap_index] - 1
        while True:
            offset += 1
            if heap_blob[offset] & 0x80:
                if column_index == 0:
                    break
                column_index -= 1

        for square_row in range(11):
            square_desc = heap_blob[offset]
            square_index = square_desc & 0x3F
            primary_tile = primary_squares[square_index]
            if 0xE5 <= primary_tile <= 0xEA:
                primary_tile = tile_object_primary[primary_tile - 0xE5]

            write_square(
                tile_words,
                palette_selectors,
                square_col,
                square_row,
                square_index,
                primary_tile,
                secondary_squares,
                attr_bytes,
            )

            if square_desc & 0x40:
                repeat_state ^= 0x40
                if repeat_state == 0:
                    offset += 1
            else:
                offset += 1

    return tile_words, palette_selectors


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    data_dir = root / "src" / "data"
    reports_dir = root / "builds" / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)

    rooms_ow = data_dir / "rooms_overworld.inc"
    room_layouts = data_dir / "room_layouts.inc"
    room_columns = data_dir / "room_columns.inc"
    level_info = data_dir / "level_info.inc"
    palettes = data_dir / "palettes.inc"
    tiles_common = data_dir / "tiles_common.inc"
    tiles_overworld = data_dir / "tiles_overworld.inc"
    rooms_asm = root / "src" / "rooms.asm"

    start_room_id = parse_bytes("LevelInfoOW", level_info)[ROOM_START_ROOM_OFFSET]
    attrs_a = parse_bytes("RoomAttrsOW_A", rooms_ow)
    attrs_b = parse_bytes("RoomAttrsOW_B", rooms_ow)
    attrs_d = parse_bytes("RoomAttrsOW_D", rooms_ow)
    layouts = parse_bytes_span("RoomLayoutsOW", room_layouts, 57 * 16)
    selector_table = parse_bytes("RoomPaletteSelectorToNTAttr", rooms_asm)
    primary_squares = parse_bytes("PrimarySquaresOW", rooms_asm)
    secondary_squares = parse_bytes("SecondarySquaresOW", rooms_asm)
    tile_object_primary = parse_bytes("TileObjectPrimarySquaresOW", rooms_asm)
    nes_to_cram = parse_words("NesColorToGenesisCRAM", palettes)
    level_info_ow = parse_bytes("LevelInfoOW", level_info)

    heap_blob = parse_bytes("ColumnHeapOWBlob", room_columns)
    directory_offsets = parse_words("ColumnDirectoryOWOffsets", room_columns)

    cram_words = [0] * 64
    for palette_index in range(4):
        for color_index in range(4):
            nes_color = level_info_ow[3 + palette_index * 4 + color_index]
            cram_words[palette_index * 16 + color_index] = nes_to_cram[nes_color]
    attr_bytes = build_play_area_attrs(start_room_id, attrs_a, attrs_b, selector_table)
    tile_words, palette_selectors = decode_overworld_room(
        start_room_id,
        layouts,
        attrs_d,
        primary_squares,
        secondary_squares,
        tile_object_primary,
        heap_blob,
        directory_offsets,
        attr_bytes,
    )

    tiles = (
        parse_tile_block("TilesCommonBG", tiles_common)
        + parse_tile_block("TilesOverworldBG", tiles_overworld)
        + parse_tile_block("TilesCommonMisc", tiles_common)
    )
    palette_lines = [
        [cram_to_rgb(word) for word in cram_words[row * 16 : row * 16 + 4]]
        for row in range(4)
    ]

    image = Image.new("RGB", (ROOM_TILE_COLS * 8, ROOM_TILE_ROWS * 8), (0, 0, 0))
    pixels = image.load()
    for row in range(ROOM_TILE_ROWS):
        for col in range(ROOM_TILE_COLS):
            tile_word = tile_words[row][col]
            selector = (tile_word >> 13) & 0x03
            tile_index = tile_word & 0x07FF
            if tile_index == 0:
                tile = [[0] * 8 for _ in range(8)]
            else:
                tile = tiles[tile_index - 1] if tile_index - 1 < len(tiles) else [[0] * 8 for _ in range(8)]
            colors = palette_lines[selector]
            for py in range(8):
                for px in range(8):
                    pixels[col * 8 + px, row * 8 + py] = colors[tile[py][px] & 0x03]

    png_path = reports_dir / "overworld_start_room_reference.png"
    json_path = reports_dir / "overworld_start_room_reference.json"
    image.save(png_path)

    payload = {
        "room_id": start_room_id,
        "cram_words": cram_words,
        "playarea_attrs": attr_bytes,
        "palette_selectors": palette_selectors,
        "tile_words": tile_words,
    }
    json_path.write_text(json.dumps(payload, indent=2))

    print(f"Wrote {png_path}")
    print(f"Wrote {json_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
