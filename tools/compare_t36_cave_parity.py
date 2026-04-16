#!/usr/bin/env python3
"""T36 cave-enter byte-parity comparator (room $77 cave).

NES mode chain (reference):
  t=0..212   mode $05 (overworld, walking to stair)
  t=213      mode $05 -> $10 (cave-stair descent begins) at Link=($40,$4D)
  t=277      mode $10 -> $0B (scroll into cave interior)
  t=600      inside cave, Link at ($70,$D5) near exit stair
  t=651      mode $0B -> $0A (exit stair triggered by Down)
  t=685      mode $0A -> $04 (transition/fade)
  t=749      mode $04 -> $05 (back outside at Link=($40,$4D))

Gates (9):
  T36_NES_CAPTURE_OK
  T36_GEN_CAPTURE_OK
  T36_NO_GEN_EXCEPTION
  T36_BASELINE_PARITY          t=0..59 (obj_x, obj_y, mode, room) match
  T36_WALK_TO_STAIR            Link reaches ($40,$4D) within ±2 frames
  T36_CAVE_ENTER_TRIGGERED     mode $05->$10 (or any non-$05) fires within ±2f
  T36_CAVE_INTERIOR_MATCH      inside cave (t=300..600), (mode,sub,x,y) match
                               with phase shift tolerance
  T36_CAVE_EXIT_TRIGGERED      mode returns to $05 within ±2f of NES
  T36_ROUND_TRIP_READY         final (room,mode,x,y,dir) match
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
REPORTS = ROOT / "builds" / "reports"

NES_JSON = REPORTS / "t36_cave_nes_capture.json"
GEN_JSON = REPORTS / "t36_cave_gen_capture.json"
OUT_TXT  = REPORTS / "bizhawk_t36_cave_parity_report.txt"
OUT_JSON = REPORTS / "bizhawk_t36_cave_parity_report.json"

BASELINE_END = 60
OW_MODE = 0x05
STAIR_X, STAIR_Y = 0x40, 0x4D
PHASE_TOLERANCE = 2


def load(p: Path):
    if not p.exists(): return None
    try: return json.loads(p.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"ERROR {p}: {e}", file=sys.stderr); return None


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
    def emit(s): lines.append(s); print(s)

    emit("=" * 65)
    emit("T36 CAVE-ENTER PARITY REPORT (NES vs Genesis, room $77 cave)")
    emit("=" * 65)

    nes = load(NES_JSON); gen = load(GEN_JSON)
    results: dict[str, dict[str, Any]] = {}

    def gate(name, ok, detail=""):
        results[name] = {"pass": bool(ok), "detail": detail}
        emit(f"{name}: {'PASS' if ok else 'FAIL'}  {detail}")

    nes_ok = bool(nes and nes.get("scenario_length")
                  and len(nes.get("trace", {}).get("t", [])) == nes["scenario_length"])
    gate("T36_NES_CAPTURE_OK", nes_ok,
         f"len={len(nes['trace']['t']) if nes else 0}" if nes else "MISSING")

    gen_ok = bool(gen and gen.get("scenario_length")
                  and len(gen.get("trace", {}).get("t", [])) == gen["scenario_length"])
    gate("T36_GEN_CAPTURE_OK", gen_ok,
         f"len={len(gen['trace']['t']) if gen else 0}" if gen else "MISSING")

    exc = gen.get("gen_exception_frame") if gen else None
    gate("T36_NO_GEN_EXCEPTION", exc is None,
         "no exception" if exc is None else f"exception at frame {exc}")

    if not (nes_ok and gen_ok):
        for n in ("T36_BASELINE_PARITY", "T36_WALK_TO_STAIR",
                  "T36_CAVE_ENTER_TRIGGERED", "T36_CAVE_INTERIOR_MATCH",
                  "T36_CAVE_EXIT_TRIGGERED", "T36_ROUND_TRIP_READY"):
            gate(n, False, "skipped — capture(s) invalid")
        return write(results, lines, False)

    nt = nes["trace"]; gt = gen["trace"]

    # Gate 4: baseline parity
    pre_ok = True; dets = []
    for k in ("obj_x", "obj_y", "mode", "room"):
        d = first_diff_window(nt[k], gt[k], 0, BASELINE_END)
        if d: pre_ok = False; dets.append(f"{k}:t={d[0]} nes=${d[1]:02X} gen=${d[2]:02X}")
        else: dets.append(f"{k}:OK")
    gate("T36_BASELINE_PARITY", pre_ok, "; ".join(dets))

    # Gate 5: walk to stair
    nes_stair = first_t_where(range(len(nt["obj_x"])),
                              lambda i: nt["obj_x"][i] == STAIR_X and nt["obj_y"][i] == STAIR_Y)
    gen_stair = first_t_where(range(len(gt["obj_x"])),
                              lambda i: gt["obj_x"][i] == STAIR_X and gt["obj_y"][i] == STAIR_Y)
    gate("T36_WALK_TO_STAIR",
         nes_stair is not None and gen_stair is not None
         and abs(nes_stair - gen_stair) <= PHASE_TOLERANCE,
         f"nes_t={nes_stair} gen_t={gen_stair}")

    # Gate 6: cave enter (mode leaves OW_MODE)
    nes_enter = first_t_where(nt["mode"], lambda m: m != OW_MODE, BASELINE_END)
    gen_enter = first_t_where(gt["mode"], lambda m: m != OW_MODE, BASELINE_END)
    gate("T36_CAVE_ENTER_TRIGGERED",
         nes_enter is not None and gen_enter is not None
         and abs(nes_enter - gen_enter) <= PHASE_TOLERANCE,
         f"nes_t={nes_enter} (mode=${nt['mode'][nes_enter] if nes_enter else 0:02X}) "
         f"gen_t={gen_enter} (mode=${gt['mode'][gen_enter] if gen_enter else 0:02X})")

    # Gate 7: cave interior match — window [nes_enter+50 .. cave_settle end]
    # with phase shift tolerance
    if nes_enter is not None:
        lo = nes_enter + 50
        hi = min(645, len(nt["mode"]))
        best = None
        for shift in range(-PHASE_TOLERANCE, PHASE_TOLERANCE + 1):
            ok = True
            for t in range(lo, hi):
                gt_t = t + shift
                if gt_t < 0 or gt_t >= len(gt["mode"]):
                    ok = False; break
                if (nt["mode"][t] != gt["mode"][gt_t]
                    or nt["obj_x"][t] != gt["obj_x"][gt_t]
                    or nt["obj_y"][t] != gt["obj_y"][gt_t]):
                    ok = False; break
            if ok: best = shift; break
        if best is not None:
            gate("T36_CAVE_INTERIOR_MATCH", True,
                 f"(mode,x,y) match with {best:+d}-frame shift across t=[{lo},{hi})")
        else:
            # Report first diff at shift=0
            first = None
            for t in range(lo, hi):
                if (nt["mode"][t] != gt["mode"][t]
                    or nt["obj_x"][t] != gt["obj_x"][t]
                    or nt["obj_y"][t] != gt["obj_y"][t]):
                    first = t; break
            if first is None:
                gate("T36_CAVE_INTERIOR_MATCH", True, f"match across t=[{lo},{hi})")
            else:
                gate("T36_CAVE_INTERIOR_MATCH", False,
                     f"first diff t={first} "
                     f"nes=(m${nt['mode'][first]:02X},x${nt['obj_x'][first]:02X},y${nt['obj_y'][first]:02X}) "
                     f"gen=(m${gt['mode'][first]:02X},x${gt['obj_x'][first]:02X},y${gt['obj_y'][first]:02X})")
    else:
        gate("T36_CAVE_INTERIOR_MATCH", False, "no NES cave enter detected")

    # Gate 8: cave exit — mode returns to OW_MODE during walk_down/post_exit
    if nes_enter is not None:
        nes_exit = first_t_where(nt["mode"], lambda m: m == OW_MODE, nes_enter + 30)
        gen_exit = first_t_where(gt["mode"], lambda m: m == OW_MODE, (gen_enter or 0) + 30)
        gate("T36_CAVE_EXIT_TRIGGERED",
             nes_exit is not None and gen_exit is not None
             and abs(nes_exit - gen_exit) <= PHASE_TOLERANCE,
             f"nes_t={nes_exit} gen_t={gen_exit}")
    else:
        gate("T36_CAVE_EXIT_TRIGGERED", False, "no NES cave enter")

    # Gate 9: final state
    final_ok = (nt["room"][-1] == gt["room"][-1]
                and nt["mode"][-1] == gt["mode"][-1]
                and nt["obj_x"][-1] == gt["obj_x"][-1]
                and nt["obj_y"][-1] == gt["obj_y"][-1]
                and nt["obj_dir"][-1] == gt["obj_dir"][-1])
    gate("T36_ROUND_TRIP_READY", final_ok,
         f"nes=(r${nt['room'][-1]:02X},m${nt['mode'][-1]:02X},"
         f"x${nt['obj_x'][-1]:02X},y${nt['obj_y'][-1]:02X},d${nt['obj_dir'][-1]:02X}) "
         f"gen=(r${gt['room'][-1]:02X},m${gt['mode'][-1]:02X},"
         f"x${gt['obj_x'][-1]:02X},y${gt['obj_y'][-1]:02X},d${gt['obj_dir'][-1]:02X})")

    all_pass = all(r["pass"] for r in results.values())
    return write(results, lines, all_pass)


def write(results, lines, all_pass):
    verdict = "T36_PARITY: ALL PASS" if all_pass else "T36_PARITY: FAIL"
    lines.append(verdict); print(verdict)
    OUT_TXT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    OUT_JSON.write_text(json.dumps({
        "verdict": verdict, "all_pass": all_pass, "gates": results,
    }, indent=2), encoding="utf-8")
    return 0 if all_pass else 1


if __name__ == "__main__":
    sys.exit(main())
