#!/usr/bin/env python3
"""Verify Phase 3 cave + Phase 4 dispatcher RoomRom-runtime parity.

Per Codex parity audit (debate roomrom-default-rule, 2026-05-04 ACTION 4):
both phases closed on drain-only evidence (Gate 1 NES asm match per
tools/audit/drain_findings/{3_*,4_*}.md). Gate 2 (per-RAM-cell parity
oracle trace) and Gate 3 (per-scenario oracle) were skipped. RoomRom links
the new dispatchers but never ran an integration probe to verify they
actually run and produce expected state.

This gate closes the Gate 2 hole at the RoomRom-vs-RoomRom regression
level: each probe run is diffed against a checked-in baseline. If
dispatcher-visible WRAM or CRAM diverges from the baseline across the
4 captured scenarios, the gate fails.

Gate 3 (RoomRom-vs-NES diff) is a future enhancement — needs paired NES
ROM captures via the NES capture harness from Phase 1.5.

Usage:
    python tools/parity/check_phase34_dispatchers.py            # verify
    python tools/parity/check_phase34_dispatchers.py --bootstrap  # write baseline

Workflow:
    1. Build RoomRom (cmd /c RoomRom\\build.bat).
    2. Launch BizHawk with RoomRom\\out\\Debug.md and run
       RoomRom\\tools\\probe_phase34_dispatchers.lua. Output:
       build\\probes\\ph34\\dispatchers.json.
    3. First run: this script with --bootstrap to record
       build\\probes\\ph34\\baseline.json.
    4. Subsequent runs: this script (no flag) verifies probe output
       against baseline. Failure means a RoomRom commit changed
       dispatcher state — investigate, then either fix or rebaseline.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
PROBE_DIR = REPO_ROOT / "build" / "probes" / "ph34"
PROBE_OUT = PROBE_DIR / "dispatchers.json"
BASELINE = PROBE_DIR / "baseline.json"


def load_json(path: Path) -> dict | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def diff_scenarios(actual: dict, expected: dict) -> list[str]:
    fails: list[str] = []
    a_scen = {s["name"]: s for s in actual.get("scenarios", [])}
    e_scen = {s["name"]: s for s in expected.get("scenarios", [])}

    missing = set(e_scen) - set(a_scen)
    extra = set(a_scen) - set(e_scen)
    for name in sorted(missing):
        fails.append(f"missing scenario: {name}")
    for name in sorted(extra):
        fails.append(f"extra scenario: {name}")

    for name in sorted(set(a_scen) & set(e_scen)):
        a = a_scen[name]
        e = e_scen[name]
        # WRAM slice
        a_w = a.get("wram_state", [])
        e_w = e.get("wram_state", [])
        if len(a_w) != len(e_w):
            fails.append(f"{name}: wram_state length {len(a_w)} != baseline {len(e_w)}")
        else:
            mismatched = [(i, a_w[i], e_w[i]) for i in range(len(a_w)) if a_w[i] != e_w[i]]
            if mismatched:
                fails.append(f"{name}: wram diff in {len(mismatched)} cells (first 5: "
                             + ", ".join(f"@0x{i:04X}: {a:02X}->{e:02X}" for i, a, e in mismatched[:5])
                             + ")")
        # CRAM
        a_c = a.get("cram", [])
        e_c = e.get("cram", [])
        if a_c != e_c:
            fails.append(f"{name}: cram diff")

    return fails


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--bootstrap", action="store_true",
                    help="write current probe output as the new baseline")
    args = ap.parse_args(argv[1:])

    actual = load_json(PROBE_OUT)
    if actual is None:
        print(f"[check_phase34_dispatchers] no probe output at "
              f"{PROBE_OUT.relative_to(REPO_ROOT)} — run probe Lua first",
              file=sys.stderr)
        return 1

    if args.bootstrap:
        PROBE_DIR.mkdir(parents=True, exist_ok=True)
        BASELINE.write_text(json.dumps(actual, indent=2, sort_keys=True),
                            encoding="utf-8")
        print(f"[check_phase34_dispatchers] wrote baseline -> "
              f"{BASELINE.relative_to(REPO_ROOT)}")
        return 0

    expected = load_json(BASELINE)
    if expected is None:
        print(f"[check_phase34_dispatchers] no baseline yet at "
              f"{BASELINE.relative_to(REPO_ROOT)}; pass "
              f"(run with --bootstrap to record)")
        return 0

    fails = diff_scenarios(actual, expected)
    if not fails:
        sc = len(actual.get("scenarios", []))
        print(f"[check_phase34_dispatchers] OK ({sc} scenarios match baseline)")
        return 0

    print(f"[check_phase34_dispatchers] FAIL ({len(fails)} divergences):", file=sys.stderr)
    for f in fails:
        print(f"  {f}", file=sys.stderr)
    print("If divergence is intentional (e.g. dispatcher refactor), "
          "rebaseline: python tools/parity/check_phase34_dispatchers.py --bootstrap",
          file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
