#!/usr/bin/env python3
"""
tools/builder/strict_build_check.py
=====================================
Master-plan Task 1.11 — Strict Generated-Only Build Gate runner.

Sole Build Target Amendment 2026-05-08: this script runs `Debug.bat`
with `REQUIRE_GENERATED_ASSETS=1`, captures its output, collects every
"STRICT GATE FAIL: ..." line, and prints a summary report. The
prior dual-target (Title.md + RoomRom.md) plumbing is retired.

Exit codes:
  0  Build produced no STRICT GATE FAIL lines.
  1  At least one STRICT GATE FAIL line was found, or the build crashed
     for an unrelated reason.

Usage:
  python tools/builder/strict_build_check.py

This script is intended to be called:
  - Manually during development: to check how many extractors are still missing.
  - From a CI job: "Strict Builder Gate" (required green before release packaging
    per master plan; recommended green per phase close from Phase 3 onward).

NOTE: This gate may still produce failures while Phase 1 extractors are
incomplete. It becomes mandatory at Phase 1.10 close. See
docs/audit/strict_build_gate.md for the full policy.
"""

import os
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent


def run_build(label: str, bat_path: Path, env: dict) -> tuple[int, list[str], list[str]]:
    if not bat_path.exists():
        print(f"[{label}] SKIP — {bat_path} not found")
        return 0, [], []

    print(f"[{label}] Running {bat_path} with REQUIRE_GENERATED_ASSETS=1 ...")
    print("-" * 72)

    result = subprocess.run(
        ["cmd.exe", "/c", str(bat_path)],
        cwd=str(bat_path.parent),
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )

    lines = result.stdout.splitlines()
    for line in lines:
        print(line)

    fail_lines = [ln for ln in lines if ln.startswith("STRICT GATE FAIL:")]
    print("-" * 72)
    print(f"[{label}] Exit code: {result.returncode}")
    print(f"[{label}] STRICT GATE FAIL hits: {len(fail_lines)}")
    print()
    return result.returncode, lines, fail_lines


def main() -> int:
    env = os.environ.copy()
    env["REQUIRE_GENERATED_ASSETS"] = "1"

    debug_bat = REPO_ROOT / "Debug.bat"

    all_fails: list[tuple[str, str]] = []
    any_crash = False

    rc, _lines, fails = run_build("Debug.md", debug_bat, env)
    if rc != 0 and not fails:
        print(
            f"WARNING: Debug.md build exited {rc} with no STRICT GATE FAIL lines."
            " This may be a toolchain or extractor error unrelated to the gate."
        )
        any_crash = True
    for f in fails:
        all_fails.append(("Debug.md", f))

    print("=" * 72)
    print("STRICT BUILD GATE SUMMARY")
    print("=" * 72)

    if not all_fails and not any_crash:
        print("GREEN — no Nintendo-derived files served from checked-in fallback.")
        print()
        print(
            "NOTE: A clean run here means all compiled Nintendo-derived files are\n"
            "      covered by the generated manifest. It does NOT guarantee the\n"
            "      manifest itself is correct — run Phase 1.5 NES capture harness\n"
            "      to verify byte-level fidelity."
        )
        return 0

    if all_fails:
        print(f"RED — {len(all_fails)} STRICT GATE FAIL hit(s):")
        print()
        for label, line in all_fails:
            path_part = line.removeprefix("STRICT GATE FAIL:").strip()
            print(f"  [{label}]  {path_part}")
        print()
        print(
            "These files are Nintendo-derived and are currently served from\n"
            "checked-in fallback data. Each one needs a Phase 1 extractor\n"
            "that writes it into GENERATED_ASSET_ROOT before the gate can pass.\n"
            "\n"
            "See docs/audit/strict_build_gate.md for the planned extractor schedule."
        )

    if any_crash:
        print()
        print(
            "WARNING: build exited non-zero without any STRICT GATE FAIL lines.\n"
            "Investigate the build output above for toolchain or extractor\n"
            "errors that prevented the gate from reaching the data-compile steps."
        )

    return 1


if __name__ == "__main__":
    sys.exit(main())
