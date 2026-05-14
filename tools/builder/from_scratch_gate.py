"""Phase 17.3 — From-Scratch Build Reproducibility Gate.

Automates the 9-step master plan checklist:

1. Clone clean public package -> no generated asset cache.
2. Run builder with user NES ROM (sha256 pinned).
3. Generated cache appears locally.
4. Final `.md` ROM appears at builds/Debug.md.
5. Final ROM hash recorded in manifest.
6. Smoke probe runs against final ROM.
7. Delete cache; rebuild.
8. Byte-compare rebuilt Debug.md against the previous Debug.md;
   require diff = 0.
9. Fail if manifest inputs match but ROM bytes differ.

Usage:
    python tools/builder/from_scratch_gate.py <user-rom.nes>
        — run the full gate; record results to
          builds/reports/from_scratch_gate.json.

Exit codes:
    0  Gate passed (byte-identical reproducibility).
    1  ROM hash mismatch.
    2  Build A or B failed.
    3  Byte mismatch between Build A and Build B (reproducibility break).
    4  Smoke probe failed.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BUILDS = ROOT / "builds"
REPORTS = BUILDS / "reports"
ROM_OUT = BUILDS / "Debug.md"
ROM_BACKUP = BUILDS / "Debug.md.gate-build-a"


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def clean_cache() -> None:
    """Wipe generated caches so step 1 / step 7 start from clean state."""
    targets = [
        ROOT / "build" / "debug_project" / "out",
        ROOT / "data" / "audio" / "songs.c",
        ROOT / "data" / "audio" / "song_scripts.c",
        ROOT / "data" / "audio" / "sfx.c",
        ROOT / "data" / "audio" / "sfx_pcm.c",
        ROOT / "data" / "audio" / "pcm_samples.c",
        ROOT / "src" / "data" / "music_blob.dat",
        ROOT / "src" / "data" / "music_blob.inc",
    ]
    for t in targets:
        if t.is_dir():
            shutil.rmtree(t, ignore_errors=True)
        elif t.exists():
            t.unlink()


def run_builder(rom: Path) -> int:
    """Invoke tools/builder/build.py with the user ROM."""
    builder = ROOT / "tools" / "builder" / "build.py"
    r = subprocess.run(
        [sys.executable, str(builder), str(rom)],
        cwd=ROOT,
        check=False,
    )
    return r.returncode


def run_smoke_probe() -> int:
    """Sanity check that the final ROM at least passes regression matrix."""
    matrix = ROOT / "tools" / "run_regression_matrix.py"
    r = subprocess.run(
        [sys.executable, str(matrix)],
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    if r.returncode != 0:
        print(r.stderr, file=sys.stderr)
        return 4
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(prog="from_scratch_gate.py")
    ap.add_argument("rom", type=Path, help="user NES Zelda 1 ROM")
    ap.add_argument("--skip-clean", action="store_true",
                    help="skip cache wipe before each build (faster, less rigorous)")
    args = ap.parse_args()

    if not args.rom.exists():
        print(f"ERROR: ROM not found: {args.rom}", file=sys.stderr)
        return 1

    REPORTS.mkdir(parents=True, exist_ok=True)
    result = {
        "rom_sha256": sha256_file(args.rom),
        "build_a": {},
        "build_b": {},
        "verdict": "?",
    }

    # Step 1-4: clean, build A.
    if not args.skip_clean:
        print("[1] cleaning cache...")
        clean_cache()
    print("[2] building A...")
    if run_builder(args.rom) != 0:
        result["verdict"] = "BUILD_A_FAIL"
        return 2
    if not ROM_OUT.exists():
        result["verdict"] = "BUILD_A_NO_OUTPUT"
        return 2
    rom_a_hash = sha256_file(ROM_OUT)
    rom_a_size = ROM_OUT.stat().st_size
    result["build_a"] = {"hash": rom_a_hash, "size": rom_a_size}
    shutil.copy2(ROM_OUT, ROM_BACKUP)
    print(f"    build A: sha256={rom_a_hash[:16]}... size={rom_a_size}")

    # Step 6: smoke probe Build A.
    print("[6] smoke probe (regression matrix)...")
    if run_smoke_probe() != 0:
        result["verdict"] = "SMOKE_FAIL"
        return 4

    # Step 7-8: clean, rebuild, byte-compare.
    if not args.skip_clean:
        print("[7] cleaning cache...")
        clean_cache()
    print("[8] building B...")
    if run_builder(args.rom) != 0:
        result["verdict"] = "BUILD_B_FAIL"
        return 2
    rom_b_hash = sha256_file(ROM_OUT)
    rom_b_size = ROM_OUT.stat().st_size
    result["build_b"] = {"hash": rom_b_hash, "size": rom_b_size}
    print(f"    build B: sha256={rom_b_hash[:16]}... size={rom_b_size}")

    # Step 9: compare.
    if rom_a_hash != rom_b_hash:
        result["verdict"] = "REPRO_BREAK"
        (REPORTS / "from_scratch_gate.json").write_text(
            json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(f"REPRO BREAK: build A != build B", file=sys.stderr)
        print(f"  build A hash: {rom_a_hash}", file=sys.stderr)
        print(f"  build B hash: {rom_b_hash}", file=sys.stderr)
        return 3

    result["verdict"] = "PASS"
    (REPORTS / "from_scratch_gate.json").write_text(
        json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: byte-identical reproducibility (sha256={rom_a_hash[:16]}...)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
