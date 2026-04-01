#!/usr/bin/env python3
"""
Debug room 77 (starting room) to see what's wrong.
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
layouts_path = root / "src" / "data" / "room_layouts.inc"

prg = read_ines_rom(rom_path)

# Check room 77 unique layout ID
room_id = 0x77

# Read the correct RoomAttrsOW_D from NES ROM
levelblock_start = 0x18400 - 0x10  # Account for stripped header
attrs_d_offset = 0x180
rom_attrs_d = prg[levelblock_start + attrs_d_offset + room_id]
rom_unique_id = rom_attrs_d & 0x3F

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

extracted_unique_id = extracted_attrs_d[room_id] & 0x3F

print("=== Room 77 Debug ===\n")
print(f"Room ID: 0x{room_id:02X} (decimal {room_id})")
print(f"Position: Row {room_id // 16}, Column {room_id % 16}")
print()
print(f"ROM RoomAttrsOW_D[0x{room_id:02X}]: 0x{rom_attrs_d:02X}")
print(f"ROM unique layout ID: 0x{rom_unique_id:02X} (decimal {rom_unique_id})")
print()
print(f"Extracted RoomAttrsOW_D[0x{room_id:02X}]: 0x{extracted_attrs_d[room_id]:02X}")
print(f"Extracted unique layout ID: 0x{extracted_unique_id:02X} (decimal {extracted_unique_id})")
print()

if rom_unique_id == extracted_unique_id:
    print("✓ Room 77 has correct unique layout ID")
else:
    print(f"✗ Room 77 has wrong unique layout ID (diff: {extracted_unique_id - rom_unique_id:+3d})")

print()

# Check if the layout data for that unique ID is correct
layout_offset = rom_unique_id * 16  # Each layout is 16 bytes

# Read RoomLayoutsOW from ROM
room_layouts_offset = 0x15818 - 0x10  # RoomLayoutsOW ROM offset minus header
rom_layout_data = prg[room_layouts_offset + layout_offset : room_layouts_offset + layout_offset + 16]

# Read RoomLayoutsOW from extracted data
layouts_text = layouts_path.read_text()
match = re.search(r'RoomLayoutsOW:\s*\n((?:\s*dc\.b.*\n)+)', layouts_text)
extracted_layout_data = []
if match:
    layout_text = match.group(1)
    for line in layout_text.split('\n'):
        if 'dc.b' in line:
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            extracted_layout_data.extend([int(h, 16) for h in hex_values])

extracted_layout = extracted_layout_data[layout_offset : layout_offset + 16]

print(f"Layout data for unique ID 0x{rom_unique_id:02X}:")
print(f"ROM:    {rom_layout_data.hex()}")
print(f"Extracted: {bytes(extracted_layout).hex()}")
print()

if rom_layout_data == bytes(extracted_layout):
    print("✓ Layout data is correct")
else:
    print("✗ Layout data is wrong")
    # Check if it's offset by some amount
    for offset in range(-64, 65, 16):
        test_layout = extracted_layout_data[layout_offset + offset : layout_offset + offset + 16]
        if rom_layout_data == bytes(test_layout):
            print(f"  Layout is offset by {offset:+3d} bytes ({offset//16:+3d} layouts)")
            break
