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
# Empirical L1: StartRoomId at blob offset 43, BossRoomId at 122.
# Try multiple strides to find one that validates for L2-L9.
START_OFF = 43
BOSS_OFF = 58  # empirically blob[3072+58]=$35 for L1 (Aquamentus)
TRIFORCE_OFF = 44

# Known NES Z1 boss rooms for validation (per common knowledge).
KNOWN_BOSSES = {
    1: 0x35,  # Aquamentus (verified by probe)
    2: 0x73,  # Dodongo (unverified)
    3: 0x0F,  # Manhandla (unverified)
    4: 0x45,  # Gleeok 2 (unverified)
    5: 0x06,  # Digdogger (unverified)
    6: 0x0F,  # Gohma Red (unverified)
    7: 0x23,  # Aquamentus 2 (unverified)
    8: 0x1F,  # Gleeok 4 (unverified)
    9: 0x1F,  # Ganon (unverified)
}

LEVELINFO_STRIDE = 256  # placeholder; try several below


def load_blob():
    text = DUNGEONS_C.read_text(encoding="utf-8")
    # Match all 0xXX hex literals; concat into a single byte list.
    bytes_list = [int(b, 16) for b in re.findall(r"0x([0-9a-fA-F]{2})", text)]
    return bytes(bytes_list)


def search_boss():
    """Find blob offsets where ALL 9 levels match KNOWN_BOSSES."""
    blob = load_blob()
    print(f"# dungeons.c blob = {len(blob)} bytes")
    print(f"# Searching for layout that matches NES boss rooms...")
    print()
    # Try various strides; check if blob[base + (level-1)*stride + 122] matches.
    for stride in (256, 272, 288, 316, 320, 384, 256+60, 408):
        matches = []
        for level in range(1, 10):
            base = LEVELINFO_BASE + (level - 1) * stride
            if base + BOSS_OFF >= len(blob):
                break
            actual = blob[base + BOSS_OFF]
            expected = KNOWN_BOSSES[level]
            matches.append((level, expected, actual))
        match_count = sum(1 for _, e, a in matches if e == a)
        print(f"stride={stride}: {match_count}/9 match: " +
              " ".join(f"L{l}{'*' if e==a else ''}${a:02X}" for l, e, a in matches))


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
    search_boss()
    print()
    extract()
