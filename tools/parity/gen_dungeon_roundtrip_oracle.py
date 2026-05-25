"""Phase F oracle generator — emit expected outcomes for all 18
(level, quest) tuples.

For each row the probe must produce:
  dest_scene    = 0   (ROOMROM_MAIN_SCENE_OW)
  dest_level    = 0
  dest_room_id  = 0x77 (canonical OW source latch — probe pre-loads
                       s_save.source_room_id = $77 before driving
                       detect_warp_uw_to_ow, and the dispatch replays
                       save.source_room_id into outcome.dest_room_id)
  pass_flags    = 0x0F (all four bits set)

`start_room_id` comes from RoomRom/data/uw_level{N}_quest{Q}_rooms.json
(same source the Phase B manifest generator uses).

Output: tools/parity/dungeon_roundtrip_expected.json
"""

from __future__ import annotations

import json
import pathlib
import sys

REPO = pathlib.Path(__file__).resolve().parents[2]
MANIFEST_DIR = REPO / "RoomRom" / "data"
OUT_JSON = REPO / "tools" / "parity" / "dungeon_roundtrip_expected.json"


def parse_room_id(value) -> int:
    if isinstance(value, int):
        return value
    s = str(value).strip()
    if s.lower().startswith("0x"):
        return int(s, 16)
    return int(s, 10)


def main() -> int:
    rows = []
    for level in range(1, 10):
        for quest in (1, 2):
            manifest = (
                MANIFEST_DIR / f"uw_level{level}_quest{quest}_rooms.json"
            )
            if not manifest.exists():
                print(f"missing {manifest}", file=sys.stderr)
                return 2
            data = json.loads(manifest.read_text(encoding="utf-8"))
            start_room = parse_room_id(data["start_room_id"])
            rows.append(
                {
                    "row_idx": (level - 1) * 2 + (quest - 1),
                    "level": level,
                    "quest": quest,
                    "start_room_id": start_room,
                    "expected_dest_scene": 0,
                    "expected_dest_level": 0,
                    "expected_dest_room_id": 0x77,
                    "expected_pass_flags": 0x0F,
                }
            )

    payload = {
        "schema": "phase_f_dungeon_roundtrip_v1",
        "row_count": len(rows),
        "rows": rows,
    }
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    with OUT_JSON.open("w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)
        f.write("\n")
    print(f"wrote {OUT_JSON.relative_to(REPO)} ({len(rows)} rows)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
