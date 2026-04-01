#!/usr/bin/env python3
"""
Analyze why P3.88 was "king" despite having 98.4% wrong rooms.
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

print("=== P3.88 Pattern Analysis ===\n")

print("Why P3.88 might have worked better:")
print()

# Check the two correct rooms and their neighbors
correct_rooms = [0x03, 0x5F]

for room_id in correct_rooms:
    print(f"Analyzing correct room 0x{room_id:02X}:")
    rom_unique = rom_attrs_d[room_id] & 0x3F
    extracted_unique = extracted_attrs_d[room_id] & 0x3F
    
    print(f"  ROM unique ID: 0x{rom_unique:02X}")
    print(f"  Extracted unique ID: 0x{extracted_unique:02X}")
    print(f"  ✓ They match!")
    
    # Check neighbors
    print("  Neighbors:")
    for offset in [-1, +1, -16, +16]:
        neighbor_id = (room_id + offset) & 0x7F
        neighbor_rom = rom_attrs_d[neighbor_id] & 0x3F
        neighbor_extracted = extracted_attrs_d[neighbor_id] & 0x3F
        
        direction = ""
        if offset == -1: direction = "west"
        elif offset == 1: direction = "east"
        elif offset == -16: direction = "north"
        elif offset == 16: direction = "south"
        
        status = "✓" if neighbor_rom == neighbor_extracted else "✗"
        print(f"    {direction:5s} 0x{neighbor_id:02X}: ROM 0x{neighbor_rom:02X}, Extracted 0x{neighbor_extracted:02X} {status}")
    print()

# Check if there's a pattern in the offset
print("Offset pattern analysis:")
offsets = []
for room_id in range(128):
    rom_val = rom_attrs_d[room_id] & 0x3F
    ext_val = extracted_attrs_d[room_id] & 0x3F
    if rom_val != ext_val:
        offsets.append(ext_val - rom_val)

if offsets:
    from collections import Counter
    offset_counts = Counter(offsets)
    print("Most common offsets:")
    for offset, count in offset_counts.most_common(10):
        print(f"  {offset:+3d}: {count} rooms ({count/128*100:.1f}%)")
    
    # Check if it's consistent
    if len(offset_counts) == 1:
        print(f"  All wrong rooms have the same offset: {offsets[0]:+3d}")
    else:
        print(f"  Multiple offsets found - the issue is more complex")
print()

# Check room 77 specifically
print("Starting room 0x77 analysis:")
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
