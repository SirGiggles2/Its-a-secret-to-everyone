"""Run every lockstep preset (or a subset) in parallel and archive the results.

    python tools/lockstep/run_suite.py <tag> [--jobs N] [--only NAME ...]
           [--full] [--no-cache]

Each preset runs through run_lockstep.py (cached NES, Genesis with
fail-fast, then the gate) in its own process; N presets run at once
(default cpu_count - 2), longest first (wall time of the previous suite
run, build/lockstep_cache/durations.json) so the tail stays short.
Results are copied to %TEMP%/claude/suite/<tag>/<preset>/ (RAM traces,
dumps, snapshots, text logs) and one GATE line per preset is written to
verdicts.txt, in preset order. Exit 1 when any preset fails the gate.
--full / --no-cache pass through to run_lockstep.py.
BizHawk runs on the hidden probe desktop (tools/debug/run_probe.py), so
nothing takes the user's screen focus.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PRESETS = ROOT / "tools" / "lockstep" / "presets"
REPORTS = ROOT / "builds" / "reports" / "lockstep"
DURATIONS = ROOT / "build" / "lockstep_cache" / "durations.json"
KEEP = ["diff.json", "diff.txt", "gen.txt", "nes.txt", "gen.err", "nes.err",
        "gen.ram", "nes.ram", "gen.vram", "gen.m68k", "gen.cram", "gen.vsram",
        "nes.wram", "nes.nt", "nes.oam", "nes.chr", "nes.pal",
        # T-136: per-video-frame rows + their tick index (lag analysis)
        "gen.fram", "nes.fram", "gen.frtick", "nes.frtick",
        # T-141: NES cache record, padded ticks
        "nes.cache", "gen.pad", "nes.pad"]


def run_one(name: str, out: Path, extra: list[str]) -> tuple[str, float]:
    t0 = time.time()
    r = subprocess.run([sys.executable, str(ROOT / "tools" / "lockstep" / "run_lockstep.py"),
                        str(PRESETS / f"{name}.json"), *extra],
                       cwd=ROOT, capture_output=True, text=True)
    lines = r.stdout.splitlines()
    verdict = next((l for l in reversed(lines) if l.startswith("GATE:")), None)
    if verdict is None:
        err = next((l for l in reversed(lines) if l.startswith("ERROR")), "")
        verdict = f"GATE: ERROR (exit {r.returncode}) {err}"
    dst = out / name
    dst.mkdir(parents=True, exist_ok=True)
    for f in KEEP:
        src = REPORTS / name / f
        if src.exists():
            shutil.copy2(src, dst / f)
    for src in (REPORTS / name).glob("*.f[0-9]*"):   # tick snapshots (fail-fast, --snap)
        shutil.copy2(src, dst / src.name)
    return f"{name} :: {verdict}", time.time() - t0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("tag")
    ap.add_argument("--jobs", type=int, default=max(1, (os.cpu_count() or 4) - 2))
    ap.add_argument("--only", nargs="*")
    ap.add_argument("--full", action="store_true")
    ap.add_argument("--no-cache", action="store_true")
    a = ap.parse_args()
    extra = (["--full"] if a.full else []) + (["--no-cache"] if a.no_cache else [])
    names = sorted(p.stem for p in PRESETS.glob("*.json"))
    if a.only:
        names = [n for n in names if n in a.only]
    out = Path(os.path.expandvars(r"%TEMP%")) / "claude" / "suite" / a.tag
    out.mkdir(parents=True, exist_ok=True)
    try:
        dur = json.loads(DURATIONS.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        dur = {}
    t0 = time.time()
    with ThreadPoolExecutor(max_workers=a.jobs) as ex:
        futs = {n: ex.submit(run_one, n, out, extra)
                for n in sorted(names, key=lambda n: -dur.get(n, 1e9))}
        res = {n: f.result() for n, f in futs.items()}
    lines = [res[n][0] for n in names]
    dur.update({n: round(res[n][1], 1) for n in names})
    DURATIONS.parent.mkdir(parents=True, exist_ok=True)
    DURATIONS.write_text(json.dumps(dur, indent=1, sort_keys=True) + "\n", encoding="utf-8")
    bad = sum(1 for l in lines if "GATE: PASS" not in l)
    lines.append(f"TOTAL {len(names) - bad}/{len(names)} PASS  wall {time.time() - t0:.0f}s  jobs {a.jobs}")
    (out / "verdicts.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
