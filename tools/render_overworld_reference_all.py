#!/usr/bin/env python3
"""
render_overworld_reference_all.py - Render and export all 128 overworld rooms.

Outputs:
  - builds/reports/overworld_all_rooms_reference.json
  - builds/reports/overworld_all_rooms_reference.png

This extends the single-room reference flow to every overworld room using the
same extracted Zelda source tables.
"""

from __future__ import annotations

import json
from pathlib import Path

from render_overworld_reference import (
    ROOM_TILE_COLS,
    ROOM_TILE_ROWS,
    build_play_area_attrs,
    cram_to_rgb,
    decode_overworld_room,
    parse_bytes,
    parse_bytes_span,
    parse_tile_block,
    parse_words,
)

try:
    from PIL import Image, ImageDraw
except ImportError as exc:  # pragma: no cover - environment-specific
    raise SystemExit(f"Pillow is required: {exc}")


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

    tiles = (
        parse_tile_block("TilesCommonBG", tiles_common)
        + parse_tile_block("TilesOverworldBG", tiles_overworld)
        + parse_tile_block("TilesCommonMisc", tiles_common)
    )
    palette_lines = [
        [cram_to_rgb(word) for word in cram_words[row * 16 : row * 16 + 4]]
        for row in range(4)
    ]

    rooms_payload: list[dict[str, object]] = []

    atlas_cols = 16
    atlas_rows = 8
    room_px_w = ROOM_TILE_COLS * 8
    room_px_h = ROOM_TILE_ROWS * 8
    atlas = Image.new("RGB", (atlas_cols * room_px_w, atlas_rows * room_px_h), (0, 0, 0))
    atlas_pixels = atlas.load()
    draw = ImageDraw.Draw(atlas)

    for room_id in range(0x80):
        attr_bytes = build_play_area_attrs(room_id, attrs_a, attrs_b, selector_table)
        tile_words, palette_selectors = decode_overworld_room(
            room_id,
            layouts,
            attrs_d,
            primary_squares,
            secondary_squares,
            tile_object_primary,
            heap_blob,
            directory_offsets,
            attr_bytes,
        )

        room_record = {
            "room_id": room_id,
            "playarea_attrs": attr_bytes,
            "palette_selectors": palette_selectors,
            "tile_words": tile_words,
        }
        rooms_payload.append(room_record)

        atlas_col = room_id & 0x0F
        atlas_row = room_id >> 4
        origin_x = atlas_col * room_px_w
        origin_y = atlas_row * room_px_h

        for row in range(ROOM_TILE_ROWS):
            for col in range(ROOM_TILE_COLS):
                tile_word = tile_words[row][col]
                selector = (tile_word >> 13) & 0x03
                tile_index = tile_word & 0x07FF
                if tile_index == 0:
                    tile = [[0] * 8 for _ in range(8)]
                else:
                    idx = tile_index - 1
                    tile = tiles[idx] if idx < len(tiles) else [[0] * 8 for _ in range(8)]
                colors = palette_lines[selector]
                for py in range(8):
                    for px in range(8):
                        atlas_pixels[origin_x + col * 8 + px, origin_y + row * 8 + py] = colors[tile[py][px] & 0x03]

        label = f"{room_id:02X}"
        draw.text((origin_x + 2, origin_y + 2), label, fill=(255, 255, 255))

    json_path = reports_dir / "overworld_all_rooms_reference.json"
    png_path = reports_dir / "overworld_all_rooms_reference.png"

    payload = {
        "room_count": len(rooms_payload),
        "cram_words": cram_words,
        "rooms": rooms_payload,
    }
    json_path.write_text(json.dumps(payload, indent=2))
    atlas.save(png_path)

    print(f"Wrote {json_path}")
    print(f"Wrote {png_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
