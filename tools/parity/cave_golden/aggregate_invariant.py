#!/usr/bin/env python3
"""Aggregate the per-cave Tier-1 invariant-gate verdicts written by
probe_gen_cave_golden.lua (gen_<ID>/invariant.txt) into one table.

The gate (debate K2 D4) is the cheapest detector for the slot-aliasing bug
class that garbled shop-cave text — NO NES golden needed:
  - char_idx ($0416) strictly NON-DECREASING over 150 post-capture frames
  - NO enemy slot 4..11 ENEMY_ALIVE in the cave (fresh object page)
  - cave actually LOADED (ObjType+1 == CAVE_ID)

Exit 0 iff every captured cave PASSes. Missing invariant.txt = the cave
never finished capturing (force-warp failed / timed out) = FAIL.
"""
import sys, pathlib, re

ROOT = pathlib.Path(r"C:/tmp/cave_golden")
CAVES = list(range(0x6A, 0x7E))  # $6A..$7D

def main():
    rows, n_pass, n_fail, n_missing = [], 0, 0, 0
    for cid in CAVES:
        p = ROOT / f"gen_{cid:02X}" / "invariant.txt"
        if not p.exists():
            rows.append(f"| ${cid:02X} | MISSING (no capture) |")
            n_missing += 1
            continue
        line = p.read_text().strip()
        verdict = "PASS" if " PASS " in f" {line} " else "FAIL"
        if verdict == "PASS":
            n_pass += 1
        else:
            n_fail += 1
        rows.append(f"| ${cid:02X} | {line} |")

    print("# Tier-1 cave invariant-gate sweep\n")
    print("| cave | verdict |")
    print("|------|---------|")
    for r in rows:
        print(r)
    total = len(CAVES)
    print(f"\nPASS {n_pass}/{total}  FAIL {n_fail}  MISSING {n_missing}")
    return 0 if (n_fail == 0 and n_missing == 0) else 1

if __name__ == "__main__":
    sys.exit(main())
