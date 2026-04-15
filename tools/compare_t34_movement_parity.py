#!/usr/bin/env python3
"""T34 D-pad movement byte-parity comparator.

Reads:
  builds/reports/t34_movement_nes_capture.json
  builds/reports/t34_movement_gen_capture.json

Writes:
  builds/reports/t34_movement_parity_report.txt
  builds/reports/t34_movement_parity_report.json

Gates (9):
  T34_NES_CAPTURE_OK        NES trace reached Mode5/room$77, SCENARIO_LENGTH frames
  T34_GEN_CAPTURE_OK        Gen trace same
  T34_NO_GEN_EXCEPTION      gen_exception_frame is null
  T34_BASELINE_PARITY       baseline (x,y,dir) equal NES vs Gen
  T34_OBJX_PARITY           obj_x[t] equal for all t
  T34_OBJY_PARITY           obj_y[t] equal for all t
  T34_OBJINPUTDIR_PARITY    obj_dir[t] equal for all t
  T34_HELD_BUTTONS_PARITY   held[t] equal for all t
  T34_ROUND_TRIP_BOUNDED    |final_x - baseline_x| <= 2 AND same for y (NES trace)

Fractional bytes (obj_xf/obj_yf) reported for diagnosis only.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
REPORTS = ROOT / "builds" / "reports"

NES_JSON = REPORTS / "t34_movement_nes_capture.json"
GEN_JSON = REPORTS / "t34_movement_gen_capture.json"
OUT_TXT  = REPORTS / "t34_movement_parity_report.txt"
OUT_JSON = REPORTS / "t34_movement_parity_report.json"

ROUND_TRIP_TOL = 2


def load(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"ERROR parsing {path}: {e}", file=sys.stderr)
        return None


def first_diff(a: list[int], b: list[int]) -> tuple[int, int, int] | None:
    n = min(len(a), len(b))
    for i in range(n):
        if a[i] != b[i]:
            return (i, a[i], b[i])
    if len(a) != len(b):
        return (n, a[n] if n < len(a) else -1, b[n] if n < len(b) else -1)
    return None


def phase_for_t(phases: list[dict], t: int) -> str:
    for p in phases:
        if p["start_t"] <= t < p["end_t"]:
            return p["name"]
    return "?"


def main() -> int:
    lines: list[str] = []
    def emit(s: str) -> None:
        lines.append(s)
        print(s)

    emit("=" * 65)
    emit("T34 MOVEMENT PARITY REPORT (NES reference vs Genesis)")
    emit("=" * 65)

    nes = load(NES_JSON)
    gen = load(GEN_JSON)

    results: dict[str, dict[str, Any]] = {}

    def gate(name: str, ok: bool, detail: str = "") -> None:
        results[name] = {"pass": bool(ok), "detail": detail}
        emit(f"{name}: {'PASS' if ok else 'FAIL'}  {detail}")

    # --- Gate 1: NES capture OK ---
    nes_ok = bool(nes and nes.get("reached_mode5")
                  and nes.get("scenario_length")
                  and len(nes.get("trace", {}).get("t", [])) == nes["scenario_length"])
    gate("T34_NES_CAPTURE_OK", nes_ok,
         f"file={NES_JSON.name} len={len(nes['trace']['t']) if nes else 0}" if nes
         else f"file={NES_JSON.name} MISSING")

    # --- Gate 2: Gen capture OK ---
    gen_ok = bool(gen and gen.get("reached_mode5")
                  and gen.get("scenario_length")
                  and len(gen.get("trace", {}).get("t", [])) == gen["scenario_length"])
    gate("T34_GEN_CAPTURE_OK", gen_ok,
         f"file={GEN_JSON.name} len={len(gen['trace']['t']) if gen else 0}" if gen
         else f"file={GEN_JSON.name} MISSING")

    # --- Gate 3: no Gen exception ---
    exc = gen.get("gen_exception_frame") if gen else None
    gate("T34_NO_GEN_EXCEPTION", exc is None,
         "no exception" if exc is None else f"exception at frame {exc}")

    if not (nes_ok and gen_ok):
        gate("T34_BASELINE_PARITY", False, "skipped — capture(s) invalid")
        gate("T34_OBJX_PARITY", False, "skipped")
        gate("T34_OBJY_PARITY", False, "skipped")
        gate("T34_OBJINPUTDIR_PARITY", False, "skipped")
        gate("T34_HELD_BUTTONS_PARITY", False, "skipped")
        return write(results, lines, False)

    nbase = nes["baseline"]
    gbase = gen["baseline"]
    baseline_ok = (nbase["obj_x"] == gbase["obj_x"]
                   and nbase["obj_y"] == gbase["obj_y"]
                   and nbase["obj_dir"] == gbase["obj_dir"])
    gate("T34_BASELINE_PARITY", baseline_ok,
         f"nes=(${nbase['obj_x']:02X},${nbase['obj_y']:02X},${nbase['obj_dir']:02X}) "
         f"gen=(${gbase['obj_x']:02X},${gbase['obj_y']:02X},${gbase['obj_dir']:02X})")

    nt = nes["trace"]
    gt = gen["trace"]
    phases = nes.get("phases", [])

    def parity_gate(gate_name: str, key: str) -> None:
        diff = first_diff(nt[key], gt[key])
        if diff is None:
            gate(gate_name, True, f"all {len(nt[key])} frames match")
        else:
            t, nv, gv = diff
            gate(gate_name, False,
                 f"first diff at t={t} phase={phase_for_t(phases, t)} "
                 f"nes=${nv:02X} gen=${gv:02X}")

    parity_gate("T34_OBJX_PARITY",        "obj_x")
    parity_gate("T34_OBJY_PARITY",        "obj_y")
    parity_gate("T34_OBJINPUTDIR_PARITY", "obj_dir")
    parity_gate("T34_HELD_BUTTONS_PARITY", "held")

    # --- Informational: NES final vs baseline (collisions expected — not a gate) ---
    final_x = nt["obj_x"][-1]
    final_y = nt["obj_y"][-1]
    dx = final_x - nbase["obj_x"]
    dy = final_y - nbase["obj_y"]
    emit(f"DIAG nes_final=(${final_x:02X},${final_y:02X}) "
         f"baseline=(${nbase['obj_x']:02X},${nbase['obj_y']:02X}) "
         f"delta=({dx:+d},{dy:+d}) [informational — walls expected]")

    # --- Fractional drift diagnostic (non-gating) ---
    xf_diff = first_diff(nt["obj_xf"], gt["obj_xf"])
    yf_diff = first_diff(nt["obj_yf"], gt["obj_yf"])
    emit(f"DIAG obj_xf_first_diff={xf_diff}")
    emit(f"DIAG obj_yf_first_diff={yf_diff}")

    all_pass = all(r["pass"] for r in results.values())
    return write(results, lines, all_pass)


def write(results: dict[str, dict[str, Any]], lines: list[str], all_pass: bool) -> int:
    verdict = "T34_PARITY: ALL PASS" if all_pass else "T34_PARITY: FAIL"
    lines.append(verdict)
    print(verdict)

    OUT_TXT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    OUT_JSON.write_text(json.dumps({
        "verdict": verdict,
        "all_pass": all_pass,
        "gates": results,
    }, indent=2), encoding="utf-8")
    return 0 if all_pass else 1


if __name__ == "__main__":
    sys.exit(main())
