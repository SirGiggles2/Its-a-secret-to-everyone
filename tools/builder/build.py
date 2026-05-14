"""Phase 17.2 — Unified builder UX shell.

Wraps the existing extractors + Debug.bat into a single drag-drop-style
entry point.

Usage:
    python tools/builder/build.py <user-rom.nes>
        — full pipeline: validate ROM hash, run extractors, build
          Debug.md.
    python tools/builder/build.py <user-rom.nes> --skip-extract
        — assume extractors have already run, just build.
    python tools/builder/build.py --check-toolchain
        — verify gcc/objcopy/python availability.

Exit codes:
    0  Build succeeded; final ROM at builds/Debug.md.
    1  ROM validation failure (wrong hash) or extractor failure.
    2  Toolchain missing.
    3  Build failure (Debug.bat returned non-zero).
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
AUDIO_MANIFEST = ROOT / "data" / "audio" / "MANIFEST.json"


def sha256_file(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def load_supported_rom_hashes() -> list[str]:
    """Pull the supported NES ROM sha256 list from audio MANIFEST.json."""
    if not AUDIO_MANIFEST.exists():
        return []
    m = json.loads(AUDIO_MANIFEST.read_text(encoding="utf-8"))
    single = m.get("nes_rom_sha256")
    return [single] if single else []


def check_toolchain() -> int:
    """Verify gcc/objcopy/python availability."""
    gcc = ROOT / "build" / "toolchain" / "sgdk_bin" / "bin" / "gcc.exe"
    objcopy = ROOT / "build" / "toolchain" / "sgdk_bin" / "bin" / "objcopy.exe"
    issues = []
    if not gcc.exists():
        issues.append(f"missing: {gcc}")
    if not objcopy.exists():
        issues.append(f"missing: {objcopy}")
    if issues:
        for i in issues:
            print(f"  {i}", file=sys.stderr)
        print("Run sgdk install / unpack toolchain first.", file=sys.stderr)
        return 2
    print(f"  gcc:     {gcc.name}")
    print(f"  objcopy: {objcopy.name}")
    print("Toolchain ok.")
    return 0


def validate_rom(rom_path: Path) -> int:
    """Check ROM sha256 matches the pinned list."""
    if not rom_path.exists():
        print(f"ERROR: ROM not found: {rom_path}", file=sys.stderr)
        return 1
    h = sha256_file(rom_path)
    supported = load_supported_rom_hashes()
    if not supported:
        print("WARN: no supported ROM hashes in audio MANIFEST.json; "
              "skipping validation.", file=sys.stderr)
        return 0
    if h not in supported:
        print(f"ERROR: ROM hash mismatch.", file=sys.stderr)
        print(f"  expected one of: {', '.join(supported)}", file=sys.stderr)
        print(f"  got:             {h}", file=sys.stderr)
        print(f"Supply a verified NES Zelda 1 PRG0 ROM.",
              file=sys.stderr)
        return 1
    print(f"ROM ok: {rom_path.name} (sha256: {h[:16]}...)")
    return 0


def run_extractors(rom_path: Path) -> int:
    """Run audio + CHR extractors against the user ROM.

    Phase 17 scaffold: enumerates the extractors that exist as Phase
    17.1 deliverables. Implementations land per follow-up PR.
    """
    extractors = [
        ROOT / "tools" / "extract_audio.py",
        # Add CHR extractor + room blob extractor as they land.
    ]
    for ext in extractors:
        if not ext.exists():
            print(f"  skip: {ext.name} not present")
            continue
        print(f"Running {ext.name}...")
        # Per Phase 17 plan, each extractor takes the ROM path.
        # Implementations vary; this is a placeholder dispatch.
        try:
            r = subprocess.run(
                [sys.executable, str(ext), "--rom", str(rom_path)],
                cwd=ROOT,
                check=False,
            )
            if r.returncode != 0:
                print(f"  {ext.name} exited {r.returncode}", file=sys.stderr)
                return 1
        except Exception as e:
            print(f"  {ext.name} failed: {e}", file=sys.stderr)
            return 1
    return 0


def build_rom() -> int:
    """Invoke Debug.bat to produce builds/Debug.md."""
    debug_bat = ROOT / "Debug.bat"
    if not debug_bat.exists():
        print(f"ERROR: Debug.bat missing", file=sys.stderr)
        return 3
    print("Building Debug.md...")
    r = subprocess.run(
        [str(debug_bat)],
        cwd=ROOT,
        shell=True,  # .bat requires shell
        check=False,
    )
    if r.returncode != 0:
        print(f"Debug.bat exited {r.returncode}", file=sys.stderr)
        return 3
    rom_out = ROOT / "builds" / "Debug.md"
    if rom_out.exists():
        print(f"  output: {rom_out}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(prog="build.py")
    ap.add_argument("rom", type=Path, nargs="?",
                    help="path to user NES Zelda 1 ROM")
    ap.add_argument("--skip-extract", action="store_true",
                    help="assume extractors already ran")
    ap.add_argument("--check-toolchain", action="store_true",
                    help="verify gcc/objcopy availability")
    args = ap.parse_args()

    if args.check_toolchain:
        return check_toolchain()

    if not args.rom:
        ap.print_help()
        return 1

    if (rc := check_toolchain()) != 0:
        return rc
    if (rc := validate_rom(args.rom)) != 0:
        return rc
    if not args.skip_extract:
        if (rc := run_extractors(args.rom)) != 0:
            return rc
    return build_rom()


if __name__ == "__main__":
    sys.exit(main())
