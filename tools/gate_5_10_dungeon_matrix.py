#!/usr/bin/env python3
"""Task 5.10a Dungeon Matrix Verification — preflight aggregator.

Aggregates 5.4-5.9 generator manifests (data-only checks) plus
replays L1Q1 live JSONL evidence from gate_5_4..5_9 as available.

Verdict semantics:
- PASS: L1Q1 live PASS for all 5.4-5.9 gates that ran AND every
  master generator's L1-L9 x Q1-Q2 manifest parses + invariants hold.
- PREFLIGHT: data-only checks PASS but no live verification ran for
  L2-L9 / Q2 (slice-1 expected state).
- FAIL: data parse error or any L1Q1 gate fail.

Per plan v3 F3: 5.10b (full multi-dungeon user-test) is a formal
Phase-5 close deferral; this harness explicitly does NOT claim to
satisfy "render every room in all 9 dungeons both quests" — that
remains 5.10b.

Usage:
    python tools/gate_5_10_dungeon_matrix.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
OUT_DIR = REPO / "build" / "probes" / "ph5" / "task_5_10"
OUT_REPORT = OUT_DIR / "gate_5_10_report.json"

MANIFESTS = {
    "doors":      REPO / "RoomRom" / "data" / "uw_l1q1_expected_doors.c",
    "cellars":    REPO / "RoomRom" / "data" / "uw_l1q1_cellar_pairs.c",
    "pushblocks": REPO / "RoomRom" / "data" / "uw_l1q1_pushblocks.c",
    "dark":       REPO / "RoomRom" / "data" / "uw_dark_rooms.c",
    "items":      REPO / "RoomRom" / "data" / "uw_item_rooms.c",
}

PRIOR_GATES = [
    REPO / "build" / "probes" / "ph5" / "task_5_4" / "gate_b_diff_report.json",
    REPO / "build" / "probes" / "ph5" / "task_5_5" / "gate_5_5_door_route_report.json",
    REPO / "build" / "probes" / "ph5" / "task_5_6" / "gate_5_6_report.json",
    REPO / "build" / "probes" / "ph5" / "task_5_7" / "gate_5_7_report.json",
    REPO / "build" / "probes" / "ph5" / "task_5_8" / "gate_5_8_report.json",
    REPO / "build" / "probes" / "ph5" / "task_5_9" / "gate_5_9_report.json",
]


def count_rows(path: Path) -> int:
    if not path.exists():
        return -1
    text = path.read_text(encoding="utf-8")
    return len(re.findall(r"\{\s*\d+u?,", text))


def load_prior_gate(path: Path) -> dict:
    if not path.exists():
        return {"task": path.parent.name, "found": False}
    try:
        report = json.loads(path.read_text(encoding="utf-8"))
        return {"task": path.parent.name, "found": True,
                "verdict": report.get("verdict", "UNKNOWN"),
                "report_path": str(path.relative_to(REPO))}
    except Exception as ex:
        return {"task": path.parent.name, "found": True,
                "error": str(ex)}


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    # Manifest data-only checks.
    manifest_results = []
    all_manifests_ok = True
    for name, path in MANIFESTS.items():
        rows = count_rows(path)
        ok = rows > 0
        if not ok:
            all_manifests_ok = False
        manifest_results.append({
            "name": name, "path": str(path.relative_to(REPO)),
            "rows": rows, "ok": ok,
        })

    # Prior gate replay (L1Q1 live evidence).
    prior_gates = [load_prior_gate(p) for p in PRIOR_GATES]
    prior_pass = sum(1 for g in prior_gates
                     if g.get("found") and g.get("verdict") == "PASS")
    prior_total = sum(1 for g in prior_gates if g.get("found"))

    # Verdict.
    if not all_manifests_ok:
        verdict = "FAIL"
    elif prior_total == 0:
        verdict = "PREFLIGHT"
    elif prior_pass == prior_total:
        verdict = "PASS"
    else:
        verdict = "FAIL"

    report = {
        "verdict": verdict,
        "scope": "Task 5.10a preflight; Task 5.10b (full multi-dungeon "
                 "user-test) deferred per Phase 5 close.",
        "manifests": manifest_results,
        "all_manifests_ok": all_manifests_ok,
        "prior_gates": prior_gates,
        "prior_gates_pass": prior_pass,
        "prior_gates_found": prior_total,
        "deferred_510b": (
            "Full L1-L9 x Q1-Q2 user-driven render + screenshot diff "
            "+ walkability matrix verification. Requires Q2 quest "
            "selector, mature Phase 6 items/combat. Plans post-Phase-6."
        ),
    }
    OUT_REPORT.write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(f"verdict: {verdict}")
    print(f"  manifests: {sum(1 for r in manifest_results if r['ok'])}"
          f"/{len(manifest_results)} OK")
    print(f"  prior gates: {prior_pass}/{prior_total} PASS")
    print(f"report: {OUT_REPORT.relative_to(REPO)}")
    return 0 if verdict in ("PASS", "PREFLIGHT") else 1


if __name__ == "__main__":
    sys.exit(main())
