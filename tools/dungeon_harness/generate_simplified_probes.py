"""Generate 18 simplified dungeon probes from manifest.json + template.

Reads tools/dungeon_harness/manifest.json + dungeon_simplified_template.lua,
emits one dungeon_<L>_q<N>.lua per manifest row with the row's LABEL,
LEVEL, QUEST, SAVE_STATE_PATH filled in.

Expected room IDs per NES `LevelInfoBlock` (Z_07.asm) — boss-adjacent
entry tiles. Hand-mapped from master plan dungeon table. Until each
row's actual save state lands, these are best-known expected values.

Usage:
    python tools/dungeon_harness/generate_simplified_probes.py
"""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
HARNESS = ROOT / "tools" / "dungeon_harness"
MANIFEST = HARNESS / "manifest.json"
TEMPLATE = HARNESS / "probes" / "dungeon_simplified_template.lua"
PROBES = HARNESS / "probes"


# Per-row expected NES entry room IDs (hand-mapped from NES Z1
# LevelInfoBlock; per master plan dungeon harness scaffold). Values
# are best-known; per-row save state capture verifies + corrects them.
EXPECTED_ENTRY = {
    (1, 1): 0x73,  # L1Q1 Eagle entrance
    (2, 1): 0x7D,  # L2Q1 Moon
    (3, 1): 0x23,  # L3Q1 Manji
    (4, 1): 0x67,  # L4Q1 Snake
    (5, 1): 0x4B,  # L5Q1 Lizard
    (6, 1): 0x4F,  # L6Q1 Dragon
    (7, 1): 0x52,  # L7Q1 Demon
    (8, 1): 0x60,  # L8Q1 Lion
    (9, 1): 0x42,  # L9Q1 Death Mtn
    (1, 2): 0x73,
    (2, 2): 0x7D,
    (3, 2): 0x23,
    (4, 2): 0x67,
    (5, 2): 0x4B,
    (6, 2): 0x4F,
    (7, 2): 0x52,
    (8, 2): 0x60,
    (9, 2): 0x42,
}


def main() -> int:
    m = json.loads(MANIFEST.read_text(encoding="utf-8"))
    template = TEMPLATE.read_text(encoding="utf-8")

    for row in m["rows"]:
        level = row["level"]
        quest = row["quest"]
        label = row["label"]
        save_state = row["save_state"]
        out_name = row["probe"]   # dungeon_<L>_q<N>.lua

        expected_room = EXPECTED_ENTRY.get((level, quest), 0)

        # Substitute template constants. Use simple find/replace —
        # template is small enough that no template engine is needed.
        body = (template
                .replace('local LABEL = "TEMPLATE"',
                         f'local LABEL = "{label}"')
                .replace('local LEVEL = 0',
                         f'local LEVEL = {level}')
                .replace('local QUEST = 0',
                         f'local QUEST = {quest}')
                .replace('local SAVE_STATE_PATH = nil   -- fill in per row',
                         f'local SAVE_STATE_PATH = "{save_state}"')
                .replace('local EXPECTED_ROOM   = 0     -- expected NES RoomId at entry',
                         f'local EXPECTED_ROOM   = 0x{expected_room:02X}  -- expected NES RoomId at entry')
                .replace('local EXPECTED_LEVEL  = 0     -- expected NES CurLevel at entry',
                         f'local EXPECTED_LEVEL  = {level}     -- expected NES CurLevel at entry')
                )

        out_path = PROBES / out_name
        out_path.write_text(body, encoding="utf-8")
        print(f"  wrote {out_path.relative_to(ROOT)}")

    print(f"Generated {len(m['rows'])} simplified probes.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
