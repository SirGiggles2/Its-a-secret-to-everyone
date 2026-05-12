#!/usr/bin/env python3
"""Source audit for Debug ROM safe performance wins.

The checks here intentionally target wasteful patterns that should not be
needed for Zelda parity: repeated idle sprite clears, ungated heavy probes,
runtime metadata scans, and raw SGDK sprite writes outside the sprite owner.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def fail(errors: list[str], rel: str, message: str) -> None:
    errors.append(f"{rel}: {message}")


def main() -> int:
    errors: list[str] = []

    idle_clear_checks = {
        "RoomRom/src/roomrom_arrow.c": r"ARROW_IDLE\)\s*\{\s*roomrom_sprites_clear_arrow\(\)",
        "RoomRom/src/roomrom_boomerang.c": r"BOOMERANG_IDLE\)\s*\{\s*roomrom_sprites_clear_boomerang\(\)",
        "RoomRom/src/roomrom_magic_shot.c": r"MAGIC_SHOT_IDLE\)\s*\{\s*roomrom_sprites_clear_magic_shot\(\)",
        "RoomRom/src/roomrom_combat.c": r"COMBAT_IDLE\)\s*\{\s*roomrom_sprites_clear_sword\(\)",
    }
    for rel, pattern in idle_clear_checks.items():
        if re.search(pattern, read(rel), re.S):
            fail(errors, rel, "idle update branch still clears a sprite every frame")

    bomb_src = read("RoomRom/src/roomrom_bomb.c")
    if re.search(r"case\s+BOMB_IDLE:\s*roomrom_sprites_clear_bomb\(\)", bomb_src, re.S):
        fail(errors, "RoomRom/src/roomrom_bomb.c", "BOMB_IDLE still clears sprites every frame")

    candle_src = read("RoomRom/src/roomrom_candle_fire.c")
    if re.search(r"\bVDP_setSpriteFull\s*\(", candle_src):
        fail(errors, "RoomRom/src/roomrom_candle_fire.c", "candle fire writes sprites outside roomrom_sprites.c")

    push_src = read("RoomRom/src/roomrom_pushblock.c")
    solved_branch = re.search(
        r"if\s*\(\s*s_pb_state_per_room\[room_id\]\s*>=\s*1u\s*\)\s*\{(?P<body>[^{}]*)\}",
        push_src,
        re.S,
    )
    if solved_branch and "paint_metatile" in solved_branch.group("body"):
        fail(errors, "RoomRom/src/roomrom_pushblock.c", "solved pushblock path repaints every tick")

    main_src = read("RoomRom/src/main.c")
    boss_trigger_uses_debug_ram = (
        "volatile unsigned char *trig = (volatile unsigned char *)0x00FF73FEUL;" in main_src
    )
    boss_trigger_has_gate = (
        "roomrom_debug_probe_flag(ROOMROM_DEBUG_PROBE_BOSS_TRIGGER)" in main_src
    )
    if boss_trigger_uses_debug_ram and not boss_trigger_has_gate:
        fail(errors, "RoomRom/src/main.c", "boss-bank trigger reads debug RAM without explicit probe control")

    for rel in (
        "RoomRom/src/uw_dark_meta.c",
        "RoomRom/src/uw_item_room_meta.c",
        "RoomRom/src/uw_cellar_meta.c",
        "RoomRom/src/uw_push_block_meta.c",
    ):
        src = read(rel)
        if re.search(r"for\s*\([^)]*<\s*uw_.*_count", src):
            fail(errors, rel, "runtime metadata helper still linearly scans generated rows")

    # roomrom_sprites.c is the only gameplay owner allowed to call the SGDK
    # sprite setter directly. Generated/third-party files are outside this
    # narrow audit.
    for rel in (ROOT / "RoomRom" / "src").glob("*.c"):
        rel_s = rel.relative_to(ROOT).as_posix()
        if rel_s == "RoomRom/src/roomrom_sprites.c":
            continue
        if re.search(r"\bVDP_setSpriteFull\s*\(", rel.read_text(encoding="utf-8")):
            fail(errors, rel_s, "direct VDP_setSpriteFull outside sprite owner")

    if errors:
        print("debug_perf_safe_wins: FAIL")
        for error in errors:
            print(f"  - {error}")
        return 1

    print("debug_perf_safe_wins: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
