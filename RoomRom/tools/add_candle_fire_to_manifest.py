#!/usr/bin/env python3
"""One-shot manifest patch: add candle_fire_f0..f3 + tile entries.

Idempotent: skips work if candle_fire_f0 already present.
"""
import hashlib
import json
from pathlib import Path

MANIFEST = Path(__file__).resolve().parents[1] / "data" / "item_chr_manifest.json"

CANDLE_FIRE_TILES = {
    "0x44": "0000003C7E66C3DB0000000000183C3C",
    "0x46": "0000001C3E7F3E00000000001000413E",
    "0x5C": "0004292B0F2D7B7A0010000000420405",
    "0x5E": "4484A0E0E8DADEFD0000000400002000",
    "0x9E": "00004080001834240080B078FCE4C8D8",
    "0xA0": "0000000000000000010303070F0F0F07",
    "0xCE": "02040C18183838380107031F073F3F07",
    "0xD0": "0501010301000000FDFEFEFCFEFFFFFF",
}

CANDLE_FIRE_SOURCES = {
    "0x44": "common_sprite_live_chr",
    "0x46": "common_sprite_live_chr",
    "0x5C": "common_sprite_live_chr",
    "0x5E": "common_sprite_live_chr",
    "0x9E": "uw_sprite_pattern_block_uwsp127_live_chr",
    "0xA0": "uw_sprite_pattern_block_uwsp127_live_chr",
    "0xCE": "uw_sprite_pattern_block_uwsp_boss1257_live_chr",
    "0xD0": "uw_sprite_pattern_block_uwsp_boss1257_live_chr",
}

NES_DISPATCH_NOTE = (
    "UpdateFire (Z_07.asm:4622) draws fire via DrawObjectWithType anim "
    "index $40 (uses $41 after INY) -> ObjAnimations[$41]=$08 -> "
    "ObjAnimFrameHeap[$08+frame] tile pairs ($5C/$5E, $9E/$A0, $44/$46, $CE/$D0). "
    "Each frame is 2 NES tiles side-by-side (left+2=right per "
    "DrawObjectWithAnimAndSpecificSprites). ObjAnimAttrHeap[$08+frame] "
    "sub_pal sequence = (2, 0, 0, 1). Animation: 4 frames @ 4 ticks each "
    "(LDA #$04 / Anim_AdvanceAnimCounter)."
)

SPRITE_SIZE_OVERRIDE_REASON = (
    "Candle fire bypasses Anim_WriteItemSprites' Narrow/Wide tile-range "
    "dispatch. UpdateFire (Z_07.asm:4622) calls DrawObjectWithType "
    "(Z_01.asm:5011) which always uses 2 sprites side-by-side via "
    "DrawObjectWithAnimAndSpecificSprites: $07=1 (two sides), $0A=8 "
    "(8-pixel separation), right tile = ObjAnimFrameHeap[Y]+2. NES tile "
    "ranges that would normally classify as Narrow (e.g. $5C, $44) are "
    "rendered as 16x8 here regardless. Genesis SPRITE_SIZE(2,1) matches."
)

NEW_ITEM_DEFS = [
    {
        "name": "candle_fire_f0",
        "item": "candle_fire",
        "direction_class": "static",
        "nes_frame_tile": "0x5C",
        "sprite_size": [2, 1],
        "tile_ids": ["0x5C", "0x5E"],
        "draw_rule": "wide_16x8",
        "frame_index": 0,
        "frame_subpal": 2,
        "nes_dispatch_note": NES_DISPATCH_NOTE,
        "sprite_size_override_reason": SPRITE_SIZE_OVERRIDE_REASON,
    },
    {
        "name": "candle_fire_f1",
        "item": "candle_fire",
        "direction_class": "static",
        "nes_frame_tile": "0x9E",
        "sprite_size": [2, 1],
        "tile_ids": ["0x9E", "0xA0"],
        "draw_rule": "wide_16x8",
        "frame_index": 1,
        "frame_subpal": 0,
        "nes_dispatch_note": NES_DISPATCH_NOTE,
        "sprite_size_override_reason": SPRITE_SIZE_OVERRIDE_REASON,
    },
    {
        "name": "candle_fire_f2",
        "item": "candle_fire",
        "direction_class": "static",
        "nes_frame_tile": "0x44",
        "sprite_size": [2, 1],
        "tile_ids": ["0x44", "0x46"],
        "draw_rule": "wide_16x8",
        "frame_index": 2,
        "frame_subpal": 0,
        "nes_dispatch_note": NES_DISPATCH_NOTE,
        "sprite_size_override_reason": SPRITE_SIZE_OVERRIDE_REASON,
    },
    {
        "name": "candle_fire_f3",
        "item": "candle_fire",
        "direction_class": "static",
        "nes_frame_tile": "0xCE",
        "sprite_size": [2, 1],
        "tile_ids": ["0xCE", "0xD0"],
        "draw_rule": "wide_16x8",
        "frame_index": 3,
        "frame_subpal": 1,
        "nes_dispatch_note": NES_DISPATCH_NOTE,
        "sprite_size_override_reason": SPRITE_SIZE_OVERRIDE_REASON,
    },
]


def tile_entry(tile_id: str, hex_bytes: str) -> dict:
    addr = int(tile_id, 16) * 16
    return {
        "ppu_addr": f"0x{addr:04X}",
        "source": CANDLE_FIRE_SOURCES[tile_id],
        "sha256": hashlib.sha256(bytes.fromhex(hex_bytes)).hexdigest(),
        "flat_pattern": False,
        "bytes": hex_bytes,
    }


def main():
    data = json.loads(MANIFEST.read_text(encoding="utf-8"))

    existing_names = {d["name"] for d in data["item_defs"]}
    if "candle_fire_f0" in existing_names:
        print("[manifest_patch] already patched, no-op")
        return

    data["item_defs"].extend(NEW_ITEM_DEFS)

    for variant in data["variants"]:
        tiles = variant.setdefault("tiles", {})
        for tile_id, hex_bytes in CANDLE_FIRE_TILES.items():
            if tile_id not in tiles:
                tiles[tile_id] = tile_entry(tile_id, hex_bytes)

    MANIFEST.write_text(
        json.dumps(data, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    print(f"[manifest_patch] added 4 candle_fire item_defs, "
          f"{len(CANDLE_FIRE_TILES)} tiles per variant -> {MANIFEST}")


if __name__ == "__main__":
    main()
