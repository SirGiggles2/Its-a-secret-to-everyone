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

from capture_evidence import completed_ticks

ROOT = Path(__file__).resolve().parents[2]
REPORTS = ROOT / "builds" / "reports" / "lockstep"
PRESETS = ROOT / "tools" / "lockstep" / "presets"
BASE = ROOT / "tools" / "lockstep" / "baselines"


def pick_ticks(name: str, per: int) -> list[int]:
    completed_ticks(REPORTS / name, "nes")
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
    try:
        ticks = pick_ticks(name, per)
    except (OSError, ValueError) as e:
        return [f"| {name} | - | ERROR: {e} |"]
    if not ticks:
        return [f"| {name} | - | no settled play tick |"]
    run = subprocess.run([sys.executable, str(ROOT / "tools/lockstep/run_lockstep.py"),
                    str(PRESETS / f"{name}.json"), "--full",
                    "--snap", ",".join(str(t) for t in ticks)],
                   capture_output=True, text=True)
    if run.returncode:
        return [f"| {name} | - | ERROR: capture failed ({run.returncode}) |"]
    try:
        for platform in ("nes", "gen"):
            completed_ticks(REPORTS / name, platform)
    except (OSError, ValueError) as e:
        return [f"| {name} | - | ERROR: {e} |"]
    rows = []
    for t in ticks:
        out = subprocess.run([sys.executable, str(ROOT / "tools/lockstep/screen_diff.py"),
                              str(REPORTS / name), str(t), "--window-rows", "7"],
                             capture_output=True, text=True).stdout
        m = re.search(r"SCREEN: (MATCH|DIFF \d+ px in \d+ cells)", out)
        o = re.search(r"OVERLAP: (\d+) px", out)
        res = m.group(1) if m else 'ERROR: ' + out.strip()[-80:]
        if m and o:
            res += f" ({o.group(1)} px sprite overlap)"
        rows.append(f"| {name} | {t} | {res} |")
    return rows


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("presets", nargs="*")
    ap.add_argument("--per", type=int, default=6)
    ap.add_argument("--jobs", type=int, default=6)
    ap.add_argument("--md", type=Path)
    a = ap.parse_args()
    if a.per <= 0 or a.jobs <= 0:
        ap.error("--per and --jobs must be positive")
    names = a.presets or sorted(p.stem for p in BASE.glob("*.json"))
    with ThreadPoolExecutor(a.jobs) as ex:
        results = list(ex.map(lambda nm: run_preset(nm, a.per), names))
    rows = ["| Preset | Tick | Result |", "|---|---|---|"] + [r for rs in results for r in rs]
    diffs = sum(1 for r in rows if "DIFF" in r)
    checked = sum(1 for r in rows if "MATCH" in r or "DIFF" in r)
    errors = sum(1 for r in rows if "ERROR:" in r)
    if not checked:
        errors += 1
        rows.append("| - | - | ERROR: no screens checked |")
    text = "\n".join(rows)
    if a.md:
        a.md.write_text(text + "\n", encoding="utf-8")
    print(text)
    print(f"SCREENS: {diffs} diff / {checked} checked / {errors} errors")
    # Pixel differences are triage candidates (including accepted OAM
    # overlap), not automatic game failures. Missing evidence is an error.
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
