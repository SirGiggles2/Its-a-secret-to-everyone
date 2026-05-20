"""full_atlas_audit_v2.py — comprehensive byte audit with port-correct mappings.

Improvements over v1:
  - CRAM uses port's misc_palettes table (data/misc/palettes.c) for expected,
    not canonical 2C02. Port quantizes differently than 6-bit NES master.
  - SPR audit limited to first 44 Common SPR tiles (NES $00..$2B), which is
    the only region preserved before SCENE_OBJ overlay at SPR_BASE+44=577.
  - SCENE_OBJ audit: compare Genesis VRAM slot 577..577+N to per-bank enemy
    blob bytes from RoomRom/src/atlas/enemy_chr.c.
  - BG bank 0 still mismatches (Genesis bank 0 = orig_ow, NES bank 0 = Common-
    only). Documented STATE_MISMATCH, not a real bug.
"""
from __future__ import annotations

import pathlib
import re
import sys


REPO = pathlib.Path(__file__).resolve().parents[2]
NES_DIR = pathlib.Path("C:/tmp/chr_cycle_nes")
GEN_DIR = pathlib.Path("C:/tmp/chr_cycle_gen")
SPARSE_C = REPO / "RoomRom" / "src" / "bg_sparse_chr.c"
PALETTE_C = REPO / "data" / "misc" / "palettes.c"
ENEMY_C = REPO / "RoomRom" / "src" / "atlas" / "enemy_chr.c"
OUT_MD = REPO / "docs" / "atlas" / "full_atlas_audit_v2.md"

BG_TILE_BASE   = 1
SPR_TILE_BASE  = 533
SCENE_OBJ_SLOT = 577      # SPR_TILE_BASE + 44
TILE_BYTES_GEN = 32
TILE_BYTES_NES = 16

# Common SPR tiles preserved (not overwritten by SCENE_OBJ).
# Genesis slot range 533..576 (44 slots) maps to NES SPR tile_ids $00..$2B.
COMMON_SPR_PRESERVED = 44


def parse_c_array(path: pathlib.Path, name: str) -> bytes:
    text = path.read_text(encoding="utf-8", errors="ignore")
    # Accept literal size or macro name as array dimension.
    pat = re.compile(
        r"const\s+unsigned\s+char\s+" + re.escape(name) +
        r"\s*\[\s*[A-Za-z0-9_]+\s*\]\s*(?:[^=]*?)=\s*\{(.*?)\}",
        re.MULTILINE | re.DOTALL)
    m = pat.search(text)
    if not m:
        raise SystemExit(f"{path}: array `{name}` not found")
    body = m.group(1)
    return bytes(int(t.group(1), 16) for t in re.finditer(r"0x([0-9A-Fa-f]{1,2})", body))


def parse_sparse_lut(text: str) -> list[list[int]]:
    m = re.search(r"bg_sparse_tile_lut\[256\]\[4\][^=]*=\s*\{(.*?)\};", text, re.DOTALL)
    body = m.group(1)
    rows = re.findall(
        r"\{\s*0x([0-9A-Fa-f]{4})\s*,\s*0x([0-9A-Fa-f]{4})\s*,"
        r"\s*0x([0-9A-Fa-f]{4})\s*,\s*0x([0-9A-Fa-f]{4})\s*\}",
        body)
    return [[int(c, 16) for c in row] for row in rows]


def nes_to_genesis_4bpp(nes16: bytes, sub_pal: int) -> bytes:
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
# BG sparse atlas
# ---------------------------------------------------------------------------

def audit_bg(lut, sub_pal, nes_chr, gen_vram):
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
# Common SPR (first 44 preserved tiles)
# ---------------------------------------------------------------------------

def audit_common_spr(nes_chr, gen_vram):
    """Compare NES SPR tile_ids $00..$2B to Genesis VRAM slots 533..576.
    SPR atlas in Genesis is loaded via roomrom_sprites_upload_persistent_chr
    which uploads common.c verbatim (SPR section first 44 tiles = NES SPR
    $00..$2B). After slot 577, SCENE_OBJ overlay overwrites — those slots
    are audited separately."""
    mismatches = []
    for tile_id in range(COMMON_SPR_PRESERVED):
        off_nes = tile_id * TILE_BYTES_NES   # SPR table at PPU $0000+
        nes_bytes = nes_chr[off_nes:off_nes + TILE_BYTES_NES]
        if len(nes_bytes) < TILE_BYTES_NES:
            continue
        # SPR atlas in Genesis stores sub_pal-0 bytes (no bias). OAM picks PAL.
        expected = nes_to_genesis_4bpp(nes_bytes, 0)
        gen_tile = SPR_TILE_BASE + tile_id
        off_gen = gen_tile * TILE_BYTES_GEN
        actual = gen_vram[off_gen:off_gen + TILE_BYTES_GEN]
        diff = sum(1 for a, b in zip(actual, expected) if a != b)
        if diff > 0:
            mismatches.append((tile_id, gen_tile, diff, expected, actual))
    return mismatches


# ---------------------------------------------------------------------------
# SCENE_OBJ per-bank enemy/boss CHR
# ---------------------------------------------------------------------------

def audit_scene_obj(bank, gen_vram, enemy_blobs):
    """Compare Genesis VRAM at slot 577..577+N against the per-bank enemy
    blob in enemy_chr.c. enemy_blobs is a dict of bank->bytes.
    Returns (slot_count_mismatch, total_byte_diff, expected, actual)."""
    blob = enemy_blobs.get(bank)
    if blob is None:
        return (0, 0, b"", b"")
    base_off = SCENE_OBJ_SLOT * TILE_BYTES_GEN
    actual = gen_vram[base_off:base_off + len(blob)]
    if len(actual) < len(blob):
        return (1, len(blob), blob, actual)
    diff_bytes = sum(1 for a, b in zip(actual, blob) if a != b)
    diff_tiles = 0
    for tile_idx in range(len(blob) // TILE_BYTES_GEN):
        t_off = tile_idx * TILE_BYTES_GEN
        if blob[t_off:t_off + TILE_BYTES_GEN] != actual[t_off:t_off + TILE_BYTES_GEN]:
            diff_tiles += 1
    return (diff_tiles, diff_bytes, blob, actual)


def load_enemy_blobs():
    """Per-bank SCENE_OBJ blob. Maps bank index -> bytes.
    Bank 0 = no overlay. Bank 1 = OW (114 tiles). 2-4 = UW level. 5-7 = bosses."""
    blobs = {}
    # OW
    blobs[1] = parse_c_array(ENEMY_C, "roomrom_atlas_enemy_owsp")
    # UW levels
    blobs[2] = parse_c_array(ENEMY_C, "roomrom_atlas_enemy_uwsp127")
    blobs[3] = parse_c_array(ENEMY_C, "roomrom_atlas_enemy_uwsp358")
    blobs[4] = parse_c_array(ENEMY_C, "roomrom_atlas_enemy_uwsp469")
    # Boss banks — read boss_chr.c if exists
    boss_c = REPO / "RoomRom" / "src" / "atlas" / "boss_chr.c"
    if boss_c.exists():
        for bank, name in ((5, "roomrom_atlas_boss_uwspboss1257"),
                           (6, "roomrom_atlas_boss_uwspboss3468"),
                           (7, "roomrom_atlas_boss_uwspboss9")):
            try:
                blobs[bank] = parse_c_array(boss_c, name)
            except SystemExit:
                pass
    return blobs


# ---------------------------------------------------------------------------
# CRAM via port's misc_palettes table
# ---------------------------------------------------------------------------

def load_misc_palette_lut(path: pathlib.Path) -> list[int]:
    """First 128 bytes of misc_palettes = NES color $00..$3F -> Genesis CRAM
    word (LE in C array, BE on wire). Returns list of 64 16-bit values."""
    raw = parse_c_array(path, "misc_palettes")
    lut = []
    for i in range(64):
        # LE: low byte first, high byte second (matches roomrom_bg_palette_nes_to_cram)
        lut.append(raw[i * 2] | (raw[i * 2 + 1] << 8))
    return lut


def nes_color_to_gen_word_port(nes_idx: int, lut: list[int]) -> int:
    return lut[nes_idx & 0x3F]


def audit_cram(nes_pal, gen_cram, palette_lut):
    """Compare 32 NES PALRAM entries against 64 Genesis CRAM entries using
    the port's misc_palettes lookup table."""
    mismatches = []
    if len(nes_pal) < 32 or len(gen_cram) < 128:
        return mismatches

    def gen_word(pal, entry):
        off = (pal * 16 + entry) * 2
        return (gen_cram[off] << 8) | gen_cram[off + 1]

    # PAL0[0..15] = NES BG PALRAM[0..15]
    for entry in range(16):
        nes_idx = nes_pal[entry]
        actual = gen_word(0, entry)
        expected = nes_color_to_gen_word_port(nes_idx, palette_lut)
        if actual != expected:
            mismatches.append((f"PAL0[{entry}] BG sub{entry//4}.{entry%4}",
                               nes_idx, expected, actual))

    # PAL1[1..3] = NES SPR PALRAM[17..19]. PAL1[0] is PPU-mirrored
    # (NES $3F10 reads as $3F00 = universal backdrop) so the literal
    # byte at PALRAM[16] doesn't define the displayed color; PPU shows
    # PALRAM[0]. Genesis transparent-color-0 convention matches NES
    # backdrop semantics regardless. Skip [0] to avoid false positive.
    for k in (1, 2, 3):
        nes_idx = nes_pal[16 + k]
        actual = gen_word(1, k)
        expected = nes_color_to_gen_word_port(nes_idx, palette_lut)
        if actual != expected:
            mismatches.append((f"PAL1[{k}] SPR sub0.{k}",
                               nes_idx, expected, actual))

    # PAL2[1..3] = NES SPR sub-pal 1 entries 1..3 (PALRAM[16+5..16+7]).
    # PAL2[0] mirrors PALRAM[$04] -> PALRAM[$00] = backdrop. Port writes
    # 0 for Genesis transparent convention. Skip [0].
    for k in (1, 2, 3):
        nes_idx = nes_pal[16 + 4 + k]
        actual = gen_word(2, k)
        expected = nes_color_to_gen_word_port(nes_idx, palette_lut)
        if actual != expected:
            mismatches.append((f"PAL2[{k}] SPR sub1.{k}",
                               nes_idx, expected, actual))

    # PAL3[1..3] = NES SPR sub-pal 2 entries 1..3 (PALRAM[16+9..16+11]).
    # PAL3[0] mirrors PALRAM[$08] -> PALRAM[$00] = backdrop. Skip [0].
    for k in (1, 2, 3):
        nes_idx = nes_pal[16 + 8 + k]
        actual = gen_word(3, k)
        expected = nes_color_to_gen_word_port(nes_idx, palette_lut)
        if actual != expected:
            mismatches.append((f"PAL3[{k}] SPR sub2.{k}",
                               nes_idx, expected, actual))

    return mismatches


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    sparse_text = SPARSE_C.read_text(encoding="utf-8", errors="ignore")
    lut = parse_sparse_lut(sparse_text)
    print(f"parsed bg_sparse_tile_lut: {len(lut)} tile_ids")

    palette_lut = load_misc_palette_lut(PALETTE_C)
    print(f"loaded misc_palettes table: {len(palette_lut)} entries")

    enemy_blobs = load_enemy_blobs()
    print(f"loaded SCENE_OBJ blobs for banks: "
          f"{sorted(enemy_blobs.keys())} ({[len(b) for k,b in sorted(enemy_blobs.items())]} bytes)")

    bg_results = {}        # (bank, sub_pal) -> list
    spr_results = {}       # bank -> list (page=0 only — SPR is bank+page indexed but Common SPR is page-independent)
    cram_results = {}      # bank -> list
    sobj_results = {}      # bank -> tuple

    for bank in range(8):
        try:
            nes_chr, nes_pal, gen_vram, gen_cram = load_captures(bank, 0, 0, 0)
        except FileNotFoundError:
            continue
        # SPR + CRAM + SCENE_OBJ depend on bank only (sub=0, page=0).
        spr_results[bank] = audit_common_spr(nes_chr, gen_vram)
        cram_results[bank] = audit_cram(nes_pal, gen_cram, palette_lut)
        sobj_results[bank] = audit_scene_obj(bank, gen_vram, enemy_blobs)

        # BG per sub_pal
        for sub_pal in range(4):
            try:
                nes_chr_s, _, gen_vram_s, _ = load_captures(bank, sub_pal, 0, 0)
            except FileNotFoundError:
                continue
            bg_results[(bank, sub_pal)] = audit_bg(lut, sub_pal,
                                                   nes_chr_s, gen_vram_s)

    bg_total = sum(len(v) for v in bg_results.values())
    spr_total = sum(len(v) for v in spr_results.values())
    cram_total = sum(len(v) for v in cram_results.values())
    sobj_total = sum(v[0] for v in sobj_results.values())

    print(f"\nResults:")
    print(f"BG mismatches:           {bg_total} (bank 0 is STATE_MISMATCH)")
    print(f"Common SPR mismatches:   {spr_total}")
    print(f"CRAM mismatches:         {cram_total}")
    print(f"SCENE_OBJ mismatch tiles:{sobj_total}")

    # Excluding bank 0 from BG (state mismatch)
    bg_real = sum(len(v) for (b, _), v in bg_results.items() if b != 0)
    print(f"\nBG mismatches excluding bank 0: {bg_real} (real atlas drift)")

    print("\nPer-bank BG sub_pal 0:")
    for bank in range(8):
        for sp in range(4):
            n = len(bg_results.get((bank, sp), []))
            if n > 0:
                print(f"  bank{bank} sub{sp}: {n}")

    print("\nPer-bank SCENE_OBJ:")
    for bank in range(8):
        if bank in sobj_results:
            tiles, bytesd, blob, _ = sobj_results[bank]
            print(f"  bank{bank}: {tiles} tile mismatches "
                  f"({bytesd} byte mismatches / {len(blob)} blob bytes)")

    print("\nPer-bank CRAM:")
    for bank in range(8):
        n = len(cram_results.get(bank, []))
        print(f"  bank{bank}: {n} entries mismatched")

    print("\nPer-bank Common SPR (first 44 tiles, NES $00..$2B):")
    for bank in range(8):
        n = len(spr_results.get(bank, []))
        print(f"  bank{bank}: {n} tile mismatches")

    # Markdown report
    OUT_MD.parent.mkdir(parents=True, exist_ok=True)
    with OUT_MD.open("w", encoding="utf-8") as f:
        f.write("# Full Atlas Audit v2 — port-correct mappings\n\n")
        f.write(f"Generated by `tools/probes/full_atlas_audit_v2.py`. Uses port's "
                f"`misc_palettes` lookup for CRAM and correct SPR layout "
                f"(Common SPR first 44 tiles + SCENE_OBJ overlay).\n\n")
        f.write("## Summary\n\n")
        f.write(f"| Surface | Mismatches |\n|---|---|\n")
        f.write(f"| BG sparse (all banks) | {bg_total} |\n")
        f.write(f"| BG sparse (banks 1-7 only) | {bg_real} |\n")
        f.write(f"| Common SPR (NES $00..$2B) | {spr_total} |\n")
        f.write(f"| CRAM (32 entries × 8 banks) | {cram_total} |\n")
        f.write(f"| SCENE_OBJ tile mismatches | {sobj_total} |\n\n")

        f.write("## Per-bank breakdown\n\n")
        f.write("### BG sub_pal × bank\n\n")
        f.write("| Bank | sub0 | sub1 | sub2 | sub3 |\n|---|---|---|---|---|\n")
        for bank in range(8):
            cnts = [len(bg_results.get((bank, sp), [])) for sp in range(4)]
            f.write(f"| {bank} | {cnts[0]} | {cnts[1]} | {cnts[2]} | {cnts[3]} |\n")
        f.write("\n### SCENE_OBJ\n\n")
        f.write("| Bank | Mismatch tiles | Mismatch bytes | Blob bytes |\n|---|---|---|---|\n")
        for bank in range(8):
            if bank in sobj_results:
                tiles, bytesd, blob, _ = sobj_results[bank]
                f.write(f"| {bank} | {tiles} | {bytesd} | {len(blob)} |\n")
            else:
                f.write(f"| {bank} | (no blob) | - | - |\n")
        f.write("\n### CRAM\n\n")
        f.write("| Bank | Mismatches |\n|---|---|\n")
        for bank in range(8):
            f.write(f"| {bank} | {len(cram_results.get(bank, []))} |\n")
        f.write("\n### Common SPR\n\n")
        f.write("| Bank | Mismatches |\n|---|---|\n")
        for bank in range(8):
            f.write(f"| {bank} | {len(spr_results.get(bank, []))} |\n")

        # Detail sections
        f.write("\n---\n\n## Detail\n\n")
        if bg_real > 0:
            f.write("### BG mismatches (excl bank 0)\n\n")
            for (bank, sp), ms in sorted(bg_results.items()):
                if bank == 0:
                    continue
                if not ms:
                    continue
                f.write(f"#### bank {bank} sub_pal {sp} — {len(ms)}\n\n")
                for tid, slot, diff, exp, act in ms[:15]:
                    f.write(f"- tile `${tid:02X}` slot {slot}: {diff}/32 diverge\n")
                    f.write(f"  - expected: `{exp.hex()}`\n")
                    f.write(f"  - actual:   `{act.hex()}`\n")
                f.write("\n")

        if spr_total > 0:
            f.write("### Common SPR mismatches\n\n")
            for bank in range(8):
                ms = spr_results.get(bank, [])
                if not ms:
                    continue
                f.write(f"#### bank {bank} — {len(ms)}\n\n")
                for tid, slot, diff, exp, act in ms[:20]:
                    f.write(f"- NES SPR `${tid:02X}` -> slot {slot}: {diff}/32 diverge\n")
                    f.write(f"  - expected: `{exp.hex()}`\n")
                    f.write(f"  - actual:   `{act.hex()}`\n")
                f.write("\n")

        if cram_total > 0:
            f.write("### CRAM mismatches\n\n")
            for bank in range(8):
                ms = cram_results.get(bank, [])
                if not ms:
                    continue
                f.write(f"#### bank {bank} — {len(ms)}\n\n")
                for label, nes_idx, exp, act in ms[:30]:
                    f.write(f"- {label}: NES ${nes_idx:02X} "
                            f"-> expected `${exp:04X}`, actual `${act:04X}`\n")
                f.write("\n")

        if sobj_total > 0:
            f.write("### SCENE_OBJ detail\n\n")
            for bank in range(8):
                if bank not in sobj_results:
                    continue
                tiles, bytesd, blob, actual = sobj_results[bank]
                if tiles == 0:
                    continue
                f.write(f"#### bank {bank} — {tiles} tile mismatches, "
                        f"{bytesd} byte mismatches / {len(blob)} blob bytes\n\n")
                if len(blob) > 0:
                    n_tiles = len(blob) // TILE_BYTES_GEN
                    diffs = []
                    for ti in range(n_tiles):
                        t_off = ti * TILE_BYTES_GEN
                        if blob[t_off:t_off + TILE_BYTES_GEN] != actual[t_off:t_off + TILE_BYTES_GEN]:
                            diffs.append(ti)
                    f.write(f"Mismatching tile indices: {diffs[:20]}"
                            f"{' ...' if len(diffs) > 20 else ''}\n\n")

    print(f"\nwrote {OUT_MD}")


if __name__ == "__main__":
    sys.exit(main())
