"""Diff two position_log.lua outputs.

Usage:
    python tools/compare_position_logs.py <baseline.txt> <test.txt>

Reports first diverging logical tick + slot + field (X, Y, Dir, PosFrac, GridOffset).
Zero diverges = parity pass. Any diverge = parity fail, block commit.
"""
import sys
from pathlib import Path


def parse(path):
    rows = []
    with open(path) as fh:
        for line in fh:
            if line.startswith("#") or not line.strip():
                continue
            parts = line.rstrip("\n").split(",")
            # Format: tick, emu_frame, room, mode, sub, types(12), xs(12), ys(12), dirs(12), pos_frac(12), grid_ofs(12)
            if len(parts) < 5 + 12 * 6:
                # Older formats or ragged rows — skip
                continue
            tick = int(parts[0])
            room = int(parts[2], 16)
            mode = int(parts[3], 16)
            sub  = int(parts[4], 16)
            def slots(start):
                return [int(parts[start + i], 16) for i in range(12)]
            row = {
                "tick": tick,
                "room": room, "mode": mode, "sub": sub,
                "types":    slots(5 + 0 * 12),
                "xs":       slots(5 + 1 * 12),
                "ys":       slots(5 + 2 * 12),
                "dirs":     slots(5 + 3 * 12),
                "pos_frac": slots(5 + 4 * 12),
                "grid_ofs": slots(5 + 5 * 12),
            }
            rows.append(row)
    return rows


FIELDS = ("types", "xs", "ys", "dirs", "pos_frac", "grid_ofs")


def main():
    if len(sys.argv) != 3:
        print("usage: compare_position_logs.py <baseline.txt> <test.txt>", file=sys.stderr)
        return 2
    baseline = parse(sys.argv[1])
    test = parse(sys.argv[2])
    if not baseline or not test:
        print(f"ERROR: empty log(s) — baseline={len(baseline)} test={len(test)}", file=sys.stderr)
        return 2

    n = min(len(baseline), len(test))
    diffs = []
    for i in range(n):
        b, t = baseline[i], test[i]
        if b["room"] != t["room"]:
            diffs.append((i, "room", b["room"], t["room"], None))
        if b["mode"] != t["mode"] or b["sub"] != t["sub"]:
            diffs.append((i, "mode/sub", f"{b['mode']:02X}/{b['sub']:02X}", f"{t['mode']:02X}/{t['sub']:02X}", None))
        for field in FIELDS:
            for slot in range(12):
                bv = b[field][slot]
                tv = t[field][slot]
                if bv != tv:
                    diffs.append((i, field, bv, tv, slot))

    if not diffs:
        print(f"PARITY PASS — {n} logical ticks compared, zero mismatches across {len(FIELDS)} fields × 12 slots")
        return 0

    # Show first 10 diverging entries.
    print(f"PARITY FAIL — {len(diffs)} mismatches over {n} ticks")
    print()
    print(f"First mismatch at tick={baseline[diffs[0][0]]['tick']}:")
    for i, (idx, field, b, t, slot) in enumerate(diffs[:10]):
        tick = baseline[idx]["tick"]
        slot_s = f" slot={slot}" if slot is not None else ""
        print(f"  tick={tick:3d}{slot_s}  {field}: baseline=${b:02X} test=${t:02X}"
              if isinstance(b, int) else
              f"  tick={tick:3d}{slot_s}  {field}: baseline={b} test={t}")
    if len(diffs) > 10:
        print(f"  ... and {len(diffs) - 10} more")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
