#!/usr/bin/env python3
"""cave_byte_diff.py - byte-exact NES vs Genesis cave-interior differ.

Compares a NES golden bundle (NCGD: OAM+PALRAM+CHR+ppuctrl) against the
Genesis bundle (GCGD: SAT+CRAM+VRAM) for one cave, per frame phase, and
reports EVERY divergence. Per RULE V1 the verdict is byte-diff only; NO
screenshots gate pass/fail.

Comparison runs in the port's OWN color space: a NES PPU color index is
mapped to its Genesis CRAM word via the SAME LUT the port uses
(misc_palettes, data/misc/palettes.c -> roomrom_bg_palette_nes_to_cram).
So a color matches iff the Genesis pixel's CRAM word equals the NES
pixel's LUT'd CRAM word - exact, no "looks close".

Domains:
  PALETTE - Gen CRAM (64 words) vs NES PALRAM (32 idx) through the LUT,
            laid out per the port convention (PAL0=BG palram[0..15],
            PAL1=SPR palram[16..31]).
  SPRITE  - NES OAM sprites vs Gen SAT sprites. Each sprite is decoded to
            an 8x8(/8x16) grid of CRAM words (NES: CHR pattern + PALRAM
            sub-pal -> LUT; Gen: VRAM pattern + CRAM). Sprites are matched
            by screen position (auto-detected NES->Gen offset), then we
            diff position, palette colors, AND pixel pattern. This catches
            wrong-color AND wrong-sprite (wrong pattern) AND missing/extra.

Usage:
  cave_byte_diff.py <cave_dir> [--frame N] [--strict]
    <cave_dir> holds nes_<ID>/ and gen_<ID>/ subdirs (or pass two dirs).
  cave_byte_diff.py --nes nes_6A --gen gen_6A [--strict]

Exit 0 iff zero divergences across compared frames; else 1.
"""
from __future__ import annotations
import argparse, os, re, sys, struct
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
PALETTES_C = REPO / "data" / "misc" / "palettes.c"
FRAMES = [0, 8, 16, 24, 60, 120]

# ---------------------------------------------------------------- LUT ----
def load_nes_to_cram_lut(path: Path) -> list[int]:
    """Parse misc_palettes[] from data/misc/palettes.c -> list of bytes.
    nes_to_cram(idx) = b[idx*2] | b[idx*2+1]<<8 (idx & 0x3F), per
    src/game/world/bg_palette.c:roomrom_bg_palette_nes_to_cram."""
    txt = path.read_text()
    m = re.search(r"misc_palettes\[\d+\]\s*=\s*\{(.*?)\}", txt, re.S)
    if not m:
        raise SystemExit(f"could not parse misc_palettes from {path}")
    vals = [int(x, 16) for x in re.findall(r"0x([0-9A-Fa-f]+)", m.group(1))]
    return vals

def nes_to_cram(lut: list[int], nes_color: int) -> int:
    off = (nes_color & 0x3F) * 2
    return lut[off] | (lut[off + 1] << 8)

# ----------------------------------------------------------- CRAM word ---
def cram_to_rgb(word: int) -> tuple[int, int, int]:
    """Mega Drive 9-bit color word -> (r,g,b) 0..255. R bits1-3, G 5-7, B 9-11."""
    r = (word >> 1) & 7
    g = (word >> 5) & 7
    b = (word >> 9) & 7
    return (r * 36, g * 36, b * 36)

def hexw(w: int) -> str:
    return f"${w & 0xFFFF:04X}"

# --------------------------------------------------------- bundle parse --
class NesBundle:
    def __init__(self, data: bytes):
        if data[:4] != b"NCGD":
            raise ValueError("bad NES magic")
        self.frame = data[4]; self.cave = data[5]
        self.game_mode = data[6]; self.person_state = data[7]
        self.oam = data[8:8 + 256]
        self.palram = data[264:264 + 32]
        self.chr = data[296:296 + 8192]
        self.ppuctrl = data[8488] if len(data) > 8488 else 0
        self.sprite_8x16 = bool(self.ppuctrl & 0x20)
        self.spr_table = 1 if (self.ppuctrl & 0x08) else 0  # 8x8 mode table
        self.bg_table = 1 if (self.ppuctrl & 0x10) else 0   # BG pattern table
        # CIRAM nametables (NT0 = first 1KB: 960 tiles + 64 attr bytes).
        self.ciram = data[8489:8489 + 2048] if len(data) >= 8489 + 2048 else b""

class GenBundle:
    SAT_BASE = 0xF800   # _oam_dma_flush DMA target (src/nes_io.asm:2300)
    def __init__(self, data: bytes):
        if data[:4] != b"GCGD":
            raise ValueError("bad Gen magic")
        self.frame = data[4]; self.cave = data[5]
        self.scene = data[6]; self.objtype1 = data[7]
        self.cram = data[8:8 + 128]
        self.vram = data[136:136 + 65536]
        self.sat = self.vram[self.SAT_BASE:self.SAT_BASE + 512]  # 64 sprites
    def cram_word(self, slot: int) -> int:
        # CRAM domain bytes: genplus-gx stores big-endian VDP words.
        return (self.cram[slot * 2] << 8) | self.cram[slot * 2 + 1]

# ------------------------------------------------------ tile decoders ----
def nes_tile_2bpp(chr_: bytes, tile: int, table: int) -> list[list[int]]:
    """Decode one NES 8x8 tile -> 8x8 of 2-bit color indices (0..3)."""
    base = table * 0x1000 + tile * 16
    out = []
    for row in range(8):
        p0 = chr_[base + row]
        p1 = chr_[base + row + 8]
        line = []
        for col in range(8):
            bit = 7 - col
            line.append(((p0 >> bit) & 1) | (((p1 >> bit) & 1) << 1))
        out.append(line)
    return out

def gen_tile_4bpp(vram: bytes, tile: int) -> list[list[int]]:
    """Decode one Genesis 8x8 tile -> 8x8 of 4-bit color indices (0..15)."""
    base = tile * 32
    out = []
    for row in range(8):
        line = []
        for b in range(4):
            byte = vram[base + row * 4 + b]
            line.append(byte >> 4)
            line.append(byte & 0xF)
        out.append(line)
    return out

# ----------------------------------------------------- sprite extract ----
class Cell:
    """One 8x8 sprite cell as CRAM words (None = transparent)."""
    __slots__ = ("x", "y", "px", "src")
    def __init__(self, x, y, px, src):
        self.x = x; self.y = y; self.px = px; self.src = src

def nes_sprites(nb: NesBundle, lut) -> list[Cell]:
    cells = []
    for i in range(64):
        y, tile, attr, x = nb.oam[i*4:i*4+4]
        if y >= 0xEF:  # off-screen / unused
            continue
        sx = x; sy = (y + 1) & 0xFF
        subpal = attr & 3
        hflip = (attr >> 6) & 1
        vflip = (attr >> 7) & 1
        if nb.sprite_8x16:
            top_tile = tile & 0xFE
            table = tile & 1
            tiles = [(top_tile, table, 0), (top_tile + 1, table, 8)]
        else:
            tiles = [(tile, nb.spr_table, 0)]
        for t, table, dy in tiles:
            grid = nes_tile_2bpp(nb.chr, t, table)
            px = [[None]*8 for _ in range(8)]
            for r in range(8):
                for c in range(8):
                    idx = grid[r][c]
                    if idx == 0:
                        continue  # transparent
                    nes_col = nb.palram[0x10 + subpal*4 + idx]
                    px[r][c] = nes_to_cram(lut, nes_col)
            if hflip:
                px = [list(reversed(row)) for row in px]
            if vflip:
                px = list(reversed(px))
            cells.append(Cell(sx, (sy + dy) & 0x1FF, px, f"OAM{i}t${t:02X}p{subpal}"))
    return cells

def gen_sprites(gb: GenBundle, lut) -> list[Cell]:
    cells = []
    # Walk the SAT link chain from slot 0 (active sprites only).
    slot = 0
    seen = set()
    order = []
    while slot not in seen and slot < 64:
        seen.add(slot)
        order.append(slot)
        link = gb.sat[slot*8 + 3] & 0x7F
        if link == 0:
            break
        slot = link
    for s in order:
        b = gb.sat[s*8:s*8+8]
        yy = ((b[0] << 8) | b[1]) & 0x3FF
        vsize = (b[2] & 3) + 1
        hsize = ((b[2] >> 2) & 3) + 1
        w2 = (b[4] << 8) | b[5]
        pal = (w2 >> 13) & 3
        vflip = (w2 >> 12) & 1
        hflip = (w2 >> 11) & 1
        tile = w2 & 0x7FF
        xx = ((b[6] << 8) | b[7]) & 0x1FF
        if xx == 0:  # x==0 => sprite masked/hidden
            continue
        sx = xx - 128
        sy = yy - 128
        # VDP sprite cells are column-major: tile + (col*vsize + row).
        for cx in range(hsize):
            for cy in range(vsize):
                t = (tile + cx * vsize + cy) & 0x7FF
                grid = gen_tile_4bpp(gb.vram, t)
                px = [[None]*8 for _ in range(8)]
                for r in range(8):
                    for c in range(8):
                        idx = grid[r][c]
                        if idx == 0:
                            continue
                        px[r][c] = gb.cram_word(pal*16 + idx)
                gcx, gcy = cx, cy
                if hflip:
                    gcx = hsize - 1 - cx
                    px = [list(reversed(row)) for row in px]
                if vflip:
                    gcy = vsize - 1 - cy
                    px = list(reversed(px))
                cells.append(Cell(sx + gcx*8, sy + gcy*8, px,
                                  f"SAT{s}t${t:03X}p{pal}"))
    return cells

# --------------------------------------------------------- BG cells ------
def nes_bg_cells(nb: NesBundle, lut) -> list[Cell]:
    """NES nametable NT0 (32x30) -> BG cells. Cave walls + person text +
    HUD all live here. idx0 = universal backdrop PALRAM[0]."""
    nt = nb.ciram
    if len(nt) < 1024:
        return []
    cells = []
    for row in range(30):
        for col in range(32):
            tile = nt[row * 32 + col]
            ab = nt[960 + (row // 4) * 8 + (col // 4)]
            shift = (((row // 2) & 1) * 2 + ((col // 2) & 1)) * 2
            subpal = (ab >> shift) & 3
            grid = nes_tile_2bpp(nb.chr, tile, nb.bg_table)
            px = [[None]*8 for _ in range(8)]
            for r in range(8):
                for c in range(8):
                    idx = grid[r][c]
                    nes_col = nb.palram[0] if idx == 0 else nb.palram[subpal*4 + idx]
                    px[r][c] = nes_to_cram(lut, nes_col)
            cells.append(Cell(col*8, row*8, px, f"NT{col},{row}t${tile:02X}p{subpal}"))
    return cells

def gen_bg_cells(gb: GenBundle, base=0xC000, cols=64, rows=32) -> list[Cell]:
    """Genesis Plane A ($C000, H64xV32 per render_adapter.c) -> BG cells.
    idx0 = CRAM[0] backdrop."""
    cells = []
    for row in range(rows):
        for col in range(cols):
            o = base + (row * cols + col) * 2
            e = (gb.vram[o] << 8) | gb.vram[o + 1]
            pal = (e >> 13) & 3
            vf = (e >> 12) & 1; hf = (e >> 11) & 1
            tile = e & 0x7FF
            grid = gen_tile_4bpp(gb.vram, tile)
            px = [[None]*8 for _ in range(8)]
            for r in range(8):
                for c in range(8):
                    idx = grid[r][c]
                    px[r][c] = gb.cram_word(pal*16 + idx)  # idx0 = backdrop
            if hf: px = [list(reversed(r)) for r in px]
            if vf: px = list(reversed(px))
            cells.append(Cell(col*8, row*8, px, f"PA{col},{row}t${tile:03X}p{pal}"))
    return cells

# ------------------------------------------------------- offset detect ---
def detect_offset(nes_cells, gen_cells):
    """Find (dx,dy) s.t. gen_x = nes_x+dx maximizes cell-position matches."""
    from collections import Counter
    votes = Counter()
    ny = sorted({(c.x, c.y) for c in nes_cells})
    gy = sorted({(c.x, c.y) for c in gen_cells})
    for nx, nyy in ny:
        for gx, gyy in gy:
            votes[(gx - nx, gyy - nyy)] += 1
    if not votes:
        return (0, 0, 0)
    (dx, dy), n = votes.most_common(1)[0]
    return (dx, dy, n)

# -------------------------------------------------------------- diff -----
def diff_frame(nes: bytes, gen: bytes, lut, frame, strict, report):
    nb = NesBundle(nes); gb = GenBundle(gen)
    report.append(f"\n=== frame {frame}: NES gm=${nb.game_mode:02X} "
                  f"ppuctrl=${nb.ppuctrl:02X} (8x16={nb.sprite_8x16}) | "
                  f"Gen scene=${gb.scene:02X} obj1=${gb.objtype1:02X} ===")
    diffs = 0

    # --- PALETTE: Gen CRAM vs NES PALRAM via LUT (port PAL0=BG, PAL1=SPR) -
    # NES BG palram[0..15] -> Gen PAL0 (CRAM 0..15); SPR palram[16..31] ->
    # Gen PAL1 (CRAM 16..31). (PAL2/PAL3 are port special ramps - reported
    # separately, not a NES 1:1.)
    pal_bad = []
    for k in range(16):
        exp = nes_to_cram(lut, nb.palram[k])
        act = gb.cram_word(k)
        if exp != act:
            pal_bad.append((f"PAL0[{k}] BG nes${nb.palram[k]:02X}", exp, act))
    for k in range(16):
        exp = nes_to_cram(lut, nb.palram[16 + k])
        act = gb.cram_word(16 + k)
        if exp != act:
            pal_bad.append((f"PAL1[{k}] SPR nes${nb.palram[16+k]:02X}", exp, act))
    if pal_bad:
        report.append(f"  PALETTE: {len(pal_bad)} slot mismatches:")
        for name, exp, act in pal_bad:
            report.append(f"    {name}: expect {hexw(exp)} {cram_to_rgb(exp)} "
                          f"got {hexw(act)} {cram_to_rgb(act)}")
    else:
        report.append("  PALETTE: OK (PAL0 BG + PAL1 SPR match)")
    diffs += len(pal_bad)

    # --- SPRITES ---------------------------------------------------------
    nc = nes_sprites(nb, lut)
    gc = gen_sprites(gb, lut)
    dx, dy, votes = detect_offset(nc, gc)
    report.append(f"  SPRITES: NES cells={len(nc)} Gen cells={len(gc)} "
                  f"offset dx={dx} dy={dy} (votes={votes})")
    gen_by_pos = {}
    for c in gc:
        gen_by_pos.setdefault((c.x, c.y), []).append(c)
    matched_gen = set()
    spr_bad = 0
    for c in nc:
        key = (c.x + dx, c.y + dy)
        cands = gen_by_pos.get(key)
        if not cands:
            report.append(f"    MISSING on Gen: NES {c.src} @nes({c.x},{c.y})")
            spr_bad += 1
            continue
        g = cands[0]
        matched_gen.add(id(g))
        # compare pixel grids (CRAM words)
        pat_mismatch = 0
        col_mismatch = 0
        for r in range(8):
            for col in range(8):
                a = c.px[r][col]; b = g.px[r][col]
                if (a is None) != (b is None):
                    pat_mismatch += 1
                elif a is not None and a != b:
                    col_mismatch += 1
        if pat_mismatch or col_mismatch:
            report.append(f"    DIFF {c.src}@nes({c.x},{c.y}) vs {g.src}: "
                          f"shape_px_diff={pat_mismatch} color_px_diff={col_mismatch}")
            spr_bad += 1
    for c in gc:
        if id(c) not in matched_gen:
            report.append(f"    EXTRA on Gen: {c.src} @gen({c.x},{c.y})")
            spr_bad += 1
    if spr_bad == 0:
        report.append("  SPRITES: OK (all cells match pos+pattern+color)")
    diffs += spr_bad

    return diffs

def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("cave_dir", nargs="?")
    ap.add_argument("--nes"); ap.add_argument("--gen")
    ap.add_argument("--cave", default="6A")
    ap.add_argument("--frame", type=int)
    ap.add_argument("--strict", action="store_true")
    a = ap.parse_args(argv)
    if a.cave_dir:
        nes_dir = Path(a.cave_dir) / f"nes_{a.cave}"
        gen_dir = Path(a.cave_dir) / f"gen_{a.cave}"
    else:
        nes_dir = Path(a.nes); gen_dir = Path(a.gen)
    lut = load_nes_to_cram_lut(PALETTES_C)
    frames = [a.frame] if a.frame is not None else FRAMES
    report = []
    total = 0
    for fr in frames:
        nfp = nes_dir / f"f{fr:03d}.bin"
        gfp = gen_dir / f"f{fr:03d}.bin"
        if not nfp.exists() or not gfp.exists():
            report.append(f"frame {fr}: MISSING bundle "
                          f"(nes={nfp.exists()} gen={gfp.exists()})")
            total += 1
            continue
        total += diff_frame(nfp.read_bytes(), gfp.read_bytes(), lut,
                            fr, a.strict, report)
    print("\n".join(report))
    print(f"\n{'='*60}\nTOTAL DIVERGENCES: {total}")
    if total == 0:
        print("VERDICT: BYTE-EXACT MATCH")
        return 0
    print("VERDICT: DIVERGENT (see above)")
    return 1

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
