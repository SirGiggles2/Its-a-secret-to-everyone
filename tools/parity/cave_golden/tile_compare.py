#!/usr/bin/env python3
"""One-off: decode ONE NES BG cell vs the aligned Gen Plane A cell to
rendered CRAM-word grids, side by side, to disambiguate the BG RGB deltas.

Question: are the cave wall tiles pixel-IDENTICAL to NES (color delta =
NES-vs-genplus curve noise) or APPROXIMATIONS (different tile art / wrong
sub-pal mapping)? This prints both 8x8 grids + a per-pixel diff so the
answer is byte-visible, not guessed.

Usage: python tile_compare.py <cave_golden_dir> --cave 6A --frame 120 --col 0 --row 8
"""
import sys, argparse, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).parent))
import cave_byte_diff as D

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cave_dir")
    ap.add_argument("--cave", default="6A")
    ap.add_argument("--frame", type=int, default=120)
    ap.add_argument("--col", type=int, default=0)   # NES NT col
    ap.add_argument("--row", type=int, default=8)    # NES NT row
    a = ap.parse_args()
    base = pathlib.Path(a.cave_dir)
    nb = D.NesBundle((base / f"nes_{a.cave}" / f"f{a.frame:03d}.bin").read_bytes())
    gb = D.GenBundle((base / f"gen_{a.cave}" / f"f{a.frame:03d}.bin").read_bytes())
    lut = D.load_nes_to_cram_lut(D.PALETTES_C)

    # NES cell
    col, row = a.col, a.row
    tile = nb.ciram[row * 32 + col]
    ab = nb.ciram[960 + (row // 4) * 8 + (col // 4)]
    shift = (((row // 2) & 1) * 2 + ((col // 2) & 1)) * 2
    subpal = (ab >> shift) & 3
    ng = D.nes_tile_2bpp(nb.chr, tile, nb.bg_table)
    nes_px = [[ (nb.palram[0] if ng[r][c]==0 else nb.palram[subpal*4+ng[r][c]])
                for c in range(8)] for r in range(8)]
    nes_cram = [[ D.nes_to_cram(lut, nes_px[r][c]) for c in range(8)] for r in range(8)]

    # Gen cell at same screen position (caves static, offset 0)
    o = 0xC000 + (row * 64 + col) * 2
    e = (gb.vram[o] << 8) | gb.vram[o+1]
    gpal = (e >> 13) & 3; gtile = e & 0x7FF
    gg = D.gen_tile_4bpp(gb.vram, gtile)
    gen_cram = [[ gb.cram_word(gpal*16 + gg[r][c]) for c in range(8)] for r in range(8)]

    print(f"cave {a.cave} f{a.frame} cell(col={col},row={row})")
    print(f"  NES tile=${tile:02X} subpal={subpal} (2bpp idx)   "
          f"GEN tile=${gtile:03X} pal={gpal} (4bpp idx)")
    print("  NES idx grid:        GEN idx grid:        match?")
    diffpx = 0
    for r in range(8):
        nrow = "".join(f"{ng[r][c]:x}" for c in range(8))
        grow = "".join(f"{gg[r][c]:x}" for c in range(8))
        mrow = ""
        for c in range(8):
            same = nes_cram[r][c] == gen_cram[r][c]
            mrow += "." if same else "X"
            if not same: diffpx += 1
        print(f"  {nrow}   {grow}   {mrow}")
    print(f"  rendered-color diff px = {diffpx}/64")
    # Show the distinct CRAM words each side uses
    nset = sorted({nes_cram[r][c] for r in range(8) for c in range(8)})
    gset = sorted({gen_cram[r][c] for r in range(8) for c in range(8)})
    print(f"  NES colors: {[D.hexw(w) for w in nset]}")
    print(f"  GEN colors: {[D.hexw(w) for w in gset]}")

    # HUNT: translate NES subpal-3 idx (0->0, 1->13, 2->14, 3->15; matches
    # palram[12..15] -> CRAM[12..15]) into the expected Gen 4bpp idx grid,
    # then scan ALL Gen VRAM tiles 0..2047 for an EXACT pattern match. If one
    # exists, the renderer picked the wrong atlas tile (cheap map fix). If
    # none, the atlas lacks NES $D8's exact art -> CHR regen needed.
    n2g = {0:0, 1:12+1, 2:12+2, 3:12+3}
    want = [[ n2g[ng[r][c]] for c in range(8)] for r in range(8)]
    hits = []
    for t in range(2048):
        gt = D.gen_tile_4bpp(gb.vram, t)
        if all(gt[r][c] == want[r][c] for r in range(8) for c in range(8)):
            hits.append(t)
    print(f"  HUNT exact NES-$%02X-pattern in Gen VRAM (subpal3->idx 0/13/14/15): "
          % tile + (f"FOUND at {[hex(h) for h in hits]}" if hits
                    else "NONE -> atlas tile is an approximation (CHR regen needed)"))

if __name__ == "__main__":
    main()
