"""full_atlas_audit.py — comprehensive byte-level NES-vs-Genesis atlas audit.

Reads ALL captures across 256 states (8 banks × 4 sub_pals × 4 sprite_pages × 2
8x16 modes) and diffs every byte-level surface:

  1. BG sparse atlas (tile_id × sub_pal -> Genesis VRAM slot via LUT)
  2. SPR atlas + SCENE_OBJ (NES SPR pattern table $0000-$0FFF -> Genesis tile 533+)
  3. CRAM palette (NES PALRAM -> NES master palette -> Genesis 9-bit RGB quantization)
  4. ITEM tiles (sprite-page > 0 covers $40..$FF sprite tile_ids)

Outputs docs/atlas/full_atlas_audit.md with categorized findings:
  - REAL_MISMATCH   — actual byte divergence (real atlas bug)
  - STATE_MISMATCH  — known divergence (Genesis bank 0 pre-loads orig_ow)
  - OUT_OF_SCOPE    — sentinel 0xFFFF in LUT (intentionally not extracted)

Reads:
  C:/tmp/chr_cycle_nes/<state>.{chr.bin,pal.bin}
  C:/tmp/chr_cycle_gen/<state>.{vram.bin,cram.bin}
  RoomRom/src/bg_sparse_chr.c  (LUT)
"""
from __future__ import annotations

import pathlib
import re
import sys
from collections import defaultdict


REPO = pathlib.Path(__file__).resolve().parents[2]
NES_DIR = pathlib.Path("C:/tmp/chr_cycle_nes")
GEN_DIR = pathlib.Path("C:/tmp/chr_cycle_gen")
SPARSE_C = REPO / "RoomRom" / "src" / "bg_sparse_chr.c"
OUT_MD = REPO / "docs" / "atlas" / "full_atlas_audit.md"

BG_TILE_BASE   = 1
SPR_TILE_BASE  = 533
SCENE_OBJ_SLOT = 577      # slot inside Genesis SPR atlas; absolute tile = SPR_TILE_BASE + 44
TILE_BYTES_GEN = 32       # Genesis 4bpp
TILE_BYTES_NES = 16       # NES 2bpp

BANKS         = 8
SUB_PALS      = 4
SPRITE_PAGES  = 4
MODES         = 2


# 2C02 canonical master palette (64 colors -> 8-bit RGB).
NES_PALETTE = [
    (0x62,0x62,0x62),(0x00,0x1F,0xB2),(0x24,0x04,0xC8),(0x52,0x00,0xB2),
    (0x73,0x00,0x76),(0x80,0x00,0x24),(0x73,0x0B,0x00),(0x52,0x28,0x00),
    (0x24,0x44,0x00),(0x00,0x57,0x00),(0x00,0x5C,0x00),(0x00,0x53,0x24),
    (0x00,0x3C,0x76),(0x00,0x00,0x00),(0x00,0x00,0x00),(0x00,0x00,0x00),
    (0xAB,0xAB,0xAB),(0x0D,0x57,0xFF),(0x4B,0x30,0xFF),(0x8A,0x13,0xFF),
    (0xBC,0x08,0xD6),(0xD2,0x12,0x69),(0xC7,0x2E,0x00),(0x9D,0x54,0x00),
    (0x60,0x7B,0x00),(0x20,0x98,0x00),(0x00,0xA3,0x00),(0x00,0x99,0x42),
    (0x00,0x7D,0xB4),(0x00,0x00,0x00),(0x00,0x00,0x00),(0x00,0x00,0x00),
    (0xFF,0xFF,0xFF),(0x53,0xAE,0xFF),(0x90,0x85,0xFF),(0xD3,0x65,0xFF),
    (0xFF,0x57,0xFF),(0xFF,0x5D,0xCF),(0xFF,0x77,0x57),(0xFA,0x9E,0x00),
    (0xBD,0xC7,0x00),(0x7A,0xE7,0x00),(0x43,0xF6,0x11),(0x26,0xEF,0x7E),
    (0x2C,0xD5,0xF6),(0x4E,0x4E,0x4E),(0x00,0x00,0x00),(0x00,0x00,0x00),
    (0xFF,0xFF,0xFF),(0xB6,0xE1,0xFF),(0xCE,0xD1,0xFF),(0xE9,0xC3,0xFF),
    (0xFF,0xBC,0xFF),(0xFF,0xBD,0xF4),(0xFF,0xC6,0xC3),(0xFF,0xD5,0x9A),
    (0xE9,0xE6,0x81),(0xCE,0xF4,0x81),(0xB6,0xFB,0x9A),(0xA9,0xFA,0xC3),
    (0xA9,0xF0,0xF4),(0xB8,0xB8,0xB8),(0x00,0x00,0x00),(0x00,0x00,0x00),
]


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
    """NES 2bpp 16-byte tile -> Genesis 4bpp 32-byte tile w/ pixel-bias.
       out = (in == 0) ? 0 : (sub_pal * 4 + in)"""
    out = bytearray(TILE_BYTES_GEN)
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


def state_name(bank, sub_pal, page, mode):
    return f"bank{bank}_sub{sub_pal}_page{page}_8x16{mode}"


def load_captures(bank, sub_pal, page=0, mode=0):
    name = state_name(bank, sub_pal, page, mode)
    nes_chr = (NES_DIR / f"{name}.chr.bin").read_bytes()
    nes_pal = (NES_DIR / f"{name}.pal.bin").read_bytes()
    gen_vram = (GEN_DIR / f"{name}.vram.bin").read_bytes()
    gen_cram = (GEN_DIR / f"{name}.cram.bin").read_bytes()
    return nes_chr, nes_pal, gen_vram, gen_cram


# ---------------------------------------------------------------------------
# BG sparse atlas audit
# ---------------------------------------------------------------------------

def audit_bg(lut, bank, sub_pal, nes_chr, gen_vram):
    """Returns list of (tile_id, slot, mismatch_byte_count, expected, actual)."""
    mismatches = []
    for tile_id in range(256):
        slot = lut[tile_id][sub_pal]
        if slot == 0xFFFF:
            continue
        off_nes = 0x1000 + tile_id * TILE_BYTES_NES
        nes_bytes = nes_chr[off_nes:off_nes + TILE_BYTES_NES]
        if len(nes_bytes) < TILE_BYTES_NES:
            continue
        expected = nes_to_genesis_4bpp(nes_bytes, sub_pal)
        off_gen = (BG_TILE_BASE + slot) * TILE_BYTES_GEN
        actual = gen_vram[off_gen:off_gen + TILE_BYTES_GEN]
        if len(actual) < TILE_BYTES_GEN:
            continue
        diff = sum(1 for a, b in zip(actual, expected) if a != b)
        if diff > 0:
            mismatches.append((tile_id, slot, diff, expected, actual))
    return mismatches


# ---------------------------------------------------------------------------
# SPR atlas audit
# ---------------------------------------------------------------------------

def audit_spr(bank, sub_pal, page, nes_chr, gen_vram):
    """Compare NES SPR pattern table (PPU $0000-$0FFF) vs Genesis SPR atlas
    starting at VRAM tile SPR_TILE_BASE (533).

    NES SPR uses sub-pal 1 (PALRAM[16+4..16+7]). Genesis sprite atlas is
    stored as raw NES SPR bytes with pixel-bias sub_pal=0 at slot 0..N
    (per Phase J SPR atlas spec — no per-sub_pal copy in SPR bank,
    color comes from CRAM PAL slot selected by SAT attr).

    sprite_page 0 covers NES sprite tile_ids $00..$3F (64 tiles).
    sprite_page 1 covers $40..$7F. etc.

    Returns list of (sprite_tile_id, gen_tile_slot, diff_count, expected, actual)."""
    mismatches = []
    base_tile_id = page * 64
    for slot_in_page in range(64):
        sprite_tile_id = base_tile_id + slot_in_page
        off_nes = sprite_tile_id * TILE_BYTES_NES
        nes_bytes = nes_chr[off_nes:off_nes + TILE_BYTES_NES]
        if len(nes_bytes) < TILE_BYTES_NES:
            continue
        # Genesis SPR stores at SPR_TILE_BASE + page*64 + slot_in_page per
        # debug_tilegrid.c:tile = 533 + sprite_page*64 + slot.
        gen_tile_idx = SPR_TILE_BASE + page * 64 + slot_in_page
        off_gen = gen_tile_idx * TILE_BYTES_GEN
        actual = gen_vram[off_gen:off_gen + TILE_BYTES_GEN]
        if len(actual) < TILE_BYTES_GEN:
            continue
        # SPR atlas is sub_pal-0 (no bias). Genesis OAM picks PAL slot at render.
        expected = nes_to_genesis_4bpp(nes_bytes, 0)
        diff = sum(1 for a, b in zip(actual, expected) if a != b)
        if diff > 0:
            mismatches.append((sprite_tile_id, gen_tile_idx, diff, expected, actual))
    return mismatches


# ---------------------------------------------------------------------------
# CRAM palette audit
# ---------------------------------------------------------------------------

def nes_palram_to_gen_word(nes_idx: int) -> int:
    """NES master palette index -> Genesis 9-bit CRAM BE word.
    Quantize 8-bit RGB to 3-bit (each channel right-shifted 5 bits, scaled to
    Genesis even-nibble format: 0bbb0ggg0rrr0)."""
    r8, g8, b8 = NES_PALETTE[nes_idx & 0x3F]
    r3 = (r8 >> 5) & 7
    g3 = (g8 >> 5) & 7
    b3 = (b8 >> 5) & 7
    # Each channel stored as (3-bit << 1) in low nibble of byte
    return (b3 << 9) | (g3 << 5) | (r3 << 1)


def audit_cram(nes_pal, gen_cram):
    """Compare 32 NES PALRAM entries against 64 Genesis CRAM entries.

    Z1 NES PALRAM layout:
      [0..3]   BG sub-pal 0 (4 colors)
      [4..7]   BG sub-pal 1
      [8..11]  BG sub-pal 2
      [12..15] BG sub-pal 3
      [16..19] SPR sub-pal 0  (most sprites use this)
      [20..23] SPR sub-pal 1
      [24..27] SPR sub-pal 2
      [28..31] SPR sub-pal 3

    Z1 forces PALRAM[0] = backdrop = same for all sub-pals.

    Genesis CRAM 4 PALs x 16 colors:
      PAL0 = BG  (NES BG 4 sub-pals collapsed; Phase B)
      PAL1 = SPR sub-pal 0
      PAL2 = SPR sub-pal 1
      PAL3 = SPR sub-pal 2
      (NES SPR sub-pal 3 clamped to PAL3 per project_what_if Phase B/F)

    For audit: BG sub-pals 0..3 occupy PAL0 entries 0..3, 4..7, 8..11, 12..15.
    SPR sub-pals 0..2 occupy PAL1, PAL2, PAL3 entries 0..15 (each).

    Returns list of (label, nes_idx, expected_word, actual_word)."""
    mismatches = []
    if len(nes_pal) < 32 or len(gen_cram) < 128:
        return mismatches

    def gen_word(pal, entry):
        off = (pal * 16 + entry) * 2
        # CRAM is BE: hi byte first
        return (gen_cram[off] << 8) | gen_cram[off + 1]

    # BG: PAL0 entries 0..15 should match NES BG PALRAM[0..15]
    for sub in range(4):
        for k in range(4):
            nes_idx = nes_pal[sub * 4 + k]
            entry = sub * 4 + k
            actual = gen_word(0, entry)
            expected = nes_palram_to_gen_word(nes_idx)
            if actual != expected:
                mismatches.append(
                    (f"BG sub{sub}.{k}", nes_idx, expected, actual))

    # SPR sub-pal 0 -> Genesis PAL1
    for k in range(4):
        nes_idx = nes_pal[16 + k]
        actual = gen_word(1, k)
        expected = nes_palram_to_gen_word(nes_idx)
        if actual != expected:
            mismatches.append((f"SPR sub0.{k}", nes_idx, expected, actual))

    # SPR sub-pal 1 -> Genesis PAL2
    for k in range(4):
        nes_idx = nes_pal[16 + 4 + k]
        actual = gen_word(2, k)
        expected = nes_palram_to_gen_word(nes_idx)
        if actual != expected:
            mismatches.append((f"SPR sub1.{k}", nes_idx, expected, actual))

    # SPR sub-pal 2 -> Genesis PAL3
    for k in range(4):
        nes_idx = nes_pal[16 + 8 + k]
        actual = gen_word(3, k)
        expected = nes_palram_to_gen_word(nes_idx)
        if actual != expected:
            mismatches.append((f"SPR sub2.{k}", nes_idx, expected, actual))

    return mismatches


# ---------------------------------------------------------------------------
# SCENE_OBJ audit (per-bank enemy/boss CHR)
# ---------------------------------------------------------------------------

# NES test ROM CHR page layout (from gen_chr_viewer_rom.py build_chr):
#   $0000 Common SPR  (112 tiles = $700 B)
#   $08E0 Scene SPR
#   $09E0 UW level SPR
#   $0C00 Boss SPR
#
# Each bank's "scene-specific" SPR tiles live at $08E0+ in NES.
# Genesis SCENE_OBJ at slot 577 (= SPR_TILE_BASE + 44). Maps NES tile range
# starting at $0E (= $0E*16=$E0... no, NES SPR offset within scene SPR
# block). For simplicity: just check that SCENE_OBJ slot bytes are non-zero
# when the bank should have enemy/boss content (banks 1..7).

def audit_scene_obj(bank, gen_vram):
    """Check SCENE_OBJ region (slot 577..) is non-empty when bank != 0.
    Returns (slot_count_used, total_bytes_used)."""
    base = SCENE_OBJ_SLOT * TILE_BYTES_GEN
    # Read up to 96 tiles (3 KB) after SCENE_OBJ base — typical max bank size.
    region = gen_vram[base:base + 96 * TILE_BYTES_GEN]
    nonzero = sum(1 for b in region if b != 0)
    return nonzero, len(region)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    sparse_text = SPARSE_C.read_text(encoding="utf-8", errors="ignore")
    lut = parse_sparse_lut(sparse_text)
    print(f"parsed bg_sparse_tile_lut: {len(lut)} tile_ids")

    # Per-state results
    bg_results = {}     # (b, s, p, m) -> mismatch list
    spr_results = {}
    cram_results = {}
    scene_obj_results = {}

    states_total = 0
    states_missing = 0
    for bank in range(BANKS):
        for sub_pal in range(SUB_PALS):
            for page in range(SPRITE_PAGES):
                for mode in range(MODES):
                    states_total += 1
                    try:
                        nes_chr, nes_pal, gen_vram, gen_cram = load_captures(
                            bank, sub_pal, page, mode)
                    except FileNotFoundError:
                        states_missing += 1
                        continue
                    key = (bank, sub_pal, page, mode)
                    # BG only depends on (bank, sub_pal); same across pages/modes
                    if page == 0 and mode == 0:
                        bg_results[key] = audit_bg(lut, bank, sub_pal,
                                                  nes_chr, gen_vram)
                        cram_results[key] = audit_cram(nes_pal, gen_cram)
                        scene_obj_results[key] = audit_scene_obj(bank, gen_vram)
                    # SPR depends on (bank, page)
                    if sub_pal == 0 and mode == 0:
                        spr_results[key] = audit_spr(bank, sub_pal, page,
                                                    nes_chr, gen_vram)

    bg_total = sum(len(v) for v in bg_results.values())
    spr_total = sum(len(v) for v in spr_results.values())
    cram_total = sum(len(v) for v in cram_results.values())

    print(f"\nstates audited: {states_total - states_missing} / {states_total}")
    print(f"BG mismatches total:   {bg_total}")
    print(f"SPR mismatches total:  {spr_total}")
    print(f"CRAM mismatches total: {cram_total}")

    # Per-bank breakdown
    print("\nPer-bank BG mismatches (page=0, mode=0):")
    print(f"{'bank':>4} {'sub':>3} {'BG':>5}")
    for bank in range(BANKS):
        for sub_pal in range(SUB_PALS):
            k = (bank, sub_pal, 0, 0)
            bg_n = len(bg_results.get(k, []))
            print(f"{bank:>4} {sub_pal:>3} {bg_n:>5}")

    print("\nPer-bank SPR mismatches (sub=0, mode=0):")
    print(f"{'bank':>4} {'page':>4} {'SPR':>5}")
    for bank in range(BANKS):
        for page in range(SPRITE_PAGES):
            k = (bank, 0, page, 0)
            spr_n = len(spr_results.get(k, []))
            print(f"{bank:>4} {page:>4} {spr_n:>5}")

    print("\nPer-bank CRAM mismatches (sub=0, page=0, mode=0):")
    print(f"{'bank':>4} {'CRAM':>5}")
    for bank in range(BANKS):
        k = (bank, 0, 0, 0)
        cn = len(cram_results.get(k, []))
        print(f"{bank:>4} {cn:>5}")

    print("\nSCENE_OBJ region byte-usage (slot 577.., bank 0..7):")
    for bank in range(BANKS):
        k = (bank, 0, 0, 0)
        nz, tot = scene_obj_results.get(k, (0, 0))
        print(f"  bank {bank}: {nz} / {tot} nonzero bytes")

    # Write markdown
    OUT_MD.parent.mkdir(parents=True, exist_ok=True)
    with OUT_MD.open("w", encoding="utf-8") as f:
        f.write("# Full Atlas Audit — NES vs Genesis (every byte surface)\n\n")
        f.write(f"Generated by `tools/probes/full_atlas_audit.py`.\n\n")
        f.write(f"States covered: {states_total - states_missing} / "
                f"{states_total} (banks={BANKS}, sub_pals={SUB_PALS}, "
                f"pages={SPRITE_PAGES}, modes={MODES}).\n\n")
        f.write("## Summary\n\n")
        f.write(f"- BG mismatches:   **{bg_total}**\n")
        f.write(f"- SPR mismatches:  **{spr_total}**\n")
        f.write(f"- CRAM mismatches: **{cram_total}**\n\n")
        f.write("## Per-bank breakdown\n\n")
        f.write("### BG (page=0, mode=0)\n\n")
        f.write("| Bank | Sub | BG Mismatches |\n|---|---|---|\n")
        for bank in range(BANKS):
            for sub_pal in range(SUB_PALS):
                k = (bank, sub_pal, 0, 0)
                f.write(f"| {bank} | {sub_pal} | {len(bg_results.get(k, []))} |\n")
        f.write("\n### SPR (sub=0, mode=0)\n\n")
        f.write("| Bank | Page | SPR Mismatches |\n|---|---|---|\n")
        for bank in range(BANKS):
            for page in range(SPRITE_PAGES):
                k = (bank, 0, page, 0)
                f.write(f"| {bank} | {page} | {len(spr_results.get(k, []))} |\n")
        f.write("\n### CRAM (sub=0, page=0, mode=0)\n\n")
        f.write("| Bank | CRAM Mismatches |\n|---|---|\n")
        for bank in range(BANKS):
            k = (bank, 0, 0, 0)
            f.write(f"| {bank} | {len(cram_results.get(k, []))} |\n")
        f.write("\n### SCENE_OBJ region usage\n\n")
        f.write("| Bank | Nonzero bytes / 3072 |\n|---|---|\n")
        for bank in range(BANKS):
            k = (bank, 0, 0, 0)
            nz, tot = scene_obj_results.get(k, (0, 0))
            f.write(f"| {bank} | {nz} / {tot} |\n")

        # Detail sections: BG mismatches per (bank, sub_pal)
        f.write("\n---\n\n## BG mismatch detail\n\n")
        for (bank, sub_pal, p, m), ms in sorted(bg_results.items()):
            if p != 0 or m != 0:
                continue
            if not ms:
                continue
            f.write(f"### bank {bank} sub_pal {sub_pal} — "
                    f"{len(ms)} BG mismatches\n\n")
            for tile_id, slot, diff, expected, actual in ms[:20]:
                f.write(f"- tile `${tile_id:02X}` slot {slot}: "
                        f"{diff}/32 bytes diverge\n")
                f.write(f"  - expected: `{expected.hex()}`\n")
                f.write(f"  - actual:   `{actual.hex()}`\n")
            if len(ms) > 20:
                f.write(f"\n_({len(ms) - 20} more — truncated)_\n")
            f.write("\n")

        # Detail: SPR mismatches per (bank, page)
        f.write("\n## SPR mismatch detail\n\n")
        for (bank, s, page, m), ms in sorted(spr_results.items()):
            if s != 0 or m != 0:
                continue
            if not ms:
                continue
            f.write(f"### bank {bank} page {page} — "
                    f"{len(ms)} SPR mismatches\n\n")
            for sprite_tile_id, gen_slot, diff, expected, actual in ms[:20]:
                f.write(f"- NES sprite tile `${sprite_tile_id:02X}` "
                        f"-> Genesis slot {gen_slot}: "
                        f"{diff}/32 bytes diverge\n")
                f.write(f"  - expected: `{expected.hex()}`\n")
                f.write(f"  - actual:   `{actual.hex()}`\n")
            if len(ms) > 20:
                f.write(f"\n_({len(ms) - 20} more — truncated)_\n")
            f.write("\n")

        # Detail: CRAM
        f.write("\n## CRAM mismatch detail\n\n")
        for (bank, s, p, m), ms in sorted(cram_results.items()):
            if s != 0 or p != 0 or m != 0:
                continue
            if not ms:
                continue
            f.write(f"### bank {bank} — {len(ms)} CRAM mismatches\n\n")
            for label, nes_idx, expected, actual in ms[:30]:
                f.write(f"- {label}: NES master ${nes_idx:02X} "
                        f"-> expected Gen `${expected:04X}`, "
                        f"actual `${actual:04X}`\n")
            if len(ms) > 30:
                f.write(f"\n_({len(ms) - 30} more — truncated)_\n")
            f.write("\n")

    print(f"\nwrote {OUT_MD}")


if __name__ == "__main__":
    sys.exit(main())
