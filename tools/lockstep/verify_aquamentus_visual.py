"""Compare live NES Aquamentus/fireball sprites to Genesis SAT, CHR and CRAM.

    python tools/lockstep/verify_aquamentus_visual.py REPORT TICK [TICK ...]

Requires --snap captures at the requested ticks. Checks displayed 8x16 sprite
pixels by NES palette color after ROM-derived NES-to-Genesis conversion.
"""
from __future__ import annotations

import sys
from pathlib import Path

from screen_diff import nes_to_cram
from verify_sprites import flipped, gen_img, gen_sprites, nes_px, nes_sprites


def check(report: Path, tick: int, lut: list[int]) -> tuple[int, int, int]:
    tag = f"f{tick:05d}"
    oam = (report / f"nes.{tag}.oam").read_bytes()
    chr_ = (report / f"nes.{tag}.chr").read_bytes()
    pal = (report / f"nes.{tag}.pal").read_bytes()
    vram = (report / f"gen.{tag}.vram").read_bytes()
    cram = (report / f"gen.{tag}.cram").read_bytes()
    gen = gen_sprites(vram)
    boss = shots = pixels = 0

    for number, x, y, tile, attr in nes_sprites(oam):
        is_boss = 0xC0 <= tile <= 0xD2
        is_shot = tile == 0x44
        if not (is_boss or is_shot):
            continue
        candidates = [s for s in gen if s[1] == x and s[2] == y - 7]
        if len(candidates) != 1:
            raise ValueError(f"tick {tick} NES#{number}: expected one Genesis sprite at {x},{y-7}, got {len(candidates)}")
        _, _, _, gattr, gsize = candidates[0]
        np = flipped(nes_px(chr_, tile), (attr >> 6) & 1, (attr >> 7) & 1)
        gp, width, height = gen_img(vram, gattr, gsize)
        if (width, height) != (8, 16):
            raise ValueError(f"tick {tick} NES#{number}: Genesis size {width}x{height}")
        gpal = (gattr >> 13) & 3
        for nr, gr in zip(np, gp):
            for n, g in zip(nr, gr):
                if n == 0 and g == 0:
                    continue
                nc = lut[pal[16 + (attr & 3) * 4 + n]] if n else None
                gc = int.from_bytes(cram[(gpal * 16 + g) * 2:(gpal * 16 + g) * 2 + 2], "big") if g else None
                if nc != gc:
                    raise ValueError(f"tick {tick} NES#{number} tile {tile:02X}: color {nc} != {gc}")
                pixels += 1
        boss += is_boss
        shots += is_shot
    print(f"tick {tick}: boss={boss} fireballs={shots} colored pixels={pixels} exact")
    return boss, shots, pixels


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    report = Path(sys.argv[1])
    lut = nes_to_cram()
    total = [0, 0, 0]
    for arg in sys.argv[2:]:
        counts = check(report, int(arg), lut)
        for i, n in enumerate(counts):
            total[i] += n
    print(f"TOTAL: boss={total[0]} fireballs={total[1]} colored pixels={total[2]} exact")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
