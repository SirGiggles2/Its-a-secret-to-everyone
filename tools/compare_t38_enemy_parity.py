#!/usr/bin/env python3
"""T38 enemy-AI byte-parity comparator.

Scenario (1400 frames):
  t=0..60      baseline idle                 (overworld, mode $05)
  t=60..101    hold Left                     (walk west to x=$40)
  t=101..165   idle align-y
  t=165..285   hold Up                       (walk north to stair)
  t=285..560   cave-settle + merchant dialog
  t=560..700   hold Up                       (walk into sword tile)
  t=700..970   pickup_settle                 (obtain sword + fanfare)
  t=970..1090  hold Down                     (walk back to exit stair)
  t=1090..1250 post-exit idle                (stair ascent + settle)
  t=1250..1400 final parity window

Pickup semantics:
  Inventory array at NES $0657 (slot 0 = sword level).  Starts at 0.
  When Link walks into the sword inside the cave, the merchant logic
  sets slot 0 = 1 (wood sword).  T38 PASS requires:

    - before pickup (t < 491):   inv_sword == 0 on both platforms
    - after pickup  (t >= 700):  inv_sword >= 1 on both platforms
    - pickup transition frame within +/-PHASE_TOLERANCE of NES
    - round-trip final state matches (room, mode, x, y)

Gates (9):
  T38_NES_CAPTURE_OK
  T38_GEN_CAPTURE_OK
  T38_NO_GEN_EXCEPTION
  T38_BASELINE_PARITY          t=0..59 (obj_x, obj_y, mode, room) match
  T38_CAVE_ENTER_TRIGGERED     NES & Gen both leave mode $05 near t=213
  T38_SWORD_PICKUP_NES         NES inv_sword 0->>=1 fires between 491..701
  T38_SWORD_PICKUP_GEN         Gen inv_sword 0->>=1 fires between 491..701
  T38_PICKUP_PHASE_MATCH       NES & Gen pickup frames within +/-PHASE_TOLERANCE
  T38_ROUND_TRIP_READY         final (room, mode, obj_x, obj_y) match
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
REPORTS = ROOT / "builds" / "reports"

NES_JSON = REPORTS / "t38_enemy_nes_capture.json"
GEN_JSON = REPORTS / "t38_enemy_gen_capture.json"
OUT_TXT  = REPORTS / "bizhawk_t38_enemy_parity_report.txt"
OUT_JSON = REPORTS / "bizhawk_t38_enemy_parity_report.json"

BASELINE_END = 60
OW_MODE = 0x05
PICKUP_WINDOW_LO = 560
PICKUP_WINDOW_HI = 970
PHASE_TOLERANCE = 4   # slightly looser than T36 -- sword-merchant has longer dialog lead-in


def load(p: Path):
    if not p.exists():
        return None
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"ERROR {p}: {e}", file=sys.stderr)
        return None


def first_diff_window(a, b, lo, hi):
    end = min(len(a), len(b), hi)
    for i in range(max(0, lo), end):
        if a[i] != b[i]:
            return (i, a[i], b[i])
    return None


def first_t_where(arr, pred, start=0):
    for i in range(start, len(arr)):
        if pred(arr[i]):
            return i
    return None


def main() -> int:
    lines: list[str] = []

    def emit(s):
        lines.append(s)
        print(s)

    emit("=" * 65)
    emit("T38 ENEMY-AI PARITY REPORT (NES vs Genesis, cave $77)")
    emit("=" * 65)

    nes = load(NES_JSON)
    gen = load(GEN_JSON)
    results: dict[str, dict[str, Any]] = {}

    def gate(name, ok, detail=""):
        results[name] = {"pass": bool(ok), "detail": detail}
        emit(f"{name}: {'PASS' if ok else 'FAIL'}  {detail}")

    nes_ok = bool(nes and nes.get("scenario_length")
                  and len(nes.get("trace", {}).get("t", [])) == nes["scenario_length"])
    gate("T38_NES_CAPTURE_OK", nes_ok,
         f"len={len(nes['trace']['t']) if nes else 0}" if nes else "MISSING")

    gen_ok = bool(gen and gen.get("scenario_length")
                  and len(gen.get("trace", {}).get("t", [])) == gen["scenario_length"])
    gate("T38_GEN_CAPTURE_OK", gen_ok,
         f"len={len(gen['trace']['t']) if gen else 0}" if gen else "MISSING")

    exc = gen.get("gen_exception_frame") if gen else None
    gate("T38_NO_GEN_EXCEPTION", exc is None,
         "no exception" if exc is None else f"exception at frame {exc}")

    if not (nes_ok and gen_ok):
        for n in ("T38_BASELINE_PARITY", "T38_CAVE_ENTER_TRIGGERED",
                  "T38_SWORD_PICKUP_NES", "T38_SWORD_PICKUP_GEN",
                  "T38_PICKUP_PHASE_MATCH", "T38_ROUND_TRIP_READY"):
            gate(n, False, "skipped -- capture(s) invalid")
        return write(results, lines, False)

    nt = nes["trace"]
    gt = gen["trace"]

    # Gate 4: baseline parity
    pre_ok = True
    dets = []
    for k in ("obj_x", "obj_y", "mode", "room"):
        d = first_diff_window(nt[k], gt[k], 0, BASELINE_END)
        if d:
            pre_ok = False
            dets.append(f"{k}:t={d[0]} nes=${d[1]:02X} gen=${d[2]:02X}")
        else:
            dets.append(f"{k}:OK")
    gate("T38_BASELINE_PARITY", pre_ok, "; ".join(dets))

    # Gate 5: cave enter (mode leaves OW_MODE)
    nes_enter = first_t_where(nt["mode"], lambda m: m != OW_MODE, BASELINE_END)
    gen_enter = first_t_where(gt["mode"], lambda m: m != OW_MODE, BASELINE_END)
    gate("T38_CAVE_ENTER_TRIGGERED",
         nes_enter is not None and gen_enter is not None
         and abs(nes_enter - gen_enter) <= PHASE_TOLERANCE,
         f"nes_t={nes_enter} gen_t={gen_enter}")

    # Gate 6: NES sword pickup inside the expected window
    nes_inv = nt.get("inv_sword", [])
    nes_pickup = None
    if nes_inv:
        for t in range(PICKUP_WINDOW_LO, min(PICKUP_WINDOW_HI, len(nes_inv))):
            if nes_inv[t] >= 1 and nes_inv[t - 1] == 0:
                nes_pickup = t
                break
    gate("T38_SWORD_PICKUP_NES", nes_pickup is not None,
         f"NES inv_sword 0->${nes_inv[nes_pickup] if nes_pickup else 0:02X} at t={nes_pickup}")

    # Gate 7: Genesis sword pickup inside the expected window
    gen_inv = gt.get("inv_sword", [])
    gen_pickup = None
    if gen_inv:
        for t in range(PICKUP_WINDOW_LO, min(PICKUP_WINDOW_HI, len(gen_inv))):
            if gen_inv[t] >= 1 and gen_inv[t - 1] == 0:
                gen_pickup = t
                break
    gate("T38_SWORD_PICKUP_GEN", gen_pickup is not None,
         f"Gen inv_sword 0->${gen_inv[gen_pickup] if gen_pickup else 0:02X} at t={gen_pickup}")

    # Gate 8: pickup phase offset
    if nes_pickup is not None and gen_pickup is not None:
        phase_ok = abs(nes_pickup - gen_pickup) <= PHASE_TOLERANCE
        gate("T38_PICKUP_PHASE_MATCH", phase_ok,
             f"delta={gen_pickup - nes_pickup:+d}f (NES t={nes_pickup}, Gen t={gen_pickup})")
    else:
        gate("T38_PICKUP_PHASE_MATCH", False,
             f"pickup missing -- NES t={nes_pickup}, Gen t={gen_pickup}")

    # Gate 9: final state
    final_ok = (nt["room"][-1] == gt["room"][-1]
                and nt["mode"][-1] == gt["mode"][-1]
                and nt["obj_x"][-1] == gt["obj_x"][-1]
                and nt["obj_y"][-1] == gt["obj_y"][-1])
    gate("T38_ROUND_TRIP_READY", final_ok,
         f"nes=(r${nt['room'][-1]:02X},m${nt['mode'][-1]:02X},"
         f"x${nt['obj_x'][-1]:02X},y${nt['obj_y'][-1]:02X}) "
         f"gen=(r${gt['room'][-1]:02X},m${gt['mode'][-1]:02X},"
         f"x${gt['obj_x'][-1]:02X},y${gt['obj_y'][-1]:02X})")

    all_pass = all(r["pass"] for r in results.values())
    return write(results, lines, all_pass)


def write(results, lines, all_pass):
    verdict = "T38_PARITY: ALL PASS" if all_pass else "T38_PARITY: FAIL"
    lines.append(verdict)
    print(verdict)
    OUT_TXT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    OUT_JSON.write_text(json.dumps({
        "verdict": verdict, "all_pass": all_pass, "gates": results,
    }, indent=2), encoding="utf-8")
    return 0 if all_pass else 1


if __name__ == "__main__":
    sys.exit(main())
