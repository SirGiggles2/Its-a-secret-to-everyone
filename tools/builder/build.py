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


# How each extractor receives the ROM. Probed from the sources, not
# assumed — the conventions are NOT uniform, and the previous code passed
# "--rom" to all of them. Only extract_nes_banks.py accepts that flag;
# the argparse-less scripts silently ignored it and fell back to their own
# lookup, so the user's ROM was never actually reaching them.
#
#   "env"  — reads ZELDA_NES_ROM, falls back to a repo-root path
#   "argv" — takes the ROM as sys.argv[1]
#   "flag" — takes --rom <path>
#   "none" — needs no ROM (reads the committed disassembly reference tree)
# Third element: extra flags the extractor needs to emit everything the build
# consumes. --legacy-inc is NOT optional for a from-scratch build: it is what
# writes src/data/music_blob.{dat,inc} (included by src/audio_driver.asm) and
# the reference/aldonunez/dat/*.dat sidecars. Without it the gate deletes
# music_blob.dat during its cache wipe and nothing regenerates it, so the
# assembler fails with "file not found: src/data/music_blob.dat".
EXTRACTORS: tuple[tuple[str, str, tuple[str, ...]], ...] = (
    # PRG banks first: later extractors read the dat sidecars it emits.
    ("extract_nes_banks.py", "flag", ()),
    ("extract_dat_sidecars.py", "env", ()),
    ("extract_chr.py", "env", ("--legacy-inc",)),
    ("extract_rooms.py", "env", ("--legacy-inc",)),
    ("extract_enemies.py", "env", ("--legacy-inc",)),
    ("extract_audio.py", "env", ("--legacy-inc",)),
    ("extract_dmc_samples.py", "argv", ()),
    ("extract_frontend.py", "env", ("--legacy-inc",)),
    ("extract_misc.py", "env", ("--legacy-inc",)),
    ("extract_demo_text.py", "env", ()),
    ("extract_intro_assets.py", "none", ()),
)

# Needs a CHR-RAM dump captured live from Zelda Redux, not the base ROM.
# Cannot run unattended from a ROM path alone; see tools/extract_fs_assets.py.
MANUAL_EXTRACTORS: tuple[tuple[str, str], ...] = (
    (
        "extract_fs_assets.py",
        "requires a live CHR-RAM dump from Zelda Redux (manual capture step)",
    ),
)


def run_extractors(rom_path: Path) -> int:
    """Regenerate every ROM-derived asset from the user's NES ROM.

    Sets ZELDA_NES_ROM for the whole subprocess environment so the
    env-convention extractors see the ROM the user actually supplied
    rather than whatever happens to sit at the repo-root fallback path.
    """
    env = dict(os.environ)
    env["ZELDA_NES_ROM"] = str(rom_path)

    failures: list[str] = []
    for name, convention, extra in EXTRACTORS:
        ext = ROOT / "tools" / name
        if not ext.exists():
            print(f"  MISSING: {name} — cannot regenerate its assets",
                  file=sys.stderr)
            failures.append(f"{name} (missing)")
            continue

        if convention == "flag":
            argv = [sys.executable, str(ext), "--rom", str(rom_path)]
        elif convention == "argv":
            argv = [sys.executable, str(ext), str(rom_path)]
        else:  # "env" and "none" both take no ROM argument
            argv = [sys.executable, str(ext)]
        argv.extend(extra)

        print(f"Running {name} ({convention})"
              f"{' ' + ' '.join(extra) if extra else ''}...")
        try:
            r = subprocess.run(argv, cwd=ROOT, env=env, check=False)
        except Exception as e:  # noqa: BLE001 — report and continue
            print(f"  {name} failed: {e}", file=sys.stderr)
            failures.append(f"{name} ({e})")
            continue
        if r.returncode != 0:
            print(f"  {name} exited {r.returncode}", file=sys.stderr)
            failures.append(f"{name} (exit {r.returncode})")

    for name, why in MANUAL_EXTRACTORS:
        print(f"  SKIP {name}: {why}")

    if failures:
        print(f"\n{len(failures)} extractor(s) failed:", file=sys.stderr)
        for f in failures:
            print(f"  - {f}", file=sys.stderr)
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
