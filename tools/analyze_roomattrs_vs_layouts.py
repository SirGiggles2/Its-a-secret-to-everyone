#!/usr/bin/env python3
"""
Analyze the relationship between RoomAttrsOW_D and RoomLayoutsOW.

The issue: rooms 00-3F are wrong, but 40-7F are correct.
This suggests either:
1. RoomAttrsOW_D has wrong unique layout IDs for rooms 00-3F
2. RoomLayoutsOW is missing the first 64 layouts
3. Both are misaligned

Let's check what unique layout IDs rooms 00-3F SHOULD have.
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

# Read the CORRECT RoomAttrsOW_D from NES ROM
levelblock_start = 0x18400 - 0x10  # Account for stripped header
attrs_d_offset = 0x180
rom_attrs_d = prg[levelblock_start + attrs_d_offset : levelblock_start + attrs_d_offset + 128]

# Read the extracted RoomAttrsOW_D (which is wrong)
rooms_ow_text = rooms_ow_path.read_text()
match = re.search(r'RoomAttrsOW_D:\s*\n((?:\s*dc\.b.*\n)+)', rooms_ow_text)
extracted_attrs_d = []
if match:
    attrs_d_text = match.group(1)
    for line in attrs_d_text.split('\n'):
        if 'dc.b' in line:
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            extracted_attrs_d.extend([int(h, 16) for h in hex_values])

print("=== RoomAttrsOW_D Analysis ===\n")
print("Comparing correct ROM data vs extracted data for rooms 00-3F:")
print()

print("Room | ROM (correct) | Extracted (wrong) | Difference")
print("-----|--------------|-------------------|----------")

for room_id in range(0x40):  # 0x00 to 0x3F
    rom_value = rom_attrs_d[room_id] & 0x3F  # Low 6 bits = unique layout ID
    extracted_value = extracted_attrs_d[room_id] & 0x3F
    
    if rom_value != extracted_value:
        diff = extracted_value - rom_value
        print(f"0x{room_id:02X} | 0x{rom_value:02X}        | 0x{extracted_value:02X}           | {diff:+3d}")
    else:
        print(f"0x{room_id:02X} | 0x{rom_value:02X}        | 0x{extracted_value:02X}           | ✓")

print()
print("Summary:")
print(f"Rooms with wrong unique layout ID: {sum(1 for i in range(0x40) if (rom_attrs_d[i] & 0x3F) != (extracted_attrs_d[i] & 0x3F))}/64")
print()

# Check if there's a pattern in the differences
differences = []
for i in range(0x40):
    rom_val = rom_attrs_d[i] & 0x3F
    ext_val = extracted_attrs_d[i] & 0x3F
    if rom_val != ext_val:
        differences.append(ext_val - rom_val)

if differences:
    print("Difference pattern:")
    if all(d == differences[0] for d in differences):
        print(f"  All differences are the same: {differences[0]:+3d}")
        print(f"  This means extracted data is offset by {differences[0]:+3d} unique layout IDs")
    else:
        print("  Differences vary, suggesting a more complex issue")
        print(f"  Range: {min(differences):+3d} to {max(differences):+3d}")
