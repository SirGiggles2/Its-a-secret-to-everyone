#!/usr/bin/env python3
"""Parity contract checks for RoomRom UW Link walking.

This is intentionally small and source-level: the RoomRom build targets m68k,
so these tests pin the constants and public API that must back the runtime
module before the ROM build proves it compiles.
"""

from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "RoomRom" / "src"
HEADER = SRC / "uw_walk_model.h"
IMPL = SRC / "uw_walk_model.c"
BUILD = ROOT / "tools" / "debug" / "build_debug.py"
MAIN = SRC / "main.c"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def must_match(text: str, pattern: str, label: str) -> None:
    if not re.search(pattern, text, re.MULTILINE):
        raise AssertionError(f"missing {label}: {pattern}")


def main() -> int:
    if not HEADER.exists():
        raise AssertionError(f"missing {HEADER}")
    if not IMPL.exists():
        raise AssertionError(f"missing {IMPL}")

    header = read(HEADER)
    impl = read(IMPL)
    build = read(BUILD)
    main_c = read(MAIN)

    constants = {
        "UW_WALK_VISUAL_X_BIAS_PX": "0",
        "UW_WALK_NES_PLAYFIELD_TOP_PX": "0x38",
        "UW_WALK_DOORWAY_H_Y": "0x85",
        "UW_WALK_DOORWAY_V_X": "(0x78 + UW_WALK_VISUAL_X_BIAS_PX)",
        "UW_WALK_DOORWAY_W_MIN": "(0x00 + UW_WALK_VISUAL_X_BIAS_PX)",
        "UW_WALK_DOORWAY_E_MIN": "(0xCF + UW_WALK_VISUAL_X_BIAS_PX)",
        "UW_WALK_DOWN_ASIS_Y": "0xD5",
    }
    for name, value in constants.items():
        must_match(header, rf"#define\s+{name}\s+\(?{re.escape(value)}\)?",
                   name)

    for symbol in (
        "uw_walk_collidable_probe",
        "uw_walk_tile_passable",
        "uw_walk_find_doorway",
        "uw_walk_modify_dir_in_doorway",
        "uw_walk_snap_to_doorway_axis",
        "uw_walk_edge_crossing",
        "uw_walk_arrival_position",
    ):
        must_match(header, rf"\b{symbol}\b", symbol)
        must_match(impl, rf"\b{symbol}\b", symbol)

    must_match(impl, r"static const unsigned char s_door_required_coord\[4\]",
               "NES doorway required-coordinate table")
    must_match(impl, r"static const unsigned char s_door_min_over\[4\]",
               "NES doorway overflow min table")
    must_match(impl, r"static const unsigned char s_door_min_under\[4\]",
               "NES doorway underflow min table")
    must_match(impl, r"hot_y < UW_WALK_NES_PLAYFIELD_TOP_PX",
               "NES playfield-top collision check")
    must_match(impl, r"probe->tile_col \+ 1",
               "NES vertical second-column check")

    must_match(build, r"uw_walk_model\.c", "build compiles uw_walk_model.c")
    must_match(build, r"uw_walk_model\.o", "build links uw_walk_model.o")

    must_match(main_c, r"if \(s_scene == SCENE_UW\)[\s\S]*?uw_walk_collidable_probe",
               "UW collision uses NES collidable probe")
    must_match(main_c, r"if \(s_scene == SCENE_UW\)[\s\S]*?uw_walk_tile_passable",
               "UW collision uses NES tile passability")
    must_match(main_c, r"if \(s_scene == SCENE_UW\)[\s\S]*?roomrom_uw_room_render_walkable_tile_at",
               "UW collision samples 8px tile grid")
    must_match(main_c, r"players\[0\]\.x\s*=\s*120;",
               "UW boot X starts on NES doorway grid center")
    must_match(main_c, r"players\[0\]\.y\s*=\s*133;",
               "UW boot Y starts on NES doorway centerline")
    must_match(main_c, r"static signed char\s+s_link_grid_offset",
               "NES movement keeps signed ObjGridOffset")
    for symbol in (
        "link_nes_add_qspeed",
        "link_nes_sub_qspeed",
        "link_nes_move_object",
    ):
        must_match(main_c, rf"\b{symbol}\b", symbol)
    must_match(main_c,
               r"if \(moving_dir != LINK_DIR_NONE && s_link_grid_offset == 0\)[\s\S]*?"
               r"link_walkable_at\(players\[0\]\.x, players\[0\]\.y, moving_dir\)",
               "NES tile collision is checked before movement at grid points")
    if re.search(r"switch \(s_link_dir\)[\s\S]*?link_walkable_at\(players\[0\]\.x, players\[0\]\.y, s_link_dir\)",
                 main_c):
        raise AssertionError("NES branch still checks UW walkability after moving")
    if re.search(r"if \(s_scene == SCENE_UW\)[\s\S]*?hot_x = \(short\)\(x \+ 8\)",
                 main_c):
        raise AssertionError("UW collision still uses the broken Apr 30 metatile hotspot")

    render = read(SRC / "uw_room_render_roomrom.c")
    must_match(render, r"return \(t < 0x78u\) \? 1u : 0u;",
               "UW tile threshold classifier")
    must_match(render, r"s_uw_tile_walkable\[col\]\[row\] = uw_walkable_tile_id\(raw\)",
               "blob rooms preserve exact rendered tile collision")
    must_match(render, r"uw_room_walkable\(s_uw_level,\s*s_uw_quest,\s*room_id",
               "non-blob rooms use generated UW collision grid")
    must_match(render, r"set_walkable_metatile_only\(",
               "legacy metatile diagnostics no longer expand over tile grid")
    if re.search(r"uw_room_walkable\(s_uw_level,\s*s_uw_quest,\s*\(unsigned char\)g_uw_room_index\[idx\]\[3\]",
                 render):
        raise AssertionError("blob rooms still use generated LayoutUWFloor collision")

    overlay = read(ROOT / "RoomRom" / "tools" / "compare_uw_walkability_overlay.py")
    must_match(overlay, r"roomrom_blob_tile_mask", "walkability report uses blob mask")
    must_match(overlay, r"tile < 0x78", "walkability report uses NES tile threshold")
    must_match(overlay, r"collision_tile_mask", "walkability report still renders NES grid")

    print("RESULT: OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
