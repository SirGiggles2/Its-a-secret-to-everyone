#!/usr/bin/env python3
"""
Compare the captured NES start-room tilemap against the current Genesis
offline room decode for room $77.
"""

from __future__ import annotations

import json
from pathlib import Path


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    nes_path = root / "builds" / "reports" / "nes_start_tilemap.json"
    genesis_path = root / "builds" / "reports" / "overworld_start_room_reference.json"

    nes = json.loads(nes_path.read_text())
    genesis = json.loads(genesis_path.read_text())

    mismatches: list[tuple[int, int, int, int]] = []
    for row in range(22):
        for col in range(32):
            tile_word = genesis["tile_words"][row][col] & 0x7FF
            genesis_raw = 0 if tile_word == 0 else tile_word - 1
            nes_raw = nes["tile_rows"][row][col]
            if nes_raw != genesis_raw:
                mismatches.append((row, col, nes_raw, genesis_raw))

    print(f"NES room id: ${nes['room_id']:02X}")
    print(f"Mismatch count: {len(mismatches)}")
    for row, col, nes_raw, genesis_raw in mismatches[:80]:
        print(
            f"row {row:02d} col {col:02d}: "
            f"nes=${nes_raw:02X} genesis=${genesis_raw:02X}"
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
