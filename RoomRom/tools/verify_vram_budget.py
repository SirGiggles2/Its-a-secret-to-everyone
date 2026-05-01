#!/usr/bin/env python3
"""Hard gate: VRAM tile-bank ranges do not overlap each other or VDP tables.

Reads constants from RoomRom/src/roomrom_vram_map.h.
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
VRAM_MAP_H = ROOT / "src" / "roomrom_vram_map.h"

VDP_TABLES = {
    "plane_b":  (0xC000, 0xC000 + 0x2000),  # max 8KB region (game-config dependent)
    "window":   (0xD000, 0xD000 + 0x1000),
    "plane_a":  (0xE000, 0xE000 + 0x2000),
    "h_scroll": (0xF000, 0xF000 + 0x0400),
    "sat":      (0xF400, 0xF400 + 0x0280),
}

# Conservative end-of-tile-data limit ($C000 -> tile 1536).
TILE_DATA_LIMIT_BYTES = 0xC000


def fail(msg):
    print(f"verify_vram_budget: FAIL: {msg}", file=sys.stderr)
    sys.exit(1)


def parse_constants():
    text = VRAM_MAP_H.read_text(encoding="utf-8")
    consts = {}
    for name in ("ROOMROM_BG_TILE_BASE",
                 "ROOMROM_BG_TILE_COUNT_PER_PAL",
                 "ROOMROM_BG_SUBPAL_COUNT",
                 "ROOMROM_SPR_TILE_BASE",
                 "ROOMROM_SPR_TILE_COUNT_PER_PAL",
                 "ROOMROM_SPR_SUBPAL_COUNT"):
        m = re.search(rf"#define\s+{name}\s+(\d+)u?", text)
        if not m:
            fail(f"missing {name} in {VRAM_MAP_H}")
        consts[name] = int(m.group(1))
    return consts


def tile_range_bytes(base_tile, tile_count):
    return (base_tile * 32, (base_tile + tile_count) * 32)


def overlaps(a, b):
    return not (a[1] <= b[0] or b[1] <= a[0])


def main():
    c = parse_constants()
    bg_count  = c["ROOMROM_BG_SUBPAL_COUNT"]  * c["ROOMROM_BG_TILE_COUNT_PER_PAL"]
    spr_count = c["ROOMROM_SPR_SUBPAL_COUNT"] * c["ROOMROM_SPR_TILE_COUNT_PER_PAL"]
    bg_range  = tile_range_bytes(c["ROOMROM_BG_TILE_BASE"],  bg_count)
    spr_range = tile_range_bytes(c["ROOMROM_SPR_TILE_BASE"], spr_count)

    # SPR base must be >= the address the BG bank reserves at full sub-pal expansion.
    bg_reserve = c["ROOMROM_BG_TILE_BASE"] + 4 * c["ROOMROM_BG_TILE_COUNT_PER_PAL"]
    if c["ROOMROM_SPR_TILE_BASE"] < bg_reserve:
        fail(f"SPR base {c['ROOMROM_SPR_TILE_BASE']} < BG reserve {bg_reserve} "
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

    print(f"verify_vram_budget: OK  BG=0x{bg_range[0]:X}..0x{bg_range[1]:X} "
          f"SPR=0x{spr_range[0]:X}..0x{spr_range[1]:X}")


if __name__ == "__main__":
    main()
