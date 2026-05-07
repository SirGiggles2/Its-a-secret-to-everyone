#!/usr/bin/env python3
"""Task 5.9 Gate B harness: verify item pickup + triforce stub.

Slice-1 minimum: at least one item_pickup event AND one
triforce_pickup event captured. Full HUD render + key decrement +
mini-map verification deferred to follow-up.

Output: build/probes/ph5/task_5_9/gate_5_9_report.json
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
JSONL = Path(r"C:\tmp\uw_inventory_observations.jsonl")
OUT_DIR = REPO / "build" / "probes" / "ph5" / "task_5_9"
OUT_REPORT = OUT_DIR / "gate_5_9_report.json"


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
    events = parse_events()
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    pickups = [e for e in events if e.get("event") == "item_pickup"]
    triforces = [e for e in events if e.get("event") == "triforce_pickup"]
    compass_evs = [e for e in events if e.get("event") == "compass_set"]
    map_evs = [e for e in events if e.get("event") == "map_set"]

    pickup_ok = len(pickups) >= 1
    triforce_ok = len(triforces) >= 1
    slice_1_ok = pickup_ok and triforce_ok

    report = {
        "verdict": "PASS" if slice_1_ok else "FAIL",
        "events_total": len(events),
        "pickup_events": len(pickups),
        "triforce_events": len(triforces),
        "compass_events": len(compass_evs),
        "map_events": len(map_evs),
        "first_pickup": pickups[0] if pickups else None,
        "first_triforce": triforces[0] if triforces else None,
        "slice_1_required": "≥1 item_pickup + ≥1 triforce_pickup",
        "jsonl_path": str(JSONL),
    }
    OUT_REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"verdict: {report['verdict']}")
    print(f"  pickup={len(pickups)} triforce={len(triforces)} "
          f"compass={len(compass_evs)} map={len(map_evs)}")
    print(f"report: {OUT_REPORT.relative_to(REPO)}")
    return 0 if slice_1_ok else 1


if __name__ == "__main__":
    sys.exit(main())
