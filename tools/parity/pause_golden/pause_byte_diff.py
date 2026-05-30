#!/usr/bin/env python3
"""pause_byte_diff.py — byte-exact NES vs Genesis pause-subscreen differ.

Reuses the proven decoders from cave_byte_diff.py (palette LUT, NES 2bpp /
Gen 4bpp tile decode, OAM->cells, SAT->cells, BG-cell decode, offset
detect) and applies them to the pause/inventory subscreen.

Per RULE V1 the verdict is byte-diff only — never a screenshot. Compares,
for one sub-state bundle pair (active / blink0 / blink1):
  PALETTE  NES PALRAM -> Gen CRAM via misc_palettes LUT (all 4 PALs).
  SPRITES  NES OAM (item icons + cursor) vs Gen SAT — pixel + position
           cross-check (the "every sprite present + correct" proof).
  BG       NES subscreen nametable (CIRAM page 1 = NT2, the menu) vs Gen
           Plane A — rendered-pixel per cell, auto vertical offset.
And the scroll ladders (scroll_open.csv / scroll_close.csv) for the
animation-cadence proof.

Usage:
  pause_byte_diff.py --nes C:/tmp/pause_golden/nes_ow --gen C:/tmp/pause_golden/gen_boot
  pause_byte_diff.py ... --sub active   (default: active+blink0+blink1)
Exit 0 iff zero gated divergences.
"""
from __future__ import annotations
import argparse, sys, csv
from pathlib import Path

# Reuse cave_golden's decoders verbatim.
CAVE = Path(__file__).resolve().parents[1] / "cave_golden"
sys.path.insert(0, str(CAVE))
import cave_byte_diff as C   # noqa: E402

REPO = Path(__file__).resolve().parents[3]
PALETTES_C = REPO / "data" / "misc" / "palettes.c"


# ---- BG cells for an arbitrary CIRAM page (cave version is NT0 only) ----
def nes_bg_cells_page(nb: "C.NesBundle", lut, page: int) -> list:
    """NES nametable PAGE (0 or 1) -> rendered BG cells. The subscreen menu
    is built in NT2 = physical page 1 under Z1 horizontal mirroring."""
    nt = nb.ciram[page * 1024:(page + 1) * 1024]
    if len(nt) < 1024:
        return []
    cells = []
    for row in range(30):
        for col in range(32):
            tile = nt[row * 32 + col]
            ab = nt[960 + (row // 4) * 8 + (col // 4)]
            shift = (((row // 2) & 1) * 2 + ((col // 2) & 1)) * 2
            subpal = (ab >> shift) & 3
            grid = C.nes_tile_2bpp(nb.chr, tile, nb.bg_table)
            px = [[None] * 8 for _ in range(8)]
            for r in range(8):
                for c in range(8):
                    idx = grid[r][c]
                    nes_col = nb.palram[0] if idx == 0 else nb.palram[subpal * 4 + idx]
                    px[r][c] = C.nes_to_cram(lut, nes_col)
            cells.append(C.Cell(col * 8, row * 8, px, f"NT{col},{row}t${tile:02X}p{subpal}"))
    return cells


def gen_sprites_all(gb, lut, nslots=80):
    """Like cave_byte_diff.gen_sprites but scans ALL 80 SAT slots instead of
    walking the link chain. The inventory subscreen writes up to 80 SAT
    entries directly to VRAM $F400; a broken/early link=0 in that list would
    make the chain-walk miss real sprites (memory feedback_genesis_sprite_
    link_chain). For a golden diff we want every populated slot."""
    sat = gb.vram[0xF400:0xF400 + nslots * 8]
    cells = []
    for s in range(nslots):
        b = sat[s * 8:s * 8 + 8]
        if len(b) < 8:
            break
        yy = ((b[0] << 8) | b[1]) & 0x3FF
        vsize = (b[2] & 3) + 1
        hsize = ((b[2] >> 2) & 3) + 1
        w2 = (b[4] << 8) | b[5]
        pal = (w2 >> 13) & 3
        vflip = (w2 >> 12) & 1
        hflip = (w2 >> 11) & 1
        tile = w2 & 0x7FF
        xx = ((b[6] << 8) | b[7]) & 0x1FF
        if xx == 0 and yy == 0 and tile == 0:
            continue  # blank slot
        sx = xx - 128
        sy = yy - 128
        for cx in range(hsize):
            for cy in range(vsize):
                t = (tile + cx * vsize + cy) & 0x7FF
                grid = C.gen_tile_4bpp(gb.vram, t)
                px = [[None] * 8 for _ in range(8)]
                for r in range(8):
                    for c in range(8):
                        idx = grid[r][c]
                        if idx == 0:
                            continue
                        px[r][c] = gb.cram_word(pal * 16 + idx)
                gcx, gcy = cx, cy
                if hflip:
                    gcx = hsize - 1 - cx
                    px = [list(reversed(row)) for row in px]
                if vflip:
                    gcy = vsize - 1 - cy
                    px = list(reversed(px))
                cells.append(C.Cell(sx + gcx * 8, sy + gcy * 8, px,
                                    f"SAT{s}t${t:03X}p{pal}"))
    return cells


def best_sprite_offset(nc, gen_by_pos):
    """The port writes Gen SAT = NES OAM + (128,0x81); after gen_sprites'
    -128 the differ-space offset is small (items +4x/+0y, cursor +0/+0).
    Search ONLY that plausible window so a spurious far offset can't win."""
    best = (0, 0, -1)
    for dx in range(-2, 9):
        for dy in range(-3, 4):
            m = 0
            for c in nc:
                cands = gen_by_pos.get((c.x + dx, c.y + dy))
                if cands and any(g.px == c.px for g in cands):
                    m += 1
            if m > best[2]:
                best = (dx, dy, m)
    return best


def best_bg_offset(nbg, gbg_by_pos):
    """Pick the vertical offset that MAXIMIZES non-blank content matches
    (not 'minimizes missing' — blank Gen tiles exist at every position, so
    minimizing missing falsely rewards aligning menu rows onto blank rows)."""
    best = (0, -1)
    for dy in range(-16 * 8, 16 * 8 + 1, 8):
        match = 0
        for c in nbg:
            cands = gbg_by_pos.get((c.x, c.y + dy))
            if cands and cands[0].px == c.px:
                match += 1
        if match > best[1]:
            best = (dy, match)
    return best


def diff_palette(nb, gb, lut, report):
    bad = 0
    names = {0: "PAL0/BG", 1: "PAL1/SPR", 2: "PAL2", 3: "PAL3"}
    for p in range(4):
        slot_bad = []
        for k in range(16):
            # NES has only 2 sub-pal groups (BG palram[0..15], SPR[16..31]);
            # Gen PAL2/PAL3 are port ramps with no NES 1:1 — report raw.
            if p < 2:
                exp = C.nes_to_cram(lut, nb.palram[p * 16 + k])
                act = gb.cram_word(p * 16 + k)
                if exp != act:
                    slot_bad.append((k, nb.palram[p * 16 + k], exp, act))
        if slot_bad:
            report.append(f"  PALETTE {names[p]}: {len(slot_bad)} slot mismatch")
            for k, nes, exp, act in slot_bad[:8]:
                report.append(f"    [{k}] nes${nes:02X} expect {C.hexw(exp)}{C.cram_to_rgb(exp)} "
                              f"got {C.hexw(act)}{C.cram_to_rgb(act)}")
            if p == 0:   # PAL0 BG is the byte-exact gate
                bad += len(slot_bad)
        elif p < 2:
            report.append(f"  PALETTE {names[p]}: OK")
    return bad


def diff_sprites(nb, gb, lut, report):
    nc = C.nes_sprites(nb, lut)
    gc = gen_sprites_all(gb, lut)
    gen_by_pos = {}
    for c in gc:
        gen_by_pos.setdefault((c.x, c.y), []).append(c)
    dx, dy, m = best_sprite_offset(nc, gen_by_pos)
    report.append(f"  SPRITES: NES cells={len(nc)} Gen cells={len(gc)} "
                  f"offset dx={dx} dy={dy} (exact-pixel matches={m})")
    bad = 0
    matched = set()
    for c in nc:
        cands = gen_by_pos.get((c.x + dx, c.y + dy))
        if not cands:
            report.append(f"    MISSING on Gen: NES {c.src} @nes({c.x},{c.y})")
            bad += 1
            continue
        g = cands[0]; matched.add(id(g))
        shape = sum(1 for r in range(8) for col in range(8)
                    if (c.px[r][col] is None) != (g.px[r][col] is None))
        color = sum(1 for r in range(8) for col in range(8)
                    if c.px[r][col] is not None and g.px[r][col] is not None
                    and c.px[r][col] != g.px[r][col])
        if shape or color:
            report.append(f"    DIFF {c.src}@nes({c.x},{c.y}) vs {g.src}: "
                          f"shape_px={shape} color_px={color}")
            bad += 1
    for c in gc:
        if id(c) in matched:
            continue
        if 0 <= c.x <= 248 and 0 <= c.y <= 232:
            report.append(f"    EXTRA on Gen (on-screen): {c.src} @gen({c.x},{c.y})")
            bad += 1
    return bad


def diff_bg(nb, gb, lut, report):
    nbg = nes_bg_cells_page(nb, lut, page=1)   # NT2 = menu
    # Drop all-backdrop (blank) NES cells — they carry no menu content and
    # would falsely "match" anything; the menu proof is the non-blank cells.
    bd = C.nes_to_cram(lut, nb.palram[0])
    nbg = [c for c in nbg if any(c.px[r][col] != bd for r in range(8) for col in range(8))]
    gbg = C.gen_bg_cells(gb)
    gbg_by_pos = {}
    for c in gbg:
        gbg_by_pos.setdefault((c.x, c.y), []).append(c)
    dy, match = best_bg_offset(nbg, gbg_by_pos)
    miss = 0
    rgb = 0
    examples = []
    for c in nbg:
        cands = gbg_by_pos.get((c.x, c.y + dy))
        if not cands:
            miss += 1
            if len(examples) < 12:
                examples.append(f"MISSING Gen @({c.x},{c.y + dy}) for NES {c.src}")
            continue
        g = cands[0]
        cm = sum(1 for r in range(8) for col in range(8) if c.px[r][col] != g.px[r][col])
        if cm:
            rgb += 1
            if len(examples) < 12:
                examples.append(f"{c.src} vs {g.src}: px_diff={cm}")
    report.append(f"  BG: non-blank NES menu cells={len(nbg)} best dy={dy} "
                  f"(content matches={match}) -> {miss} missing, {rgb} pixel-delta")
    for e in examples:
        report.append(f"    {e}")
    return miss + rgb


def read_ladder(path):
    if not path.exists():
        return None
    rows = []
    with open(path, newline="") as f:
        for row in csv.DictReader(f):
            rows.append(row)
    return rows


def diff_scroll(nes_dir, gen_dir, report):
    """Compare the scroll-open ladder shape. NES CurVScroll steps $EF->$41
    by -3/frame (deterministic from Z_05.asm). Gen VSRAM0 should trace a
    matching frame count + monotonic ramp. Reports the NES ladder + Gen
    ladder so the mapping is visible (Phase B derives the exact mapping)."""
    nl = read_ladder(nes_dir / "scroll_open.csv")
    gl = read_ladder(gen_dir / "scroll_open.csv")
    report.append("  SCROLL open ladder:")
    if nl:
        vs = [int(r["CurVScroll"]) for r in nl]
        ms = [int(r["MenuState"]) for r in nl]
        report.append(f"    NES CurVScroll: {vs[:24]}{'...' if len(vs)>24 else ''}")
        report.append(f"    NES MenuState : {ms[:24]}{'...' if len(ms)>24 else ''}")
        report.append(f"    NES frames to active: {len(nl)}")
    else:
        report.append("    NES ladder MISSING")
    if gl:
        gv = [int(r["VSRAM0"]) for r in gl]
        report.append(f"    Gen VSRAM0    : {gv[:24]}{'...' if len(gv)>24 else ''}")
        report.append(f"    Gen frames to settle: {len(gl)}")
    else:
        report.append("    Gen ladder MISSING")
    # Gate: the Gen scroll must actually animate (VSRAM changes), and the
    # frame counts should be comparable. A flat Gen VSRAM0 = fake (row-write)
    # animation = FAIL until Phase B.
    if gl:
        gv = [int(r["VSRAM0"]) for r in gl]
        if len(set(gv)) <= 1:
            report.append("    SCROLL FAIL: Gen VSRAM0 is FLAT — no real vertical "
                          "scroll (row-write fake). Phase B not yet applied.")
            return 1
    return 0


def diff_sub(nes_dir, gen_dir, sub, lut, report):
    nfp = nes_dir / f"{sub}.bin"
    gfp = gen_dir / f"{sub}.bin"
    if not nfp.exists() or not gfp.exists():
        report.append(f"\n=== {sub}: MISSING bundle (nes={nfp.exists()} gen={gfp.exists()}) ===")
        return 1
    nb = C.NesBundle(nfp.read_bytes())
    gb = C.GenBundle(gfp.read_bytes())
    report.append(f"\n=== {sub}: NES gm=${nb.game_mode:02X} ppuctrl=${nb.ppuctrl:02X} "
                  f"(8x16={nb.sprite_8x16}) MenuState=${nb.cave:02X} | Gen scene=${gb.scene:02X} ===")
    d = 0
    d += diff_palette(nb, gb, lut, report)
    d += diff_sprites(nb, gb, lut, report)
    d += diff_bg(nb, gb, lut, report)
    return d


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--nes", required=True)
    ap.add_argument("--gen", required=True)
    ap.add_argument("--sub", help="single sub-state; default active+blink0+blink1")
    a = ap.parse_args(argv)
    nes_dir = Path(a.nes); gen_dir = Path(a.gen)
    lut = C.load_nes_to_cram_lut(PALETTES_C)
    subs = [a.sub] if a.sub else ["active", "blink0", "blink1"]
    report = []
    total = 0
    for s in subs:
        total += diff_sub(nes_dir, gen_dir, s, lut, report)
    total += diff_scroll(nes_dir, gen_dir, report)
    print("\n".join(report))
    print(f"\n{'='*60}\nGATE DIVERGENCES (PAL0 BG + BG presence + sprites + scroll): {total}")
    print("VERDICT:", "PASS — pause subscreen byte-exact (modulo SAT+128 / CRAM quantize)"
          if total == 0 else "FAIL — divergences above")
    return 0 if total == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
