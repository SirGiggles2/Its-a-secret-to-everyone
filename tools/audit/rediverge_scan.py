"""Find NES RAM cells that match the NES and then split again.

    python tools/audit/rediverge_scan.py [preset ...] [--md OUT]

The ratchet baselines record only the FIRST tick a cell differs. A cell
that differs from boot (tick 0) is filed as a boot-state difference, which
hides a real behavior bug when the cell later matches the NES and then
goes its own way (T-171: CurObjIndex $340, RoomAllDead $34D, ObjCollidedTile
$49E all hid there). This scan reads the full per-tick RAM of each report
(builds/reports/lockstep/<preset>/{nes,gen}.ram, 2 KB per tick) and lists,
per cell, the first tick it differs AFTER having been equal: a
re-divergence is behavior, not boot state.

Masked cells (tools/lockstep/gate.py MASKS) and the report's ACCEPTED
registry are skipped. Output: cell, name, presets, first re-divergence
(preset@tick). Verdict line: REDIVERGE: <n> cells.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPORTS = ROOT / "builds" / "reports" / "lockstep"
sys.path.insert(0, str(ROOT / "tools" / "lockstep"))
sys.path.insert(0, str(ROOT / "tools" / "audit"))
import gate  # type: ignore  # noqa: E402
import diff  # type: ignore  # noqa: E402
from baseline_mismatch_report import ACCEPTED  # noqa: E402


def masked(a: int) -> bool:
    m = gate.MASKS
    try:
        return any(lo <= a <= hi for lo, hi in m)
    except TypeError:
        return a in m


def scan(d: Path) -> dict[int, int]:
    n = (d / "nes.ram").read_bytes()
    g = (d / "gen.ram").read_bytes()
    ticks = min(len(n), len(g)) // 2048
    first: dict[int, int] = {}
    for a in range(0x800):
        if masked(a) or a in ACCEPTED:
            continue
        seen_equal = False
        for t in range(ticks):
            same = n[t * 2048 + a] == g[t * 2048 + a]
            if same:
                seen_equal = True
            elif seen_equal:
                first[a] = t
                break
    return first


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("presets", nargs="*")
    ap.add_argument("--md", type=Path)
    a = ap.parse_args()
    base = ROOT / "tools" / "lockstep" / "baselines"
    names = a.presets or sorted(p.stem for p in base.glob("*.json"))
    pool: dict[int, list[tuple[int, str]]] = {}
    for name in names:
        d = REPORTS / name
        if not (d / "nes.ram").exists() or not (d / "gen.ram").exists():
            continue
        for cell, t in scan(d).items():
            pool.setdefault(cell, []).append((t, name))
    rows = ["| Cell | Name | Presets | First re-divergence (preset@tick) |", "|---|---|---|---|"]
    for cell in sorted(pool, key=lambda c: (-len(pool[c]), c)):
        hits = sorted(pool[cell])
        rows.append(f"| ${cell:04X} | {diff.name(cell)} | {len(hits)} | "
                    + ", ".join(f"{p}@{t}" for t, p in hits[:4]) + " |")
    text = "\n".join(rows)
    if a.md:
        a.md.write_text(text + "\n", encoding="utf-8")
    print(text)
    print(f"REDIVERGE: {len(pool)} cells")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
