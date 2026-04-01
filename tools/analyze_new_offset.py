#!/usr/bin/env python3
"""
Analyze the new offset to see what's happening.
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

print("=== New Offset Analysis ===\n")

# Check what's at the old vs new offset
old_offset = 0x18400 - 0x10  # prg_data offset for ROM 0x18400
new_offset = 0x18410 - 0x10  # prg_data offset for ROM 0x18410

print(f"Old offset (ROM 0x18400): prg_data 0x{old_offset:05X}")
print(f"New offset (ROM 0x18410): prg_data 0x{new_offset:05X}")
print()

# Show data at both offsets
old_data = prg[old_offset : old_offset + 64]
new_data = prg[new_offset : new_offset + 64]

print("First 64 bytes at old offset:")
print(f"  {old_data.hex()}")
print()

print("First 64 bytes at new offset:")
print(f"  {new_data.hex()}")
print()

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

# Check the pattern of offsets now
print("Offset pattern with new extraction:")
from collections import Counter

# Read the correct RoomAttrsOW_D from NES ROM
levelblock_start = 0x18400 - 0x10  # Account for stripped header
attrs_d_offset = 0x180
rom_attrs_d = prg[levelblock_start + attrs_d_offset : levelblock_start + attrs_d_offset + 128]

offsets = []
for room_id in range(128):
    rom_val = rom_attrs_d[room_id] & 0x3F
    ext_val = extracted_attrs_d[room_id] & 0x3F
    if rom_val != ext_val:
        offsets.append(ext_val - rom_val)

offset_counts = Counter(offsets)
print("Most common offsets:")
for offset, count in offset_counts.most_common(10):
    print(f"  {offset:+3d}: {count} rooms ({count/128*100:.1f}%)")

if len(offset_counts) == 1:
    print(f"  All wrong rooms have the same offset: {offsets[0]:+3d}")
else:
    print(f"  Multiple offsets found - the issue is more complex")

print()
print("Room 77 analysis:")
room_77_rom = rom_attrs_d[0x77] & 0x3F
room_77_extracted = extracted_attrs_d[0x77] & 0x3F
print(f"  ROM unique ID: 0x{room_77_rom:02X}")
print(f"  Extracted unique ID: 0x{room_77_extracted:02X}")
print(f"  Offset: {room_77_extracted - room_77_rom:+3d}")

# Find which room has the correct unique ID for room 77
for room_id in range(128):
    if extracted_attrs_d[room_id] & 0x3F == room_77_rom:
        print(f"  Room 0x{room_id:02X} has the unique ID that room 0x77 should have")
        break
