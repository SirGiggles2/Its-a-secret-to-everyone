#!/usr/bin/env python3
"""
tools/nes_capture/verify_capture.py
=====================================
Master plan Phase 1.5 — Task 1.5.3: NES Reference Capture Verifier.

For each scenario in captures.json, checks whether a previous capture exists
in build/generated/nes_reference/<rom_hash_prefix8>/<scenario_id>/ and verifies
that every artifact SHA-256 still matches the recorded manifest.json.

Exit codes:
    0  Every existing capture matches its manifest (or no captures exist yet).
    1  At least one artifact SHA-256 differs from the recorded manifest,
       or a manifest is missing for a directory that contains artifacts.

Usage:
    python tools/nes_capture/verify_capture.py
    python tools/nes_capture/verify_capture.py --scenario title_idle
    python tools/nes_capture/verify_capture.py --rom-prefix a1b2c3d4
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
CAPTURES_JSON = SCRIPT_DIR / "captures.json"
GENERATED_ROOT = REPO_ROOT / "build" / "generated" / "nes_reference"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


# ---------------------------------------------------------------------------
# Core verifier
# ---------------------------------------------------------------------------

def verify_scenario_dir(scenario_dir: Path, scenario_id: str) -> list[str]:
    """
    Verify all artifacts in scenario_dir against manifest.json.

    Returns a list of failure strings (empty = all good).
    """
    failures: list[str] = []

    manifest_path = scenario_dir / "manifest.json"
    if not manifest_path.exists():
        # Check if there are any artifacts at all.
        artifacts_present = list(scenario_dir.iterdir())
        if artifacts_present:
            failures.append(
                f"{scenario_id}: manifest.json missing"
                f" but {len(artifacts_present)} file(s) exist"
            )
        # If the directory is empty, that's fine — no capture yet.
        return failures

    try:
        with open(manifest_path, encoding="utf-8") as f:
            manifest = json.load(f)
    except Exception as ex:
        failures.append(f"{scenario_id}: manifest.json unreadable: {ex}")
        return failures

    expected_hashes: dict[str, str] = manifest.get("artifact_sha256", {})
    if not expected_hashes:
        failures.append(f"{scenario_id}: manifest.json has no artifact_sha256 entries")
        return failures

    for filename, expected_sha in expected_hashes.items():
        artifact_path = scenario_dir / filename
        if expected_sha == "MISSING":
            # Was never captured; skip.
            continue
        if not artifact_path.exists():
            failures.append(f"{scenario_id}/{filename}: file missing (expected SHA {expected_sha[:12]}...)")
            continue
        actual_sha = sha256_file(artifact_path)
        if actual_sha != expected_sha:
            failures.append(
                f"{scenario_id}/{filename}: SHA mismatch\n"
                f"    expected: {expected_sha}\n"
                f"    actual  : {actual_sha}"
            )

    return failures


def find_all_capture_dirs(
    rom_prefix_filter: Optional[str],
    scenario_filter: Optional[str],
) -> list[tuple[str, str, Path]]:
    """
    Return [(rom_prefix, scenario_id, path), ...] for all existing capture dirs.
    """
    result: list[tuple[str, str, Path]] = []
    if not GENERATED_ROOT.exists():
        return result

    for rom_dir in sorted(GENERATED_ROOT.iterdir()):
        if not rom_dir.is_dir():
            continue
        if rom_prefix_filter and rom_dir.name != rom_prefix_filter:
            continue
        for scenario_dir in sorted(rom_dir.iterdir()):
            if not scenario_dir.is_dir():
                continue
            if scenario_filter and scenario_dir.name != scenario_filter:
                continue
            result.append((rom_dir.name, scenario_dir.name, scenario_dir))

    return result


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="NES Reference Capture Verifier — Phase 1.5"
    )
    parser.add_argument(
        "--scenario",
        type=str,
        default=None,
        help="Verify a single scenario by id (default: all).",
    )
    parser.add_argument(
        "--rom-prefix",
        type=str,
        default=None,
        help="Filter by ROM hash prefix (first 8 chars of SHA-256).",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help=(
            "Exit 1 if no captures exist at all"
            " (use this from the strict build gate)."
        ),
    )
    args = parser.parse_args()

    # Load scenario manifest for reference.
    if not CAPTURES_JSON.exists():
        print(f"ERROR: captures.json not found at {CAPTURES_JSON}", file=sys.stderr)
        return 1

    with open(CAPTURES_JSON, encoding="utf-8") as f:
        manifest_data = json.load(f)
    all_scenario_ids = {s["id"] for s in manifest_data.get("scenarios", [])}

    # Discover existing capture directories.
    capture_dirs = find_all_capture_dirs(
        rom_prefix_filter=args.rom_prefix,
        scenario_filter=args.scenario,
    )

    if not capture_dirs:
        if args.strict:
            print(
                "ERROR (--strict): No captures found under"
                f" {GENERATED_ROOT}",
                file=sys.stderr,
            )
            print(
                "  Run: python tools/nes_capture/run_capture.py --rom <path>",
                file=sys.stderr,
            )
            return 1
        else:
            print(
                "No captures found under"
                f" {GENERATED_ROOT}."
            )
            print("  Nothing to verify — run run_capture.py first.")
            return 0

    print(f"Verifying {len(capture_dirs)} capture dir(s)...\n")

    all_failures: list[str] = []
    verified = 0
    unknown_scenarios: list[str] = []

    for rom_prefix, sid, cap_dir in capture_dirs:
        if sid not in all_scenario_ids:
            unknown_scenarios.append(f"{rom_prefix}/{sid}")

        failures = verify_scenario_dir(cap_dir, sid)
        if failures:
            for f in failures:
                print(f"  FAIL: {f}")
            all_failures.extend(failures)
        else:
            print(f"  OK  : {rom_prefix}/{sid}")
            verified += 1

    # Summary
    print()
    print("=" * 72)
    print("NES CAPTURE VERIFY SUMMARY")
    print("=" * 72)
    print(f"  Checked   : {len(capture_dirs)}")
    print(f"  Passed    : {verified}")
    print(f"  Failed    : {len(all_failures)}")

    if unknown_scenarios:
        print(f"\n  Unknown scenario ids (not in captures.json):")
        for s in unknown_scenarios:
            print(f"    {s}")

    if all_failures:
        print("\nCapture integrity check FAILED.")
        print("Re-run run_capture.py to regenerate affected scenarios.")
        return 1

    print("\nAll captures match their manifests. GREEN.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
