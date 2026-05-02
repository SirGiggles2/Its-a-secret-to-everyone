#!/usr/bin/env python3
"""Hard gate: VRAM tile-bank ranges do not overlap each other or VDP tables.

Reads constants from RoomRom/src/roomrom_vram_map.h and
RoomRom/src/atlas/items_chr_x4.h.
VDP table layout from SGDK defaults (sgdk/src/vdp.c:23-27):
  plane B  = $C000 (size depends on plane size; 64x32 = $0800)
  window   = $D000 ($1000 in H40)
  plane A  = $E000 ($2000 max)
  hscroll  = $F000 ($0400)
  SAT      = $F400 ($0280)

Conservative bound: tile data must end before $C000 (= tile 1536).

Exit code 0 = pass, 1 = fail.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VRAM_MAP_H    = ROOT / "src" / "roomrom_vram_map.h"
ITEM_CHR_H    = ROOT / "src" / "atlas" / "items_chr_x4.h"

VDP_TABLES = {
    "plane_b":  (0xC000, 0xC000 + 0x2000),  # max 8KB region (game-config dependent)
    "window":   (0xD000, 0xD000 + 0x1000),
    "plane_a":  (0xE000, 0xE000 + 0x2000),
    "h_scroll": (0xF000, 0xF000 + 0x0400),
    "sat":      (0xF400, 0xF400 + 0x0280),
}

# Conservative end-of-tile-data limit ($C000 -> tile 1536).
TILE_DATA_LIMIT_BYTES = 0xC000
TILE_DATA_LIMIT_TILES = TILE_DATA_LIMIT_BYTES // 32  # 1536


def fail(msg):
    print(f"verify_vram_budget: FAIL: {msg}", file=sys.stderr)
    sys.exit(1)


def parse_constants():
    text_map  = VRAM_MAP_H.read_text(encoding="utf-8")
    text_item = ITEM_CHR_H.read_text(encoding="utf-8")

    consts = {}

    # --- BG and SPR banks (literal numeric defines in roomrom_vram_map.h) ---
    for name in ("ROOMROM_BG_TILE_BASE",
                 "ROOMROM_BG_TILE_COUNT_PER_PAL",
                 "ROOMROM_BG_SUBPAL_COUNT",
                 "ROOMROM_SPR_TILE_BASE",
                 "ROOMROM_SPR_TILE_COUNT_PER_PAL",
                 "ROOMROM_SPR_SUBPAL_COUNT"):
        m = re.search(rf"#define\s+{name}\s+(\d+)u?", text_map)
        if not m:
            fail(f"missing {name} in {VRAM_MAP_H}")
        consts[name] = int(m.group(1))

    # --- ITEM bank ---
    # ROOMROM_ITEM_TILE_BASE = ROOMROM_SPR_TILE_BASE + ROOMROM_SPR_TILE_COUNT_PER_PAL
    # (transitive resolution: read from the header expression, then derive here)
    consts["ROOMROM_ITEM_TILE_BASE"] = (
        consts["ROOMROM_SPR_TILE_BASE"] + consts["ROOMROM_SPR_TILE_COUNT_PER_PAL"]
    )

    # ROOMROM_ITEM_TILE_COUNT_PER_PAL aliases ROOMROM_ATLAS_ITEMS_X4_TILE_COUNT
    # from atlas/items_chr_x4.h (supersedes legacy ROOMROM_ITEM_CHR_TILE_COUNT)
    m = re.search(r"#define\s+ROOMROM_ATLAS_ITEMS_X4_TILE_COUNT\s+(\d+)u?", text_item)
    if not m:
        fail(f"missing ROOMROM_ATLAS_ITEMS_X4_TILE_COUNT in {ITEM_CHR_H}")
    consts["ROOMROM_ITEM_TILE_COUNT_PER_PAL"] = int(m.group(1))

    # ROOMROM_ITEM_SUBPAL_COUNT is a literal numeric define
    m = re.search(r"#define\s+ROOMROM_ITEM_SUBPAL_COUNT\s+(\d+)u?", text_map)
    if not m:
        fail(f"missing ROOMROM_ITEM_SUBPAL_COUNT in {VRAM_MAP_H}")
    consts["ROOMROM_ITEM_SUBPAL_COUNT"] = int(m.group(1))

    return consts


def tile_range_bytes(base_tile, tile_count):
    return (base_tile * 32, (base_tile + tile_count) * 32)


def overlaps(a, b):
    return not (a[1] <= b[0] or b[1] <= a[0])


def main():
    c = parse_constants()

    bg_count   = c["ROOMROM_BG_SUBPAL_COUNT"]   * c["ROOMROM_BG_TILE_COUNT_PER_PAL"]
    spr_count  = c["ROOMROM_SPR_SUBPAL_COUNT"]  * c["ROOMROM_SPR_TILE_COUNT_PER_PAL"]
    item_count = c["ROOMROM_ITEM_SUBPAL_COUNT"] * c["ROOMROM_ITEM_TILE_COUNT_PER_PAL"]

    bg_base   = c["ROOMROM_BG_TILE_BASE"]
    spr_base  = c["ROOMROM_SPR_TILE_BASE"]
    item_base = c["ROOMROM_ITEM_TILE_BASE"]

    bg_range   = tile_range_bytes(bg_base,   bg_count)
    spr_range  = tile_range_bytes(spr_base,  spr_count)
    item_range = tile_range_bytes(item_base, item_count)

    # --- BG/SPR existing checks (unchanged) ---

    # SPR base must be >= the address the BG bank reserves at full sub-pal expansion.
    bg_reserve = c["ROOMROM_BG_TILE_BASE"] + 4 * c["ROOMROM_BG_TILE_COUNT_PER_PAL"]
    if c["ROOMROM_SPR_TILE_BASE"] < bg_reserve:
        fail(f"SPR base {spr_base} < BG reserve {bg_reserve} "
             "(BG bank could collide with SPR after future sub-pal expansion)")

    if overlaps(bg_range, spr_range):
        fail(f"BG range {bg_range} overlaps SPR range {spr_range}")

    if spr_range[1] > TILE_DATA_LIMIT_BYTES:
        fail(f"SPR range end 0x{spr_range[1]:X} exceeds tile-data limit "
             f"0x{TILE_DATA_LIMIT_BYTES:X} (=$C000); tiles would clobber "
             f"VDP table region")

    for name, vdp_range in VDP_TABLES.items():
        if overlaps(bg_range, vdp_range):
            fail(f"BG range {bg_range} collides with VDP {name} {vdp_range}")
        if overlaps(spr_range, vdp_range):
            fail(f"SPR range {spr_range} collides with VDP {name} {vdp_range}")

    # --- ITEM bank checks ---

    # SPR bank end must not exceed ITEM bank start
    spr_end_tile  = spr_base  + spr_count
    item_end_tile = item_base + item_count

    if spr_end_tile > item_base:
        fail(f"SPR bank end tile {spr_end_tile} > ITEM bank start tile {item_base} "
             "(SPR and ITEM banks overlap)")

    if overlaps(bg_range, item_range):
        fail(f"BG range {bg_range} overlaps ITEM range {item_range}")

    if overlaps(spr_range, item_range):
        fail(f"SPR range {spr_range} overlaps ITEM range {item_range}")

    if item_end_tile > TILE_DATA_LIMIT_TILES:
        fail(f"ITEM bank end tile {item_end_tile} exceeds VDP table region start "
             f"tile {TILE_DATA_LIMIT_TILES} (=$C000); ITEM bank would clobber "
             f"VDP table region")

    if item_range[1] > TILE_DATA_LIMIT_BYTES:
        fail(f"ITEM range end 0x{item_range[1]:X} exceeds tile-data limit "
             f"0x{TILE_DATA_LIMIT_BYTES:X} (=$C000); tiles would clobber "
             f"VDP table region")

    for name, vdp_range in VDP_TABLES.items():
        if overlaps(item_range, vdp_range):
            fail(f"ITEM range {item_range} collides with VDP {name} {vdp_range}")

    # --- Success summary ---
    headroom_tiles = TILE_DATA_LIMIT_TILES - item_end_tile
    print(
        f"verify_vram_budget: OK  "
        f"BG=tiles {bg_base}..{bg_base + bg_count - 1}  "
        f"SPR=tiles {spr_base}..{spr_base + spr_count - 1}  "
        f"ITEM=tiles {item_base}..{item_end_tile - 1}  "
        f"headroom={headroom_tiles} tiles before VDP tables"
    )


if __name__ == "__main__":
    main()
