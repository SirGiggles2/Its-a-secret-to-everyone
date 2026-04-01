#!/usr/bin/env python3
"""
List exactly which rooms are right and wrong in P3.93
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

from pathlib import Path
import re

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
rom_path = root / "Legend of Zelda, The (USA).nes"
rooms_ow_path = root / "src" / "data" / "rooms_overworld.inc"

prg = read_ines_rom(rom_path)

print("ROOM STATUS IN P3.93")
print("=" * 50)
print()

# Read NES ROM data
levelblock_start = 0x18400 - 0x10
attrs_d_offset = 0x180
rom_attrs_d = prg[levelblock_start + attrs_d_offset : levelblock_start + attrs_d_offset + 128]

# Read extracted data
rooms_ow_text = rooms_ow_path.read_text()
match = re.search(r'RoomAttrsOW_D:\s*\n((?:\s*dc\.b.*\n)+)', rooms_ow_text)
extracted_attrs_d = []
if match:
    attrs_d_text = match.group(1)
    for line in attrs_d_text.split('\n'):
        if 'dc.b' in line:
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            extracted_attrs_d.extend([int(h, 16) for h in hex_values])

correct_rooms = []
wrong_rooms = []

print("CORRECT ROOMS (2 total):")
print("-" * 30)
for room_id in range(128):
    rom_val = rom_attrs_d[room_id] & 0x3F
    ext_val = extracted_attrs_d[room_id] & 0x3F
    
    if rom_val == ext_val:
        row = room_id // 16
        col = room_id % 16
        correct_rooms.append(room_id)
        print(f"  Room 0x{room_id:02X} (Row {row}, Col {col}) -> Unique ID 0x{rom_val:02X}")

print()
print("WRONG ROOMS (126 total):")
print("-" * 30)
for room_id in range(128):
    rom_val = rom_attrs_d[room_id] & 0x3F
    ext_val = extracted_attrs_d[room_id] & 0x3F
    
    if rom_val != ext_val:
        row = room_id // 16
        col = room_id % 16
        offset = ext_val - rom_val
        wrong_rooms.append((room_id, offset))
        print(f"  Room 0x{room_id:02X} (Row {row}, Col {col}) -> ROM 0x{rom_val:02X}, Ext 0x{ext_val:02X} ({offset:+3d})")

print()
print("SUMMARY BY ROW:")
print("-" * 30)
for row in range(8):
    row_correct = [r for r in correct_rooms if r // 16 == row]
    row_wrong = [r for r, _ in wrong_rooms if r // 16 == row]
    print(f"  Row {row}: {len(row_correct)} correct, {len(row_wrong)} wrong")
    if row_correct:
        print(f"    Correct: {[f'0x{r:02X}' for r in row_correct]}")

print()
print("KEY ROOMS:")
print("-" * 30)
key_rooms = [0x77, 0x47, 0x37, 0x27]  # Starting room and rooms above it
for room_id in key_rooms:
    rom_val = rom_attrs_d[room_id] & 0x3F
    ext_val = extracted_attrs_d[room_id] & 0x3F
    offset = ext_val - rom_val
    row = room_id // 16
    col = room_id % 16
    status = "✓" if rom_val == ext_val else "✗"
    
    relation = ""
    if room_id == 0x77:
        relation = " (STARTING ROOM)"
    elif room_id == 0x47:
        relation = " (4 rooms above start)"
    elif room_id == 0x37:
        relation = " (6 rooms above start)"
    elif room_id == 0x27:
        relation = " (8 rooms above start)"
    
    print(f"  Room 0x{room_id:02X} (Row {row}, Col {col}){relation}")
    print(f"    ROM: 0x{rom_val:02X}, Extracted: 0x{ext_val:02X}, Offset: {offset:+3d} {status}")

print()
print("OFFSET PATTERN:")
print("-" * 30)
from collections import Counter
offsets = [offset for _, offset in wrong_rooms]
offset_counts = Counter(offsets)
for offset, count in sorted(offset_counts.items()):
    print(f"  {offset:+3d}: {count} rooms ({count/126*100:.1f}% of wrong rooms)")
