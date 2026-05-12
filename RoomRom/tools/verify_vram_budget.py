#!/usr/bin/env python3
"""Hard gate: VRAM tile-bank ranges do not overlap each other or VDP tables.

Reads constants from RoomRom/src/roomrom_vram_map.h and
RoomRom/src/atlas/items_chr_x4.h.

CRITICAL (PR-2b 2026-05-08): RoomRom now uses 64x32 plane mode
(render_mode_set_h64v32 in main.c init_video; VDP reg 16 = $9001).
With BG_A address override -> $C000 and BG_B override -> $E000,
SGDK case-11 layout places VDP tables at:
  plane A  = $C000 (tile 1536)   4 KB
  Window   = $D000 (tile 1664)   4 KB
  plane B  = $E000 (tile 1792)   4 KB
  HScroll  = $F000 (tile 1920)   1 KB
  SAT      = $F400 (tile 1952)   640 B
  free     = $F800-$FFFF         2 KB (unused, reserved for future)

Conservative tile-data ceiling for 64x32 mode: $C000 = tile 1536
(+192 tiles vs 64x64 mode's $A800 limit).

Exit code 0 = pass, 1 = fail.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VRAM_MAP_H    = ROOT / "src" / "roomrom_vram_map.h"
ITEM_CHR_H    = ROOT / "src" / "atlas" / "items_chr_x4.h"

VDP_TABLES = {
    # 64x32 plane layout (PR-2b: render_mode_set_h64v32 + BGA/BGB overrides).
    # SGDK case 11 default places tables here, with our BGA->$C000,
    # BGB->$E000 overrides keeping plane addresses fixed:
    "plane_a":  (0xC000, 0xC000 + 0x1000),  # tile 1536..1663 (4 KB)
    "window":   (0xD000, 0xD000 + 0x1000),  # tile 1664..1791 (4 KB)
    "plane_b":  (0xE000, 0xE000 + 0x1000),  # tile 1792..1919 (4 KB)
    "h_scroll": (0xF000, 0xF000 + 0x0400),  # tile 1920..1951 (1 KB)
    "sat":      (0xF400, 0xF400 + 0x0280),  # tile 1952..1971 (640 B)
}

# Conservative end-of-tile-data limit for 64x32 mode = $C000 (tile 1536).
# Anything beyond this overlaps VDP tables and gets clobbered each frame.
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

    # HUD backdrop tile count is a literal numeric define. Its base is the
    # first free tile after the ITEM bank.
    m = re.search(r"#define\s+ROOMROM_HUD_BACKDROP_TILE_COUNT\s+(\d+)u?", text_map)
    if not m:
        fail(f"missing ROOMROM_HUD_BACKDROP_TILE_COUNT in {VRAM_MAP_H}")
    consts["ROOMROM_HUD_BACKDROP_TILE_COUNT"] = int(m.group(1))

    # --- PR-5 BOSS bank (shares SCENE_OBJ slot inside SPR bank, NES parity
    # per z_03.asm:91 -- boss rooms have no enemies). Verified at the C
    # level via #define ROOMROM_BOSS_TILE_BASE = (SPR_TILE_BASE + 44u);
    # no independent VRAM range to check here. ---

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
    hud_base = item_base + item_count
    hud_count = c["ROOMROM_HUD_BACKDROP_TILE_COUNT"]

    bg_range   = tile_range_bytes(bg_base,   bg_count)
    spr_range  = tile_range_bytes(spr_base,  spr_count)
    item_range = tile_range_bytes(item_base, item_count)
    hud_range  = tile_range_bytes(hud_base,  hud_count)

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
             f"0x{TILE_DATA_LIMIT_BYTES:X} (=$C000 in 64x32 mode); tiles would clobber "
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
             f"tile {TILE_DATA_LIMIT_TILES} (=$C000 in 64x32 mode); ITEM bank would clobber "
             f"VDP table region")

    if item_range[1] > TILE_DATA_LIMIT_BYTES:
        fail(f"ITEM range end 0x{item_range[1]:X} exceeds tile-data limit "
             f"0x{TILE_DATA_LIMIT_BYTES:X} (=$C000 in 64x32 mode); tiles would clobber "
             f"VDP table region")

    for name, vdp_range in VDP_TABLES.items():
        if overlaps(item_range, vdp_range):
            fail(f"ITEM range {item_range} collides with VDP {name} {vdp_range}")

    # --- HUD backdrop bank checks ---

    hud_end_tile = hud_base + hud_count
    if item_end_tile > hud_base:
        fail(f"ITEM bank end tile {item_end_tile} > HUD backdrop start tile {hud_base} "
             "(ITEM and HUD backdrop banks overlap)")

    for label, rng in (("BG", bg_range), ("SPR", spr_range), ("ITEM", item_range)):
        if overlaps(rng, hud_range):
            fail(f"{label} range {rng} overlaps HUD backdrop range {hud_range}")

    if hud_end_tile > TILE_DATA_LIMIT_TILES:
        fail(f"HUD backdrop end tile {hud_end_tile} exceeds VDP table region start "
             f"tile {TILE_DATA_LIMIT_TILES} (=$C000 in 64x32 mode); backdrop tiles would clobber "
             f"VDP table region")

    for name, vdp_range in VDP_TABLES.items():
        if overlaps(hud_range, vdp_range):
            fail(f"HUD backdrop range {hud_range} collides with VDP {name} {vdp_range}")

    # --- Success summary ---
    headroom_tiles = TILE_DATA_LIMIT_TILES - hud_end_tile
    print(
        f"verify_vram_budget: OK  "
        f"BG=tiles {bg_base}..{bg_base + bg_count - 1}  "
        f"SPR=tiles {spr_base}..{spr_base + spr_count - 1}  "
        f"ITEM=tiles {item_base}..{item_end_tile - 1}  "
        f"HUD_BACKDROP=tiles {hud_base}..{hud_end_tile - 1}  "
        f"BOSS=SCENE_OBJ-shared (NES parity)  "
        f"headroom={headroom_tiles} tiles before VDP tables"
    )


if __name__ == "__main__":
    main()
