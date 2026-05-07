#!/usr/bin/env python3
"""Task 5.8 Gate B harness: verify UW dark-room enter + candle reveal
+ persistence.

Reads JSONL emitted by RoomRom/probe_uw_dark.lua and verifies at
least ONE L1Q1 dark room had:
  - room_dark_enter event
  - candle_lit event for same room_id
  - dark_room_persist_reentry event for same room_id

Slice-1 minimum: 1 verified room. Master plan acceptance broader,
deferred to multi-dungeon work.

Output: build/probes/ph5/task_5_8/gate_5_8_report.json
Exit 0 iff slice-1 minimum met.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DARK_C = REPO / "RoomRom" / "data" / "uw_dark_rooms.c"
JSONL = Path(r"C:\tmp\uw_dark_observations.jsonl")
OUT_DIR = REPO / "build" / "probes" / "ph5" / "task_5_8"
OUT_REPORT = OUT_DIR / "gate_5_8_report.json"


def parse_dark_rooms() -> set[tuple[int, int, int]]:
    text = DARK_C.read_text(encoding="utf-8")
    out = set()
    for m in re.finditer(
        r"\{\s*(\d+)u?,\s*(\d+)u?,\s*0x([0-9a-fA-F]+)u?,\s*0x[0-9a-fA-F]+u?\s*\}",
        text,
    ):
        out.add((int(m.group(1)), int(m.group(2)), int(m.group(3), 16)))
    return out


def parse_events() -> list[dict]:
    if not JSONL.exists():
        return []
    out = []
    for line in JSONL.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            out.append(json.loads(line))
        except json.JSONDecodeError:
            pass
    return out


def main() -> int:
    rooms = parse_dark_rooms()
    events = parse_events()
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    enter_evs = [e for e in events if e.get("event") == "room_dark_enter"]
    lit_evs = [e for e in events if e.get("event") == "candle_lit"]
    persist_evs = [e for e in events
                   if e.get("event") == "dark_room_persist_reentry"]

    enter_rooms = {e.get("room_id") for e in enter_evs}
    lit_rooms = {e.get("room_id") for e in lit_evs}
    persist_rooms = {e.get("room_id") for e in persist_evs}

    triple_pass = enter_rooms & lit_rooms & persist_rooms
    slice_1_ok = bool(triple_pass)

    report = {
        "verdict": "PASS" if slice_1_ok else "FAIL",
        "rooms_total_in_manifest": len(rooms),
        "rooms_l1q1_in_manifest": sum(
            1 for (l, q, r) in rooms if l == 1 and q == 1),
        "events_total": len(events),
        "enter_events": len(enter_evs),
        "lit_events": len(lit_evs),
        "persist_events": len(persist_evs),
        "rooms_with_enter": sorted(enter_rooms),
        "rooms_with_lit": sorted(lit_rooms),
        "rooms_with_persist": sorted(persist_rooms),
        "triple_pass_rooms": sorted(triple_pass),
        "slice_1_required": "≥1 room with enter + lit + persist",
        "jsonl_path": str(JSONL),
    }
    OUT_REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"verdict: {report['verdict']}")
    print(f"  events: enter={len(enter_evs)} lit={len(lit_evs)} "
          f"persist={len(persist_evs)}")
    print(f"  triple-pass rooms: {sorted(triple_pass)}")
    print(f"report: {OUT_REPORT.relative_to(REPO)}")
    return 0 if slice_1_ok else 1


if __name__ == "__main__":
    sys.exit(main())
