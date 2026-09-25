"""T-050: byte-diff NES PlayAreaTiles ($6530-$67DB, 32 columns x $16 rows,
column-major) at the end of a lockstep capture.

NES: Battery RAM dump (<nes>.wram, $6000-based). Genesis: 68K work RAM
dump (<gen>.m68k), NES $6000+ mirrored at $FFE000+ (A4 base $FF8000).
Both runs must end in the same room (RoomId $EB in the last RAM frame).
"""
import sys
from pathlib import Path

from diff import load

BASE, LEN = 0x6530, 32 * 0x16


def main():
    d = Path(sys.argv[1])
    nes_ram, gen_ram = load(d / "nes")[-1], load(d / "gen")[-1]
    if nes_ram[0xEB] != gen_ram[0xEB]:
        raise SystemExit(f"ERROR: rooms differ NES {nes_ram[0xEB]:02X} GEN {gen_ram[0xEB]:02X}")
    nes = (d / "nes.wram").read_bytes()[BASE - 0x6000:BASE - 0x6000 + LEN]
    gen = (d / "gen.m68k").read_bytes()[0xE000 + BASE - 0x6000:0xE000 + BASE - 0x6000 + LEN]
    diffs = [(i // 0x16, i % 0x16, nes[i], gen[i]) for i in range(LEN) if nes[i] != gen[i]]
    print(f"{d.name}: room {nes_ram[0xEB]:02X} PlayAreaTiles {LEN - len(diffs)}/{LEN} equal"
          f" -> {'PASS' if not diffs else 'FAIL'}")
    for c, r, n, g in diffs[:40]:
        print(f"  col {c:2d} row {r:2d}: NES {n:02X} GEN {g:02X}")
    return 1 if diffs else 0


if __name__ == "__main__":
    raise SystemExit(main())
