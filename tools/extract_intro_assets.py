"""Extract Zelda intro assets from the committed disassembly reference tree.

Reads reference/aldonunez/dat/ and emits src/gen/intro_*.c files containing
font CHR, art CHR, palette table, story tilemap, showcase tilemap, restore
blobs, and a handoff-state struct. Also emits src/gen/intro_asset_hashes.txt
listing SHA256 of every output for regression detection.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent

def nes_tile_to_gen_tile(nes: bytes) -> bytes:
    """Convert a single 8x8 NES 2bpp tile (16 bytes) to Genesis 4bpp (32 bytes).

    NES layout: 8 bytes of bitplane 0 (rows 0..7), then 8 bytes of bitplane 1.
    Genesis layout: 8 rows x 4 bytes/row; each row packs 8 pixels as 4-bit
    indices, high nibble first.
    """
    if len(nes) != 16:
        raise ValueError(f"nes tile must be 16 bytes, got {len(nes)}")
    out = bytearray(32)
    for row in range(8):
        bp0 = nes[row]
        bp1 = nes[row + 8]
        row_out = bytearray(4)
        for px in range(8):
            bit = 7 - px
            color = ((bp0 >> bit) & 1) | (((bp1 >> bit) & 1) << 1)
            byte_idx = px >> 1
            if (px & 1) == 0:
                row_out[byte_idx] |= (color & 0x0F) << 4
            else:
                row_out[byte_idx] |= (color & 0x0F)
        out[row * 4:(row + 1) * 4] = row_out
    return bytes(out)

def main() -> int:
    ap = argparse.ArgumentParser(description="extract intro assets")
    ap.add_argument("--ref-dir", default=str(REPO / "reference" / "aldonunez" / "dat"),
                    help="path to committed disassembly reference data")
    ap.add_argument("--out-dir", default=str(REPO / "src" / "gen"),
                    help="output directory for generated C files")
    ap.add_argument("--handoff-json", default=str(REPO / "docs" / "superpowers" /
                    "captures" / "2026-04-24-intro-handoff-state.json"),
                    help="captured handoff state JSON")
    ap.add_argument("--restore-chr", default=str(REPO / "docs" / "superpowers" /
                    "captures" / "2026-04-24-intro-restore-chr.bin"))
    ap.add_argument("--restore-cram", default=str(REPO / "docs" / "superpowers" /
                    "captures" / "2026-04-24-intro-restore-cram.bin"))
    ap.add_argument("--verify", action="store_true",
                    help="re-check SHA of emitted files against committed hashes")
    args = ap.parse_args()

    ref_dir = Path(args.ref_dir)
    if not ref_dir.is_dir():
        print(f"error: reference dir not found: {ref_dir}", file=sys.stderr)
        return 2
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    # Subsequent tasks fill in the emit steps.
    emitted: dict[str, str] = {}

    hash_file = out_dir / "intro_asset_hashes.txt"
    if args.verify:
        return _verify(emitted, hash_file)
    _write_hashes(emitted, hash_file)
    return 0

def _sha(path: Path) -> str:
    h = hashlib.sha256()
    h.update(path.read_bytes())
    return h.hexdigest()

def _write_hashes(emitted: dict[str, str], hash_file: Path) -> None:
    lines = [f"{sha}  {name}\n" for name, sha in sorted(emitted.items())]
    hash_file.write_text("".join(lines))

def _verify(emitted: dict[str, str], hash_file: Path) -> int:
    if not hash_file.exists():
        print(f"error: hash file missing: {hash_file}", file=sys.stderr)
        return 3
    expected = {}
    for line in hash_file.read_text().splitlines():
        sha, name = line.split("  ", 1)
        expected[name] = sha
    if expected != emitted:
        print("error: emitted SHA set differs from committed", file=sys.stderr)
        return 3
    return 0

if __name__ == "__main__":
    sys.exit(main())
