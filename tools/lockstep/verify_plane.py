"""T-050: byte-diff the Genesis plane playfield against the NES nametable.

Expected Genesis tile index for each playfield cell = ROOMROM_BG_TILE_BASE
(1) + bg_sparse_tile_lut[NES tile][NES attribute sub-palette], from the NES
CIRAM dump (NT0 or NT1, whichever holds the room: tiles + attributes). The Genesis cell is found at
plane A or B (VRAM $C000 / $E000, 128-byte rows) row = row_off + tile_row, col =
col_off + tile_col. The offsets (active slot / row base) come from the
command line, or, when omitted, the best-matching of row 0..63 x col 0/32
is used and reported. Compares the tile index bits only.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def lut():
    s = (ROOT / "RoomRom" / "src" / "bg_sparse_chr.c").read_text()
    body = s[s.index("{", s.index("bg_sparse_tile_lut")):]
    rows = re.findall(r"\{\s*(0x[0-9A-Fa-f]+),\s*(0x[0-9A-Fa-f]+),\s*(0x[0-9A-Fa-f]+),\s*(0x[0-9A-Fa-f]+)\s*\}", body)[:256]
    return [[int(x, 16) for x in r] for r in rows]


def main():
    d = Path(sys.argv[1])
    L = lut()
    nt = (d / "nes.nt").read_bytes()
    v = (d / "gen.vram").read_bytes()
    if len(sys.argv) > 3:
        offsets = [(int(sys.argv[2]), int(sys.argv[3]), 0xC000, 0)]
    else:
        offsets = [(r, c, b, n) for n in (0, 0x400) for b in (0xC000, 0xE000) for r in range(64) for c in (0, 32)]
    best = None
    for row_off, col_off, plane, ntb in offsets:
        bad = compare(L, nt[ntb:ntb + 0x400], v, row_off, col_off, plane)
        if best is None or score(bad) < score(best[4]):
            best = (row_off, col_off, plane, ntb, bad)
    row_off, col_off, plane, ntb, bad = best
    print(f"NES NT{ntb // 0x400} -> plane ${plane:04X} offsets row {row_off} col {col_off}")
    report(d, bad)
    return 1 if bad else 0


def score(bad):
    """Tile-identity mismatches weigh far more than sub-palette ones."""
    return sum(1000 if b[6] == "TILE" else 1 for b in bad)


def compare(L, nt, v, row_off, col_off, plane):
    bad = []
    for tr in range(22):
        for tc in range(32):
            ntr = tr + 8
            tile = nt[ntr * 32 + tc]
            attr = nt[0x3C0 + (ntr // 4) * 8 + tc // 4]
            pal = (attr >> (((ntr & 2) << 1) | (tc & 2))) & 3
            slot = L[tile][pal]
            exp = 0 if slot == 0xFFFF else 1 + slot
            a = plane + 2 * ((row_off + tr) % 64 * 64 + (col_off + tc) % 64)
            got = ((v[a] << 8) | v[a + 1]) & 0x7FF
            if got != exp:
                same_tile = any(L[tile][q] != 0xFFFF and got == 1 + L[tile][q] for q in range(4))
                bad.append((tc, tr, tile, pal, exp, got, "palette" if same_tile else "TILE"))
    return bad


def report(d, bad):
    tiles = sum(1 for b in bad if b[6] == "TILE")
    pals = len(bad) - tiles
    print(f"{d.name}: plane playfield {704 - len(bad)}/704 exact; tile identity "
          f"{704 - tiles}/704; sub-palette mismatches {pals} -> "
          f"{'PASS' if not bad else 'FAIL'}")
    for b in bad[:20]:
        print("  col %2d row %2d NES tile %02X pal %d exp %d got %d (%s)" % b)


if __name__ == "__main__":
    raise SystemExit(main())
