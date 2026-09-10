Adversarial review of TWO Python scripts for a Zelda 1 NES→Sega Genesis byte-parity tool, BEFORE first run (project RULE V2 extended to all scripts). These decode the LINK sprite from NES OAM and Genesis SAT each frame of the cave-entry transition and byte-compare it. A silent decode bug produces a false PASS/FAIL and poisons the parity verdict — find every such bug.

## Context / ground truth (verified)
- NES OAM: 64 sprites × 4 bytes {y, tile, attr, x}. Sprite on-screen if y < $EF. NES screen Y is OAM_y+1. 8x16 sprite mode when ppuctrl bit5 set: tile pairs (tile&$FE, table=tile&1) top + (+1) bottom 8px down; else 8x8 with table = ppuctrl bit3. attr: subpal=bits0-1, hflip=bit6, vflip=bit7. Sprite palette = PALRAM[$10 + subpal*4 + idx]. NES Link = OAM slots $10-$13.
- Genesis SAT (Mega Drive): 8 bytes/sprite {y(10b BE), size(vsize=b2&3+1, hsize=(b2>>2)&3+1), link=b3&$7F, attr-word(pal=bits13-14,vflip=12,hflip=11,tile=0-10), x(9b BE)}. Screen x=xx-128, y=yy-128. x==0 = masked. VDP sprite cells are COLUMN-MAJOR: tile + col*vsize + row. Active sprites = SAT link chain from slot 0 (stop when link==0). Gameplay SAT base = VRAM $F400.
- NES→Gen color: misc_palettes LUT (nes_to_cram). Both decode to 8x8 grids of CRAM words (None=transparent), flip baked in — a grid match proves tile+flip+pixels+palette.
- Transition bundles (per-frame): NCTB = magic(4)+frame(1)+13 state bytes+OAM 256@18+PALRAM 32@274; ppuctrl@16. GCTB = magic(4)+frame(1)+scene(1)+linkxy(4)+12 state+SAT 2048@22+CRAM 128@2070+OAM-mirror 256@2198. chr_ref.bin="NCHR"(4)+CHR 8192+CIRAM 2048. vram_ref.bin="GVRM"(4)+VRAM 65536.
- Anchor: NES frame0=GameMode$10, Gen frame0=arm; Gen frame compared to NES N is N+shift (default 2).

## Check specifically (severity BLOCKER/MAJOR/MINOR/NIT + fix)
1. cave_byte_diff.py refactor: I split nes_sprites→nes_sprites_with_chr(oam,chr_,palram,ppuctrl,lut,slots) and gen_sprites→gen_sprites_with_vram(sat,vram,cram), keeping old funcs as wrappers. Did the refactor preserve EXACT behavior (8x16 pairing, spr_table from ppuctrl bit3, subpal math, flip order, column-major Gen cells, chain-walk termination)? Any off-by-one or dropped logic vs the originals?
2. Link-slot isolation: nes uses slots=range(0x10,0x14). Correct for NES Link in 8x16? (Link is OAM $10-$13.) On Gen there's no slot filter — gen_sprites_with_vram returns ALL chain sprites (Link + NPC + 2 bonfires in caves). The differ then position-matches NES-Link cells to Gen cells at (nx+dx,ny+dy). Is matching ALL gen cells by position sound, or could a bonfire/NPC cell alias a Link position and give a false match?
3. Offset detection: detect_offset votes (dx,dy) maximizing position matches, run on (nes_link, gen_ALL) per frame, summed across frames, fallback (0,-8). Is voting on nes-Link vs gen-ALL robust, or do the 2 static bonfires + NPC dominate the vote and pick a wrong global offset? Should it vote nes-Link vs gen-Link-candidates only?
4. Bundle offsets: confirm N_OAM=18, N_PAL=274, N_PPU=16 for NCTB and G_SAT=22, G_CRAM=2070 for GCTB against the documented layouts. chr_ref slice [4:4+8192], vram_ref [4:4+65536].
5. SAT window: GCTB stores a 2048-byte window from $F400. gen_sprites_with_vram walks slot*8 from sat[0]=$F400. Correct that sat[0] is the gameplay SAT base? Any risk it reads the $F800 title SAT inside the window?
6. grid_key / px compare: comparing tuple-of-tuples of CRAM words (None for transparent). Does this correctly treat transparent vs color-0? Any aliasing where two different sprites hash equal?
7. Verdict logic: PASS iff px-diff==0 AND missing==0 AND compared>0. Frames where NES Link has 0 cells (upper-half off-screen at Y=$F8 during descent) are skipped — is skipping correct, or does it hide real divergence? Could the whole run skip every frame (compared==0) and falsely... (it guards compared>0 → FAIL). Verify.
8. Crashes: index errors if a bundle is short, chr_ref/vram_ref wrong size, empty votes (fallback ok?), gen_by_pos collisions (dict overwrite — two gen cells same pos).

Full source of both files below. End with VERDICT: APPROVE / APPROVE-WITH-CHANGES / REWORK + the single highest-priority fix.

==================== cave_byte_diff.py (sprite section, refactored) ====================

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

def nes_sprites_with_chr(oam: bytes, chr_: bytes, palram: bytes,
                         ppuctrl: int, lut, slots=None) -> list[Cell]:
    """Decode NES OAM sprites to CRAM-word Cells. CHR/PALRAM/ppuctrl passed
    explicitly so callers with a separate CHR ref (transition bundles) can
    reuse this. `slots` = iterable of OAM indices to include (None = all 64);
    pass range(0x10, 0x14) for Link-only."""
    sprite_8x16 = bool(ppuctrl & 0x20)
    spr_table = 1 if (ppuctrl & 0x08) else 0
    idxs = range(64) if slots is None else slots
    cells = []
    for i in idxs:
        y, tile, attr, x = oam[i*4:i*4+4]
        if y >= 0xEF:  # off-screen / unused
            continue
        sx = x; sy = (y + 1) & 0xFF
        subpal = attr & 3
        hflip = (attr >> 6) & 1
        vflip = (attr >> 7) & 1
        if sprite_8x16:
            top_tile = tile & 0xFE
            table = tile & 1
            tiles = [(top_tile, table, 0), (top_tile + 1, table, 8)]
        else:
            tiles = [(tile, spr_table, 0)]
        for t, table, dy in tiles:
            grid = nes_tile_2bpp(chr_, t, table)
            px = [[None]*8 for _ in range(8)]
            for r in range(8):
                for c in range(8):
                    idx = grid[r][c]
                    if idx == 0:
                        continue  # transparent
                    nes_col = palram[0x10 + subpal*4 + idx]
                    px[r][c] = nes_to_cram(lut, nes_col)
            if hflip:
                px = [list(reversed(row)) for row in px]
            if vflip:
                px = list(reversed(px))
            cells.append(Cell(sx, (sy + dy) & 0x1FF, px,
                              f"OAM{i}t${t:02X}p{subpal}f{hflip}{vflip}"))
    return cells

def nes_sprites(nb: NesBundle, lut) -> list[Cell]:
    return nes_sprites_with_chr(nb.oam, nb.chr, nb.palram, nb.ppuctrl, lut)

def _cram_word_raw(cram: bytes, slot: int) -> int:
    return (cram[slot*2] << 8) | cram[slot*2 + 1]

def gen_sprites_with_vram(sat: bytes, vram: bytes, cram: bytes) -> list[Cell]:
    """Decode Genesis SAT sprites to CRAM-word Cells. SAT (>=512B at the VDP
    SAT base), VRAM (full 64KB ref), CRAM (128B) passed explicitly so callers
    with a separate VRAM ref (transition bundles) can reuse this."""
    cells = []
    # Walk the SAT link chain from slot 0 (active sprites only).
    slot = 0
    seen = set()
    order = []
    while slot not in seen and slot < 64:
        seen.add(slot)
        order.append(slot)
        link = sat[slot*8 + 3] & 0x7F
        if link == 0:
            break
        slot = link
    for s in order:
        b = sat[s*8:s*8+8]
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
                grid = gen_tile_4bpp(vram, t)
                px = [[None]*8 for _ in range(8)]
                for r in range(8):
                    for c in range(8):
                        idx = grid[r][c]
                        if idx == 0:
                            continue
                        px[r][c] = _cram_word_raw(cram, pal*16 + idx)
                gcx, gcy = cx, cy
                if hflip:
                    gcx = hsize - 1 - cx
                    px = [list(reversed(row)) for row in px]
                if vflip:
                    gcy = vsize - 1 - cy
                    px = list(reversed(px))
                cells.append(Cell(sx + gcx*8, sy + gcy*8, px,
                                  f"SAT{s}t${t:03X}p{pal}f{hflip}{vflip}"))
    return cells

def gen_sprites(gb: GenBundle, lut) -> list[Cell]:
    return gen_sprites_with_vram(gb.sat, gb.vram, gb.cram)

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
    # PAL0 (BG) is the byte-exact GATE: NES BG PALRAM[0..15] -> Gen CRAM[0..15]
    # via the misc_palettes LUT must match exactly. PAL1 (SPR) is INFO only --
    # sprites are pixel/count-judged (NES OAM != Gen SAT 1:1), so SPR palette
    # deltas are absorbed by the sprite pixel cross-check, not byte-gated.
    pal0_bad, pal1_bad = [], []
    for k in range(16):
        exp = nes_to_cram(lut, nb.palram[k]); act = gb.cram_word(k)
        if exp != act:
            pal0_bad.append((f"PAL0[{k}] BG nes${nb.palram[k]:02X}", exp, act))

==================== cave_transition_sprite_diff.py (FULL) ====================
#!/usr/bin/env python3
"""cave_transition_sprite_diff.py — Tier-B per-frame Link SPRITE byte-diff.

Companion to cave_transition_diff.py (Tier A = RAM trajectory). This decodes
the LINK sprite on both platforms each frame of the cave-entry transition and
compares it pixel-for-pixel in the port's own CRAM color space:
  NES  Link = OAM slots $10-$13 (8x16 via ppuctrl), CHR from chr_ref.bin,
             sub-pal from the per-frame PALRAM -> misc_palettes LUT -> CRAM word.
  Gen  Link = SAT (chain-walked from $F400), tile pixels from vram_ref.bin,
             color from the per-frame CRAM.
Both sides decode to 8x8 grids of CRAM words (flip baked in), so a grid match
proves tile + h/v-flip + pixels + palette all agree — i.e. the visible walk
cadence (R2) and behind-BG result. Position match proves {y,x}.

This reuses the decoders in cave_byte_diff.py:
  load_nes_to_cram_lut, nes_sprites_with_chr (slots=Link), gen_sprites_with_vram,
  detect_offset, cram_to_rgb, Cell.

Bundle layouts (must match probe_{nes,gen}_cave_transition.lua capture()):
  NCTB: magic(4) frame(1) 13 state + OAM 256 @18 + PALRAM 32 @274 ; ppuctrl @16.
  GCTB: magic(4) frame(1) scene(1) linkxy(4) 12 state + SAT 2048 @22
        + CRAM 128 @2070 + NES-OAM-mirror 256 @2198.
  chr_ref.bin: "NCHR"(4) + CHR 8192 + CIRAM 2048.
  vram_ref.bin: "GVRM"(4) + VRAM 65536.

Anchor: NES frame 0 = GameMode=$10; Gen frame 0 = arm. Pass --shift to align
(default 2, matching cave_transition_diff.py's reported best shift); the Gen
frame compared to NES frame N is N+shift.

Usage:
  cave_transition_sprite_diff.py <nes_dir> <gen_dir> [--shift N] [--report out.txt]
Exit 0 iff every compared frame's Link sprite matches (pos + pixels); else 1.
"""
from __future__ import annotations
import argparse, sys
from pathlib import Path

# Reuse the verified decoders.
from cave_byte_diff import (
    load_nes_to_cram_lut, nes_sprites_with_chr, gen_sprites_with_vram,
    detect_offset, PALETTES_C, Cell,
)

# Bundle field offsets (mirror cave_transition_diff.py / the probes).
N_PPU = 16
N_OAM = 18
N_PAL = 274
G_SAT = 22
G_CRAM = 2070
LINK_OAM_SLOTS = range(0x10, 0x14)   # NES Link = OAM $10..$13


def load_frames(d: Path, magic: bytes) -> dict[int, bytes]:
    out = {}
    for p in sorted(d.glob("f*.bin")):
        data = p.read_bytes()
        if data[:4] == magic:
            out[data[4]] = data
    return out


def grid_key(px):
    """Hashable signature of an 8x8 CRAM-word grid (None=transparent)."""
    return tuple(tuple(row) for row in px)


def link_cells_nes(nctb: bytes, chr_ref: bytes, lut):
    oam = nctb[N_OAM:N_OAM + 256]
    palram = nctb[N_PAL:N_PAL + 32]
    ppuctrl = nctb[N_PPU]
    chr_ = chr_ref[4:4 + 8192]
    return nes_sprites_with_chr(oam, chr_, palram, ppuctrl, lut,
                                slots=LINK_OAM_SLOTS)


def link_cells_gen(gctb: bytes, vram_ref: bytes):
    sat = gctb[G_SAT:G_SAT + 2048]
    cram = gctb[G_CRAM:G_CRAM + 128]
    vram = vram_ref[4:4 + 65536]
    return gen_sprites_with_vram(sat, vram, cram)


def match_link(nes_cells, gen_cells, dx, dy):
    """Match each NES Link cell to the Gen cell at (nx+dx, ny+dy). Return
    (matched, pos_only, missing) where matched = same position AND same pixels."""
    gen_by_pos = {(c.x, c.y): c for c in gen_cells}
    matched = pos_only = missing = 0
    detail = []
    for nc in nes_cells:
        gx, gy = nc.x + dx, nc.y + dy
        gc = gen_by_pos.get((gx, gy))
        if gc is None:
            missing += 1
            detail.append((nc, None, "MISSING"))
        elif grid_key(gc.px) == grid_key(nc.px):
            matched += 1
            detail.append((nc, gc, "OK"))
        else:
            pos_only += 1
            detail.append((nc, gc, "PX-DIFF"))
    return matched, pos_only, missing, detail


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("nes_dir"); ap.add_argument("gen_dir")
    ap.add_argument("--shift", type=int, default=2,
                    help="Gen frame compared to NES frame N is N+shift")
    ap.add_argument("--report", default=None)
    a = ap.parse_args()

    nes = load_frames(Path(a.nes_dir), b"NCTB")
    gen = load_frames(Path(a.gen_dir), b"GCTB")
    chr_ref = (Path(a.nes_dir) / "chr_ref.bin").read_bytes()
    vram_ref = (Path(a.gen_dir) / "vram_ref.bin").read_bytes()
    if not nes or not gen or chr_ref[:4] != b"NCHR" or vram_ref[:4] != b"GVRM":
        print(f"FATAL: bad inputs (nes={len(nes)} gen={len(gen)} "
              f"chr={chr_ref[:4]!r} vram={vram_ref[:4]!r})")
        return 1
    lut = load_nes_to_cram_lut(PALETTES_C)

    # Global NES->Gen offset: vote across frames where Link is on-screen on
    # both sides (fall back to BG-proven (0,-8) if voting is empty).
    from collections import Counter
    votes = Counter()
    for off, nctb in nes.items():
        gctb = gen.get(off + a.shift)
        if gctb is None:
            continue
        nc = link_cells_nes(nctb, chr_ref, lut)
        gc = link_cells_gen(gctb, vram_ref)
        if nc and gc:
            dx, dy, n = detect_offset(nc, gc)
            votes[(dx, dy)] += n
    dx, dy = votes.most_common(1)[0][0] if votes else (0, -8)

    lines = []
    def out(s=""): lines.append(s); print(s)
    out("== cave_transition_sprite_diff: TIER B (Link sprite, pixel-exact) ==")
    out(f"nes frames={len(nes)} gen frames={len(gen)} shift={a.shift} "
        f"offset=(dx={dx},dy={dy})")

    tot_n = tot_ok = tot_px = tot_miss = 0
    bad_frames = []
    for off in sorted(nes):
        gctb = gen.get(off + a.shift)
        if gctb is None:
            continue
        nc = link_cells_nes(nes[off], chr_ref, lut)
        gc = link_cells_gen(gctb, vram_ref)
        if not nc:
            continue  # Link off-screen on NES this frame (e.g. upper-half hidden)
        m, p, miss, detail = match_link(nc, gc, dx, dy)
        tot_n += len(nc); tot_ok += m; tot_px += p; tot_miss += miss
        if p or miss:
            bad_frames.append((off, m, p, miss, detail))

    out(f"\nLink cells compared={tot_n}  OK={tot_ok}  PX-DIFF={tot_px}  "
        f"MISSING={tot_miss}")
    if bad_frames:
        out(f"\n{len(bad_frames)} frames with Link sprite divergence:")
        for off, m, p, miss, detail in bad_frames[:24]:
            out(f"  fr{off:3d}: ok={m} px-diff={p} missing={miss}")
            for nc, gc, tag in detail:
                if tag != "OK":
                    g = f"GEN({gc.x},{gc.y}) {gc.src}" if gc else "GEN <none>"
                    out(f"      {tag}: NES({nc.x},{nc.y}) {nc.src}  vs  {g}")
        if len(bad_frames) > 24:
            out(f"    ... +{len(bad_frames)-24} more frames")

    verdict = "PASS" if (tot_px == 0 and tot_miss == 0 and tot_n > 0) else "FAIL"
    out(f"\n== TIER B VERDICT: {verdict} ==")
    if a.report:
        Path(a.report).write_text("\n".join(lines), encoding="utf-8")
        print(f"\nreport -> {a.report}")
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
