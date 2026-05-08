#!/usr/bin/env python3
"""PR-3b manifest patch: add triforce_piece + magic_shot + fairy_spark.

Idempotent: skips entries already present.

Maps the remaining whole-CHR-rollout PR-3 items to NES Z1 dispatch:

  triforce_piece — Anim_ItemFrameTiles[$20]=$6E (item slot 26).
    Wide @ Z_01.asm:5279 ($6E >= $62 -> @Wide -> render ($6E,$70)).
    Used by Z_07 ItemDropTarget when boss drops triforce piece.

  magic_shot_v / magic_shot_h — Anim_ItemFrameTiles[$2B]=$7A, [$2C]=$7C
    (item slot $23, magic-rod projectile from Z_07.asm:3493).
    Both wide. Vert frame=($7A,$7C), Horz frame=($7C,$7E).

  fairy_spark — Anim_ItemFrameTiles[$19]=$50, [$1A]=$52 (item slot $14,
    UpdatePondFairy/DrawFairy in Z_04.asm:11508).
    Both narrow ($50,$52 in [$20,$62) per Z_01.asm:5279 dispatch).
    Two animation frames toggled every 4 video frames (DrawFairy ASL/AND
    FrameCounter).

Bytes captured from live NES PPU $0000+ via build/probes/ph5/
nes_uw_chr_dump_candle.lua (PPUCTRL bit 3 = 0 -> sprite pattern table 0).
"""
import hashlib
import json
from pathlib import Path

MANIFEST = Path(__file__).resolve().parents[1] / "data" / "item_chr_manifest.json"

# Bytes captured from C:/tmp/nes_chr_dump_out/summary.json (Zelda1 Lvl1 UW).
PR3B_TILES = {
    "0x50": "3854FFC7C76E4628442881B9B9523A54",
    "0x51": "387C1204000000206CC62A3830202000",
    "0x52": "38547E4647EDC7AE442800387991BBD6",
    "0x53": "12391004000000204683283830202000",
    "0x6E": "00000000000000000000000000000101",
    "0x70": "070F3F776F6FEFF7070F3F7F7F7FFFFF",
    "0x7A": "071F3F70408000000000000000071F3C",
    "0x7C": "000010080C0406060003018040602030",
    "0x7E": "20180C0E06070707000080C0C0E06060",
}

PR3B_SOURCES = {
    "0x50": "common_sprite_live_chr",
    "0x51": "common_sprite_live_chr",
    "0x52": "common_sprite_live_chr",
    "0x53": "common_sprite_live_chr",
    "0x6E": "common_sprite_live_chr",
    "0x70": "uw_sprite_pattern_block_uwsp_live_chr",
    "0x7A": "uw_sprite_pattern_block_uwsp_live_chr",
    "0x7C": "uw_sprite_pattern_block_uwsp_live_chr",
    "0x7E": "uw_sprite_pattern_block_uwsp_live_chr",
}

TRIFORCE_NOTE = (
    "Anim_ItemFrameTiles[$20]=$6E (item slot 26 'PowerTriangle / "
    "TriforcePiece'). Wide dispatch in Anim_WriteSpecificItemSprites "
    "(Z_01.asm:5279): $6E >= $62 -> @Wide, right tile = $6E + 2 = $70. "
    "Renders as 2 sprites side-by-side via $07=1, $0A=8."
)

MAGIC_SHOT_NOTE = (
    "Anim_ItemFrameTiles[$2B]=$7A, [$2C]=$7C (item slot $23, "
    "magic-rod projectile). Z_07 DrawSwordShotOrMagicShot @WriteMagicSprites "
    "(line 3492) sets Y=$23 -> Anim_WriteItemSprites. Both tiles >= $62 -> "
    "@Wide. Vertical frame uses $7A+$7C; horizontal frame uses $7C+$7E."
)

FAIRY_NOTE = (
    "Anim_ItemFrameTiles[$19]=$50, [$1A]=$52 (item slot $14 'FairyMoving'). "
    "DrawFairy (Z_04.asm:11508) toggles frame every 4 video frames "
    "(ASL / AND FrameCounter / LSR LSR -> $0C). Both tiles in [$20,$62) -> "
    "@Narrow dispatch (single 8x16 sprite per OAM entry, NES PPU 8x16 "
    "obj-size mode). Anim_SetSpriteDescriptorRedPaletteRow forces sub-pal "
    "row 1 (red)."
)

FAIRY_SIZE_OVERRIDE_REASON = (
    "NES uses 8x16 hardware sprites (PPU OAM obj size bit). Tile $50 "
    "is the top 8x8, tile $51 is the bottom 8x8 of one 8x16 hardware "
    "sprite (and $52/$53 likewise for frame 1). Anim_WriteSpecificItemSprites "
    "@Narrow (Z_01.asm:5288) emits a single OAM entry whose hardware "
    "height is 16 px. Genesis SPRITE_SIZE(1,2) matches NES visual output "
    "exactly. Identical pattern to the existing sword_vert / arrow_vert "
    "manifest entries."
)

NEW_ITEM_DEFS = [
    {
        "name": "triforce_piece",
        "item": "triforce_piece",
        "direction_class": "static",
        "nes_frame_tile": "0x6E",
        "sprite_size": [2, 1],
        "tile_ids": ["0x6E", "0x70"],
        "draw_rule": "wide_16x8",
        "frame_index": 0,
        "frame_subpal": 2,
        "nes_dispatch_note": TRIFORCE_NOTE,
    },
    {
        "name": "magic_shot_v",
        "item": "magic_shot",
        "direction_class": "vertical",
        "nes_frame_tile": "0x7A",
        "sprite_size": [2, 1],
        "tile_ids": ["0x7A", "0x7C"],
        "draw_rule": "wide_16x8",
        "frame_index": 0,
        "frame_subpal": 0,
        "nes_dispatch_note": MAGIC_SHOT_NOTE,
    },
    {
        "name": "magic_shot_h",
        "item": "magic_shot",
        "direction_class": "horizontal",
        "nes_frame_tile": "0x7C",
        "sprite_size": [2, 1],
        "tile_ids": ["0x7C", "0x7E"],
        "draw_rule": "wide_16x8",
        "frame_index": 1,
        "frame_subpal": 0,
        "nes_dispatch_note": MAGIC_SHOT_NOTE,
    },
    {
        "name": "fairy_spark_f0",
        "item": "fairy_spark",
        "direction_class": "static",
        "nes_frame_tile": "0x50",
        "sprite_size": [1, 2],
        "tile_ids": ["0x50", "0x51"],
        "draw_rule": "narrow_8x16",
        "frame_index": 0,
        "frame_subpal": 1,
        "nes_dispatch_note": FAIRY_NOTE,
        "sprite_size_override_reason": FAIRY_SIZE_OVERRIDE_REASON,
    },
    {
        "name": "fairy_spark_f1",
        "item": "fairy_spark",
        "direction_class": "static",
        "nes_frame_tile": "0x52",
        "sprite_size": [1, 2],
        "tile_ids": ["0x52", "0x53"],
        "draw_rule": "narrow_8x16",
        "frame_index": 1,
        "frame_subpal": 1,
        "nes_dispatch_note": FAIRY_NOTE,
        "sprite_size_override_reason": FAIRY_SIZE_OVERRIDE_REASON,
    },
]


def tile_entry(tile_id: str, hex_bytes: str) -> dict:
    addr = int(tile_id, 16) * 16
    return {
        "ppu_addr": f"0x{addr:04X}",
        "source": PR3B_SOURCES[tile_id],
        "sha256": hashlib.sha256(bytes.fromhex(hex_bytes)).hexdigest(),
        "flat_pattern": False,
        "bytes": hex_bytes,
    }


def main():
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))

    existing_names = {d["name"] for d in data["item_defs"]}
    new_defs = [d for d in NEW_ITEM_DEFS if d["name"] not in existing_names]
    data["item_defs"].extend(new_defs)

    tiles_added = 0
    for variant in data["variants"]:
        tiles = variant.setdefault("tiles", {})
        for tile_id, hex_bytes in PR3B_TILES.items():
            if tile_id not in tiles:
                tiles[tile_id] = tile_entry(tile_id, hex_bytes)
                tiles_added += 1

    MANIFEST.write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"[pr3b_patch] added {len(new_defs)} item_defs "
          f"({', '.join(d['name'] for d in new_defs)}), "
          f"{tiles_added} new tile entries -> {MANIFEST}")


if __name__ == "__main__":
    main()
