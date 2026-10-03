"""T-172 lag gate: frame-dump runs of the busiest presets, then lag_scan
with the frame-budget margin check.

    python tools/lockstep/lag_gate.py [--budget 0xD8] [preset ...]

Default presets are the scenes that ran closest to the frame budget (busy
rooms, boss fights, loads, death, pause). Verdict line: LAG: PASS / FAIL.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
BUSY = ["t013_route", "t171_patra_sword", "t171_patra_blue", "t171_manhandla_sword",
        "t171_gleeok_sword", "t171_boss_l8", "t013_continue", "t097_death",
        "t050_rock_push", "t111_dark_candle", "t171_flute_pond", "t013_save"]


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("presets", nargs="*")
    ap.add_argument("--budget", default="0xE0")
    ap.add_argument("--rom", type=Path, help="use a frozen ROM for every capture")
    ap.add_argument("--report-suffix", default="",
                    help="isolate reports from other agents' captures")
    a = ap.parse_args(argv)
    names = a.presets or BUSY
    if not names:
        print("LAG: FAIL (zero requested cases)")
        return 1
    failures = []
    for n in names:
        command = [sys.executable, str(HERE / "run_lockstep.py"),
                   str(HERE / "presets" / f"{n}.json"), "--full", "--frame-dump"]
        if a.rom:
            command.extend(["--rom", str(a.rom)])
        if a.report_suffix:
            command.extend(["--report-suffix", a.report_suffix])
        r = subprocess.run(command,
                           capture_output=True, text=True)
        print(f"{n}: run rc={r.returncode}")
        if r.returncode != 0:
            failures.append(n)
            for line in ((r.stdout or "") + "\n" + (r.stderr or "")).strip().splitlines()[-12:]:
                print(f"  {line}")
    # A complete old trace (or a RAM gate failure with complete new traces)
    # must never become acceptance through a successful timing-only scan.
    if failures:
        print(f"LAG: FAIL ({len(failures)} capture/gate failures: {', '.join(failures)})")
        return 1
    reports = [n + a.report_suffix for n in names]
    return subprocess.run([sys.executable, str(HERE / "lag_scan.py"), *reports,
                           "--budget", a.budget]).returncode


if __name__ == "__main__":
    raise SystemExit(main())
