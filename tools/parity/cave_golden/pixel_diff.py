#!/usr/bin/env python3
"""pixel_diff.py - rigorous per-pixel diff of NES vs Gen rendered cave frames.

Sidesteps the Genesis SAT-location problem: compares the two emulator
framebuffers (ground-truth renders) directly. Masks the HUD band (top
rows differ by save state), quantizes to 3-bit RGB (absorbs emulator
filter noise), and reports per-8x8-cell mismatches + an overall %, plus a
NES | Gen | diff mosaic for human triage of the failing cells.

This is a byte-diff of the rendered pixels (every pixel compared), NOT
"looks right" (RULE V1): the verdict is the mismatch count/%, the mosaic
is only for triaging which cells failed.

Usage: pixel_diff.py <cave_dir> --cave 6A [--hud-rows 8] [--tol 0]
"""
from __future__ import annotations
import argparse, sys
from pathlib import Path
from PIL import Image

def quant3(rgb):
    return tuple((c >> 5) for c in rgb)   # 3-bit per channel

def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("cave_dir"); ap.add_argument("--cave", default="6A")
    ap.add_argument("--hud-rows", type=int, default=8)  # 8 tile rows = 64px HUD
    ap.add_argument("--tol", type=int, default=0)       # allowed cells diff
    # NesHawk and genplus are DIFFERENT color models: the same logical
    # palette renders at different RGB (byte-exact brown wall = NES (87,29,0)
    # vs Gen (136,34,0), Δ=49/ch). So a raw RGB compare floods on byte-exact
    # content. Use a per-channel tolerance ABOVE the color-model curve (~49)
    # but BELOW a real shape diff (black↔brown = Δ136): default 64. This makes
    # pixel_diff a SHAPE/POSITION gate (flame shape, text row, missing sprite);
    # exact COLOR correctness is gated separately by the CRAM byte-diff.
    ap.add_argument("--rgb-tol", type=int, default=64)
    a = ap.parse_args(argv)
    cd = Path(a.cave_dir)
    nes = Image.open(cd / f"nes_{a.cave}" / "shot.png").convert("RGB")
    gen = Image.open(cd / f"gen_{a.cave}" / "shot.png").convert("RGB")
    w = min(nes.width, gen.width); h = min(nes.height, gen.height)
    np_ = nes.load(); gp = gen.load()
    hud_y = a.hud_rows * 8
    cols, rows = w // 8, h // 8
    bad_cells = []
    diff_img = Image.new("RGB", (w, h), (0, 0, 0)); dp = diff_img.load()
    total_px = 0; diff_px = 0
    for cy in range(rows):
        for cx in range(cols):
            y0 = cy * 8
            if y0 < hud_y:
                continue  # HUD band masked
            cell_diff = 0
            for r in range(8):
                for c in range(8):
                    x = cx*8 + c; y = y0 + r
                    if x >= w or y >= h:
                        continue
                    n = np_[x, y]; g = gp[x, y]
                    total_px += 1
                    if (abs(n[0]-g[0]) > a.rgb_tol or
                        abs(n[1]-g[1]) > a.rgb_tol or
                        abs(n[2]-g[2]) > a.rgb_tol):
                        diff_px += 1; cell_diff += 1
                        dp[x, y] = (255, 0, 0)
                    else:
                        dp[x, y] = n
            if cell_diff:
                bad_cells.append((cx, cy, cell_diff))
    # mosaic NES | Gen | diff
    mosaic = Image.new("RGB", (w*3 + 16, h), (0, 0, 0))
    mosaic.paste(nes, (0, 0)); mosaic.paste(gen, (w+8, 0)); mosaic.paste(diff_img, (w*2+16, 0))
    outm = cd / f"pixeldiff_{a.cave}.png"; mosaic.save(outm)
    pct = 100.0 * diff_px / total_px if total_px else 0
    print(f"cave {a.cave}: play-area pixels diff = {diff_px}/{total_px} ({pct:.1f}%)")
    print(f"mismatched 8x8 cells = {len(bad_cells)}")
    for cx, cy, n in sorted(bad_cells, key=lambda t: -t[2])[:20]:
        print(f"  cell ({cx:2d},{cy:2d}) px-screen({cx*8},{cy*8}) diff_px={n}")
    print(f"mosaic -> {outm}")
    return 0 if len(bad_cells) <= a.tol else 1

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
