#!/usr/bin/env python3
"""
tools/builder/strict_build_check.py
=====================================
Master-plan Task 1.11 — Strict Generated-Only Build Gate runner.

Sets REQUIRE_GENERATED_ASSETS=1 and runs both build targets (Title.md and
RoomRom.md), captures their output, collects every "STRICT GATE FAIL: ..."
line, and prints a summary report.

Exit codes:
  0  Both builds produced no STRICT GATE FAIL lines (or builds were skipped).
  1  At least one STRICT GATE FAIL line was found, or a build crashed for an
     unrelated reason.

Usage:
  python tools/builder/strict_build_check.py [--title-only] [--roomrom-only]

This script is intended to be called:
  - Manually during development: to check how many extractors are still missing.
  - From a CI job: "Strict Builder Gate" (required green before release packaging
    per master plan; recommended green per phase close from Phase 3 onward).

NOTE: As of 2026-05-02 this gate is EXPECTED to produce failures because not
all Phase 1 extractors are complete.  It becomes mandatory at Phase 1.10 close.
See docs/audit/strict_build_gate.md for the full policy.
"""

import argparse
import os
import subprocess
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Repo root is two levels up from this file (tools/builder/strict_build_check.py)
# ---------------------------------------------------------------------------
REPO_ROOT = Path(__file__).resolve().parent.parent.parent


def run_build(label: str, bat_path: Path, env: dict) -> tuple[int, list[str], list[str]]:
    """
    Run a build.bat with strict-gate env vars set.

    Returns (returncode, all_output_lines, strict_fail_lines).
    """
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
    parser = argparse.ArgumentParser(
        description="Run both build targets with REQUIRE_GENERATED_ASSETS=1 and report fallback hits."
    )
    parser.add_argument(
        "--title-only",
        action="store_true",
        help="Run Title.md build only (skip RoomRom).",
    )
    parser.add_argument(
        "--roomrom-only",
        action="store_true",
        help="Run RoomRom build only (skip Title).",
    )
    args = parser.parse_args()

    # Build env: inherit everything, then add/override the gate flags.
    env = os.environ.copy()
    env["REQUIRE_GENERATED_ASSETS"] = "1"
    # GENERATED_ASSET_ROOT may already be set by the caller; if not, leave it
    # unset so that check_generated always falls through to the FAIL path,
    # which is the correct strict-gate behaviour when no ROM has been supplied.

    title_bat = REPO_ROOT / "build.bat"
    roomrom_bat = REPO_ROOT / "RoomRom" / "build.bat"

    all_fails: list[tuple[str, str]] = []  # [(label, fail_line), ...]
    any_crash = False

    # ----- Title.md -----
    if not args.roomrom_only:
        rc, _lines, fails = run_build("Title.md", title_bat, env)
        if rc != 0 and not fails:
            # Non-zero exit but no STRICT GATE FAIL lines: unrelated build error.
            print(
                f"WARNING: Title.md build exited {rc} with no STRICT GATE FAIL lines."
                " This may be a toolchain or extractor error unrelated to the gate."
            )
            any_crash = True
        for f in fails:
            all_fails.append(("Title.md", f))

    # ----- RoomRom.md -----
    if not args.title_only:
        rc, _lines, fails = run_build("RoomRom.md", roomrom_bat, env)
        if rc != 0 and not fails:
            print(
                f"WARNING: RoomRom.md build exited {rc} with no STRICT GATE FAIL lines."
                " This may be a toolchain or extractor error unrelated to the gate."
            )
            any_crash = True
        for f in fails:
            all_fails.append(("RoomRom.md", f))

    # ----- Summary report -----
    print("=" * 72)
    print("STRICT BUILD GATE SUMMARY")
    print("=" * 72)

    if not all_fails and not any_crash:
        print("GREEN — no Nintendo-derived files served from checked-in fallback.")
        print()
        print(
            "NOTE: A clean run here means all compiled Nintendo-derived files are\n"
            "      covered by the generated manifest.  It does NOT guarantee the\n"
            "      manifest itself is correct — run Phase 1.5 NES capture harness\n"
            "      to verify byte-level fidelity."
        )
        return 0

    if all_fails:
        print(f"RED — {len(all_fails)} STRICT GATE FAIL hit(s):")
        print()
        for label, line in all_fails:
            # Strip the "STRICT GATE FAIL: " prefix to get just the file path.
            path_part = line.removeprefix("STRICT GATE FAIL:").strip()
            print(f"  [{label}]  {path_part}")
        print()
        print(
            "These files are Nintendo-derived and are currently served from\n"
            "checked-in fallback data.  Each one needs a Phase 1 extractor\n"
            "that writes it into GENERATED_ASSET_ROOT before the gate can pass.\n"
            "\n"
            "See docs/audit/strict_build_gate.md — 'Known acceptable fallback\n"
            "windows' — for the planned extractor schedule."
        )

    if any_crash:
        print()
        print(
            "WARNING: one or more builds exited non-zero without any STRICT GATE\n"
            "FAIL lines.  Investigate the build output above for toolchain or\n"
            "extractor errors that prevented the gate from reaching the data-\n"
            "compile steps."
        )

    return 1


# ---------------------------------------------------------------------------
# Phase 1.5 NES Reference Capture verification gate
# ---------------------------------------------------------------------------
# When Phase 1.5 captures are fully populated, wire the verifier here so that
# a missing or stale NES reference capture fails this strict build gate.
#
# Uncomment and integrate the block below once run_capture.py has been run
# successfully for all canonical scenarios:
#
#   import subprocess as _subprocess
#
#   def _run_nes_capture_verify(repo_root: Path) -> list[tuple[str, str]]:
#       """Call verify_capture.py and return any failures as (label, msg) pairs."""
#       verifier = repo_root / "tools" / "nes_capture" / "verify_capture.py"
#       if not verifier.exists():
#           return []  # harness not installed; skip silently
#       result = _subprocess.run(
#           [sys.executable, str(verifier), "--strict"],
#           cwd=str(repo_root),
#           stdout=_subprocess.PIPE,
#           stderr=_subprocess.STDOUT,
#           text=True,
#           encoding="utf-8",
#           errors="replace",
#       )
#       if result.returncode != 0:
#           return [("NES Capture", "verify_capture.py --strict returned non-zero")]
#       return []
#
# Then in main(), before "return 1":
#
#   nes_fails = _run_nes_capture_verify(REPO_ROOT)
#   for label, msg in nes_fails:
#       all_fails.append((label, msg))
#
# See tools/nes_capture/README.md for the full integration description.
# ---------------------------------------------------------------------------


if __name__ == "__main__":
    sys.exit(main())
