#!/usr/bin/env python3
"""
verify_no_alias_collisions.py — Workstream G: Alias Collision Gate

Scans every src/state/*.h file for RAM() and OBJ() macro definitions,
then fails with exit code 1 if any two distinct macro names map to the
same numeric NES RAM offset (same-kind pairs: RAM-RAM or OBJ-OBJ).

Required green in the phase close gate per master plan Task 2.0.

Usage:
    python tools/state/verify_no_alias_collisions.py [--repo-root PATH]

Exit codes:
    0 — no alias collisions
    1 — one or more alias collisions found (detailed report on stdout)
"""

import argparse
import sys
from pathlib import Path

# Re-use scanner from audit script (same directory)
_HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(_HERE))

from audit_macro_shims import scan_all, find_collisions  # noqa: E402


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--repo-root",
        default=None,
        help="Repository root (default: two levels up from this script's directory)",
    )
    args = parser.parse_args()

    if args.repo_root:
        repo_root = Path(args.repo_root).resolve()
    else:
        repo_root = Path(__file__).resolve().parent.parent.parent

    state_dir = repo_root / "src" / "state"

    if not state_dir.is_dir():
        print(f"ERROR: state dir not found: {state_dir}", file=sys.stderr)
        return 1

    entries = scan_all(state_dir)
    collisions = find_collisions(entries)

    if not collisions:
        print("OK: no alias collisions found.")
        return 0

    # Detailed failure report
    print(f"FAIL: {len(collisions)} alias collision(s) found in src/state/*.h\n")
    print("Two distinct macro names map to the same NES RAM offset.")
    print("Each must be resolved (one canonical name chosen) before the")
    print("owning subsystem is promoted to typed structs.\n")
    print(f"{'Offset':<8}  {'Kind':<4}  {'Name A':<40}  {'Location A':<30}  {'Name B':<40}  {'Location B'}")
    print("-" * 160)
    for a, b in collisions:
        offset_str = f"0x{a.resolved_offset:04X}"
        loc_a = f"{a.filename}:{a.lineno}"
        loc_b = f"{b.filename}:{b.lineno}"
        print(f"{offset_str:<8}  {a.kind:<4}  {a.name:<40}  {loc_a:<30}  {b.name:<40}  {loc_b}")

    print(f"\nTotal: {len(collisions)} collision(s).")
    return 1


if __name__ == "__main__":
    sys.exit(main())
