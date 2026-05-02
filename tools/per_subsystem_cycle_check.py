#!/usr/bin/env python3
"""
tools/per_subsystem_cycle_check.py
=====================================
Workstream F — Per-Subsystem Cycle Budget Checker.

Reads cycle budgets from builds/reports/perf/genesis_budget_baseline.md,
reads recent perf measurements from builds/reports/perf/<phase>_<scene>.json,
compares each subsystem's current cycles against its budget envelope, and
reports violations.

Required green in the phase close gate from Phase 6 onward
(master plan Workstream F + debate 002 hybrid, Phase Close Gate step 7).

Exit codes:
    0  All measured subsystems are within their budget envelope.
    1  One or more subsystems exceeded their budget.

Usage:
    python tools/per_subsystem_cycle_check.py
    python tools/per_subsystem_cycle_check.py --phase 6
    python tools/per_subsystem_cycle_check.py --scene uw_l1_room0
    python tools/per_subsystem_cycle_check.py --quiet
    python tools/per_subsystem_cycle_check.py --list-budgets
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parent.parent

PERF_DIR = REPO_ROOT / "builds" / "reports" / "perf"

# Budget baseline: checked in under docs/audit/ (source-controlled).
# Falls back to builds/reports/perf/ for backward compat (that path is gitignored).
_BUDGET_IN_DOCS = REPO_ROOT / "docs" / "audit" / "genesis_budget_baseline.md"
_BUDGET_IN_PERF = PERF_DIR / "genesis_budget_baseline.md"
BUDGET_BASELINE_MD = _BUDGET_IN_DOCS if _BUDGET_IN_DOCS.exists() else _BUDGET_IN_PERF

# ---------------------------------------------------------------------------
# Budget parser
# ---------------------------------------------------------------------------

# Canonical subsystem order (must stay in sync with genesis_budget_baseline.md)
CANONICAL_SUBSYSTEMS = [
    "cpu_frame",
    "vblank",
    "dma_queue",
    "sat",
    "sprite_count",
    "vram_upload",
    "cram_writes",
    "audio_tick",
]


def parse_budget_baseline(path: Path) -> dict[str, dict]:
    """
    Parse genesis_budget_baseline.md and return a dict keyed by subsystem name.
    Each entry:
        {
          "budget_cycles": int or None,  # None = TBD
          "baseline_cycles": int or None,
          "note": str,
        }

    Expected table format in the Markdown:
        | subsystem | baseline_cycles | budget_cycles | note |
        |-----------|-----------------|---------------|------|
        | cpu_frame | TBD             | TBD           | ...  |
    """
    if not path.exists():
        return {}

    budgets: dict[str, dict] = {}
    in_table = False

    for line in path.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if not stripped.startswith("|"):
            in_table = False
            continue

        # Detect header row
        cols = [c.strip() for c in stripped.split("|") if c.strip()]
        if not cols:
            continue

        if "subsystem" in cols[0].lower() and "baseline" in (cols[1].lower() if len(cols) > 1 else ""):
            in_table = True
            continue

        # Skip separator rows
        if all(c.replace("-", "").replace(":", "") == "" for c in cols):
            continue

        if in_table and len(cols) >= 2:
            subsystem = cols[0].lower().replace(" ", "_").replace("-", "_")
            baseline_raw = cols[1] if len(cols) > 1 else "TBD"
            budget_raw = cols[2] if len(cols) > 2 else "TBD"
            note = cols[3] if len(cols) > 3 else ""

            def _parse_int_or_none(s: str):
                s = s.strip()
                if s.upper() in ("TBD", "N/A", "", "-"):
                    return None
                # Strip commas / underscores for readability
                s_clean = s.replace(",", "").replace("_", "").replace("~", "")
                try:
                    return int(s_clean)
                except ValueError:
                    return None

            budgets[subsystem] = {
                "budget_cycles": _parse_int_or_none(budget_raw),
                "baseline_cycles": _parse_int_or_none(baseline_raw),
                "note": note,
            }

    return budgets


# ---------------------------------------------------------------------------
# Perf measurement loader
# ---------------------------------------------------------------------------

def discover_perf_jsons(phase: str = None, scene: str = None) -> list[Path]:
    """
    Find builds/reports/perf/<phase>_<scene>.json files.
    If phase is given, filter to files starting with that phase prefix.
    If scene is given, filter to files containing that scene substring.
    """
    if not PERF_DIR.exists():
        return []

    perf_files = sorted(PERF_DIR.glob("*.json"))
    results = []
    for p in perf_files:
        stem = p.stem
        if phase and not stem.startswith(f"phase{phase}_") and not stem.startswith(f"{phase}_"):
            continue
        if scene and scene not in stem:
            continue
        results.append(p)
    return results


def load_perf_json(path: Path) -> dict:
    """
    Load a perf measurement JSON file.
    Expected format (any key subset is accepted):
        {
          "phase": "6",
          "scene": "uw_l1_room0",
          "subsystems": {
            "cpu_frame": 12345,
            "vblank": 3200,
            ...
          }
        }
    Also accepts the legacy flat format where subsystem names are top-level keys.
    """
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as e:
        print(f"WARNING: Could not load {path}: {e}", file=sys.stderr)
        return {}

    # Normalize to subsystems sub-dict
    if "subsystems" in data and isinstance(data["subsystems"], dict):
        return data

    # Flat format: treat all int-valued keys as subsystem measurements
    subsystems = {}
    for k, v in data.items():
        if k in ("phase", "scene", "timestamp", "builder_version", "notes"):
            continue
        if isinstance(v, (int, float)):
            subsystems[k.lower().replace(" ", "_").replace("-", "_")] = int(v)

    return {
        "phase": data.get("phase", path.stem.split("_")[0]),
        "scene": data.get("scene", path.stem),
        "subsystems": subsystems,
    }


# ---------------------------------------------------------------------------
# Comparison logic
# ---------------------------------------------------------------------------

def check_subsystem(
    name: str,
    measured: int,
    budget_entry: dict,
) -> dict:
    """
    Compare a measured cycle count against the budget.

    Returns:
        {
          "subsystem": name,
          "measured": measured,
          "budget": int or None,
          "verdict": "GREEN" | "RED" | "SKIP",
          "note": str,
        }
    """
    budget = budget_entry.get("budget_cycles")
    baseline = budget_entry.get("baseline_cycles")

    if budget is None:
        # Budget not yet established — warn but don't fail
        note = "budget TBD (Phase 15.2 will fill this in)"
        return {
            "subsystem": name,
            "measured": measured,
            "budget": None,
            "baseline": baseline,
            "verdict": "SKIP",
            "note": note,
        }

    if measured <= budget:
        pct = round(100.0 * measured / budget, 1) if budget > 0 else 0.0
        return {
            "subsystem": name,
            "measured": measured,
            "budget": budget,
            "baseline": baseline,
            "verdict": "GREEN",
            "note": f"{measured} <= {budget} ({pct}% of budget)",
        }

    overage = measured - budget
    pct = round(100.0 * measured / budget, 1) if budget > 0 else 0.0
    return {
        "subsystem": name,
        "measured": measured,
        "budget": budget,
        "baseline": baseline,
        "verdict": "RED",
        "note": f"{measured} > {budget} (over by {overage}, {pct}% of budget)",
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Workstream F — Per-Subsystem Cycle Budget Checker. "
            "Compares recent perf measurements against genesis_budget_baseline.md. "
            "Required green in phase close gate from Phase 6 onward."
        )
    )
    parser.add_argument(
        "--phase",
        help="Filter to perf files from this phase (e.g. --phase 6).",
    )
    parser.add_argument(
        "--scene",
        help="Filter to perf files for this scene substring (e.g. --scene uw_l1_room0).",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="Emit only the verdict line.",
    )
    parser.add_argument(
        "--list-budgets",
        action="store_true",
        help="Print parsed budget table and exit.",
    )
    args = parser.parse_args()

    # ── Load budgets ──────────────────────────────────────────────────────────
    budgets = parse_budget_baseline(BUDGET_BASELINE_MD)

    if args.list_budgets:
        if not budgets:
            print(f"No budgets found in {BUDGET_BASELINE_MD}")
            print("(Phase 15.2 fills in the budget values.)")
            return 0
        print(f"Budgets from {BUDGET_BASELINE_MD}:")
        for name, entry in sorted(budgets.items()):
            baseline = entry['baseline_cycles']
            budget = entry['budget_cycles']
            print(f"  {name:<25} baseline={baseline or 'TBD':<10} budget={budget or 'TBD':<10} | {entry.get('note', '')}")
        return 0

    # ── Discover perf JSON files ──────────────────────────────────────────────
    perf_files = discover_perf_jsons(phase=args.phase, scene=args.scene)

    if not perf_files:
        msg = "No perf measurement files found"
        if args.phase:
            msg += f" for phase {args.phase}"
        if args.scene:
            msg += f" for scene {args.scene}"
        msg += f" in {PERF_DIR}"
        if not args.quiet:
            print(f"INFO: {msg}. Cycle check is vacuously GREEN.")
            print("(Run the Genesis probe scripts to populate builds/reports/perf/*.json)")
        else:
            print(f"cycle_check SKIP (no perf data) | GREEN (vacuous)")
        return 0

    # ── Check each file ───────────────────────────────────────────────────────
    all_results: list[dict] = []
    file_summaries: list[str] = []

    for perf_path in perf_files:
        perf_data = load_perf_json(perf_path)
        measured_subsystems = perf_data.get("subsystems", {})
        phase_label = perf_data.get("phase", "?")
        scene_label = perf_data.get("scene", perf_path.stem)

        file_results = []
        for subsystem, measured_cycles in measured_subsystems.items():
            key = subsystem.lower().replace(" ", "_").replace("-", "_")
            if key not in budgets:
                # Unknown subsystem — not in baseline, warn but don't fail
                file_results.append({
                    "subsystem": subsystem,
                    "measured": measured_cycles,
                    "budget": None,
                    "baseline": None,
                    "verdict": "SKIP",
                    "note": "subsystem not in genesis_budget_baseline.md",
                })
                continue
            result = check_subsystem(subsystem, measured_cycles, budgets[key])
            file_results.append(result)

        all_results.extend(file_results)

        green = sum(1 for r in file_results if r["verdict"] == "GREEN")
        red = sum(1 for r in file_results if r["verdict"] == "RED")
        skip = sum(1 for r in file_results if r["verdict"] == "SKIP")
        file_summaries.append(
            f"  phase={phase_label} scene={scene_label}: "
            f"GREEN={green} RED={red} SKIP={skip}"
        )

    # ── Report ────────────────────────────────────────────────────────────────
    total_green = sum(1 for r in all_results if r["verdict"] == "GREEN")
    total_red = sum(1 for r in all_results if r["verdict"] == "RED")
    total_skip = sum(1 for r in all_results if r["verdict"] == "SKIP")
    overall = "GREEN" if total_red == 0 else "RED"

    if args.quiet:
        print(
            f"cycle_check | {overall} | "
            f"green={total_green} red={total_red} skip={total_skip}"
        )
        return 1 if total_red > 0 else 0

    print(f"Per-Subsystem Cycle Budget Check")
    print(f"Budget baseline: {BUDGET_BASELINE_MD}")
    print(f"Perf files checked: {len(perf_files)}")
    print()

    for line in file_summaries:
        print(line)
    print()

    if total_red > 0:
        print("BUDGET EXCEEDED (unexpected):")
        for r in all_results:
            if r["verdict"] == "RED":
                print(f"  FAIL  {r['subsystem']}: {r['note']}")
        print()

    if total_skip > 0:
        print("SKIPPED (budget TBD or unknown subsystem):")
        for r in all_results:
            if r["verdict"] == "SKIP":
                print(f"  SKIP  {r['subsystem']}: {r['note']}")
        print()

    if total_green > 0 and not total_red:
        print("All measured subsystems within budget:")
        for r in all_results:
            if r["verdict"] == "GREEN":
                print(f"  OK    {r['subsystem']}: {r['note']}")
        print()

    print(
        f"Overall: {overall} | "
        f"GREEN={total_green} RED={total_red} SKIP={total_skip}"
    )

    if total_red == 0 and total_green == 0:
        print(
            "\nNOTE: No budgets are established yet (all TBD). "
            "Phase 15.2 fills in genesis_budget_baseline.md."
        )
        print(
            "This check becomes mandatory from Phase 6 onward "
            "(master plan Workstream F + debate 002 hybrid, Phase Close Gate step 7)."
        )

    return 1 if total_red > 0 else 0


if __name__ == "__main__":
    sys.exit(main())
