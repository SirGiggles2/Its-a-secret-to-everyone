#!/usr/bin/env python3
"""
Find which rooms are actually correct in P3.88.
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

# Read the correct RoomAttrsOW_D from NES ROM
levelblock_start = 0x18400 - 0x10  # Account for stripped header
attrs_d_offset = 0x180
rom_attrs_d = prg[levelblock_start + attrs_d_offset : levelblock_start + attrs_d_offset + 128]

# Read the extracted RoomAttrsOW_D
rooms_ow_text = rooms_ow_path.read_text()
match = re.search(r'RoomAttrsOW_D:\s*\n((?:\s*dc\.b.*\n)+)', rooms_ow_text)
extracted_attrs_d = []
if match:
    attrs_d_text = match.group(1)
    for line in attrs_d_text.split('\n'):
        if 'dc.b' in line:
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            extracted_attrs_d.extend([int(h, 16) for h in hex_values])

print("=== Correct Rooms in P3.88 ===\n")

correct_rooms = []
for room_id in range(128):
    rom_value = rom_attrs_d[room_id] & 0x3F  # Low 6 bits = unique layout ID
    extracted_value = extracted_attrs_d[room_id] & 0x3F
    
    if rom_value == extracted_value:
        correct_rooms.append(room_id)

print(f"Found {len(correct_rooms)} correct rooms:")
for room_id in correct_rooms:
    row = room_id // 16
    col = room_id % 16
    unique_id = rom_attrs_d[room_id] & 0x3F
    print(f"  Room 0x{room_id:02X} (Row {row}, Col {col}) -> Unique ID 0x{unique_id:02X}")

print()
print("These are the ONLY rooms that work correctly in P3.88!")
print("My fixes in P3.89/P3.90 must have broken these somehow.")
