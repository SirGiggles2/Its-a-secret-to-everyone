#!/usr/bin/env python3
"""Side-by-side viewer for NES vs Gen room screenshots.

Emits C:/tmp/dual/diff/VIEWER.md with per-room <img> embeds + div count.
"""
import re
from pathlib import Path

ROOT = Path("C:/tmp/dual")
NES  = ROOT / "nes"
GEN  = ROOT / "gen"
DIFF = ROOT / "diff"

def main():
    rooms = []
    for d in NES.iterdir():
        if not d.is_dir():
            continue
        m = re.match(r"^lv([0-9A-Fa-f]{2})_rm([0-9A-Fa-f]{2})$", d.name)
        if not m:
            continue
        lv, rm = m.group(1).upper(), m.group(2).upper()
        gen_dir = GEN / d.name
        if not gen_dir.exists():
            continue
        rooms.append((lv, rm, d.name))
    rooms.sort()

    lines = ["# Dual NES↔Gen screenshot viewer\n"]
    lines.append(f"_Rooms in both: {len(rooms)}_\n")
    lines.append("| Level | Room | NES | Gen |")
    lines.append("|---|---|---|---|")
    for lv, rm, tag in rooms:
        nes_png = f"../nes/{tag}/{tag}.png"
        gen_png = f"../gen/{tag}/{tag}.png"
        lines.append(f"| ${lv} | ${rm} | "
                     f"![nes]({nes_png}) | "
                     f"![gen]({gen_png}) |")
    out = DIFF / "VIEWER.md"
    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"Viewer: {out}  ({len(rooms)} rooms)")

if __name__ == "__main__":
    main()
