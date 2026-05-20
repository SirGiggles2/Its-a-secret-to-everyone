"""byte_atlas_audit_fix.py — clean byte-diff of Genesis atlas vs NES CHR
using LIVE captures from the chr-cycle probes. No palette gamut noise.

Reads:
  C:/tmp/chr_cycle_nes/bank{B}_sub{S}_page0_8x160.chr.bin  (8 KB NES PPU CHR)
  C:/tmp/chr_cycle_gen/bank{B}_sub{S}_page0_8x160.vram.bin (29 KB Genesis VRAM)

For each (bank, sub_pal) combo:
  - For tile_id in 0..255:
    - NES bytes: chr_nes[$1000 + tile_id*16 : +16]  (BG pattern table)
    - Genesis slot = bg_sparse_tile_lut[tile_id][sub_pal]
      Skip if 0xFFFF (sentinel, tile not in atlas).
    - Genesis VRAM bytes: vram_gen[(1 + slot) * 32 : +32]
    - Expected Genesis = pixel-bias(NES 2bpp, sub_pal) -> 4bpp Genesis
    - If actual != expected, log (bank, tile_id, sub_pal, slot, diff_count).

Modes:
  --report  (default) emit docs/atlas/byte_atlas_audit.md
  --fix     also patch RoomRom/src/bg_sparse_chr.c by re-encoding expected
            bytes for each divergent slot in the orig_ow / orig_uw blob.

Per user direction 2026-05-19: redux variants untouched.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys


REPO = pathlib.Path(__file__).resolve().parents[2]
NES_DIR = pathlib.Path("C:/tmp/chr_cycle_nes")
GEN_DIR = pathlib.Path("C:/tmp/chr_cycle_gen")
SPARSE_C = REPO / "RoomRom" / "src" / "bg_sparse_chr.c"
OUT_MD   = REPO / "docs" / "atlas" / "byte_atlas_audit.md"

BG_TILE_BASE = 1
TILE_BYTES   = 32   # Genesis 4bpp
NES_TILE_BYTES = 16 # NES 2bpp


def parse_sparse_lut(text: str) -> list[list[int]]:
    m = re.search(r"bg_sparse_tile_lut\[256\]\[4\][^=]*=\s*\{(.*?)\};", text, re.DOTALL)
    if not m:
        raise SystemExit("bg_sparse_tile_lut not found in bg_sparse_chr.c")
    body = m.group(1)
    rows = re.findall(
        r"\{\s*0x([0-9A-Fa-f]{4})\s*,\s*0x([0-9A-Fa-f]{4})\s*,"
        r"\s*0x([0-9A-Fa-f]{4})\s*,\s*0x([0-9A-Fa-f]{4})\s*\}",
        body)
    return [[int(c, 16) for c in row] for row in rows]


def nes_to_genesis_4bpp(nes16: bytes, sub_pal: int) -> bytes:
    """16-byte NES 2bpp tile -> 32-byte Genesis 4bpp w/ pixel-bias:
       out = (in == 0) ? 0 : (sub_pal * 4 + in)"""
    out = bytearray(TILE_BYTES)
    for row in range(8):
        p0 = nes16[row]
        p1 = nes16[row + 8]
        for col in range(8):
            bit0 = (p0 >> (7 - col)) & 1
            bit1 = (p1 >> (7 - col)) & 1
            pix2 = (bit1 << 1) | bit0
            pix4 = 0 if pix2 == 0 else (sub_pal * 4 + pix2)
            byte_idx = row * 4 + (col // 2)
            if col % 2 == 0:
                out[byte_idx] |= pix4 << 4
            else:
                out[byte_idx] |= pix4
    return bytes(out)


def state_name(bank, sub_pal):
    """Per-state filename anchor — page 0, 8x16 = 0 for BG audit."""
    return f"bank{bank}_sub{sub_pal}_page0_8x160"


def load_captures(bank, sub_pal):
    nes = (NES_DIR / f"{state_name(bank, sub_pal)}.chr.bin").read_bytes()
    gen = (GEN_DIR / f"{state_name(bank, sub_pal)}.vram.bin").read_bytes()
    return nes, gen


def get_nes_bg_tile(chr_bytes: bytes, tile_id: int) -> bytes:
    """NES BG pattern table at $1000+. Tile T occupies $1000 + T*16 .. +16."""
    off = 0x1000 + tile_id * NES_TILE_BYTES
    return chr_bytes[off:off + NES_TILE_BYTES]


def get_gen_slot_tile(vram_bytes: bytes, slot: int) -> bytes:
    """Genesis VRAM tile (BG_TILE_BASE + slot). Each tile = 32 bytes."""
    off = (BG_TILE_BASE + slot) * TILE_BYTES
    return vram_bytes[off:off + TILE_BYTES]


def audit(lut, bank, sub_pal, nes_chr, gen_vram):
    """Returns list of mismatches: [(tile_id, slot, mismatch_byte_count)]."""
    mismatches = []
    for tile_id in range(256):
        slot = lut[tile_id][sub_pal]
        if slot == 0xFFFF:
            continue
        nes_bytes = get_nes_bg_tile(nes_chr, tile_id)
        expected = nes_to_genesis_4bpp(nes_bytes, sub_pal)
        actual = get_gen_slot_tile(gen_vram, slot)
        if len(actual) < TILE_BYTES:
            continue
        diff = sum(1 for a, b in zip(actual, expected) if a != b)
        if diff > 0:
            mismatches.append((tile_id, slot, diff, expected, actual))
    return mismatches


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--fix", action="store_true",
                   help="patch bg_sparse_chr.c orig_* blobs to match NES")
    args = p.parse_args()

    sparse_text = SPARSE_C.read_text(encoding="utf-8", errors="ignore")
    lut = parse_sparse_lut(sparse_text)
    print(f"parsed bg_sparse_tile_lut: {len(lut)} tile_ids")

    # Audit each (bank, sub_pal) combo.
    all_mismatches = {}  # (bank, sub_pal) -> list
    for bank in range(8):
        for sub_pal in range(4):
            try:
                nes, gen = load_captures(bank, sub_pal)
            except FileNotFoundError as e:
                print(f"  bank={bank} sub_pal={sub_pal}: capture missing — skip")
                continue
            ms = audit(lut, bank, sub_pal, nes, gen)
            all_mismatches[(bank, sub_pal)] = ms

    total = sum(len(v) for v in all_mismatches.values())
    print(f"total mismatches across {len(all_mismatches)} (bank, sub_pal) combos: {total}")

    # Per-(bank, sub_pal) breakdown
    OUT_MD.parent.mkdir(parents=True, exist_ok=True)
    with OUT_MD.open("w", encoding="utf-8") as f:
        f.write("# Byte Atlas Audit — NES CHR vs Genesis VRAM\n\n")
        f.write(f"Generated by `tools/probes/byte_atlas_audit_fix.py`. "
                f"Per-state byte-diff using LIVE captures from probes "
                f"(no palette gamut noise).\n\n")
        f.write("**Pixel-bias formula:** "
                "`out = (in == 0) ? 0 : (sub_pal * 4 + in)` per "
                "`bg_sparse_chr.h:8`.\n\n")
        f.write(f"## Summary\n\n")
        f.write(f"Total mismatches: **{total}** across "
                f"{len(all_mismatches)} (bank, sub_pal) combos\n\n")
        f.write("| Bank | Sub | Mismatches |\n|---|---|---|\n")
        for (bank, sp), ms in sorted(all_mismatches.items()):
            f.write(f"| {bank} | {sp} | {len(ms)} |\n")
        f.write("\n---\n\n")
        # Detail per (bank, sub_pal)
        for (bank, sp), ms in sorted(all_mismatches.items()):
            f.write(f"## bank {bank} sub_pal {sp} — {len(ms)} mismatches\n\n")
            if not ms:
                f.write("_clean_\n\n")
                continue
            for tile_id, slot, diff, expected, actual in ms[:50]:
                f.write(f"- tile `\\${tile_id:02X}` slot {slot}: "
                        f"{diff}/32 bytes diverge\n")
                f.write(f"  - expected: `{expected.hex()}`\n")
                f.write(f"  - actual:   `{actual.hex()}`\n")
            if len(ms) > 50:
                f.write(f"\n_({len(ms) - 50} more — truncated)_\n")
            f.write("\n")
    print(f"wrote {OUT_MD}")

    if args.fix:
        print("\n--- patching bg_sparse_chr.c (orig_ow + orig_uw) ---")
        # For each divergent slot, write expected bytes into the blob.
        # Genesis uses orig_ow for banks 0/1 (OW), orig_uw for banks 2-7 (UW).
        # Slot is the same index in both blobs. Source NES bytes differ by bank.

        # Pick canonical source per slot:
        #   For each slot, find first (bank, sub_pal, tile_id) tuple that
        #   produces that slot (per sparse_lut). Use that NES bytes for the fix.
        slot_source = {}  # slot -> (tile_id, sub_pal)
        for tile_id in range(256):
            for sub_pal in range(4):
                s = lut[tile_id][sub_pal]
                if s != 0xFFFF and s not in slot_source:
                    slot_source[s] = (tile_id, sub_pal)

        # Build new blobs: orig_ow uses bank 0 or 1 NES captures; orig_uw uses
        # bank 2 NES captures.
        BLOB_SIZE = 532 * TILE_BYTES   # 17024
        new_ow = bytearray(BLOB_SIZE)
        new_uw = bytearray(BLOB_SIZE)

        # For each slot 0..531
        bank_ow = 1  # OW bank for sourcing $70+ scene tiles in orig_ow
        bank_uw = 2  # UW1/2/7 for orig_uw
        nes_ow_chr = (NES_DIR / f"bank{bank_ow}_sub0_page0_8x160.chr.bin").read_bytes()
        nes_uw_chr = (NES_DIR / f"bank{bank_uw}_sub0_page0_8x160.chr.bin").read_bytes()

        for slot, (tile_id, sub_pal) in slot_source.items():
            nes_bytes_ow = get_nes_bg_tile(nes_ow_chr, tile_id)
            nes_bytes_uw = get_nes_bg_tile(nes_uw_chr, tile_id)
            enc_ow = nes_to_genesis_4bpp(nes_bytes_ow, sub_pal)
            enc_uw = nes_to_genesis_4bpp(nes_bytes_uw, sub_pal)
            off = slot * TILE_BYTES
            new_ow[off:off + TILE_BYTES] = enc_ow
            new_uw[off:off + TILE_BYTES] = enc_uw

        # Patch bg_sparse_chr.c: replace bytes in orig_ow / orig_uw arrays.
        def fmt_blob(blob: bytes, name: str) -> str:
            lines = [f"const unsigned char {name}[17024] __attribute__((aligned(4))) = {{"]
            for i in range(0, len(blob), 16):
                row = blob[i:i + 16]
                lines.append("    " + ", ".join(f"0x{b:02X}" for b in row) + ",")
            # Trailing comma OK in C array
            lines.append("};")
            return "\n".join(lines)

        text = SPARSE_C.read_text(encoding="utf-8", errors="ignore")
        for name, blob in (("bg_sparse_chr_orig_ow", new_ow),
                           ("bg_sparse_chr_orig_uw", new_uw)):
            pat = re.compile(
                rf"const unsigned char {re.escape(name)}\[17024\][^=]*=\s*\{{(.*?)\}};",
                re.DOTALL)
            replacement = fmt_blob(blob, name)
            text, n = pat.subn(replacement, text, count=1)
            print(f"  patched {name}: replaced {n} block")

        SPARSE_C.write_text(text, encoding="utf-8")
        print(f"wrote {SPARSE_C}")


if __name__ == "__main__":
    sys.exit(main())
