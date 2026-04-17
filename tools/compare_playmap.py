"""compare_playmap.py — byte-diff Gen playmap vs NES playmap for a room.

Usage: python tools/compare_playmap.py 75

Both captures already include `playmap_rows` (NES after the recent
nes_room_capture.lua update). This prints mismatches at the metatile
level (pre-render), which is what LayoutRoomOrCaveOW produces — much
more useful for finding decoder bugs than visible-row diffs.
"""
import json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ROOMS = ROOT / "builds" / "reports" / "rooms"

def main():
    if len(sys.argv) < 2:
        print(__doc__); return 1
    rid = int(sys.argv[1], 16)
    nes = json.loads((ROOMS / f"nes_room_{rid:02X}.json").read_text())
    gen = json.loads((ROOMS / f"gen_room_{rid:02X}.json").read_text())
    np = nes.get("playmap_rows")
    gp = gen.get("playmap_rows")
    if not np:
        print("NES capture has no playmap_rows — re-capture NES after pulling latest nes_room_capture.lua"); return 1
    if not gp:
        print("GEN capture has no playmap_rows"); return 1
    rows = len(np); cols = len(np[0])
    mm = []
    for r in range(rows):
        for c in range(cols):
            if np[r][c] != gp[r][c]:
                mm.append((r, c, np[r][c], gp[r][c]))
    print(f"Room ${rid:02X} playmap-level mismatches: {len(mm)}/{rows*cols}")
    for r, c, n, g in mm[:40]:
        print(f"  row{r:02d} col{c:02d}  NES=${n:02X}  GEN=${g:02X}")
    # Column-major view — show full columns with diffs
    cols_bad = sorted({c for _, c, _, _ in mm})
    print(f"\nColumns touched: {cols_bad}")
    for c in cols_bad[:8]:
        ncol = " ".join(f"{np[r][c]:02X}" for r in range(rows))
        gcol = " ".join(f"{gp[r][c]:02X}" for r in range(rows))
        print(f" col{c:02d} NES: {ncol}")
        print(f"         GEN: {gcol}")

if __name__ == "__main__":
    raise SystemExit(main())
