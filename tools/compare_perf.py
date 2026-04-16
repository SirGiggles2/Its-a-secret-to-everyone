#!/usr/bin/env python3
"""Perf regression comparator for Phase 0 harness.

Reads:
  builds/reports/perf_baseline.json  (reference — committed, rebuild manually)
  builds/reports/perf_sample.json    (current run)

Writes:
  builds/reports/perf_report.txt
  builds/reports/perf_report.json

Gates:
  PERF_SAMPLE_OK         current sample reached scenario end (all 361 frames)
  PERF_CYCLE_API_OK      emu.totalexecutedcycles() available on this core
                         (WARN-only if absent — wall_ms fallback still works)
  PERF_NO_REGRESS_MEAN   mean cycles_delta <= baseline * 1.02
  PERF_NO_REGRESS_P99    p99 cycles_delta <= baseline * 1.05
  PERF_WALL_NO_REGRESS   mean wall_ms <= baseline * 1.02

Exit code = failing gate count.

Bootstrap: if perf_baseline.json does not exist, copy current perf_sample.json
to baseline and exit 0 with WARN banner. First run establishes baseline.
"""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent.parent
REPORTS = ROOT / "builds" / "reports"

BASELINE_JSON = REPORTS / "perf_baseline.json"
CURRENT_JSON  = REPORTS / "perf_sample.json"
OUT_TXT       = REPORTS / "perf_report.txt"
OUT_JSON      = REPORTS / "perf_report.json"

MEAN_TOL = 1.02   # +2%
P99_TOL  = 1.05   # +5%
WALL_TOL = 1.02   # +2%


def load(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as e:
        print(f"ERROR parsing {path}: {e}", file=sys.stderr)
        return None


def pct_delta(cur: float, base: float) -> float:
    if base == 0:
        return 0.0
    return (cur - base) / base * 100.0


def main() -> int:
    lines: list[str] = []

    def emit(s: str) -> None:
        lines.append(s)
        print(s)

    emit("=" * 65)
    emit("PERF REGRESSION REPORT")
    emit("=" * 65)

    cur = load(CURRENT_JSON)
    if cur is None:
        emit(f"FATAL: {CURRENT_JSON.name} missing. Run bizhawk_perf_sample.lua first.")
        OUT_TXT.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return 1

    base = load(BASELINE_JSON)
    if base is None:
        emit(f"WARN: {BASELINE_JSON.name} missing — bootstrapping baseline from current sample.")
        shutil.copy(CURRENT_JSON, BASELINE_JSON)
        base = cur
        emit("Baseline committed. Rerun after code changes to detect regressions.")

    gates: dict[str, bool] = {}

    # PERF_SAMPLE_OK
    cur_len = cur.get("samples_collected", 0)
    scenario_len = cur.get("scenario_length", 361)
    gates["PERF_SAMPLE_OK"] = cur_len >= scenario_len
    emit(f"PERF_SAMPLE_OK: {cur_len}/{scenario_len} frames " +
         ("PASS" if gates["PERF_SAMPLE_OK"] else "FAIL"))

    # PERF_CYCLE_API_OK (warn-only)
    cycle_api = cur.get("cycle_api_available", False)
    gates["PERF_CYCLE_API_OK"] = cycle_api
    emit(f"PERF_CYCLE_API_OK: emu.totalexecutedcycles available = {cycle_api} " +
         ("PASS" if cycle_api else "WARN (wall_ms only)"))

    # Cycle metrics
    c_mean_cur  = cur.get("cycles_delta_mean", 0.0)
    c_p99_cur   = cur.get("cycles_delta_p99", 0)
    c_mean_base = base.get("cycles_delta_mean", 0.0)
    c_p99_base  = base.get("cycles_delta_p99", 0)

    mean_pct = pct_delta(c_mean_cur, c_mean_base)
    p99_pct  = pct_delta(c_p99_cur, c_p99_base)

    # Gates only meaningful if cycle API available
    if cycle_api and c_mean_base > 0:
        gates["PERF_NO_REGRESS_MEAN"] = c_mean_cur <= c_mean_base * MEAN_TOL
        gates["PERF_NO_REGRESS_P99"]  = c_p99_cur  <= c_p99_base  * P99_TOL
    else:
        gates["PERF_NO_REGRESS_MEAN"] = True  # skip — no cycle data
        gates["PERF_NO_REGRESS_P99"]  = True

    emit(f"cycles_delta_mean: current={c_mean_cur:.1f} baseline={c_mean_base:.1f} " +
         f"delta={mean_pct:+.2f}%")
    emit(f"cycles_delta_p99:  current={c_p99_cur} baseline={c_p99_base} " +
         f"delta={p99_pct:+.2f}%")
    emit(f"PERF_NO_REGRESS_MEAN: {'PASS' if gates['PERF_NO_REGRESS_MEAN'] else 'FAIL'} " +
         f"(tolerance +{(MEAN_TOL-1)*100:.0f}%)")
    emit(f"PERF_NO_REGRESS_P99:  {'PASS' if gates['PERF_NO_REGRESS_P99']  else 'FAIL'} " +
         f"(tolerance +{(P99_TOL-1)*100:.0f}%)")

    # Wall metric (always available)
    w_mean_cur  = cur.get("wall_ms_mean", 0.0)
    w_mean_base = base.get("wall_ms_mean", 0.0)
    wall_pct = pct_delta(w_mean_cur, w_mean_base)

    if w_mean_base > 0:
        gates["PERF_WALL_NO_REGRESS"] = w_mean_cur <= w_mean_base * WALL_TOL
    else:
        gates["PERF_WALL_NO_REGRESS"] = True

    emit(f"wall_ms_mean: current={w_mean_cur:.3f} baseline={w_mean_base:.3f} " +
         f"delta={wall_pct:+.2f}%")
    emit(f"PERF_WALL_NO_REGRESS: {'PASS' if gates['PERF_WALL_NO_REGRESS'] else 'FAIL'} " +
         f"(tolerance +{(WALL_TOL-1)*100:.0f}%)")

    # Final tally
    fail_count = sum(1 for v in gates.values() if not v)
    emit("")
    emit(f"PERF_REPORT: {len(gates) - fail_count}/{len(gates)} PASS, {fail_count} FAIL")

    OUT_TXT.write_text("\n".join(lines) + "\n", encoding="utf-8")

    report = {
        "gates": gates,
        "fail_count": fail_count,
        "metrics": {
            "cycles_mean_current": c_mean_cur,
            "cycles_mean_baseline": c_mean_base,
            "cycles_mean_delta_pct": mean_pct,
            "cycles_p99_current": c_p99_cur,
            "cycles_p99_baseline": c_p99_base,
            "cycles_p99_delta_pct": p99_pct,
            "wall_mean_current": w_mean_cur,
            "wall_mean_baseline": w_mean_base,
            "wall_mean_delta_pct": wall_pct,
        },
        "tolerances": {
            "mean": MEAN_TOL,
            "p99": P99_TOL,
            "wall": WALL_TOL,
        },
    }
    OUT_JSON.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    return fail_count


if __name__ == "__main__":
    sys.exit(main())
