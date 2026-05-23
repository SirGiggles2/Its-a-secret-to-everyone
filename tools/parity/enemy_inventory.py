#!/usr/bin/env python3
"""Scan NES dumps and emit a per-(level, room) enemy-type inventory.

Reads C:/tmp/dual/nes/lv*_rm*/static.txt [SLOTS] section, parses each
slot's t:$XX type byte, builds a map: enemy_type → [(level, room), ...].

Output: C:/tmp/dual/enemy_inventory.md  + .json
Helps pick rooms with specific enemy types for targeted parity work.
"""
import json
import re
from pathlib import Path
from collections import defaultdict

NES_DIR = Path("C:/tmp/dual/nes")
OUT_MD  = Path("C:/tmp/dual/enemy_inventory.md")
OUT_JSON = Path("C:/tmp/dual/enemy_inventory.json")

# NES Z1 enemy type names (partial — fill as needed)
TYPE_NAMES = {
    0x01: "Lynel",
    0x02: "BlueLynel",
    0x03: "RedMoblin",
    0x04: "BlueMoblin",
    0x05: "Octorok",
    0x07: "RedOctorok",
    0x08: "BlueOctorok",
    0x09: "RedOctorokFast",
    0x0A: "BlueOctorokFast",
    0x0B: "RedTektite",
    0x0C: "BlueTektite",
    0x0D: "RedLeever",
    0x0E: "BlueLeever",
    0x0F: "Zora",
    0x10: "RedPeahat",
    0x11: "Vire",
    0x12: "Zol",
    0x13: "Gel",
    0x14: "PolsVoice",
    0x15: "LikeLike",
    0x16: "PolsVoice2",
    0x17: "LikeLike2",
    0x18: "Stalfos",
    0x19: "Gibdo",
    0x1A: "Goriya",
    0x1B: "BlueGoriya",
    0x1C: "RedDarknut",
    0x1D: "BlueDarknut",
    0x1E: "Armos",
    0x1F: "Wallmaster",
    0x20: "Rope",
    0x21: "BlueRope",
    0x22: "Keese",
    0x23: "BlueKeese",
    0x24: "RedKeese",
    0x25: "ZolBlob",
    0x26: "RedWizzrobe",
    0x27: "BlueWizzrobe",
    0x28: "Aquamentus",
    0x29: "Dodongo",
    0x2A: "Gohma",
    0x2B: "Manhandla",
    0x2C: "Gleeok1",
    0x2D: "Gleeok2",
    0x2E: "Gleeok3",
    0x2F: "Gleeok4",
    0x30: "Digdogger",
    0x31: "DigdoggerKid",
    0x32: "Patra1",
    0x33: "Patra2",
    0x34: "Ganon",
    0x35: "Zelda",
    0x36: "OldMan",
    0x37: "OldWoman",
}


def parse_slots(path):
    """Yield (slot_idx, type_byte) tuples from static.txt [SLOTS]."""
    if not path.exists():
        return
    in_slots = False
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if line == "[SLOTS]":
            in_slots = True
            continue
        if line.startswith("[") and in_slots:
            break
        if not in_slots:
            continue
        m = re.match(r"^s(\d+)=t:\$([0-9A-Fa-f]+)", line)
        if m:
            slot = int(m.group(1))
            t    = int(m.group(2), 16)
            if t != 0:
                yield slot, t


def main():
    by_type = defaultdict(list)        # type → [(lv, rm), ...]
    by_room = defaultdict(list)        # (lv, rm) → [type, ...]
    for room_dir in NES_DIR.iterdir():
        if not room_dir.is_dir():
            continue
        m = re.match(r"^lv([0-9A-Fa-f]{2})_rm([0-9A-Fa-f]{2})$", room_dir.name)
        if not m:
            continue
        lv = m.group(1).upper()
        rm = m.group(2).upper()
        types_in_room = []
        for slot, t in parse_slots(room_dir / "static.txt"):
            types_in_room.append(t)
            by_type[t].append((lv, rm))
        by_room[(lv, rm)] = types_in_room

    # Emit JSON
    blob = {
        "by_type": {f"0x{t:02X}": [{"lv": lv, "rm": rm} for lv, rm in v]
                    for t, v in by_type.items()},
        "by_room": {f"lv{lv}_rm{rm}": [f"0x{t:02X}" for t in v]
                    for (lv, rm), v in by_room.items()},
        "type_names": {f"0x{t:02X}": n for t, n in TYPE_NAMES.items()},
    }
    OUT_JSON.write_text(json.dumps(blob, indent=2), encoding="utf-8")

    # Emit markdown
    lines = ["# NES enemy inventory by type\n"]
    lines.append("| Type | Name | Rooms | Count |")
    lines.append("|---|---|---|---:|")
    for t in sorted(by_type.keys()):
        name = TYPE_NAMES.get(t, f"Type${t:02X}")
        rooms = by_type[t]
        room_list = ", ".join(f"${lv}/${rm}" for lv, rm in rooms[:10])
        if len(rooms) > 10:
            room_list += f" ... (+{len(rooms)-10})"
        lines.append(f"| ${t:02X} | {name} | {room_list} | {len(rooms)} |")
    lines.append("\n## Rooms with enemies (sample)\n")
    rooms_with = [(rm, lv, ts) for (lv, rm), ts in by_room.items() if ts]
    rooms_with.sort()
    for rm, lv, ts in rooms_with[:30]:
        type_str = " ".join(f"${t:02X}" for t in ts)
        lines.append(f"- ${lv}/${rm}: {type_str}")
    OUT_MD.write_text("\n".join(lines), encoding="utf-8")
    print(f"Inventory written: {OUT_MD}")
    print(f"Types found: {len(by_type)}; rooms-with-enemies: {len(rooms_with)}")


if __name__ == "__main__":
    main()
