"""Pool every lockstep ratchet baseline into one NES-vs-Genesis RAM list.

    python tools/audit/baseline_mismatch_report.py [--md OUT] [--min-tick N]

Each tools/lockstep/baselines/<preset>.json maps an NES RAM cell to the
first game tick it differed from the NES in that preset (an accepted,
non-KEY difference). A cell that differs from tick 0 is a boot-state
difference (Genesis boots straight into a staged save); cells that start
later are behavior differences: each one is a bug candidate or a
documented Genesis improvement.

Output: one row per cell that differs after --min-tick (default 1) in
any preset: cell, NES name, number of presets, the earliest
(preset, tick) pairs. Names come from tools/lockstep (the differ's map).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "tools" / "lockstep" / "baselines"


def cell_names() -> dict[int, str]:
    sys.path.insert(0, str(ROOT / "tools" / "lockstep"))
    import diff  # type: ignore  (the lockstep differ's Variables.inc map)
    return {a: diff.name(a) for a in range(0x800)}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--md", type=Path)
    ap.add_argument("--min-tick", type=int, default=1)
    args = ap.parse_args()
    pool: dict[int, list[tuple[int, str]]] = {}
    for f in sorted(BASE.glob("*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        for k, t in d.get("cells", {}).items():
            if t >= args.min_tick:
                pool.setdefault(int(k, 16), []).append((t, d.get("preset", f.stem)))
    names = cell_names()
    rows = ["| Cell | Name | Presets | Earliest (preset@tick) |", "|---|---|---|---|"]
    for a in sorted(pool, key=lambda a: (-len(pool[a]), a)):
        hits = sorted(pool[a])
        first = ", ".join(f"{p}@{t}" for t, p in hits[:4])
        rows.append(f"| ${a:04X} | {names.get(a, '')} | {len(hits)} | {first} |")
    text = "\n".join(rows)
    if args.md:
        args.md.write_text(text + "\n", encoding="utf-8")
    print(text)
    print(f"MISMATCH: {len(pool)} cells differ after tick {args.min_tick - 1} "
          f"across {len(list(BASE.glob('*.json')))} baselines")


if __name__ == "__main__":
    main()
