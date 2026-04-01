#!/usr/bin/env python3
"""
Find the correct offset for RoomLayoutsOW by testing different offsets.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

from pathlib import Path
import re

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
rom_path = root / "Legend of Zelda, The (USA).nes"
layouts_path = root / "src" / "data" / "room_layouts.inc"

prg = read_ines_rom(rom_path)

# Room 77 needs unique layout ID 0x22
room_id = 0x77
unique_layout_id = 0x22
layout_offset = unique_layout_id * 16

# Read the correct layout from ROM
room_layouts_rom_offset = 0x15818 - 0x10  # RoomLayoutsOW ROM offset minus header
rom_layout_data = prg[room_layouts_rom_offset + layout_offset : room_layouts_rom_offset + layout_offset + 16]

# Read extracted layouts
layouts_text = layouts_path.read_text()
match = re.search(r'RoomLayoutsOW:\s*\n((?:\s*dc\.b.*\n)+)', layouts_text)
extracted_layout_data = []
if match:
    layout_text = match.group(1)
    for line in layout_text.split('\n'):
        if 'dc.b' in line:
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            extracted_layout_data.extend([int(h, 16) for h in hex_values])

print("=== Finding Correct RoomLayoutsOW Offset ===\n")
print(f"Room 77 needs unique layout ID 0x{unique_layout_id:02X}")
print(f"Correct layout data: {rom_layout_data.hex()}")
print()

# Test different offsets
for offset in range(-128, 129, 16):
    test_layout = extracted_layout_data[layout_offset + offset : layout_offset + offset + 16]
    if rom_layout_data == bytes(test_layout):
        print(f"✓ Found correct offset: {offset:+3d} bytes ({offset//16:+3d} layouts)")
        print(f"  Current extraction needs to add {offset:+3d} bytes")
        break
else:
    print("✗ Could not find matching offset in range -128 to +128")
    
    # Show the closest matches
    min_diff = 999
    best_offset = 0
    for offset in range(-128, 129, 16):
        if layout_offset + offset >= 0 and layout_offset + offset + 16 <= len(extracted_layout_data):
            test_layout = extracted_layout_data[layout_offset + offset : layout_offset + offset + 16]
            diff = sum(1 for i, j in zip(test_layout, rom_layout_data) if i != j)
            if diff < min_diff:
                min_diff = diff
                best_offset = offset
    
    print(f"Closest match: {best_offset:+3d} bytes ({best_offset//16:+3d} layouts) with {min_diff} byte differences")
