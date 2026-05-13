#!/usr/bin/env python3
"""RoomRom atlas Phase 1c: verify live CHR RAM against PRG-extracted blocks.

For Phase 1 items-only scope: verifies CommonSpritePatterns.

Strategy:
  1. Check if a fresh CHR dump exists at C:\\tmp\\atlas_chr_live_orig.bin
     (written by probe_atlas_chr_live.lua via BizHawk).
  2. If not, try the existing nes_item_chr_pt0_orig.bin from prior captures.
  3. Byte-match the dump against the P1b-extracted PRG block at
     RoomRom/out/prg_blocks/orig/CommonSpritePatterns.bin.
  4. Per spec: CommonSpritePatterns is loaded into CHR RAM at PPU $0000,
     so the live CHR RAM at offsets 0..1791 should byte-match the block.

BizHawk launch:
  If ATLAS_CHR_OUT exists and is fresh (written < 5 min ago), skip launch.
  Otherwise try to launch BizHawk with probe_atlas_chr_live.lua and wait
  up to 120s for the dump to appear. Falls back to existing dump if launch
  fails or times out.

Spec: docs/superpowers/specs/2026-05-01-roomrom-z1-full-atlas-design.md
      Section 5.3 (verify_chr_live.py) + Section 10 Phase 1c.

Usage: python RoomRom/tools/verify_chr_live.py
       python RoomRom/tools/verify_chr_live.py --skip-launch

Exit: 0 if byte-match passes; 1 on mismatch or missing files.
"""

from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Optional

ROOT = Path(__file__).resolve().parents[2]
PRG_BLOCK = ROOT / "RoomRom" / "out" / "prg_blocks" / "orig" / "CommonSpritePatterns.bin"
# Fallback: existing live CHR dump from earlier captures
EXISTING_DUMP = ROOT / "RoomRom" / "out" / "nes_item_chr_pt0_orig.bin"
# Live dump target from the new probe
LIVE_CHR_OUT = Path("C:/tmp/atlas_chr_live_orig.bin")

PROBE_LUA = ROOT / "RoomRom" / "probe_atlas_chr_live.lua"
LOCK_FILE = ROOT / "RoomRom" / "data" / "rom_inputs.lock"
ORIG_ROM_NAME = "Legend of Zelda, The (USA).nes"

# CommonSpritePatterns is loaded to PPU $0000 by Z1 boot code (Z_02.asm).
# 112 tiles * 16 bytes/tile = 1792 bytes.
COMMON_SPRITE_PPU_ADDR = 0x0000
COMMON_SPRITE_BYTE_LEN = 1792  # 112 NES tiles


def short_path(path: Path) -> str:
    raw = str(path.resolve())
    if os.name != "nt":
        return raw
    buf = ctypes.create_unicode_buffer(32768)
    n = ctypes.windll.kernel32.GetShortPathNameW(raw, buf, len(buf))
    return buf.value if n else raw


def sha256_hex(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def find_rom() -> Optional[Path]:
    for candidate in [ROOT / ORIG_ROM_NAME, ROOT.parent / "FINAL TRY" / ORIG_ROM_NAME]:
        if candidate.exists():
            return candidate
    return None


def parse_lock() -> dict[str, str]:
    out: dict[str, str] = {}
    if not LOCK_FILE.exists():
        return out
    for line in LOCK_FILE.read_text(encoding="ascii").splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        toks = s.split()
        if len(toks) >= 2:
            out[toks[0]] = toks[1]
    return out


def find_bizhawk_root() -> Optional[Path]:
    """Locate BizHawk root from env var or common paths."""
    env = os.environ.get("CODEX_BIZHAWK_ROOT", "")
    if env:
        p = Path(env)
        if (p / "EmuHawk.exe").exists():
            return p
    common = [
        Path("C:/BizHawk"),
        Path("C:/Users/Jake Diggity/Documents/BizHawk"),
        Path("C:/Users/Jake Diggity/BizHawk"),
        Path("C:/emulators/BizHawk"),
    ]
    for p in common:
        if (p / "EmuHawk.exe").exists():
            return p
    return None


def launch_bizhawk_probe(rom_path: Path) -> bool:
    """Launch BizHawk with the probe Lua. Returns True if launched."""
    bizhawk = find_bizhawk_root()
    if not bizhawk:
        print("  BizHawk not found; skipping auto-launch.")
        return False

    # Copy probe to BizHawk dir (avoids path parsing issues with spaces)
    probe_copy = bizhawk / "probe_atlas_chr_live.lua"
    probe_copy.write_bytes(PROBE_LUA.read_bytes())

    LIVE_CHR_OUT.parent.mkdir(parents=True, exist_ok=True)

    env = os.environ.copy()
    env["ATLAS_CHR_OUT"] = str(LIVE_CHR_OUT)
    env["ATLAS_CHR_ROM_ID"] = "orig"
    env["CODEX_BIZHAWK_ROOT"] = str(bizhawk)

    cmd = [
        short_path(bizhawk / "EmuHawk.exe"),
        f"--lua={short_path(probe_copy)}",
        short_path(rom_path),
    ]
    print(f"  Launching BizHawk: {' '.join(cmd)}")
    try:
        subprocess.Popen(cmd, cwd=short_path(bizhawk), env=env, shell=False)
        return True
    except Exception as e:
        print(f"  BizHawk launch failed: {e}")
        return False


def wait_for_dump(out_path: Path, timeout_s: int = 120) -> bool:
    """Poll until dump file appears or timeout."""
    deadline = time.time() + timeout_s
    print(f"  Waiting up to {timeout_s}s for dump at {out_path}...")
    while time.time() < deadline:
        if out_path.exists() and out_path.stat().st_size >= 4096:
            return True
        time.sleep(2)
    return False


def is_fresh(path: Path, max_age_s: int = 300) -> bool:
    """True if path exists and was modified within max_age_s seconds."""
    if not path.exists():
        return False
    age = time.time() - path.stat().st_mtime
    return age < max_age_s


def verify_block(chr_data: bytes, prg_data: bytes, ppu_offset: int, label: str) -> bool:
    """Byte-match prg_data against chr_data at ppu_offset. Returns True on match."""
    needed = ppu_offset + len(prg_data)
    if len(chr_data) < needed:
        print(f"  FAIL: CHR dump too small: {len(chr_data)} < {needed}")
        return False

    live_slice = chr_data[ppu_offset : ppu_offset + len(prg_data)]
    if live_slice == prg_data:
        sha = sha256_hex(prg_data)
        print(
            f"  MATCH: {label} at PPU ${ppu_offset:04X}..${ppu_offset + len(prg_data) - 1:04X} "
            f"({len(prg_data)} bytes) byte-identical. sha256={sha[:16]}..."
        )
        return True

    # Report first mismatches
    mismatches = [
        (i, live_slice[i], prg_data[i])
        for i in range(len(prg_data))
        if live_slice[i] != prg_data[i]
    ]
    print(
        f"  FAIL: {label} at PPU ${ppu_offset:04X} — "
        f"{len(mismatches)}/{len(prg_data)} bytes differ"
    )
    for i, a, b in mismatches[:8]:
        print(
            f"    byte {ppu_offset + i:#06x}: CHR={a:#04x}  PRG={b:#04x}"
        )
    if len(mismatches) > 8:
        print(f"    ... ({len(mismatches) - 8} more mismatches)")
    print()
    print("  Possible causes (per spec §5.3):")
    print("    1. Disasm-located label is wrong (PRG offset is at the wrong block).")
    print("    2. PRG offset extraction error in extract_z1_prg_chr.py.")
    print("    3. Z1 runtime transfer routine transforms bytes before writing to CHR RAM.")
    print("       Case 3 is not a PRG mutation — PRG is read-only — but a transfer-time")
    print("       transform. The registry must record the transform so generators can")
    print("       replay it. All three cases are bugs/gaps to fix before gen_atlas_master.py.")
    return False


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--skip-launch",
        action="store_true",
        help="Skip BizHawk auto-launch; use existing dump only.",
    )
    args = parser.parse_args()

    print("=== verify_chr_live.py Phase 1c (items-only: CommonSpritePatterns) ===\n")

    if not PRG_BLOCK.exists():
        print(f"ERROR: P1b output missing: {PRG_BLOCK}")
        print("       Run extract_z1_prg_chr.py first.")
        return 1

    prg_data = PRG_BLOCK.read_bytes()
    print(f"PRG block: {PRG_BLOCK.name}  {len(prg_data)} bytes  sha256={sha256_hex(prg_data)[:16]}...")

    # Determine which CHR dump to use
    chr_path: Optional[Path] = None
    source_label = ""

    if not args.skip_launch and is_fresh(LIVE_CHR_OUT):
        print(f"Fresh live dump found: {LIVE_CHR_OUT}")
        chr_path = LIVE_CHR_OUT
        source_label = "live (recent BizHawk probe)"
    elif not args.skip_launch:
        # Try to launch BizHawk
        rom_path = find_rom()
        if rom_path:
            print(f"ROM found: {rom_path.name}")
            launched = launch_bizhawk_probe(rom_path)
            if launched:
                if wait_for_dump(LIVE_CHR_OUT, timeout_s=120):
                    chr_path = LIVE_CHR_OUT
                    source_label = "live (BizHawk probe)"
                else:
                    print("  BizHawk probe timed out; falling back to existing dump.")
            else:
                print("  BizHawk launch skipped; falling back to existing dump.")
        else:
            print("  ROM not found; falling back to existing dump.")

    # Fall back to existing dump
    if chr_path is None or not chr_path.exists():
        if EXISTING_DUMP.exists():
            chr_path = EXISTING_DUMP
            source_label = f"fallback ({EXISTING_DUMP.name})"
            print(f"\nUsing fallback dump: {EXISTING_DUMP}")
            print(
                "  NOTE: this dump was captured earlier; not a fresh BizHawk launch.\n"
                "  Wire BizHawk auto-launch in a follow-up to get a deterministic fresh capture."
            )
        else:
            print(f"\nERROR: no CHR dump available.")
            print(f"  Expected live dump at: {LIVE_CHR_OUT}")
            print(f"  Expected fallback at:  {EXISTING_DUMP}")
            print()
            print("To capture manually:")
            print(f"  1. Launch BizHawk with rom = Legend of Zelda, The (USA).nes")
            print(f"  2. Run Lua probe: {PROBE_LUA}")
            print(f"  3. The probe will write a 4096-byte dump to C:\\tmp\\atlas_chr_live_orig.bin")
            print(f"  4. Re-run: python RoomRom/tools/verify_chr_live.py --skip-launch")
            return 1

    chr_data = chr_path.read_bytes()
    print(
        f"CHR dump:  {source_label}  {len(chr_data)} bytes  "
        f"sha256={sha256_hex(chr_data)[:16]}...\n"
    )

    if len(chr_data) < 4096:
        print(f"ERROR: CHR dump < 4096 bytes ({len(chr_data)}); needs full PPU $0000-$0FFF")
        return 1

    # Verify CommonSpritePatterns at PPU $0000
    ok = verify_block(chr_data, prg_data, COMMON_SPRITE_PPU_ADDR, "CommonSpritePatterns")

    print()
    if ok:
        print("verify_chr_live: OK - CommonSpritePatterns byte-matches live CHR RAM at PPU $0000")
        print(
            "  This confirms: PRG-extracted bytes == runtime CHR RAM bytes for this block.\n"
            "  No transfer-time transform detected for CommonSpritePatterns.\n"
            "  Phase 1c gate: PASS."
        )
        return 0
    else:
        print("verify_chr_live: FAIL - byte mismatch detected (see details above)")
        return 1


if __name__ == "__main__":
    sys.exit(main())
