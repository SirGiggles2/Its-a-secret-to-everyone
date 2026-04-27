"""tools/file_select_test/check_probe_sequence.py — v2 RAM probe gate."""
from __future__ import annotations

import csv
import sys
from pathlib import Path

CSV = Path(__file__).resolve().parent / "out" / "phase_sequence.csv"
if not CSV.exists():
    sys.exit(f"FAIL: {CSV} missing — run probe_phase_sequence.lua first")

rows = list(csv.DictReader(CSV.open()))
if not rows:
    sys.exit("FAIL: empty CSV")

errors: list[str] = []


def find_after(frame_min: int) -> dict[str, str] | None:
    for r in rows:
        if int(r["frame"]) >= frame_min:
            return r
    return None


# 1. Phase must be FS_NAV (=1) once dispatcher has run (frame 30 well into FS_LOAD->FS_NAV).
r30 = find_after(30)
if r30 is None or int(r30["phase"], 16) != 1:
    errors.append(f"frame >=30: phase = {r30['phase'] if r30 else '?'}, expected 01 (FS_NAV)")

# 2. After 4 Down presses (last at frame 150), cursor must reach 4 by frame 180.
r180 = find_after(180)
if r180 is None or int(r180["cursor"], 16) != 4:
    errors.append(f"frame >=180: cursor = {r180['cursor'] if r180 else '?'}, expected 04 (4 Downs walk 0->4)")

# 3. After 4 Up presses (last at frame 300), cursor must be back at 0 by frame 330.
r330 = find_after(330)
if r330 is None or int(r330["cursor"], 16) != 0:
    errors.append(f"frame >=330: cursor = {r330['cursor'] if r330 else '?'}, expected 00 (4 Ups walk 4->0)")

if errors:
    for e in errors:
        print("FAIL:", e)
    print()
    print("Last 12 CSV rows:")
    for r in rows[-12:]:
        print(f"  frame={r['frame']:>4}  phase={r['phase']}  cursor={r['cursor']}")
    sys.exit(1)

print("PASS: phase sequence matches expected (FS_NAV reached, cursor 0->4->0 via D-pad)")
