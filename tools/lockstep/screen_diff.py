"""Byte-level screen diff of a lockstep snapshot: NES vs Genesis, per pixel.

    python tools/lockstep/screen_diff.py <report_dir> <tick> [--png]

Builds both frames from the snapshot's video memory (run_lockstep --snap T:
nes.fTTTTT.{nt,chr,pal,oam} + nes.ram row T, gen.fTTTTT.{vram,cram,vsram})
and compares every pixel as a Genesis CRAM color word:

NES (256x240): name table $2000 (CIRAM page 0, the only page shown at
scroll 0), BG pattern table from PPUCTRL bit 4 (CurPpuControl $FF),
attributes, PALRAM; OAM sprites (8x16 when PPUCTRL bit 5: odd tile ids
from table $1000), OAM order priority, behind-BG bit, Y + 1. Each NES
color goes through data/misc/palettes.c misc_palettes (the port's
NES-color -> CRAM table, roomrom_bg_palette_nes_to_cram). Supported only
for screens at scroll 0 without the sprite-0 split: CurHScroll $FD,
CurVScroll $FC, PPUCTRL name-table bits and IsSprite0CheckActive $E3
must be 0, else the tool stops (it does not model scrolling screens).

Genesis (256x224): the gameplay VDP layout from RoomRom/src/main.c
init_video (plane A and B at $C000, 64x64 cells, H scroll table $F000 per
plane, SAT $F400); VSRAM words 0/1. The HUD window is not modelled: use
only for screens that turn it off (GameMode 8 / $0D, roomrom_mode8_blank).
Planes B/A and sprites with priority bits, SAT link chain from slot 0,
backdrop = CRAM 0.

The Genesis frame is the NES frame without its top 8 lines: Genesis line
y is NES line y + 8. Verdict line "SCREEN: MATCH" or "SCREEN: DIFF <n>".
--png writes both frames and a diff mask next to the report (triage only).
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def nes_to_cram() -> list[int]:
    src = (ROOT / "data" / "misc" / "palettes.c").read_text(encoding="utf-8")
    body = src[src.index("misc_palettes"):]
    body = body[body.index("{") + 1: body.index("}")]
    vals = [int(v, 0) for v in re.findall(r"0x[0-9A-Fa-f]+|\d+", body)]
    return [vals[2 * c] | (vals[2 * c + 1] << 8) for c in range(64)]


def nes_frame(nt: bytes, chr_: bytes, pal: bytes, oam: bytes, ram: bytes) -> list[list[int]]:
    ctrl = ram[0xFF]
    if ram[0xFD] or ram[0xFC] or (ctrl & 3) or ram[0xE3]:
        raise SystemExit(f"NES screen scrolled/split (H {ram[0xFD]:02X} V {ram[0xFC]:02X} "
                         f"ctrl {ctrl:02X} sprite0 {ram[0xE3]:02X}): not supported")
    bg_tab = 0x1000 if ctrl & 0x10 else 0
    tall = bool(ctrl & 0x20)
    spr_tab = 0x1000 if ctrl & 0x08 else 0

    def tile_px(base: int, tile: int, x: int, y: int) -> int:
        a = base + tile * 16 + y
        return ((chr_[a] >> (7 - x)) & 1) | (((chr_[a + 8] >> (7 - x)) & 1) << 1)

    img = [[0] * 256 for _ in range(240)]
    opaque = [[False] * 256 for _ in range(240)]
    for ty in range(30):
        for tx in range(32):
            t = nt[ty * 32 + tx]
            at = nt[0x3C0 + (ty // 4) * 8 + tx // 4]
            p = (at >> (((ty % 4) // 2) * 4 + ((tx % 4) // 2) * 2)) & 3
            for y in range(8):
                for x in range(8):
                    c = tile_px(bg_tab, t, x, y)
                    img[ty * 8 + y][tx * 8 + x] = pal[p * 4 + c] if c else pal[0]
                    opaque[ty * 8 + y][tx * 8 + x] = c != 0
    done = [[False] * 256 for _ in range(240)]
    for i in range(64):
        sy, t, a, sx = oam[i * 4: i * 4 + 4]
        if sy >= 0xEF:
            continue
        h = 16 if tall else 8
        for y in range(h):
            yy = sy + 1 + y
            if yy >= 240:
                continue
            ry = (h - 1 - y) if a & 0x80 else y
            if tall:
                base = 0x1000 if t & 1 else 0
                tt = (t & 0xFE) + (1 if ry >= 8 else 0)
                ry &= 7
            else:
                base, tt = spr_tab, t
            for x in range(8):
                xx = sx + x
                if xx >= 256 or done[yy][xx]:
                    continue
                rx = (7 - x) if a & 0x40 else x
                c = tile_px(base, tt, rx, ry)
                if not c:
                    continue
                done[yy][xx] = True
                if (a & 0x20) and opaque[yy][xx]:
                    continue
                img[yy][xx] = pal[0x10 + (a & 3) * 4 + c]
    return img


def gen_frame(vram: bytes, cram: bytes, vsram: bytes) -> list[list[int]]:
    cw = [(cram[2 * i] << 8) | cram[2 * i + 1] for i in range(64)]

    def word(a: int) -> int:
        return (vram[a & 0xFFFF] << 8) | vram[(a + 1) & 0xFFFF]

    def tile_px(tile: int, x: int, y: int) -> int:
        b = vram[(tile * 32 + y * 4 + x // 2) & 0xFFFF]
        return (b >> 4) if x % 2 == 0 else (b & 15)

    hs = [word(0xF000), word(0xF002)]
    vs = [(vsram[0] << 8) | vsram[1], (vsram[2] << 8) | vsram[3]]
    # layers: (color index or None, priority) per pixel
    def plane(n: int):
        out = [[(0, 0)] * 256 for _ in range(224)]
        for y in range(224):
            py = (y + vs[n]) & 511
            for x in range(256):
                px = (x - hs[n]) & 511
                w = word(0xC000 + ((py >> 3) * 64 + (px >> 3)) * 2)
                tx, ty = px & 7, py & 7
                if w & 0x0800:
                    tx = 7 - tx
                if w & 0x1000:
                    ty = 7 - ty
                c = tile_px(w & 0x7FF, tx, ty)
                out[y][x] = (((w >> 13) & 3) * 16 + c if c else 0, w >> 15)
        return out
    pb, pa = plane(1), plane(0)
    spr = [[(0, 0)] * 256 for _ in range(224)]
    sat, seen, s = 0xF400, set(), 0
    order = []
    while s not in seen and len(order) < 80:
        seen.add(s)
        order.append(s)
        s = vram[sat + s * 8 + 3] & 0x7F
        if s == 0:
            break
    for s in order:
        e = sat + s * 8
        y0 = (((vram[e] << 8) | vram[e + 1]) & 0x3FF) - 128
        hw, vh = ((vram[e + 2] >> 2) & 3) + 1, (vram[e + 2] & 3) + 1
        at = word(e + 4)
        x0 = (word(e + 6) & 0x1FF) - 128
        for y in range(vh * 8):
            yy = y0 + y
            if not 0 <= yy < 224:
                continue
            ry = (vh * 8 - 1 - y) if at & 0x1000 else y
            for x in range(hw * 8):
                xx = x0 + x
                if not 0 <= xx < 256 or spr[yy][xx][0]:
                    continue
                rx = (hw * 8 - 1 - x) if at & 0x0800 else x
                tile = (at & 0x7FF) + (rx // 8) * vh + ry // 8
                c = tile_px(tile, rx & 7, ry & 7)
                if c:
                    spr[yy][xx] = (((at >> 13) & 3) * 16 + c, at >> 15)
    img = [[cw[0]] * 256 for _ in range(224)]
    for y in range(224):
        for x in range(256):
            for layer, pr in ((pb, 0), (pa, 0), (spr, 0), (pb, 1), (pa, 1), (spr, 1)):
                c, p = layer[y][x]
                if c and p == pr:
                    img[y][x] = cw[c]
    return img


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("dir", type=Path)
    ap.add_argument("tick", type=int)
    ap.add_argument("--png", action="store_true")
    a = ap.parse_args()
    d, t = a.dir, f"f{a.tick:05d}"
    ram = (d / "nes.ram").read_bytes()[a.tick * 0x800:(a.tick + 1) * 0x800]
    lut = nes_to_cram()
    nes = nes_frame((d / f"nes.{t}.nt").read_bytes(), (d / f"nes.{t}.chr").read_bytes(),
                    (d / f"nes.{t}.pal").read_bytes(), (d / f"nes.{t}.oam").read_bytes(), ram)
    gen = gen_frame((d / f"gen.{t}.vram").read_bytes(), (d / f"gen.{t}.cram").read_bytes(),
                    (d / f"gen.{t}.vsram").read_bytes())
    bad = {}
    for y in range(224):
        for x in range(256):
            n = lut[nes[y + 8][x] & 0x3F]
            if n != gen[y][x]:
                bad.setdefault((x // 8, y // 8), []).append((x, y, n, gen[y][x]))
    total = sum(len(v) for v in bad.values())
    for (cx, cy), px in sorted(bad.items(), key=lambda kv: (kv[0][1], kv[0][0]))[:40]:
        x, y, n, g = px[0]
        print(f"  cell ({cx:2d},{cy:2d}) {len(px):2d} px  first ({x},{y}) NES {n:03X} GEN {g:03X}")
    if a.png:
        from PIL import Image

        def rgb(w: int) -> tuple:
            return (((w >> 1) & 7) * 36, ((w >> 5) & 7) * 36, ((w >> 9) & 7) * 36)
        im = Image.new("RGB", (256 * 3 + 16, 224))
        for y in range(224):
            for x in range(256):
                n = lut[nes[y + 8][x] & 0x3F]
                im.putpixel((x, y), rgb(n))
                im.putpixel((264 + x, y), rgb(gen[y][x]))
                im.putpixel((528 + x, y), (255, 0, 0) if n != gen[y][x] else (0, 0, 0))
        im.save(d / f"screen_diff.{t}.png")
    print(f"compared 256x224 px (NES lines 8-231 vs Genesis 0-223)")
    print("SCREEN: MATCH" if not total else f"SCREEN: DIFF {total} px in {len(bad)} cells")
    return 0 if not total else 1


if __name__ == "__main__":
    raise SystemExit(main())
