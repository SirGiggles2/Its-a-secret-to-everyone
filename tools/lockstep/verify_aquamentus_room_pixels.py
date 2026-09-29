"""Compare NES L1 boss-room background pixels to Genesis plane A/CRAM.

Usage: python tools/lockstep/verify_aquamentus_room_pixels.py REPORT TICK
Requires run_lockstep.py --snap TICK. The 22x32 playfield maps NES NT0 rows
8..29 to Genesis plane A at row offset 47 (measured by verify_plane.py).
"""

from pathlib import Path
import sys

from screen_diff import nes_to_cram
from verify_plane import compare, lut


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    report = Path(sys.argv[1])
    tick = int(sys.argv[2])
    tag = f"f{tick:05d}"
    nt = (report / f"nes.{tag}.nt").read_bytes()[:1024]
    chr_ = (report / f"nes.{tag}.chr").read_bytes()
    pal = (report / f"nes.{tag}.pal").read_bytes()
    vram = (report / f"gen.{tag}.vram").read_bytes()
    cram = (report / f"gen.{tag}.cram").read_bytes()
    ram = (report / "nes.ram").read_bytes()[tick * 2048:(tick + 1) * 2048]
    bad_cells = compare(lut(), nt, vram, 47, 0, 0xC000)
    if bad_cells:
        raise ValueError(f"tick {tick}: {len(bad_cells)} playfield tile/attribute mismatches: {bad_cells[:3]}")

    bg_base = 0x1000 if ram[0xFF] & 0x10 else 0
    color_lut = nes_to_cram()
    bad_pixels = []
    for tr in range(22):
        for tc in range(32):
            ntr = tr + 8
            ntile = nt[ntr * 32 + tc]
            attr = nt[0x3C0 + (ntr // 4) * 8 + tc // 4]
            npal = (attr >> (((ntr & 2) << 1) | (tc & 2))) & 3
            cell_addr = 0xC000 + 2 * (((47 + tr) % 64) * 64 + tc)
            word = (vram[cell_addr] << 8) | vram[cell_addr + 1]
            gtile, gpal = word & 0x7FF, (word >> 13) & 3
            for y in range(8):
                for x in range(8):
                    naddr = bg_base + ntile * 16 + y
                    npx = ((chr_[naddr] >> (7 - x)) & 1) | (((chr_[naddr + 8] >> (7 - x)) & 1) << 1)
                    gx = 7 - x if word & 0x0800 else x
                    gy = 7 - y if word & 0x1000 else y
                    gbyte = vram[gtile * 32 + gy * 4 + gx // 2]
                    gpx = (gbyte >> 4) if gx % 2 == 0 else (gbyte & 15)
                    if not npx and not gpx:
                        continue
                    ncolor = color_lut[pal[npal * 4 + npx]] if npx else None
                    goff = (gpal * 16 + gpx) * 2
                    gcolor = int.from_bytes(cram[goff:goff + 2], "big") if gpx else None
                    if ncolor != gcolor:
                        bad_pixels.append((tc * 8 + x, tr * 8 + y, ncolor, gcolor))
    total = 22 * 32 * 64
    print(f"tick {tick}: room plane 704/704 cells; background pixels {total-len(bad_pixels)}/{total} exact")
    if bad_pixels:
        print("first mismatches:", bad_pixels[:8])
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
