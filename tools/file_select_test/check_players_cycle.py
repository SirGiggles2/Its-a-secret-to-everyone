"""tools/file_select_test/check_players_cycle.py — v3 RAM probe gate."""
from __future__ import annotations

import csv
import sys
from pathlib import Path

CSV = Path(__file__).resolve().parent / "out" / "players_cycle.csv"
if not CSV.exists():
    sys.exit(f"FAIL: {CSV} missing")

rows = list(csv.DictReader(CSV.open()))
if not rows:
    sys.exit("FAIL: empty CSV")


def at_or_after(frame_min: int) -> dict[str, str] | None:
    for r in rows:
        if int(r["frame"]) >= frame_min:
            return r
    return None


errors: list[str] = []

# After 5 Downs (last at frame 180), cursor must reach 5 (PLAYERS) by frame 210.
r210 = at_or_after(210)
if r210 is None or int(r210["cursor"], 16) != 5:
    errors.append(f"frame >=210: cursor = {r210['cursor'] if r210 else '?'}, expected 05 (PLAYERS)")

# Initial PLAYERS value = 1 (from fs_phase_init).
if r210 and int(r210["players"], 16) != 1:
    errors.append(f"frame >=210: players = {r210['players']}, expected 01 (init default)")

# After 3 Rights (last at frame 300), players = 4.
r300 = at_or_after(301)
if r300 is None or int(r300["players"], 16) != 4:
    errors.append(f"frame >=301: players = {r300['players'] if r300 else '?'}, expected 04 (1+3)")

# After 4th Right (frame 330), players wraps to 1.
r330 = at_or_after(331)
if r330 is None or int(r330["players"], 16) != 1:
    errors.append(f"frame >=331: players = {r330['players'] if r330 else '?'}, expected 01 (wrap)")

# After Left (frame 360), players wraps to 4.
r360 = at_or_after(361)
if r360 is None or int(r360["players"], 16) != 4:
    errors.append(f"frame >=361: players = {r360['players'] if r360 else '?'}, expected 04 (wrap left)")

if errors:
    for e in errors:
        print("FAIL:", e)
    print()
    print("Last 12 CSV rows:")
    for r in rows[-12:]:
        print(f"  frame={r['frame']:>4}  phase={r['phase']}  cursor={r['cursor']}  players={r['players']}")
    sys.exit(1)

print("PASS: PLAYERS cycle 1->2->3->4->1 (wrap right) and ->4 (wrap left)")
