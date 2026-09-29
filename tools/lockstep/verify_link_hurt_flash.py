"""Compare Link's visible sprite pixels against live NES at hurt snapshots.

Usage: python tools/lockstep/verify_link_hurt_flash.py REPORT TICK [TICK ...]
Requires run_lockstep --snap for every requested game tick. This checks Link's
two NES OAM halves (18/19) against Genesis SAT halves (4/5), including NES
PALRAM -> Genesis CRAM color conversion. Other screen sprites are outside it.
"""

from __future__ import annotations

import sys
from pathlib import Path

from screen_diff import nes_to_cram
from verify_sprites import flipped, gen_img, gen_sprites, nes_px, nes_sprites


def check_tick(report: Path, tick: int, lut: list[int]) -> tuple[int, int]:
    tag = f"f{tick:05d}"
    nes_oam = (report / f"nes.{tag}.oam").read_bytes()
    nes_chr = (report / f"nes.{tag}.chr").read_bytes()
    nes_pal = (report / f"nes.{tag}.pal").read_bytes()
    gen_vram = (report / f"gen.{tag}.vram").read_bytes()
    gen_cram = (report / f"gen.{tag}.cram").read_bytes()
    nes = sorted((s for s in nes_sprites(nes_oam) if s[0] in (18, 19)),
                 key=lambda s: s[1])
    gen = sorted((s for s in gen_sprites(gen_vram) if s[0] in (4, 5)),
                 key=lambda s: s[1])
    if len(nes) != 2 or len(gen) != 2:
        raise ValueError(f"tick {tick}: expected two visible Link halves")
    checked = wrong = 0
    for (_, nx, ny, ntile, nattr), (_, gx, gy, gattr, gsize) in zip(nes, gen):
        if nx != gx or gy != ny - 7:
            raise ValueError(f"tick {tick}: Link half position mismatch")
        nimage = flipped(nes_px(nes_chr, ntile),
                         (nattr >> 6) & 1, (nattr >> 7) & 1)
        gimage, width, height = gen_img(gen_vram, gattr, gsize)
        if (width != 8 or height != 16):
            raise ValueError(f"tick {tick}: unexpected Genesis Link half size")
        gpal = (gattr >> 13) & 3
        for nrow, grow in zip(nimage, gimage):
            for npixel, gpixel in zip(nrow, grow):
                if npixel == gpixel == 0:
                    continue
                ncolor = (lut[nes_pal[16 + (nattr & 3) * 4 + npixel]]
                          if npixel else None)
                gidx = (gpal * 16 + gpixel) * 2
                gcolor = (int.from_bytes(gen_cram[gidx:gidx + 2], "big")
                          if gpixel else None)
                checked += 1
                wrong += ncolor != gcolor
    print(f"tick {tick}: Link colored pixels {checked - wrong}/{checked}")
    return checked, wrong


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    report = Path(sys.argv[1])
    lut = nes_to_cram()
    checked = wrong = 0
    for arg in sys.argv[2:]:
        count, misses = check_tick(report, int(arg), lut)
        checked += count
        wrong += misses
    print(f"TOTAL: {checked - wrong}/{checked} exact")
    return 0 if wrong == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
