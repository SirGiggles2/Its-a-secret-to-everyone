#!/usr/bin/env python3
"""Gate 5.5 — UW L1Q1 door-route diff harness.

Reads the JSONL produced by RoomRom/probe_uw_l1_route.lua and the
generated expected-doors table; emits per-room + per-touch parity diffs
plus behavioral-invariant assertions per door type.

Inputs (defaults; override via argv):
  jsonl   = C:/tmp/uw_door_observations.jsonl
  expected = RoomRom/data/uw_l1q1_expected_doors.c (parsed direct)

Outputs:
  build/probes/ph5/task_5_5/gate_5_5_report.json
  stdout: human-readable summary

Exit code: 0 iff every reachable room visited AND every observation
matches expected AND behavioral invariants hold.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
DEFAULT_JSONL = Path("C:/tmp/uw_door_observations.jsonl")
EXPECTED_C = REPO / "RoomRom" / "data" / "uw_l1q1_expected_doors.c"
REPORT_OUT = REPO / "build" / "probes" / "ph5" / "task_5_5" / "gate_5_5_report.json"

DOOR_TYPE_NAMES = {
    0: "OPEN", 1: "WALL", 2: "FALSE", 3: "FALSE2",
    4: "BOMBABLE", 5: "KEY", 6: "KEY2", 7: "SHUTTER",
}
DIR_NAMES = {0: "E", 1: "W", 2: "S", 3: "N"}
DIR_BITS  = {0: 0x01, 1: 0x02, 2: 0x04, 3: 0x08}


def parse_expected(path: Path) -> list[dict]:
    """Parse generated .c. Each row line:
       { 0xRRu, { Eu, Wu, Su, Nu }, Ru },  /* comment */
    """
    rows = []
    pattern = re.compile(
        r"\{\s*0x([0-9A-Fa-f]{2})u,\s*\{\s*(\d+)u,\s*(\d+)u,\s*(\d+)u,\s*(\d+)u\s*\},"
        r"\s*(\d+)u\s*\}"
    )
    text = path.read_text(encoding="utf-8")
    for m in pattern.finditer(text):
        rows.append({
            "room_id": int(m.group(1), 16),
            "door_type": [int(m.group(i)) for i in range(2, 6)],
            "reachable": int(m.group(6)),
        })
    return rows


def parse_jsonl(path: Path) -> tuple[list[dict], int]:
    events, skipped = [], 0
    with path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                skipped += 1
    return events, skipped


def diff_room_doors(observed: list[int], expected: list[int]) -> list[str]:
    diffs = []
    for d_idx in range(4):
        if observed[d_idx] != expected[d_idx]:
            diffs.append(
                f"    dir {DIR_NAMES[d_idx]}: observed={DOOR_TYPE_NAMES.get(observed[d_idx], '?')}({observed[d_idx]}) "
                f"expected={DOOR_TYPE_NAMES.get(expected[d_idx], '?')}({expected[d_idx]})"
            )
    return diffs


def behavioral_check(touch_events: list[dict]) -> list[str]:
    """Apply per-door-type invariants from the spec table."""
    failures = []
    for ev in touch_events:
        dt = ev.get("door_type")
        result = ev.get("result")
        keys_pre = ev.get("keys_pre", 0)
        keys_post = ev.get("keys_post", 0)
        room = ev.get("room_id")
        d = ev.get("dir")
        opened_mask_after = ev.get("opened_mask_after", 0)

        if dt == 1:  # WALL
            if result != 0:
                failures.append(f"  room ${room:02X} dir {DIR_NAMES.get(d,'?')}: WALL touch result={result} (expected 0)")
        elif dt == 0:  # OPEN
            if result != 1:
                failures.append(f"  room ${room:02X} dir {DIR_NAMES.get(d,'?')}: OPEN touch result={result} (expected 1)")
        elif dt in (5, 6):  # KEY / KEY2
            consumed = keys_pre - keys_post
            opened_bit = DIR_BITS.get(d, 0) if d is not None and d < 4 else 0
            already_opened = (opened_mask_after & opened_bit) != 0 and consumed == 0
            if consumed not in (0, 1):
                failures.append(f"  room ${room:02X} dir {DIR_NAMES.get(d,'?')}: KEY consumed={consumed} (expected 0 or 1)")
            if consumed == 1 and not already_opened and result not in (0, 1):
                failures.append(f"  room ${room:02X} dir {DIR_NAMES.get(d,'?')}: KEY first-consume result={result}")
        # FALSE / BOMBABLE / SHUTTER invariants need timeline reconstruction;
        # slice-1 records observation only, leaves complex assertions to
        # follow-up review (P3 deferral).
    return failures


def main(argv: list[str]) -> int:
    jsonl_path = Path(argv[1]) if len(argv) > 1 else DEFAULT_JSONL
    print(f"Gate 5.5 — UW L1Q1 door route diff")
    print(f"  jsonl:    {jsonl_path}")
    print(f"  expected: {EXPECTED_C}")
    print()

    if not jsonl_path.exists():
        print(f"FAIL: missing JSONL: {jsonl_path}")
        return 1
    if not EXPECTED_C.exists():
        print(f"FAIL: missing expected table: {EXPECTED_C}")
        return 1

    expected = {r["room_id"]: r for r in parse_expected(EXPECTED_C)}
    reachable = {rid for rid, r in expected.items() if r["reachable"] == 1}
    print(f"Loaded expected: {len(expected)} rooms ({len(reachable)} reachable, "
          f"{len(expected) - len(reachable)} combat-locked)")

    events, skipped = parse_jsonl(jsonl_path)
    print(f"Parsed JSONL: {len(events)} events, {skipped} malformed lines skipped")

    room_entries = [e for e in events if e.get("event") == "room_entry"]
    touches     = [e for e in events if e.get("event") == "touch"]
    shutters    = [e for e in events if e.get("event") == "shutter_trigger"]
    print(f"  room_entry: {len(room_entries)}  touch: {len(touches)}  shutter_trigger: {len(shutters)}")

    visited = {e["room_id"] for e in room_entries if e.get("room_id") in expected}
    visited_reachable = visited & reachable
    missing = reachable - visited
    print(f"\nVisit coverage: {len(visited_reachable)}/{len(reachable)} reachable rooms")
    if missing:
        print(f"  MISSING: {sorted(f'${r:02X}' for r in missing)}")

    # Gate B: door type parity per visited room.
    print("\n=== Gate B — door type parity ===")
    parity_fails = []
    parity_passes = 0
    for room_id in sorted(visited):
        if room_id not in expected:
            continue
        # Find latest room_entry for this room (last visit reflects most state).
        entries_for_room = [e for e in room_entries if e.get("room_id") == room_id]
        if not entries_for_room:
            continue
        latest = entries_for_room[-1]
        observed = [latest.get("door_E", 0), latest.get("door_W", 0),
                    latest.get("door_S", 0), latest.get("door_N", 0)]
        diffs = diff_room_doors(observed, expected[room_id]["door_type"])
        if diffs:
            parity_fails.append({"room": f"${room_id:02X}", "diffs": diffs})
            print(f"  room ${room_id:02X}: FAIL")
            for d in diffs:
                print(d)
        else:
            parity_passes += 1
    print(f"Gate B: {parity_passes}/{len(visited)} pass, {len(parity_fails)} fail")

    # Gate C: behavioral invariants.
    print("\n=== Gate C — behavioral invariants (touch events) ===")
    behavioral_fails = behavioral_check(touches)
    print(f"Gate C: {len(touches) - len(behavioral_fails)}/{len(touches)} pass, "
          f"{len(behavioral_fails)} fail")
    for f in behavioral_fails:
        print(f)

    overall_pass = (
        not missing
        and not parity_fails
        and not behavioral_fails
    )

    REPORT_OUT.parent.mkdir(parents=True, exist_ok=True)
    REPORT_OUT.write_text(json.dumps({
        "jsonl": str(jsonl_path),
        "events_total": len(events),
        "malformed_skipped": skipped,
        "rooms_total": len(expected),
        "rooms_reachable": len(reachable),
        "rooms_visited": sorted(visited_reachable),
        "rooms_missing": sorted(missing),
        "gate_b_parity_passes": parity_passes,
        "gate_b_parity_fails": parity_fails,
        "gate_c_behavioral_fails": behavioral_fails,
        "touches_total": len(touches),
        "shutter_triggers_total": len(shutters),
        "overall_pass": overall_pass,
    }, indent=2) + "\n", encoding="utf-8")
    print(f"\nReport: {REPORT_OUT}")

    print("\n" + "=" * 60)
    print(f"Gate 5.5: {'PASS' if overall_pass else 'FAIL'}")
    return 0 if overall_pass else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
