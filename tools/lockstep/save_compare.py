"""Save file byte compare: NES battery RAM vs Genesis cart SRAM.

    python tools/lockstep/save_compare.py <report_dir> [--slot N]

Inputs (run_lockstep final dumps): <dir>/nes.wram = NesHawk "Battery RAM"
($6000-$7FFF), <dir>/gen.sram = GPGX "SRAM" raw (logical byte k at index
2k + 1, memory reference_genesis_sram_probe_stride). The Genesis persists
the NES save block $6000-$652F (file A: names, items, world flags, active,
deaths, quest, markers, checksums; src/state/save_serializer.h) byte for
byte at SRAM logical 0 (T-100).

Every byte of the block is compared. Region names come from
save_serializer.h. Verdict line "SAVE: MATCH" or "SAVE: DIFF <n>".
"""
from __future__ import annotations

import argparse
from pathlib import Path

BASE = 0x6000
SIZE = 0x530


def region(a: int) -> str:
    if a < 0x6002:
        return "header"
    if a < 0x601A:
        return f"name slot {(a - 0x6002) // 8}"
    if a < 0x6092:
        return f"items slot {(a - 0x601A) // 0x28} +{(a - 0x601A) % 0x28:02X}"
    if a < 0x6512:
        return f"world flags slot {(a - 0x6092) // 0x180} +{(a - 0x6092) % 0x180:03X}"
    names = [(0x6512, "active"), (0x6515, "unknown"), (0x6518, "deaths"), (0x651B, "quest"),
             (0x651E, "open marker"), (0x6521, "close marker"), (0x6524, "checksum"),
             (0x652A, "file B committed"), (0x652D, "tail")]
    for lo, n in reversed(names):
        if a >= lo:
            return n
    return "?"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("dir", type=Path)
    a = ap.parse_args()
    nes = (a.dir / "nes.wram").read_bytes()
    raw = (a.dir / "gen.sram").read_bytes()
    if len(nes) < SIZE:
        raise SystemExit(f"nes.wram {len(nes)} bytes < {SIZE}")
    if len(raw) < 2 * SIZE:
        raise SystemExit(f"gen.sram {len(raw)} bytes < {2 * SIZE}")
    gen = bytes(raw[2 * k + 1] for k in range(SIZE))
    diffs = [(BASE + k, nes[k], gen[k]) for k in range(SIZE) if nes[k] != gen[k]]
    for addr, n, g in diffs:
        print(f"  ${addr:04X} {region(addr):32s} NES {n:02X}  GEN {g:02X}")
    print(f"compared ${BASE:04X}-${BASE + SIZE - 1:04X} ({SIZE} bytes)")
    print("SAVE: MATCH" if not diffs else f"SAVE: DIFF {len(diffs)}")
    return 0 if not diffs else 1


if __name__ == "__main__":
    raise SystemExit(main())
