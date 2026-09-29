"""Compare live NES Aquamentus death-spark pixels with Genesis SAT/CHR/CRAM.

Usage: python tools/lockstep/verify_aquamentus_spark.py REPORT TICK [TICK ...]
Snapshots must be captured by run_lockstep.py --snap. The coordinate window
keeps this focused on the boss death spark, not other $62/$64 item sprites.
"""

from pathlib import Path
import sys

from screen_diff import nes_to_cram
from verify_sprites import flipped, gen_img, gen_sprites, nes_px, nes_sprites


def check(report: Path, tick: int, lut: list[int]) -> tuple[int, int, set[int]]:
    tag = f"f{tick:05d}"
    oam = (report / f"nes.{tag}.oam").read_bytes()
    chr_ = (report / f"nes.{tag}.chr").read_bytes()
    pal = (report / f"nes.{tag}.pal").read_bytes()
    vram = (report / f"gen.{tag}.vram").read_bytes()
    cram = (report / f"gen.{tag}.cram").read_bytes()
    gen = gen_sprites(vram)
    sprites = pixels = 0
    attrs: set[int] = set()

    for number, x, y, tile, attr in nes_sprites(oam):
        if tile not in (0x62, 0x64) or not (160 <= x <= 200 and 120 <= y <= 144):
            continue
        candidates = [s for s in gen if s[1] == x and s[2] == y - 7]
        if len(candidates) != 1:
            raise ValueError(f"tick {tick} NES#{number}: expected one Genesis spark at {x},{y-7}, got {len(candidates)}")
        _, _, _, gattr, gsize = candidates[0]
        np = flipped(nes_px(chr_, tile), (attr >> 6) & 1, (attr >> 7) & 1)
        gp, width, height = gen_img(vram, gattr, gsize)
        if (width, height) != (8, 16):
            raise ValueError(f"tick {tick} NES#{number}: Genesis size {width}x{height}")
        gpal = (gattr >> 13) & 3
        for nr, gr in zip(np, gp):
            for n, g in zip(nr, gr):
                if n == g == 0:
                    continue
                nc = lut[pal[16 + (attr & 3) * 4 + n]] if n else None
                offset = (gpal * 16 + g) * 2
                gc = int.from_bytes(cram[offset:offset + 2], "big") if g else None
                if nc != gc:
                    raise ValueError(f"tick {tick} NES#{number} tile {tile:02X} attr {attr:02X}: color {nc} != {gc}")
                pixels += 1
        sprites += 1
        attrs.add(attr & 3)
    print(f"tick {tick}: sparks={sprites} colored pixels={pixels} sub-pals={sorted(attrs)} exact")
    return sprites, pixels, attrs


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    report = Path(sys.argv[1])
    lut = nes_to_cram()
    total_sprites = total_pixels = 0
    seen: set[int] = set()
    for tick_arg in sys.argv[2:]:
        sprites, pixels, attrs = check(report, int(tick_arg), lut)
        total_sprites += sprites
        total_pixels += pixels
        seen.update(attrs)
    if seen != {0, 1, 2, 3}:
        raise ValueError(f"spark palette coverage incomplete: {sorted(seen)}")
    print(f"TOTAL: sparks={total_sprites} colored pixels={total_pixels} sub-pals=0,1,2,3 exact")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
