#!/usr/bin/env python3
"""Extract UW boss room IDs from data/rooms/dungeons.c LevelInfo blob.

Per src/game/world/level_info_install.c:
  LevelInfo for level N starts at blob offset 3072 + (N-1)*256.

Per reference/aldonunez/Variables.inc + empirical probe verification:
  StartRoomId at LevelInfo offset 107 (probe L1 = $73 ✓).
  BossRoomId at offset 107 + 15 = 122 (probe L1 = $35 ✓ Aquamentus).

Prints per-level (start, triforce, boss) for L1..L9 in both quests.
"""
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
DUNGEONS_C = REPO_ROOT / "data" / "rooms" / "dungeons.c"

LEVELINFO_BASE = 3072
LEVELINFO_STRIDE = 256
START_OFF  = 43
TRIFORCE_OFF = 44
BOSS_OFF = 58


def load_blob():
    text = DUNGEONS_C.read_text(encoding="utf-8")
    # Match all 0xXX hex literals; concat into a single byte list.
    bytes_list = [int(b, 16) for b in re.findall(r"0x([0-9a-fA-F]{2})", text)]
    return bytes(bytes_list)


def extract():
    blob = load_blob()
    print(f"# dungeons.c blob = {len(blob)} bytes")
    print(f"# LevelInfo base = {LEVELINFO_BASE}, stride = {LEVELINFO_STRIDE}")
    print(f"# Offsets: start={START_OFF}, triforce={TRIFORCE_OFF}, boss={BOSS_OFF}")
    print()
    print("Level | Start | Triforce | Boss")
    print("------|-------|----------|-----")
    for level in range(1, 10):
        base = LEVELINFO_BASE + (level - 1) * LEVELINFO_STRIDE
        if base + BOSS_OFF >= len(blob):
            print(f"L{level} | (out of range)")
            continue
        start = blob[base + START_OFF]
        triforce = blob[base + TRIFORCE_OFF]
        boss = blob[base + BOSS_OFF]
        print(f"L{level}    | ${start:02X}   | ${triforce:02X}      | ${boss:02X}")


if __name__ == "__main__":
    extract()
