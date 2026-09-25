"""Sprite byte check at a lockstep run's final frame: NES OAM vs Genesis SAT.

    python tools/lockstep/verify_sprites.py builds/reports/lockstep/<name>

Every visible NES OAM sprite (8x16 mode: even tile = PT0 tile/tile+1, odd
tile = PT1 tile-1/tile) is paired with the Genesis SAT sprite (gameplay SAT
at VRAM $F400, link chain from slot 0) at the same X and Y + dy, where dy is
the one global offset that pairs the most sprites (NES OAM Y is top - 1;
the Genesis status bar sits in a different row band, so HUD rows may pair
with their own dy). Per pair: pixels must match under one consistent
NES-value -> Genesis-nibble mapping (colour 0 -> 0), NES sub-palette must
route to Genesis PAL1/2/3 (sub-pal 0/1/2, 3 -> PAL2; subpal_routing.h), and
h/v flip must match. Unpaired NES sprites are reported.
"""
from __future__ import annotations

import sys
from collections import Counter
from pathlib import Path

SUBPAL_TO_PAL = {0: 1, 1: 2, 2: 3, 3: 2}


def nes_sprites(oam: bytes):
    out = []
    for i in range(64):
        y, t, a, x = oam[i * 4:i * 4 + 4]
        if y >= 0xEF:
            continue
        out.append((i, x, y, t, a))
    return out


def gen_sprites(vram: bytes):
    out, i, seen = [], 0, set()
    while i not in seen and len(seen) < 80:
        seen.add(i)
        e = vram[0xF400 + i * 8:0xF400 + i * 8 + 8]
        y = ((e[0] << 8) | e[1]) - 128
        size, link = e[2], e[3]
        attr = (e[4] << 8) | e[5]
        x = ((e[6] << 8) | e[7]) - 128
        out.append((i, x, y, attr, size))
        if link == 0:
            break
        i = link
    return out


def nes_px(chr_: bytes, tile: int):
    pt, top = tile & 1, tile & 0xFE
    rows = []
    for t in (top, top + 1):
        b = pt * 0x1000 + t * 16
        for y in range(8):
            lo, hi = chr_[b + y], chr_[b + 8 + y]
            rows.append([((lo >> (7 - x)) & 1) | (((hi >> (7 - x)) & 1) << 1) for x in range(8)])
    return rows


def gen_img(vram: bytes, attr: int, size: int):
    """Displayed pixels of a Genesis sprite (tiles column-major, flips
    applied to the whole sprite)."""
    w, h = ((size >> 2) & 3) + 1, (size & 3) + 1
    tile = attr & 0x7FF
    img = [[0] * (w * 8) for _ in range(h * 8)]
    for c in range(w):
        for r in range(h):
            k = tile + c * h + r
            for y in range(8):
                row = vram[k * 32 + y * 4:k * 32 + y * 4 + 4]
                for x in range(8):
                    img[r * 8 + y][c * 8 + x] = (row[x // 2] >> (4 * (1 - x % 2))) & 0xF
    return flipped(img, (attr >> 11) & 1, (attr >> 12) & 1), w * 8, h * 8


def flipped(rows, h, v):
    if h:
        rows = [r[::-1] for r in rows]
    if v:
        rows = rows[::-1]
    return rows


def main() -> int:
    d = Path(sys.argv[1])
    oam = (d / "nes.oam").read_bytes()
    chr_ = (d / "nes.chr").read_bytes()
    vram = (d / "gen.vram").read_bytes()
    ns, gs = nes_sprites(oam), gen_sprites(vram)
    def covering(x, y):
        """Genesis sprites whose box contains an 8x16 NES sprite at (x, y)."""
        out = []
        for g in gs:
            w, h = (((g[4] >> 2) & 3) + 1) * 8, ((g[4] & 3) + 1) * 8
            if g[1] <= x and x + 8 <= g[1] + w and g[2] <= y and y + 16 <= g[2] + h:
                out.append(g)
        return out
    dys = Counter()
    for _, x, y, _, _ in ns:
        for dy in range(-16, 17):
            if covering(x, y + dy):
                dys[dy] += 1
    ok = bad = 0
    unpaired = []
    offsets = []
    for i, x, y, t, a in ns:
        cands = [(dy, g) for dy, _ in dys.most_common() for g in covering(x, y + dy)]
        if not cands:
            unpaired.append(f"NES#{i} x{x:02X} y{y:02X} t{t:02X}")
            continue
        best = None
        for dy, g in cands:
            gattr = g[3]
            img, _, _ = gen_img(vram, gattr, g[4])
            ox, oy = x - g[1], (y + dy) - g[2]
            g_disp = [row[ox:ox + 8] for row in img[oy:oy + 16]]
            n_disp = flipped(nes_px(chr_, t), (a >> 6) & 1, (a >> 7) & 1)
            m, px_ok = {0: 0}, True
            for rn, rg in zip(n_disp, g_disp):
                for pn, pg in zip(rn, rg):
                    if m.setdefault(pn, pg) != pg:
                        px_ok = False
            px_ok = px_ok and len(set(m.values())) == len(m)
            pal = (gattr >> 13) & 3
            errs = [] if px_ok else ["pixels"]
            if pal != SUBPAL_TO_PAL[a & 3]:
                errs.append(f"pal {pal} want {SUBPAL_TO_PAL[a & 3]}")
            if best is None or len(errs) < len(best[2]):
                best = (dy, g, errs)
            if not errs:
                break
        dy, g, errs = best
        if errs:
            bad += 1
            print(f"  FAIL NES#{i} x{x:02X} y{y:02X} t{t:02X} a{a:02X} -> GEN slot{g[0]} "
                  f"tile{g[3] & 0x7FF}: {', '.join(errs)}")
        else:
            ok += 1
            if dy != dys.most_common(1)[0][0]:
                offsets.append(f"NES#{i} t{t:02X} x{x:02X} y{y:02X} matched GEN slot{g[0]} at dy {dy}")
    for o in offsets:
        print(f"  OFFSET {o}")
    for u in unpaired:
        print(f"  UNPAIRED {u}")
    verdict = "PASS" if bad == 0 and not unpaired else "FAIL"
    print(f"{d.name}: sprites {ok}/{len(ns)} exact (pixels+palette), {bad} wrong, "
          f"{len(unpaired)} unpaired; dy {dict(dys.most_common(3))} -> {verdict}")
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
