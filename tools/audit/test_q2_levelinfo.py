#!/usr/bin/env python3
"""T-002: Q2 LevelInfo install must equal the NES (Z_06 UpdateMode2Load_Full).

Checks, offline, with the user's NES ROM:
 1. dungeons_offsets.h Q2 constants == data/rooms/MANIFEST.json offsets.
 2. Blob replacement arrays are contiguous (the C patch relies on it).
 3. For every level 1..9 and both quests, the LevelInfo that
    level_info_install_uw() would install (simulated from rooms_dungeons)
    equals the NES result computed straight from ROM pointers
    (LevelInfoAddrs + LevelInfoUWQ2ReplacementAddrs/Sizes, copy Sizes+1 bytes).
Run: python tools/audit/test_q2_levelinfo.py [--rom PATH]
"""
import argparse, json, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_ROM = ROOT / "roms" / "Legend of Zelda, The (USA).nes"


def blob_bytes() -> list[int]:
    s = (ROOT / "data/rooms/dungeons.c").read_text(errors="replace")
    s = re.sub(r"/\*.*?\*/", "", s, flags=re.S)
    return [int(x, 0) for x in re.findall(r"0x[0-9a-fA-F]+|\b\d+\b", s[s.index("{"):])]


def manifest() -> dict:
    m = json.loads((ROOT / "data/rooms/MANIFEST.json").read_text())
    out = {}
    for v in m.values():
        if isinstance(v, list):
            for e in v:
                if isinstance(e, dict) and e.get("file") == "dungeons.c":
                    out[e["name"]] = (e["byte_offset"], e["byte_size"])
    return out


def header_const(name: str) -> int:
    h = (ROOT / "data/rooms/dungeons_offsets.h").read_text()
    return int(re.search(rf"#define\s+{name}\s+(0x[0-9A-Fa-f]+)u", h).group(1), 16)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--rom", type=Path, default=DEFAULT_ROM)
    rom = ap.parse_args().rom.read_bytes()[16:]
    b6 = rom[6 * 0x4000:7 * 0x4000]
    blob, man, fails = blob_bytes(), manifest(), []

    sizes_off = header_const("ROOMROM_UW_Q2_LI_REPL_SIZES_OFF")
    base_off = header_const("ROOMROM_UW_Q2_LI_REPL_BASE_OFF")
    if man["LevelInfoUWQ2ReplacementSizes"][0] != sizes_off:
        fails.append("SIZES_OFF != MANIFEST")
    if man["LevelInfoUWQ2Replacements1"][0] != base_off:
        fails.append("BASE_OFF != MANIFEST")
    pos = base_off
    for lv in range(1, 10):
        o, n = man[f"LevelInfoUWQ2Replacements{lv}"]
        if o != pos:
            fails.append(f"Replacements{lv} not contiguous")
        pos = o + n
    if man["LevelInfoUWQ2ReplacementAddrs"][0] != pos:
        fails.append("ReplacementAddrs does not follow Replacements9")

    sizes = blob[sizes_off:sizes_off + 9]
    li_ptrs = [int.from_bytes(b6[0x14 + 2 * i:0x16 + 2 * i], "little") for i in range(10)]
    si = b6.find(bytes(sizes))
    repl_ptrs = [int.from_bytes(b6[si - 18 + 2 * i:si - 16 + 2 * i], "little") for i in range(9)]
    for quest in (1, 2):
        for lv in range(1, 10):
            nes = bytearray(b6[li_ptrs[lv] - 0x8000:li_ptrs[lv] - 0x8000 + 256])
            if quest == 2:
                a, n = repl_ptrs[lv - 1] - 0x8000, sizes[lv - 1] + 1
                nes[0x29:0x29 + n] = b6[a:a + n]
            li_off = man[f"LevelInfoUW{lv}"][0]
            port = bytearray(blob[li_off:li_off + 256])
            if quest == 2:
                src = base_off + sum(sizes[:lv - 1])
                n = sizes[lv - 1] + 1
                port[0x29:0x29 + n] = bytes(blob[src:src + n])
            diff = [i for i in range(256) if nes[i] != port[i]]
            if diff:
                fails.append(f"Q{quest} L{lv}: {len(diff)} bytes differ, first ${0x6B7E + diff[0]:04X}")
    for f in fails:
        print("FAIL", f)
    print("Q2 LevelInfo install:", "PASS 18/18 levels byte-exact vs NES" if not fails else f"{len(fails)} failures")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
