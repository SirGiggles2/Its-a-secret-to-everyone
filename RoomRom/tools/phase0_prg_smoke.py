#!/usr/bin/env python3
"""RoomRom atlas Phase 0 PRG-extraction smoke test.

Confirms that a known disasm pattern block (CommonSpritePatterns,
1792 bytes / 112 NES tiles) lives byte-identical inside the pinned
NES Z1 PRG ROM. Locates the block by scanning PRG for the byte
sequence that matches the disasm's accompanying .dat file. If found,
prints the PRG offset; if not, reports the divergence so the team
can decide whether Z1's runtime transfer routine transforms the
bytes en route to CHR RAM (in which case the registry must record
the transform).

Spec: docs/superpowers/specs/2026-05-01-roomrom-z1-full-atlas-design.md
      Section 5.2 (extract_z1_prg_chr.py) + Section 10 Phase 0.

Usage:  python RoomRom/tools/phase0_prg_smoke.py
Exit:   0 if block found byte-identical in PRG; 1 otherwise.
"""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

# Phase 0 smoke test only validates the orig variant: the disasm `.dat`
# files in reference/aldonunez/dat/ are derived from the orig ROM's
# pattern blocks, so they should byte-match. Redux modifies sprite CHR,
# so the same byte sequence is NOT present in Redux's PRG -- expected,
# not a failure. Per-variant verification lives in Phase 1's
# verify_chr_live.py, which captures CHR RAM at the runtime target
# address per ROM.
ROMS = [
    ("orig",  "Legend of Zelda, The (USA).nes"),
]
INFORMATIONAL_VARIANTS = [
    ("redux", "Zelda Redux.nes"),
]

LOCK_FILE = ROOT / "RoomRom" / "data" / "rom_inputs.lock"
DISASM_DAT = ROOT / "reference" / "aldonunez" / "dat" / "CommonSpritePatterns.dat"


def fail(msg: str) -> None:
    print(f"phase0_prg_smoke: FAIL: {msg}", file=sys.stderr)
    sys.exit(1)


def parse_lock(path: Path) -> dict[str, str]:
    """Parse rom_inputs.lock -> {variant_id: sha256}."""
    out: dict[str, str] = {}
    if not path.exists():
        fail(f"missing lock file: {path}")
    for line in path.read_text(encoding="ascii").splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        toks = s.split()
        if len(toks) < 4:
            fail(f"malformed lock line: {line!r}")
        out[toks[0]] = toks[1]
    return out


def find_block(rom_bytes: bytes, needle: bytes) -> int:
    """Return offset of needle in rom_bytes, or -1 if not found / multiple."""
    first = rom_bytes.find(needle)
    if first < 0:
        return -1
    second = rom_bytes.find(needle, first + 1)
    if second >= 0:
        # Block appears more than once -> ambiguous. Caller decides whether
        # to reject or pick the first.
        return -2
    return first


def main() -> int:
    if not DISASM_DAT.exists():
        fail(f"missing disasm .dat: {DISASM_DAT}")
    needle = DISASM_DAT.read_bytes()
    needle_sha = hashlib.sha256(needle).hexdigest()
    print(f"target block: CommonSpritePatterns")
    print(f"  source:     {DISASM_DAT}")
    print(f"  size:       {len(needle)} bytes ({len(needle)//16} NES tiles)")
    print(f"  sha256:     {needle_sha}")
    print()

    lock = parse_lock(LOCK_FILE)

    fails = 0
    for variant, name in ROMS:
        rom_path = ROOT / name
        if not rom_path.exists():
            # ROMs live one dir up in the parent worktree (FINAL TRY root)
            alt = ROOT.parent / "FINAL TRY" / name
            if alt.exists():
                rom_path = alt
        if not rom_path.exists():
            fail(f"{variant}: ROM not found at {rom_path}")
        rom_bytes = rom_path.read_bytes()
        sha = hashlib.sha256(rom_bytes).hexdigest()
        if lock.get(variant) != sha:
            fail(
                f"{variant}: SHA-256 mismatch.\n"
                f"  lock: {lock.get(variant)}\n"
                f"  rom:  {sha}\n"
                f"  path: {rom_path}"
            )

        # Skip 16-byte iNES header for offset reporting clarity, but search
        # the entire file (some tools treat header bytes as PRG-prefixed).
        offset = find_block(rom_bytes, needle)
        if offset == -1:
            print(f"{variant}: block NOT found in {rom_path.name}")
            print(f"   -> Z1's runtime transfer may transform bytes pre-CHR-RAM,")
            print(f"      OR the block lives in a non-contiguous layout.")
            print(f"      Phase 1's verify_chr_live.py captures CHR RAM at the")
            print(f"      target address to disambiguate.")
            fails += 1
            continue
        if offset == -2:
            print(f"{variant}: block found in MULTIPLE locations -> ambiguous")
            print(f"   -> registry must cite the disasm-located offset, not")
            print(f"      a byte search.")
            fails += 1
            continue

        prg_offset = offset - 16  # iNES header bytes 0..15 are not PRG
        if offset >= 16:
            origin = "PRG"
            origin_offset = prg_offset
        else:
            origin = "iNES header (unexpected)"
            origin_offset = offset
        print(f"{variant}: block found byte-identical")
        print(f"  rom:           {rom_path.name}")
        print(f"  rom sha256:    {sha}")
        print(f"  file offset:   0x{offset:06X} ({offset})")
        print(f"  {origin} offset: 0x{origin_offset:06X} ({origin_offset})")
        print()

    if fails:
        return 1

    # Informational: redux variant divergence. Redux modifies sprite CHR
    # so the orig disasm .dat is not expected to byte-match; report PRG
    # offset of the closest-prefix match for documentation.
    print("informational variants (not part of pass/fail gate):")
    for variant, name in INFORMATIONAL_VARIANTS:
        rom_path = ROOT / name
        if not rom_path.exists():
            alt = ROOT.parent / "FINAL TRY" / name
            if alt.exists():
                rom_path = alt
        if not rom_path.exists():
            print(f"  {variant}: ROM not found at {rom_path}")
            continue
        rom_bytes = rom_path.read_bytes()
        sha = hashlib.sha256(rom_bytes).hexdigest()
        if lock.get(variant) != sha:
            print(f"  {variant}: SHA mismatch with lock (expected for Redux only "
                  f"if lock has stale hash); skipping byte-match")
            continue
        offset = find_block(rom_bytes, needle)
        if offset >= 0:
            print(f"  {variant}: orig disasm .dat MATCHES Redux PRG at offset "
                  f"0x{offset:06X} -- Redux apparently kept the orig sprite block")
        else:
            print(f"  {variant}: orig disasm .dat does NOT match Redux PRG "
                  f"(expected: Redux modifies sprite CHR)")

    print()
    print("phase0_prg_smoke: OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
