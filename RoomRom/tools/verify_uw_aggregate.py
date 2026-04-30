#!/usr/bin/env python3
"""Aggregate verifier for RoomRom NES UW dumps.

Runs uw_aggregate.py first (idempotent), then validates the merged
output. Optionally re-hashes L1 entries against the L1 golden file.

Usage:
    python RoomRom/tools/verify_uw_aggregate.py [--check-golden]
"""

import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
TOOLS = REPO_ROOT / "RoomRom" / "tools"
DATA = REPO_ROOT / "RoomRom" / "data"
OUT = REPO_ROOT / "RoomRom" / "out"


def fail(msg: str) -> None:
    print(f"AGGREGATE FAIL: {msg}", file=sys.stderr)
    sys.exit(2)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check-golden", action="store_true")
    args = ap.parse_args(argv[1:])

    # Always rebuild the aggregate first.
    rc = subprocess.run(
        [sys.executable, str(TOOLS / "uw_aggregate.py")],
        cwd=str(REPO_ROOT),
    ).returncode
    if rc != 0:
        fail(f"uw_aggregate.py exit={rc}")

    agg_path = OUT / "nes_uw_aggregate.json"
    if not agg_path.exists():
        fail("aggregate JSON not produced")
    agg = json.loads(agg_path.read_text(encoding="utf-8"))
    entries = agg.get("entries") or []

    # Duplicate check (rom, quest, level, source_block, room_id)
    seen = {}
    for e in entries:
        key = (e["rom"], e["quest"], e["level"], e["source_block"], e["room_id"])
        if key in seen:
            fail(f"duplicate entry {key}")
        seen[key] = e

    # Per-(rom, quest, level) presence: at least one captured room.
    # (Probe writes per-run JSON regardless; here we check captured rows.)
    present_levels = {}
    for e in entries:
        present_levels.setdefault((e["rom"], e["quest"], e["level"]), 0)
        present_levels[(e["rom"], e["quest"], e["level"])] += 1
    # If a per-run dump file exists but contributes zero captured rooms,
    # the level is fully timed-out -> block.
    for level in range(1, 10):
        for quest in (1, 2):
            for rom in ("orig", "redux"):
                p = OUT / f"nes_uw_level{level}_quest{quest}_{rom}.json"
                if not p.exists():
                    continue
                try:
                    data = json.loads(p.read_text(encoding="utf-8"))
                except Exception:
                    continue
                if not data.get("boot_ok") or not data.get("warp_ok"):
                    fail(
                        f"L{level} Q{quest} {rom}: boot/warp failed "
                        f"({data.get('fatal_error')})"
                    )
                count = present_levels.get((rom, quest, level), 0)
                if count == 0 and (data.get("results") or []):
                    fail(
                        f"L{level} Q{quest} {rom}: zero captured rooms (full timeout)"
                    )

    if args.check_golden:
        golden_p = DATA / "uw_level1_golden.json"
        if not golden_p.exists():
            print("WARN: no L1 golden to check")
        else:
            golden = json.loads(golden_p.read_text(encoding="utf-8"))
            golden_idx = {
                (g["quest"], g["rom"], int(g["room_id"], 16)): g
                for g in golden.get("entries") or []
            }
            mismatches = []
            for e in entries:
                if e["level"] != 1:
                    continue
                key = (e["quest"], e["rom"], e["room_id"])
                g = golden_idx.get(key)
                if g is None:
                    continue
                nt_bytes = bytes(b for row in e["nt"] for b in row)
                attr_bytes = bytes(e["attr"])
                pal_bytes = bytes(e["palram"])
                nt_h = hashlib.sha256(nt_bytes).hexdigest()
                attr_h = hashlib.sha256(attr_bytes).hexdigest()
                pal_h = hashlib.sha256(pal_bytes).hexdigest()
                if (nt_h != g["nt_sha256"]
                    or attr_h != g["attr_sha256"]
                    or pal_h != g["palram_sha256"]):
                    mismatches.append(key)
            if mismatches:
                fail(
                    f"L1 golden hash drift in {len(mismatches)} entries; "
                    f"e.g. {mismatches[:5]}"
                )
            print(f"L1 golden check OK ({len(golden_idx)} entries hashed clean)")

    print(f"AGGREGATE OK: {len(entries)} entries, {len(present_levels)} (rom,quest,level) groups")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
