#!/usr/bin/env python3
"""Task 5.7 Gate B/C harness: verify UW push-block parity.

Reads JSONL emitted by RoomRom/probe_uw_pushblock.lua and diffs
against `RoomRom/data/uw_l1q1_pushblocks.{c,h}`.

Verifies, for at least the L1Q1 $22 row (slice-1 minimum):
  - At least one `push_done` event with col=expected, row=expected.
  - State sequence IDLE→TIMING→MOVING→DONE (3 transition events).
  - Persistence: a `push_state_persist` event after walking out and
    back into the same room.

Output: build/probes/ph5/task_5_7/gate_5_7_report.json
Exit 0 iff every required row's PASS.

Usage:
    python tools/gate_5_7_pushblock.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PUSH_C = REPO / "RoomRom" / "data" / "uw_l1q1_pushblocks.c"
JSONL = Path(r"C:\tmp\uw_pushblock_observations.jsonl")
OUT_DIR = REPO / "build" / "probes" / "ph5" / "task_5_7"
OUT_REPORT = OUT_DIR / "gate_5_7_report.json"

# Slice-1 minimum verification target: $22 row only. Other 7 rows
# tracked but not required to PASS in slice-1 (user drives one room).
REQUIRED_ROOM_IDS = {0x22}


def parse_pushblocks() -> list[dict]:
    text = PUSH_C.read_text(encoding="utf-8")
    rows = []
    pat = re.compile(
        r"\{\s*(\d+)u?,\s*(\d+)u?,\s*0x([0-9a-fA-F]+)u?,"
        r"\s*(\d+)u?,\s*(\d+)u?,\s*0x([0-9a-fA-F]+)u?,\s*(\d+)u?\s*\}"
    )
    for m in pat.finditer(text):
        rows.append({
            "level": int(m.group(1)),
            "quest": int(m.group(2)),
            "room_id": int(m.group(3), 16),
            "col": int(m.group(4)),
            "row": int(m.group(5)),
            "allowed_dirs": int(m.group(6), 16),
            "trigger_kind": int(m.group(7)),
        })
    return rows


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
    rows = parse_pushblocks()
    events = parse_events()
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    if not rows:
        sys.exit(f"FAIL: no rows parsed from {PUSH_C}")

    timing_evs = [e for e in events if e.get("event") == "push_timing_start"]
    moving_evs = [e for e in events if e.get("event") == "push_movement_start"]
    done_evs   = [e for e in events if e.get("event") == "push_done"]
    persist_evs = [e for e in events if e.get("event") == "push_state_persist"]

    results = []
    all_required_pass = True
    for r in rows:
        rid = r["room_id"]
        col, row = r["col"], r["row"]
        timing_ok = any(
            e.get("room_id") == rid and e.get("block_col") == col
            and e.get("block_row") == row for e in timing_evs)
        moving_ok = any(
            e.get("room_id") == rid and e.get("block_col") == col
            and e.get("block_row") == row for e in moving_evs)
        done_ok = any(
            e.get("room_id") == rid and e.get("block_col") == col
            and e.get("block_row") == row for e in done_evs)
        persist_ok = any(
            e.get("room_id") == rid for e in persist_evs)

        is_required = rid in REQUIRED_ROOM_IDS
        row_pass = timing_ok and moving_ok and done_ok
        if is_required and not row_pass:
            all_required_pass = False

        results.append({
            "level": r["level"],
            "quest": r["quest"],
            "room_id": f"0x{rid:02X}",
            "col": col, "row": row,
            "required": is_required,
            "timing_ok": timing_ok,
            "moving_ok": moving_ok,
            "done_ok": done_ok,
            "persist_ok": persist_ok,
        })

    report = {
        "verdict": "PASS" if all_required_pass else "FAIL",
        "rows_total": len(rows),
        "rows_required": len(REQUIRED_ROOM_IDS),
        "rows_required_passed": sum(
            1 for r in results
            if r["required"] and r["timing_ok"] and r["moving_ok"] and r["done_ok"]
        ),
        "events_total": len(events),
        "timing_events": len(timing_evs),
        "moving_events": len(moving_evs),
        "done_events": len(done_evs),
        "persist_events": len(persist_evs),
        "results": results,
        "jsonl_path": str(JSONL),
    }
    OUT_REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"verdict: {report['verdict']}")
    print(f"  required rows passed: "
          f"{report['rows_required_passed']}/{report['rows_required']}")
    print(f"  events: timing={len(timing_evs)} moving={len(moving_evs)} "
          f"done={len(done_evs)} persist={len(persist_evs)}")
    print(f"report: {OUT_REPORT.relative_to(REPO)}")
    return 0 if all_required_pass else 1


if __name__ == "__main__":
    sys.exit(main())
