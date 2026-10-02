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


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("presets", nargs="*")
    ap.add_argument("--budget", default="0xE0")
    a = ap.parse_args()
    names = a.presets or BUSY
    for n in names:
        r = subprocess.run([sys.executable, str(HERE / "run_lockstep.py"),
                            str(HERE / "presets" / f"{n}.json"), "--full", "--frame-dump"],
                           capture_output=True, text=True)
        print(f"{n}: run rc={r.returncode}")
    return subprocess.run([sys.executable, str(HERE / "lag_scan.py"), *names,
                           "--budget", a.budget]).returncode


if __name__ == "__main__":
    raise SystemExit(main())
