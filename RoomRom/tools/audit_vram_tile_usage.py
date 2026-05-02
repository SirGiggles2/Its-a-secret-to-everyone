#!/usr/bin/env python3
"""Per-scene VRAM tile-usage auditor for RoomRom (pre-CHR-expansion baseline).

Reports current tile counts per category and the post-4x-expansion total.
Used to commit concrete numeric VRAM constants in roomrom_vram_map.h
before Phase 3 expansion.

Categories (per scene):
  BG bank (will quadruple under Phase 3):
    common_chr BG section            (COMMON_BG_TILE_COUNT)
    overworld_bg_chr                 (OW_BG_TILE_COUNT)
    underworld_bg_chr                (UW_BG_TILE_COUNT)
    redux_overworld_bg_chr           (REDUX_OW_BG_TILE_COUNT)
    redux_overworld_secret_chr       (12)
    redux_uw_bg_chr (256 tiles)      (256)
    redux_automap_chr                (32)
    common_chr misc section          (14)
    HUD custom 3 tiles               (3)

  SPR bank (will quadruple under Phase 3):
    sprites_chr                      (232)
    common_chr full block            (238)
    Link walk + attack poses         (32 + 16)
    item atlas                       (from atlas/items_chr_x4.h)
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

CONSTS = {
    "COMMON_BG_TILE_COUNT":       112,
    "OW_BG_TILE_COUNT":           130,
    "UW_BG_TILE_COUNT":           130,
    "COMMON_MISC_TILE_COUNT":     14,
    "REDUX_AUTOMAP_TILE_COUNT":   32,
    "REDUX_SECRET_TILE_COUNT":    12,
    "REDUX_UW_TILE_COUNT":        256,
    "SPRITE_BLOCK_TILE_COUNT":    232,
    "COMMON_BLOCK_TILE_COUNT":    238,
    "LINK_WALK_TILE_COUNT":       32,
    "LINK_ATTACK_TILE_COUNT":     16,
    "HUD_CUSTOM_TILE_COUNT":      3,
}

def get_item_atlas_tiles():
    """Item atlas tile count from atlas/items_chr_x4.h (supersedes legacy roomrom_item_chr.h)."""
    atlas_x4 = ROOT / "src" / "atlas" / "items_chr_x4.h"
    if atlas_x4.exists():
        text = atlas_x4.read_text(encoding="utf-8")
        m = re.search(r"ROOMROM_ATLAS_ITEMS_X4_TILE_COUNT\s+(\d+)u?", text)
        if m:
            return int(m.group(1))
    return 0


def main():
    item_tiles = get_item_atlas_tiles()
    print(f"item atlas tiles: {item_tiles}")

    bg_ow_orig = (CONSTS["COMMON_BG_TILE_COUNT"]
                  + CONSTS["OW_BG_TILE_COUNT"]
                  + CONSTS["COMMON_MISC_TILE_COUNT"]
                  + CONSTS["REDUX_AUTOMAP_TILE_COUNT"]
                  + CONSTS["HUD_CUSTOM_TILE_COUNT"])
    bg_ow_redux = bg_ow_orig + CONSTS["REDUX_SECRET_TILE_COUNT"]
    bg_uw_orig = (CONSTS["COMMON_BG_TILE_COUNT"]
                  + CONSTS["UW_BG_TILE_COUNT"]
                  + CONSTS["COMMON_MISC_TILE_COUNT"]
                  + CONSTS["HUD_CUSTOM_TILE_COUNT"])
    bg_uw_redux = (CONSTS["REDUX_UW_TILE_COUNT"]
                   + CONSTS["HUD_CUSTOM_TILE_COUNT"])
    bg_max = max(bg_ow_orig, bg_ow_redux, bg_uw_orig, bg_uw_redux)
    print(f"BG tiles per scene: ow_orig={bg_ow_orig} ow_redux={bg_ow_redux} "
          f"uw_orig={bg_uw_orig} uw_redux={bg_uw_redux} max={bg_max}")

    spr_total = (CONSTS["SPRITE_BLOCK_TILE_COUNT"]
                 + CONSTS["COMMON_BLOCK_TILE_COUNT"]
                 + CONSTS["LINK_WALK_TILE_COUNT"]
                 + CONSTS["LINK_ATTACK_TILE_COUNT"]
                 + item_tiles)
    print(f"SPR tiles total: {spr_total}")

    bg_x4 = bg_max * 4
    spr_x1 = spr_total           # sprites: sub-pal 0 only currently -> 1x
    spr_x4 = spr_total * 4
    print(f"After 4x BG + 4x SPR: BG={bg_x4} SPR={spr_x4} sum={bg_x4 + spr_x4}")
    print(f"After 4x BG + 1x SPR (sub-pal-0 only): BG={bg_x4} SPR={spr_x1} sum={bg_x4 + spr_x1}")
    print(f"Genesis 4bpp tile budget: 2048 (64KB / 32B)")

    if bg_x4 + spr_x1 > 2048:
        print("FAIL: even 4x BG + 1x SPR exceeds VRAM budget", file=sys.stderr)
        sys.exit(1)

    # Strategy: full 4x for BG (NES AT routes any tile to any sub-pal at runtime),
    # 1x for SPR (RoomRom sprites all use NES SPR sub-pal 0 today; enemy work
    # deferred per memory). Future enemy expansion can extend SPR per-pal stride.
    suggested_bg_per_pal  = bg_max
    suggested_spr_per_pal = spr_total
    suggested_bg_base     = 1
    suggested_spr_base    = suggested_bg_base + 4 * suggested_bg_per_pal
    print()
    print("Suggested roomrom_vram_map.h constants (4x BG + 1x SPR):")
    print(f"  ROOMROM_BG_TILE_BASE          = {suggested_bg_base}")
    print(f"  ROOMROM_BG_TILE_COUNT_PER_PAL = {suggested_bg_per_pal}")
    print(f"  ROOMROM_SPR_TILE_BASE         = {suggested_spr_base}")
    print(f"  ROOMROM_SPR_TILE_COUNT_PER_PAL= {suggested_spr_per_pal}")
    end_tile = suggested_spr_base + suggested_spr_per_pal - 1
    print(f"  Total VRAM tiles used         = {end_tile}")


if __name__ == "__main__":
    main()
