"""T-007 offline check: Q2 overworld room patch (Z_06.asm @PatchQ2Rooms).

1. The 8+8 byte LevelBlockAttrsBQ2Replacement{Offsets,Values} tables in
   data/rooms/dungeons.c at the MANIFEST offsets equal the bytes in the
   supplied NES ROM, found immediately before the @PatchQ2Rooms code.
2. The seven immediate writes coded in level_info_apply_q2_ow_patch equal
   the ROM's own machine code: the exact LDA #imm / STA abs sequence occurs
   once in PRG, and is followed by RTS then the two tables.
3. The C constants and the dungeons_offsets.h defines agree with (1)/(2).

    python tools/audit/test_q2_ow_patch.py [path/to/zelda.nes]
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ROM = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "roms" / "Legend of Zelda, The (USA).nes"

# (value, NES address) for the seven fixed writes, per Z_06.asm lines 247-260.
FIXED = [(0x7B, 0x6A09), (0x7B, 0x6A3A), (0x5A, 0x6A72), (0x72, 0x68BA),
         (0x72, 0x68F2), (0x01, 0x6B3A), (0x00, 0x6B72)]


def blob_bytes() -> bytes:
    text = (ROOT / "data" / "rooms" / "dungeons.c").read_text(encoding="utf-8")
    body = text[text.index("{", text.index("rooms_dungeons")) + 1:]
    body = body[:body.index("}")]
    return bytes(int(x, 16) for x in re.findall(r"0x([0-9A-Fa-f]{2})", body))


def main() -> int:
    rom = ROM.read_bytes()
    prg = rom[16:16 + 8 * 0x4000]
    fails = 0

    code = bytearray()
    for val, addr in FIXED:
        code += bytes([0xA9, val, 0x8D, addr & 0xFF, addr >> 8])
    hits = [m.start() for m in re.finditer(re.escape(bytes(code)), prg)]
    print(f"fixed-write code sequence in PRG: {len(hits)} hit(s) {[hex(h) for h in hits]}")
    if len(hits) != 1:
        print("FAIL: expected exactly one occurrence"); return 1
    after = hits[0] + len(code)
    if prg[after] != 0x60:
        print(f"FAIL: expected RTS after fixed writes, got {prg[after]:02X}"); fails += 1
    rom_offs = prg[after + 1:after + 9]
    rom_vals = prg[after + 9:after + 17]
    print("ROM offsets:", rom_offs.hex(" "), " ROM values:", rom_vals.hex(" "))

    man = json.loads((ROOT / "data" / "rooms" / "MANIFEST.json").read_text(encoding="utf-8"))
    entries = {e["name"]: e for e in man["dungeons"] if isinstance(e, dict) and "name" in e}
    o = entries["LevelBlockAttrsBQ2ReplacementOffsets"]["byte_offset"]
    v = entries["LevelBlockAttrsBQ2ReplacementValues"]["byte_offset"]
    blob = blob_bytes()
    ok_tables = blob[o:o + 8] == rom_offs and blob[v:v + 8] == rom_vals
    print(f"blob@{o:#x}/{v:#x} == ROM tables: {ok_tables}")
    fails += not ok_tables

    hdr = (ROOT / "data" / "rooms" / "dungeons_offsets.h").read_text(encoding="utf-8")
    ho = int(re.search(r"ROOMROM_OW_Q2_ATTRB_REPL_OFFSETS_OFF\s+0x([0-9A-F]+)u", hdr).group(1), 16)
    hv = int(re.search(r"ROOMROM_OW_Q2_ATTRB_REPL_VALUES_OFF\s+0x([0-9A-F]+)u", hdr).group(1), 16)
    ok_hdr = (ho, hv) == (o, v)
    print(f"header offsets == MANIFEST: {ok_hdr}")
    fails += not ok_hdr

    c = (ROOT / "src" / "game" / "world" / "level_info_install.c").read_text(encoding="utf-8")
    fn = c[c.index("void level_info_apply_q2_ow_patch"):]
    fn = fn[:fn.index("\n}\n")]
    got = []
    for base, off, val in re.findall(r"NES_LBA_A_BASE(?: \+ 0x([0-9A-F]+)u)? \+ (\d+)u\]\s*=\s*0x([0-9A-F]+)u", fn):
        got.append((int(val, 16), 0x687E + (int(base, 16) if base else 0) + int(off)))
    ok_c = got == FIXED
    print(f"C immediates == ROM code: {ok_c} {[(hex(a), hex(b)) for a, b in got]}")
    fails += not ok_c

    print("PASS" if not fails else f"FAIL ({fails})")
    return 1 if fails else 0


if __name__ == "__main__":
    raise SystemExit(main())
