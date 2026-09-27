"""Run every lockstep preset (or a subset) in parallel and archive the results.

    python tools/lockstep/run_suite.py <tag> [--jobs N] [--only NAME ...]

Each preset runs through run_lockstep.py (NES, then Genesis, then the diff)
in its own process; N presets run at once (default 3). Results are copied to
%TEMP%/claude/suite/<tag>/<preset>/ (RAM traces, dumps, text logs) and one
VERDICT line per preset is written to verdicts.txt, in preset order.
BizHawk runs on the hidden probe desktop (tools/debug/run_probe.py), so
nothing takes the user's screen focus.
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PRESETS = ROOT / "tools" / "lockstep" / "presets"
REPORTS = ROOT / "builds" / "reports" / "lockstep"
KEEP = ["diff.json", "diff.txt", "gen.txt", "nes.txt", "gen.err", "nes.err",
        "gen.ram", "nes.ram", "gen.vram", "gen.m68k", "gen.cram", "gen.vsram",
        "nes.wram", "nes.nt", "nes.oam", "nes.chr", "nes.pal",
        # T-136: per-video-frame rows + their tick index (lag analysis)
        "gen.fram", "nes.fram", "gen.frtick", "nes.frtick"]


def run_one(name: str, out: Path) -> str:
    r = subprocess.run([sys.executable, str(ROOT / "tools" / "lockstep" / "run_lockstep.py"),
                        str(PRESETS / f"{name}.json")],
                       cwd=ROOT, capture_output=True, text=True)
    verdict = next((l for l in reversed(r.stdout.splitlines()) if "VERDICT" in l),
                   f"VERDICT: ERROR (exit {r.returncode})")
    dst = out / name
    dst.mkdir(parents=True, exist_ok=True)
    for f in KEEP:
        src = REPORTS / name / f
        if src.exists():
            shutil.copy2(src, dst / f)
    return f"{name} :: {verdict}"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("tag")
    ap.add_argument("--jobs", type=int, default=3)
    ap.add_argument("--only", nargs="*")
    a = ap.parse_args()
    names = sorted(p.stem for p in PRESETS.glob("*.json"))
    if a.only:
        names = [n for n in names if n in a.only]
    out = Path(os.path.expandvars(r"%TEMP%")) / "claude" / "suite" / a.tag
    out.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=a.jobs) as ex:
        lines = list(ex.map(lambda n: run_one(n, out), names))
    (out / "verdicts.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
