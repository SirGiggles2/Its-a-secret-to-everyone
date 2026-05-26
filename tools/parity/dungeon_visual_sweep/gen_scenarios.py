"""Phase G — Generate the dungeon_visual_sweep scenario manifest.

Reads:
  tools/parity/warp_routes_expected.json   (Phase A: 128 OW rooms -> cave_id / dungeon level)
  RoomRom/data/uw_level{N}_quest{Q}_rooms.json  (18 manifests: start_room_id per dungeon)
  reference/aldonunez/Z_06.asm:263-267       (Q2 OW attr_b overrides — hardcoded inline)

Emits:
  tools/parity/dungeon_visual_sweep/scenarios.json

Schema:
  {
    "schema": "phase_g_visual_sweep_v1",
    "scenarios": [
      {
        "id": "<scenario_id>",
        "category": "cave_enter" | "dungeon_enter" | "dungeon_exit",
        # cave fields:
        "cave_id": 0x6A..0x7D,
        "ow_room_id": int,
        "ow_link_x": int (pixel),
        "ow_link_y": int (pixel; satisfies link_y & 0x0F == 0x0D
                          for NES alignment, mapped to RoomRom playfield),
        "trigger_tile": "0x24" | "0x88" | "0x70".."0x73",
        # dungeon entry fields:
        "level": 1..9, "quest": 1..2,
        "uw_start_room_id": int,
        # dungeon exit fields:
        "uw_link_x_at_doorway": int,
        "uw_link_y_at_doorway": int,
        "expected_ow_room_id": int,
        "expected_ow_link_x": int,
        "expected_ow_link_y": int,
        # common:
        "capture_window_frames": int
      },
      ...
    ]
  }

20 caves + 18 dungeon entries + 18 dungeon exits = 56 scenarios.
"""

from __future__ import annotations

import json
import pathlib
import sys

REPO = pathlib.Path(__file__).resolve().parents[3]
ORACLE_PATH = REPO / "tools" / "parity" / "warp_routes_expected.json"
UW_MANIFEST_DIR = REPO / "RoomRom" / "data"
OUT_PATH = (
    REPO / "tools" / "parity" / "dungeon_visual_sweep" / "scenarios.json"
)

# Z_06.asm:263-267 — Q2 attr_b replacement table. Patches the LBA_B
# blob at 8 specific OW offsets when current_quest == 2.
Q2_ATTR_B_OVERRIDES = {
    0x0E: 0x7B,
    0x0F: 0x83,
    0x22: 0x84,
    0x34: 0x0F,
    0x3C: 0x0B,
    0x45: 0x12,
    0x74: 0x7A,
    0x8B: 0x2F,
}


def parse_room_id(value) -> int:
    if isinstance(value, int):
        return value
    s = str(value).strip()
    if s.lower().startswith("0x"):
        return int(s, 16)
    return int(s, 10)


def cave_id_from_attr_b_fc(attr_b_fc: int) -> int | None:
    """Mirror src/game/world/ow_meta.c cave_id_from_selector formula."""
    if attr_b_fc < 0x40:
        return None
    return 0x6A + ((attr_b_fc - 0x40) >> 2)


def level_from_attr_b_fc(attr_b_fc: int) -> int | None:
    if attr_b_fc == 0 or attr_b_fc >= 0x40:
        return None
    return attr_b_fc >> 2


def pick_cave_ow_position(cave_id: int, q1_oracle_rows: list[dict]) -> dict | None:
    """Return the first Q1 OW room whose attr_b_fc maps to `cave_id`.
    Falls back to None if no room targets this cave.
    """
    for row in q1_oracle_rows:
        if row.get("cave_id") == cave_id:
            return row
    return None


def pick_dungeon_ow_position(
    level: int, quest: int, q1_oracle_rows: list[dict]
) -> dict | None:
    """Q1: first OW row with category=='dungeon' and level==level.
    Q2: apply Z_06.asm overrides — if any Q2 override produces a
    selector that maps to this level, that's the Q2 entrance room.
    Else fall back to Q1's room (NES Q2 sometimes uses same OW room).
    """
    if quest == 1:
        for row in q1_oracle_rows:
            if row.get("category") == "dungeon" and row.get("level") == level:
                return row
        return None
    # Quest 2
    for room_id, replacement_attr_b in Q2_ATTR_B_OVERRIDES.items():
        selector = replacement_attr_b & 0xFC
        if level_from_attr_b_fc(selector) == level:
            # Synthesize a row representing the Q2-patched OW position.
            return {
                "room_id": room_id,
                "raw_attr_b": replacement_attr_b,
                "attr_b_fc": selector,
                "category": "dungeon",
                "level": level,
                "_q2_patched": True,
            }
    # Fall back to Q1's OW room — NES Q2 reuses many dungeon entrances.
    for row in q1_oracle_rows:
        if row.get("category") == "dungeon" and row.get("level") == level:
            return {**row, "_q2_inherited_from_q1": True}
    return None


def ow_room_to_link_pos(room_id: int) -> tuple[int, int, str]:
    """Return (link_x, link_y, trigger_tile) for the canonical entry
    position in this OW room. NES Z1 entrances are mostly at col 7
    metatile = pixel x 120 (= $78), centered. The Y depends on the
    tile's row in the OW playfield (which we don't have a per-room
    table for — defer to a per-scenario override if needed).
    Default: x = $78, y = $85 (matches boot spawn Y for room $77).
    """
    return (120, 0x85, "0x24")


def main() -> int:
    if not ORACLE_PATH.exists():
        print(f"missing {ORACLE_PATH}", file=sys.stderr)
        return 2

    oracle = json.loads(ORACLE_PATH.read_text(encoding="utf-8"))
    rows = oracle.get("rows", [])
    q1_cave_rows = [r for r in rows if r.get("category") in
                    ("cave_regular", "cave_shortcut")]

    scenarios: list[dict] = []

    # ── 20 cave entries (cave_id $6A..$7D) ──
    for cave_id in range(0x6A, 0x7E):
        room_meta = pick_cave_ow_position(cave_id, q1_cave_rows)
        if room_meta is None:
            # Cave_id not reachable in current oracle; emit a stub
            # that the differ will mark as "unreachable" rather than
            # silently skip.
            scenarios.append({
                "id": f"cave_{cave_id:02X}_enter",
                "category": "cave_enter",
                "cave_id": cave_id,
                "ow_room_id": None,
                "ow_link_x": None,
                "ow_link_y": None,
                "trigger_tile": None,
                "unreachable": True,
                "capture_window_frames": 240,
            })
            continue
        room_id = room_meta["room_id"]
        link_x, link_y, trigger_tile = ow_room_to_link_pos(room_id)
        scenarios.append({
            "id": f"cave_{cave_id:02X}_enter",
            "category": "cave_enter",
            "cave_id": cave_id,
            "ow_room_id": room_id,
            "ow_link_x": link_x,
            "ow_link_y": link_y,
            "trigger_tile": trigger_tile,
            "capture_window_frames": 240,
        })

    # ── 18 dungeon entries (L1-L9 × Q1+Q2) ──
    for level in range(1, 10):
        for quest in (1, 2):
            uw_manifest = (
                UW_MANIFEST_DIR
                / f"uw_level{level}_quest{quest}_rooms.json"
            )
            if not uw_manifest.exists():
                print(f"missing {uw_manifest}", file=sys.stderr)
                return 2
            uw_data = json.loads(uw_manifest.read_text(encoding="utf-8"))
            start_room = parse_room_id(uw_data["start_room_id"])

            ow = pick_dungeon_ow_position(level, quest, rows)
            if ow is None:
                scenarios.append({
                    "id": f"dungeon_L{level}Q{quest}_enter",
                    "category": "dungeon_enter",
                    "level": level,
                    "quest": quest,
                    "uw_start_room_id": start_room,
                    "ow_room_id": None,
                    "unreachable": True,
                    "capture_window_frames": 60,
                })
                continue

            link_x, link_y, trigger_tile = ow_room_to_link_pos(
                ow["room_id"]
            )
            entry = {
                "id": f"dungeon_L{level}Q{quest}_enter",
                "category": "dungeon_enter",
                "level": level,
                "quest": quest,
                "uw_start_room_id": start_room,
                "ow_room_id": ow["room_id"],
                "ow_link_x": link_x,
                "ow_link_y": link_y,
                "trigger_tile": trigger_tile,
                "capture_window_frames": 60,
            }
            if ow.get("_q2_patched"):
                entry["q2_patched_from_z06"] = True
            if ow.get("_q2_inherited_from_q1"):
                entry["q2_inherited_from_q1"] = True
            scenarios.append(entry)

    # ── 18 dungeon exits (one per entry tuple) ──
    for level in range(1, 10):
        for quest in (1, 2):
            uw_manifest = (
                UW_MANIFEST_DIR
                / f"uw_level{level}_quest{quest}_rooms.json"
            )
            uw_data = json.loads(uw_manifest.read_text(encoding="utf-8"))
            start_room = parse_room_id(uw_data["start_room_id"])

            ow = pick_dungeon_ow_position(level, quest, rows)
            if ow is None:
                scenarios.append({
                    "id": f"dungeon_L{level}Q{quest}_exit",
                    "category": "dungeon_exit",
                    "level": level,
                    "quest": quest,
                    "uw_room_id": start_room,
                    "expected_ow_room_id": None,
                    "unreachable": True,
                    "capture_window_frames": 60,
                })
                continue

            link_x_ow, link_y_ow, _ = ow_room_to_link_pos(ow["room_id"])
            scenarios.append({
                "id": f"dungeon_L{level}Q{quest}_exit",
                "category": "dungeon_exit",
                "level": level,
                "quest": quest,
                "uw_room_id": start_room,
                # Phase F probe found doorway tile at col 14, row 20.
                # link_x = 14*8 = 112, link_y = 20*8 + 45 = 205 (= $CD).
                "uw_link_x_at_doorway": 112,
                "uw_link_y_at_doorway": 205,
                "trigger_tile": "0x7D",
                "expected_ow_room_id": ow["room_id"],
                "expected_ow_link_x": link_x_ow,
                "expected_ow_link_y": link_y_ow,
                "capture_window_frames": 60,
            })

    payload = {
        "schema": "phase_g_visual_sweep_v1",
        "generated_from": [
            "tools/parity/warp_routes_expected.json",
            "RoomRom/data/uw_level{N}_quest{Q}_rooms.json",
            "reference/aldonunez/Z_06.asm:263-267 (Q2 overrides)",
        ],
        "totals": {
            "cave_entries": sum(
                1 for s in scenarios if s["category"] == "cave_enter"
            ),
            "dungeon_entries": sum(
                1 for s in scenarios if s["category"] == "dungeon_enter"
            ),
            "dungeon_exits": sum(
                1 for s in scenarios if s["category"] == "dungeon_exit"
            ),
            "unreachable": sum(
                1 for s in scenarios if s.get("unreachable")
            ),
            "total_scenarios": len(scenarios),
        },
        "scenarios": scenarios,
    }

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OUT_PATH.open("w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)
        f.write("\n")

    print(
        f"wrote {OUT_PATH.relative_to(REPO)} "
        f"({len(scenarios)} scenarios; "
        f"{payload['totals']['cave_entries']} cave, "
        f"{payload['totals']['dungeon_entries']} dungeon-enter, "
        f"{payload['totals']['dungeon_exits']} dungeon-exit, "
        f"{payload['totals']['unreachable']} unreachable)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
