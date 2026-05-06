#!/usr/bin/env python3
"""Gate B four-boot diff harness for Task 5.4.

Reads boot_d_snapshot.json + boot_w_snapshot.json captures from the
BizHawk Lua probe and computes pairwise diffs across:

  - Boot W-RR vs Boot D-RR  (RoomRom-internal warp vs direct)
  - Boot W-CD vs Boot D-CD  (CombinedDebug-internal warp vs direct)
  - Boot W-RR vs Boot W-CD  (cross-ROM warp parity)
  - Boot D-RR vs Boot D-CD  (cross-ROM direct parity baseline)

Inputs (paths follow the BizHawk probe convention; rename per run):
  build/probes/ph5/task_5_4/boot_d_rr.json
  build/probes/ph5/task_5_4/boot_w_rr.json
  build/probes/ph5/task_5_4/boot_d_cd.json
  build/probes/ph5/task_5_4/boot_w_cd.json

Output: stdout report; exit 0 iff every diff is empty for the gate-B
field set, exit 1 otherwise.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

# Fields that must match across all four boots. `frame` is excluded
# because the absolute frame number differs per boot path; only the
# logical state surface matters.
GATE_B_FIELDS = [
    "scene",
    "room_id",
    "link_x", "link_y",
    "link_face", "link_dir",
    "link_grid",
    "doorway",
    "uw_level", "uw_quest",
]
# Excluded:
#   ow_stable      — OW-side cache flag; 1 in warp path, 0 in direct boot.
#                    Not part of UW gameplay state.
#   warp_active    — Coordinator-internal state; depends on which exact
#                    frame the snapshot was taken on (LOAD vs RESUME).
#                    Boot W snapshots taken at the apply frame report 1;
#                    one frame later they report 0. Not a parity field.

# Fields that may differ between Boot D and Boot W *within the same
# target* but should match cross-ROM. The save state is populated only
# in Boot W (the warp run), so it is excluded from D vs W comparisons.
WARP_ONLY_FIELDS = [
    "save_dst_room_id",
    "save_dst_level",
    "save_dst_quest",
    "save_uet",
    "warp_unsupported_count",
]


def load_snapshot(path: Path) -> dict:
    if not path.exists():
        return {}
    with path.open("r", encoding="utf-8") as f:
        return json.loads(f.readline().strip())


def diff_snapshots(a: dict, b: dict, label_a: str, label_b: str,
                   fields: list[str]) -> list[str]:
    diffs = []
    for fld in fields:
        va = a.get(fld)
        vb = b.get(fld)
        if va != vb:
            diffs.append(f"  {fld}: {label_a}={va!r} vs {label_b}={vb!r}")
    return diffs


def report_pair(a: dict, b: dict, label_a: str, label_b: str,
                fields: list[str]) -> bool:
    print(f"\n=== {label_a} vs {label_b} ===")
    if not a:
        print(f"  MISSING: {label_a} snapshot not present")
        return False
    if not b:
        print(f"  MISSING: {label_b} snapshot not present")
        return False
    diffs = diff_snapshots(a, b, label_a, label_b, fields)
    if not diffs:
        print("  PASS — zero diff")
        return True
    print(f"  FAIL — {len(diffs)} field(s) diverge:")
    for d in diffs:
        print(d)
    return False


def main(argv: list[str]) -> int:
    repo = Path(__file__).resolve().parent.parent
    base = repo / "build" / "probes" / "ph5" / "task_5_4"

    snapshots = {
        "Boot D-RR": load_snapshot(base / "boot_d_rr.json"),
        "Boot W-RR": load_snapshot(base / "boot_w_rr.json"),
        "Boot D-CD": load_snapshot(base / "boot_d_cd.json"),
        "Boot W-CD": load_snapshot(base / "boot_w_cd.json"),
    }

    print("Gate B four-boot diff — Task 5.4")
    print("=" * 60)
    print("\nLoaded snapshots:")
    for name, snap in snapshots.items():
        if snap:
            print(f"  {name}: frame={snap.get('frame')} room=${snap.get('room_id'):02X} "
                  f"({snap.get('link_x')},{snap.get('link_y')}) face={snap.get('link_face')}")
        else:
            print(f"  {name}: MISSING")

    overall = True
    overall &= report_pair(snapshots["Boot W-RR"], snapshots["Boot D-RR"],
                           "Boot W-RR", "Boot D-RR", GATE_B_FIELDS)
    overall &= report_pair(snapshots["Boot W-CD"], snapshots["Boot D-CD"],
                           "Boot W-CD", "Boot D-CD", GATE_B_FIELDS)
    overall &= report_pair(snapshots["Boot W-RR"], snapshots["Boot W-CD"],
                           "Boot W-RR", "Boot W-CD",
                           GATE_B_FIELDS + WARP_ONLY_FIELDS)
    overall &= report_pair(snapshots["Boot D-RR"], snapshots["Boot D-CD"],
                           "Boot D-RR", "Boot D-CD", GATE_B_FIELDS)

    print("\n" + "=" * 60)
    if overall:
        print("Gate B: PASS")
        return 0
    print("Gate B: FAIL")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
