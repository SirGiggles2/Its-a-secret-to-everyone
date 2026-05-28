#!/usr/bin/env python3
"""render_check.py - validate the differ's sprite decode against ground truth.

Decodes the NES OAM and Gen SAT from a captured bundle the SAME way
cave_byte_diff.py does, plots each sprite cell at its screen position
using its real color, and writes nes_render.png / gen_render.png. Compare
those to the emulator's shot.png: if they match, the decode is correct and
the byte-diff layout findings are trustworthy; if not, the decoder is wrong
and must be fixed before any verdict (RULE V1 applied to the tool itself).

Usage: render_check.py <cave_dir> --cave 6A [--frame 0]
"""
from __future__ import annotations
import argparse, sys
from pathlib import Path
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from cave_byte_diff import (NesBundle, GenBundle, load_nes_to_cram_lut,
                            nes_sprites, gen_sprites, nes_bg_cells, gen_bg_cells,
                            cram_to_rgb, PALETTES_C)

def blit(img, cells, ox=0, oy=0):
    px = img.load(); w, h = img.size
    for c in cells:
        for r in range(8):
            for col in range(8):
                word = c.px[r][col]
                if word is None:
                    continue
                x = c.x + col + ox; y = c.y + r + oy
                if 0 <= x < w and 0 <= y < h:
                    px[x, y] = cram_to_rgb(word)
    return img

def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("cave_dir"); ap.add_argument("--cave", default="6A")
    ap.add_argument("--frame", type=int, default=0)
    a = ap.parse_args(argv)
    lut = load_nes_to_cram_lut(PALETTES_C)
    nd = Path(a.cave_dir) / f"nes_{a.cave}" / f"f{a.frame:03d}.bin"
    gd = Path(a.cave_dir) / f"gen_{a.cave}" / f"f{a.frame:03d}.bin"
    nb = NesBundle(nd.read_bytes()); gb = GenBundle(gd.read_bytes())
    nc = nes_sprites(nb, lut); gc = gen_sprites(gb, lut)
    nbg = nes_bg_cells(nb, lut); gbg = gen_bg_cells(gb)
    cdir = Path(a.cave_dir)
    # NES full scene: BG nametable (walls/text/HUD) THEN sprites on top.
    rn = Image.new("RGB", (256, 240), (0, 0, 0)); blit(rn, nbg); blit(rn, nc)
    outn = cdir / f"nes_{a.cave}" / "render.png"; rn.save(outn)
    print(f"NES bg_cells={len(nbg)} sprite_cells={len(nc)} -> {outn}")
    # Gen Plane A is 64x32 (512x256 plane space); sprites are screen-space.
    rgbg = Image.new("RGB", (512, 256), (0, 0, 0)); blit(rgbg, gbg)
    outgbg = cdir / f"gen_{a.cave}" / "render_bg.png"; rgbg.save(outgbg)
    rgsp = Image.new("RGB", (320, 224), (0, 0, 0)); blit(rgsp, gc)
    outgsp = cdir / f"gen_{a.cave}" / "render_spr.png"; rgsp.save(outgsp)
    print(f"Gen bg_cells={len(gbg)} -> {outgbg}; sprite_cells={len(gc)} -> {outgsp}")
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
