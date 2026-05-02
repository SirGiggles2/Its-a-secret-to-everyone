#!/usr/bin/env python3
"""
tools/nes_capture/run_capture.py
=================================
Master plan Phase 1.5 — Task 1.5.2: NES Reference Capture Driver.

For each scenario in captures.json, drives BizHawk via:
    EmuHawk.exe --lua=tools/nes_capture/lua/capture_bundle.lua

and writes the artifact bundle to:
    build/generated/nes_reference/<rom_sha256_prefix8>/<scenario_id>/

Then hashes every artifact and writes manifest.json.

Exit codes:
    0  All attempted captures succeeded (some may be skipped; that's OK).
    1  Hard error: ROM hash mismatch, BizHawk crash, or file I/O error.

Usage:
    python tools/nes_capture/run_capture.py --rom roms/zelda1.nes
    python tools/nes_capture/run_capture.py --rom roms/zelda1.nes --scenario title_idle
    python tools/nes_capture/run_capture.py --rom roms/zelda1.nes --dry-run
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent.parent
CAPTURES_JSON = SCRIPT_DIR / "captures.json"
LUA_SCRIPT = SCRIPT_DIR / "lua" / "capture_bundle.lua"
CAPTURE_TOOL_VERSION = "1.0.0"

# Default BizHawk install locations (checked in order).
BIZHAWK_SEARCH_PATHS = [
    Path(os.environ.get("BIZHAWK_ROOT", "")),
    Path("C:/BizHawk"),
    Path("C:/Program Files/BizHawk"),
    Path("C:/Tools/BizHawk"),
]

# Timeout per scenario capture in seconds.
CAPTURE_TIMEOUT_SECONDS = 120


# ---------------------------------------------------------------------------
# ROM hashing
# ---------------------------------------------------------------------------

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


# ---------------------------------------------------------------------------
# BizHawk discovery
# ---------------------------------------------------------------------------

def find_emuhawk() -> Optional[Path]:
    """Find EmuHawk.exe by checking BIZHAWK_ROOT env var and common locations."""
    candidates: list[Path] = []

    env_root = os.environ.get("BIZHAWK_ROOT", "")
    if env_root:
        candidates.append(Path(env_root) / "EmuHawk.exe")

    for base in BIZHAWK_SEARCH_PATHS:
        if base and str(base) != ".":
            candidates.append(base / "EmuHawk.exe")

    for candidate in candidates:
        if candidate.exists():
            return candidate

    return None


# ---------------------------------------------------------------------------
# Artifact hashing
# ---------------------------------------------------------------------------

def hash_artifacts(output_dir: Path, artifacts: list[str]) -> dict[str, str]:
    """Return {filename: sha256_hex} for each artifact that exists."""
    result: dict[str, str] = {}
    for name in artifacts:
        p = output_dir / name
        if p.exists():
            result[name] = sha256_file(p)
        else:
            result[name] = "MISSING"
    return result


# ---------------------------------------------------------------------------
# Scenario skip analysis
# ---------------------------------------------------------------------------

def check_skip_reason(scenario: dict, repo_root: Path) -> Optional[str]:
    """
    Return a human-readable skip reason if the scenario cannot be run,
    or None if it is runnable.
    """
    state = scenario.get("starting_save_state")
    movie = scenario.get("input_movie")

    if state and not (repo_root / state).exists():
        return f"save state not found: {state}"

    if movie and not (repo_root / movie).exists():
        return f"input movie not found: {movie}"

    return None


# ---------------------------------------------------------------------------
# Single scenario capture
# ---------------------------------------------------------------------------

def run_scenario(
    scenario: dict,
    rom_path: Path,
    rom_hash: str,
    emuhawk: Path,
    repo_root: Path,
    dry_run: bool,
) -> tuple[bool, str]:
    """
    Run a single scenario capture via BizHawk.

    Returns (success: bool, message: str).
    """
    sid = scenario["id"]
    target_frame = scenario.get("target_frame", 60)
    rng_seed = scenario.get("rng_seed")
    movie = scenario.get("input_movie")
    artifacts = scenario.get("capture_artifacts", [
        "screenshot.png", "ppu.bin", "oam.bin", "palram.bin",
        "ciram.bin", "ram.bin", "frame.txt", "input_log.txt", "rng_seed.txt",
    ])

    # Output directory: use first 8 chars of ROM hash as prefix.
    out_dir = (
        repo_root
        / "build" / "generated" / "nes_reference"
        / rom_hash[:8]
        / sid
    )
    out_dir.mkdir(parents=True, exist_ok=True)

    if dry_run:
        print(f"  [DRY-RUN] Would launch BizHawk for scenario '{sid}' → {out_dir}")
        return True, "dry-run"

    # Build environment for the Lua script.
    env = os.environ.copy()
    env["NES_CAPTURE_SCENARIO"] = sid
    env["NES_CAPTURE_FRAME"] = str(target_frame)
    env["NES_CAPTURE_SEED"] = "" if rng_seed is None else hex(rng_seed)
    env["NES_CAPTURE_MOVIE"] = "" if not movie else str(repo_root / movie)
    env["NES_CAPTURE_ROM"] = str(rom_path)
    env["NES_CAPTURE_OUT_DIR"] = str(out_dir)
    env["NES_CAPTURE_ROM_HASH"] = rom_hash

    # BizHawk requires the Lua path to be relative when there are spaces in
    # the path (per memory rule feedback_bizhawk_lua_env / bizhawkScript skill).
    # We copy the lua script to a temp name in the BizHawk directory to avoid
    # path-with-spaces issues — same pattern as the bizhawkScript skill.
    bizhawk_dir = emuhawk.parent
    tmp_lua = bizhawk_dir / f"_nes_capture_{sid}.lua"
    try:
        tmp_lua.write_bytes(LUA_SCRIPT.read_bytes())
    except Exception as ex:
        return False, f"failed to stage Lua script: {ex}"

    try:
        cmd = [
            str(emuhawk),
            str(rom_path),
            f"--lua={tmp_lua.name}",
            "--chromeless",
        ]
        proc = subprocess.run(
            cmd,
            cwd=str(bizhawk_dir),
            env=env,
            timeout=CAPTURE_TIMEOUT_SECONDS,
            capture_output=True,
            text=True,
        )
    except subprocess.TimeoutExpired:
        return False, f"BizHawk timed out after {CAPTURE_TIMEOUT_SECONDS}s"
    except Exception as ex:
        return False, f"BizHawk launch failed: {ex}"
    finally:
        try:
            tmp_lua.unlink(missing_ok=True)
        except Exception:
            pass

    if proc.returncode != 0:
        stderr_snippet = (proc.stderr or proc.stdout or "")[:300]
        return False, f"BizHawk exited {proc.returncode}: {stderr_snippet}"

    # Hash all produced artifacts and write manifest.json.
    artifact_hashes = hash_artifacts(out_dir, artifacts)
    missing = [k for k, v in artifact_hashes.items() if v == "MISSING"]
    if missing:
        return False, f"artifacts not produced: {missing}"

    manifest = {
        "scenario_id": sid,
        "source_rom_hash": rom_hash,
        "capture_tool_version": CAPTURE_TOOL_VERSION,
        "target_frame": target_frame,
        "rng_seed": (hex(rng_seed) if rng_seed is not None else None),
        "capture_timestamp": int(time.time()),
        "artifact_sha256": artifact_hashes,
    }
    manifest_path = out_dir / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")

    return True, f"captured {len(artifacts)} artifacts → {out_dir}"


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(
        description="NES Reference Capture Driver — Phase 1.5"
    )
    parser.add_argument(
        "--rom",
        type=Path,
        default=None,
        help="Path to NES Zelda 1 ROM (default: roms/zelda1.nes relative to repo root).",
    )
    parser.add_argument(
        "--scenario",
        type=str,
        default=None,
        help="Run a single scenario by id (default: all scenarios).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be run without launching BizHawk.",
    )
    parser.add_argument(
        "--bizhawk",
        type=Path,
        default=None,
        help="Path to EmuHawk.exe (overrides BIZHAWK_ROOT env var and auto-discovery).",
    )
    args = parser.parse_args()

    # --- Load manifest ---
    if not CAPTURES_JSON.exists():
        print(f"ERROR: captures.json not found at {CAPTURES_JSON}", file=sys.stderr)
        return 1

    with open(CAPTURES_JSON, encoding="utf-8") as f:
        manifest_data = json.load(f)

    supported_hashes: list[str] = manifest_data.get("supported_rom_hashes", [])
    scenarios: list[dict] = manifest_data.get("scenarios", [])

    # --- ROM path ---
    rom_path: Path
    if args.rom:
        rom_path = args.rom if args.rom.is_absolute() else REPO_ROOT / args.rom
    else:
        rom_path = REPO_ROOT / "roms" / "zelda1.nes"

    if not rom_path.exists():
        print(f"ERROR: ROM not found at {rom_path}", file=sys.stderr)
        print(
            "  Place your legal Zelda 1 NES dump at that path, or pass --rom <path>.",
            file=sys.stderr,
        )
        return 1

    # --- ROM hash validation ---
    print(f"Hashing ROM: {rom_path} ...")
    rom_hash = sha256_file(rom_path)
    print(f"  SHA-256: {rom_hash}")

    # Strip placeholder entries from comparison.
    real_supported = [h for h in supported_hashes if not h.startswith("PLACEHOLDER")]
    if real_supported and rom_hash not in real_supported:
        print(f"ERROR: ROM hash {rom_hash} is not in the supported list:", file=sys.stderr)
        for h in real_supported:
            print(f"  {h}", file=sys.stderr)
        print(
            "\nIf this is a valid Zelda 1 dump, add its SHA-256 to"
            " tools/nes_capture/captures.json -> supported_rom_hashes.",
            file=sys.stderr,
        )
        return 1

    if not real_supported:
        print(
            "  NOTE: supported_rom_hashes contains only placeholders."
            " Skipping hash validation (scaffolding mode)."
        )

    # --- BizHawk discovery ---
    emuhawk: Optional[Path] = None
    scaffolding_mode = False

    if args.bizhawk:
        emuhawk = args.bizhawk
        if not emuhawk.exists():
            print(f"ERROR: --bizhawk path not found: {emuhawk}", file=sys.stderr)
            return 1
    elif not args.dry_run:
        emuhawk = find_emuhawk()
        if emuhawk is None:
            print(
                "SCAFFOLDING MODE: EmuHawk.exe not found."
                " Set BIZHAWK_ROOT or use --bizhawk to point at your BizHawk install."
            )
            print(
                "  All scenarios will be reported as 'skipped (no BizHawk)'"
                " — run_capture.py structure is verified.\n"
            )
            scaffolding_mode = True

    # --- Filter scenarios ---
    if args.scenario:
        target_scenarios = [s for s in scenarios if s["id"] == args.scenario]
        if not target_scenarios:
            ids = [s["id"] for s in scenarios]
            print(f"ERROR: scenario '{args.scenario}' not found.", file=sys.stderr)
            print(f"  Available: {ids}", file=sys.stderr)
            return 1
    else:
        target_scenarios = scenarios

    print(f"\nRunning {len(target_scenarios)} scenario(s)...\n")

    # --- Execute ---
    ran = 0
    skipped: list[tuple[str, str]] = []
    failed: list[tuple[str, str]] = []

    for scenario in target_scenarios:
        sid = scenario["id"]
        print(f"[{sid}]")

        skip_reason = check_skip_reason(scenario, REPO_ROOT)
        if skip_reason:
            print(f"  SKIP: {skip_reason}")
            skipped.append((sid, skip_reason))
            continue

        if scaffolding_mode:
            print("  SKIP: no BizHawk (scaffolding mode)")
            skipped.append((sid, "no BizHawk"))
            continue

        assert emuhawk is not None
        success, message = run_scenario(
            scenario=scenario,
            rom_path=rom_path,
            rom_hash=rom_hash,
            emuhawk=emuhawk,
            repo_root=REPO_ROOT,
            dry_run=args.dry_run,
        )

        if success:
            print(f"  OK: {message}")
            ran += 1
        else:
            print(f"  FAIL: {message}")
            failed.append((sid, message))

    # --- Summary ---
    print()
    print("=" * 72)
    print("NES CAPTURE SUMMARY")
    print("=" * 72)
    print(f"  Scenarios attempted : {ran + len(failed)}")
    print(f"  Succeeded           : {ran}")
    print(f"  Skipped             : {len(skipped)}")
    print(f"  Failed              : {len(failed)}")

    if skipped:
        print("\nSkipped scenarios (prerequisites missing):")
        for sid, reason in skipped:
            print(f"  {sid}: {reason}")

    if failed:
        print("\nFailed scenarios:")
        for sid, reason in failed:
            print(f"  {sid}: {reason}")
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
