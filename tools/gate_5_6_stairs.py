#!/usr/bin/env python3
"""Task 5.6 Gate B/C harness: verify UW-stair entry/exit parity.

Reads the JSONL event stream emitted by RoomRom/probe_uw_stair.lua and
diffs against the slice-1 cellar pair manifest in
RoomRom/data/uw_l1q1_cellar_pairs.{c,h}.

For each pair (source, cellar) in the manifest:
  - Entry: at least one stair_entry event with
           source_room == source AND cellar_room == cellar.
  - Exit:  at least one stair_exit event with
           cellar_room_at_fire == cellar AND dest_room == source.

Output:  build/probes/ph5/task_5_6/gate_5_6_report.json
Exit 0 iff zero diff.

Usage:
    python tools/gate_5_6_stairs.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
PAIRS_C = REPO / "RoomRom" / "data" / "uw_l1q1_cellar_pairs.c"
JSONL = Path(r"C:\tmp\uw_stair_observations.jsonl")
OUT_DIR = REPO / "build" / "probes" / "ph5" / "task_5_6"
OUT_REPORT = OUT_DIR / "gate_5_6_report.json"


def parse_pairs() -> list[dict]:
    text = PAIRS_C.read_text(encoding="utf-8")
    rows = []
    pat = re.compile(
        r"\{\s*(\d+)u?,\s*(\d+)u?,\s*0x([0-9a-fA-F]+)u?,\s*0x([0-9a-fA-F]+)u?\s*\}"
    )
    for m in pat.finditer(text):
        rows.append({
            "level": int(m.group(1)),
            "quest": int(m.group(2)),
            "source": int(m.group(3), 16),
            "cellar": int(m.group(4), 16),
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
    pairs = parse_pairs()
    events = parse_events()
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    if not pairs:
        sys.exit(f"FAIL: no pairs parsed from {PAIRS_C}")

    entry_evs = [e for e in events if e.get("event") == "stair_entry"]
    exit_evs = [e for e in events if e.get("event") == "stair_exit"]

    results = []
    all_pass = True
    for p in pairs:
        src, cell = p["source"], p["cellar"]
        entry_ok = any(
            e.get("source_room") == src and e.get("cellar_room") == cell
            for e in entry_evs
        )
        exit_ok = any(
            e.get("cellar_room_at_fire") == cell and e.get("dest_room") == src
            for e in exit_evs
        )
        if not (entry_ok and exit_ok):
            all_pass = False
        results.append({
            "level": p["level"],
            "quest": p["quest"],
            "source": f"0x{src:02X}",
            "cellar": f"0x{cell:02X}",
            "entry_ok": entry_ok,
            "exit_ok": exit_ok,
        })

    report = {
        "verdict": "PASS" if all_pass else "FAIL",
        "pairs_total": len(pairs),
        "pairs_passed": sum(1 for r in results if r["entry_ok"] and r["exit_ok"]),
        "entry_events_seen": len(entry_evs),
        "exit_events_seen": len(exit_evs),
        "events_total": len(events),
        "results": results,
        "jsonl_path": str(JSONL),
    }
    OUT_REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"verdict: {report['verdict']}")
    print(f"  passed: {report['pairs_passed']}/{report['pairs_total']}")
    print(f"  entry events: {len(entry_evs)}, exit events: {len(exit_evs)}")
    print(f"report: {OUT_REPORT.relative_to(REPO)}")
    return 0 if all_pass else 1


if __name__ == "__main__":
    sys.exit(main())
