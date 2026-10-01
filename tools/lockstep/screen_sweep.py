"""Visual byte-diff sweep: NES vs Genesis frames at settled play ticks.

    python tools/lockstep/screen_sweep.py [preset ...] [--per 6] [--jobs 6] [--md OUT]

For each gated preset (tools/lockstep/baselines/*.json, or the presets
named), pick up to --per ticks from the existing NES per-tick RAM
(builds/reports/lockstep/<preset>/nes.ram) where the screen is settled:
GameMode 5, not paused, the same room as the tick before, NES scroll 0
(screen_diff.py models only unscrolled screens). Re-run the preset with
`--snap` at those ticks, then `screen_diff.py <dir> <tick> --window-rows 7`
(gameplay HUD window) for each. Pixel differences are bug candidates; a
screenshot is never the verdict, the per-pixel CRAM-word diff is.

Output: per preset and tick, MATCH or DIFF <px> in <cells>. Verdict line
SCREENS: <n> diff / <m> checked.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPORTS = ROOT / "builds" / "reports" / "lockstep"
PRESETS = ROOT / "tools" / "lockstep" / "presets"
BASE = ROOT / "tools" / "lockstep" / "baselines"


def pick_ticks(name: str, per: int) -> list[int]:
    ram = (REPORTS / name / "nes.ram").read_bytes()
    n = len(ram) // 2048
    ok = []
    for t in range(2, n):
        r = ram[t * 2048:(t + 1) * 2048]
        p = ram[(t - 1) * 2048:t * 2048]
        if (r[0x12] == 5 and r[0x11] == 1 and r[0xE0] == 0 and r[0xE1] == 0
                and r[0xEB] == p[0xEB] and p[0x12] == 5
                and r[0xFD] == 0 and r[0xFC] == 0 and (r[0xFF] & 3) == 0):
            ok.append(t)
    if len(ok) <= per:
        return ok
    step = len(ok) / per
    return [ok[int(i * step + step / 2)] for i in range(per)]


def run_preset(name: str, per: int) -> list[str]:
    if not (REPORTS / name / "nes.ram").exists():
        return [f"| {name} | - | no report |"]
    ticks = pick_ticks(name, per)
    if not ticks:
        return [f"| {name} | - | no settled play tick |"]
    subprocess.run([sys.executable, str(ROOT / "tools/lockstep/run_lockstep.py"),
                    str(PRESETS / f"{name}.json"), "--full",
                    "--snap", ",".join(str(t) for t in ticks)],
                   capture_output=True, text=True)
    rows = []
    for t in ticks:
        out = subprocess.run([sys.executable, str(ROOT / "tools/lockstep/screen_diff.py"),
                              str(REPORTS / name), str(t), "--window-rows", "7"],
                             capture_output=True, text=True).stdout
        m = re.search(r"SCREEN: (MATCH|DIFF \d+ px in \d+ cells)", out)
        rows.append(f"| {name} | {t} | {m.group(1) if m else 'ERROR: ' + out.strip()[-80:]} |")
    return rows


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("presets", nargs="*")
    ap.add_argument("--per", type=int, default=6)
    ap.add_argument("--jobs", type=int, default=6)
    ap.add_argument("--md", type=Path)
    a = ap.parse_args()
    names = a.presets or sorted(p.stem for p in BASE.glob("*.json"))
    with ThreadPoolExecutor(a.jobs) as ex:
        results = list(ex.map(lambda nm: run_preset(nm, a.per), names))
    rows = ["| Preset | Tick | Result |", "|---|---|---|"] + [r for rs in results for r in rs]
    diffs = sum(1 for r in rows if "DIFF" in r)
    checked = sum(1 for r in rows if "MATCH" in r or "DIFF" in r)
    text = "\n".join(rows)
    if a.md:
        a.md.write_text(text + "\n", encoding="utf-8")
    print(text)
    print(f"SCREENS: {diffs} diff / {checked} checked")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
