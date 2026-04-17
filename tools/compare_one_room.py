"""Compare a single room's NES capture against its Gen capture.

Usage:
  python tools/compare_one_room.py 77

Reads builds/reports/rooms/nes_room_XX.json + gen_room_XX.json
and prints a tile/palette diff summary + first ~20 mismatches.
"""
import json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ROOMS = ROOT / "builds" / "reports" / "rooms"

def load(path):
    return json.loads(path.read_text(encoding="utf-8"))

def main():
    if len(sys.argv) < 2:
        print("usage: compare_one_room.py <ROOM_HEX>"); return 1
    rid = int(sys.argv[1], 16)
    nes_p = ROOMS / f"nes_room_{rid:02X}.json"
    gen_p = ROOMS / f"gen_room_{rid:02X}.json"
    if not nes_p.exists():
        print(f"missing: {nes_p}"); return 1
    if not gen_p.exists():
        print(f"missing: {gen_p}"); return 1
    nes = load(nes_p)
    gen = load(gen_p)

    nv = nes["visible_rows"]
    gn = gen["nt_cache_rows"]
    np = nes["palette_rows"]
    gp = gen["palette_rows"]

    tile_mm = []
    pal_mm = []
    for r in range(22):
        for c in range(32):
            if nv[r][c] != gn[r][c]:
                tile_mm.append((r, c, nv[r][c], gn[r][c]))
            if np[r][c] != gp[r][c]:
                pal_mm.append((r, c, np[r][c], gp[r][c]))

    print(f"Room ${rid:02X}")
    print(f"  tile mismatches:    {len(tile_mm)}/{22*32}")
    print(f"  palette mismatches: {len(pal_mm)}/{22*32}")
    if tile_mm:
        print("  First 20 tile diffs (row col nes gen):")
        for r, c, n, g in tile_mm[:20]:
            print(f"    row{r:02d} col{c:02d}  NES=${n:02X}  GEN=${g:02X}")
    if pal_mm:
        print("  First 10 palette diffs (row col nes gen):")
        for r, c, n, g in pal_mm[:10]:
            print(f"    row{r:02d} col{c:02d}  NES={n}  GEN={g}")

    # Palette RAM compare
    pr = nes.get("palette_ram", [])
    cram = gen.get("cram_bg", [])
    if pr and cram:
        print("  NES palette_ram:", " ".join(f"{x:02X}" for x in pr))
        print("  GEN cram_bg:    ", " ".join(f"{x:04X}" for x in cram))

if __name__ == "__main__":
    raise SystemExit(main())
