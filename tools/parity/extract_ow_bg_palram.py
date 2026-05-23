#!/usr/bin/env python3
"""Extract per-room NES BG PALRAM from C:/tmp/dual/nes/lv00_rm*/static.txt
into src/game/world/ow_bg_palram_table.c

Reads $3F00..$3F0F (16 bytes per room) from [PALRAM] section.
"""
import re
from pathlib import Path

NES_DIR = Path("C:/tmp/dual/nes")
OUT_C = Path("C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/src/game/world/ow_bg_palram_table.c")
OUT_H = Path("C:/Users/Jake Diggity/Documents/GitHub/FINAL TRY/src/game/world/ow_bg_palram_table.h")


def parse_palram(path):
    bg = [0] * 16
    if not path.exists():
        return None
    in_palram = False
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if line == "[PALRAM]":
            in_palram = True
            continue
        if in_palram and line.startswith("[") and line != "[PALRAM]":
            break
        if not in_palram:
            continue
        m = re.match(r"^\$3F([0-9A-Fa-f]{2})=\$([0-9A-Fa-f]{2})", line)
        if m:
            addr = int(m.group(1), 16)
            val  = int(m.group(2), 16)
            if addr < 16:
                bg[addr] = val
    return bg


def main():
    rooms_data = {}
    for r in range(128):
        path = NES_DIR / f"lv00_rm{r:02X}" / "static.txt"
        bg = parse_palram(path)
        if bg is None:
            print(f"missing lv00_rm{r:02X}")
            continue
        rooms_data[r] = bg

    OUT_H.write_text(
        "/* Auto-generated. NES BG PALRAM ($3F00..$3F0F) captured per OW room. */\n"
        "#ifndef ROOMROM_OW_BG_PALRAM_TABLE_H\n"
        "#define ROOMROM_OW_BG_PALRAM_TABLE_H\n\n"
        "extern const unsigned char k_ow_bg_palram_per_room[128][16];\n\n"
        "#endif\n",
        encoding="utf-8"
    )

    lines = ["/* Auto-generated from C:/tmp/dual/nes dumps via",
             " * tools/parity/extract_ow_bg_palram.py.\n"
             " * NES BG PALRAM at $3F00..$3F0F per room (16 bytes).\n"
             " * Captured live at frame 240 post-warp from BizHawk Lua probe. */\n",
             '#include "ow_bg_palram_table.h"\n',
             "const unsigned char k_ow_bg_palram_per_room[128][16] = {"]
    for r in range(128):
        bg = rooms_data.get(r, [0x0F]*16)
        hex_bytes = ", ".join(f"0x{b:02X}" for b in bg)
        lines.append(f"    [0x{r:02X}] = {{ {hex_bytes} }},")
    lines.append("};")
    OUT_C.write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote {OUT_C} ({len(rooms_data)} rooms)")


if __name__ == "__main__":
    main()
