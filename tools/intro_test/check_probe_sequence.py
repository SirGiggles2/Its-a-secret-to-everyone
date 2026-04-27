#!/usr/bin/env python3
"""Asserts phase byte sequence in the probe CSV matches expected.

Expected progression after boot:
  PHASE_TITLE_LOAD (0)
  PHASE_TITLE_DISPLAY (1)  for ~400 frames
  PHASE_TITLE_FADEOUT (2)  for ~230 frames (14 cycles)
  PHASE_BLACK_HOLD (3)     for 180 frames
  PHASE_STORY_LOAD (4)
  PHASE_STORY_RUN (5)      for ~750+ frames
  loop to PHASE_TITLE_LOAD

The probe samples every 60 frames so transient phases (TITLE_LOAD,
STORY_LOAD) may not be captured every loop; the test allows them.

Sentinel ($07FF = $A1) confirms intro_main entered. If absent, the ROM
never reached intro_main.

Fails build with non-zero exit on mismatch.
"""
import csv
import sys
from pathlib import Path

CSV_PATH = Path("tools/intro_test/out/phase_sequence.csv")
DONE_PATH = Path("tools/intro_test/out/phase_sequence.done")

ALLOWED = {0, 1, 2, 3, 4, 5}


def main() -> int:
    if not DONE_PATH.exists():
        print(f"FAIL: {DONE_PATH} missing - probe run did not complete")
        return 1
    if not CSV_PATH.exists():
        print(f"FAIL: {CSV_PATH} missing")
        return 1

    rows = list(csv.DictReader(CSV_PATH.open()))
    if len(rows) < 30:
        print(f"FAIL: only {len(rows)} samples - expected ~133")
        return 1

    # Sentinel must be $A1 in every sample (intro_main entered, never left
    # under stable attract loop).
    for r in rows:
        s = int(r["sentinel"])
        if s != 0xA1:
            print(f"FAIL: frame {r['frame']} sentinel = {s:#x}, expected 0xA1")
            print("  intro_main may not have been reached, or RAM was overwritten")
            return 1

    # Every observed phase must be in the allowed set.
    for r in rows:
        p = int(r["phase"])
        if p not in ALLOWED:
            print(f"FAIL: frame {r['frame']} reports unknown phase {p}")
            return 1

    # We must observe at least one of each phase across the 4000-frame run.
    seen = {int(r["phase"]) for r in rows}
    for required in (1, 2, 3, 5):    # TITLE_DISPLAY, TITLE_FADEOUT, BLACK_HOLD, STORY_RUN
        if required not in seen:
            print(f"FAIL: phase {required} never observed in probe sequence")
            print("  observed phases:", sorted(seen))
            return 1

    # We must observe a loop: at least two TITLE_DISPLAY samples separated
    # by a STORY_RUN sample.
    phases = [int(r["phase"]) for r in rows]
    title_idxs = [i for i, p in enumerate(phases) if p == 1]
    story_idxs = [i for i, p in enumerate(phases) if p == 5]
    looped = any(s_i < t_i for s_i in story_idxs for t_i in title_idxs[1:])
    if not looped:
        print("FAIL: no loop - story phase never followed by title phase again")
        print("  phases:", phases)
        return 1

    print(f"OK: phase sequence valid across {len(rows)} samples; "
          f"observed {sorted(seen)}, loop confirmed, sentinel intact")
    return 0


if __name__ == "__main__":
    sys.exit(main())
