#!/usr/bin/env python3
"""
Analyze why exactly rooms 0x03 and 0x5F were correct in P3.88.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

from pathlib import Path
import re

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms/WHAT IF")
rom_path = root / "Legend of Zelda, The (USA).nes"
rooms_ow_path = root / "src" / "data" / "rooms_overworld.inc"

prg = read_ines_rom(rom_path)

print("=== Analyzing Why Rooms 0x03 and 0x5F Were Correct ===\n")

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

correct_rooms = [0x03, 0x5F]

print("Analysis of correct rooms:")
for room_id in correct_rooms:
    print(f"\nRoom 0x{room_id:02X}:")
    print(f"  Position: Row {room_id // 16}, Column {room_id % 16}")
    print(f"  ROM unique ID: 0x{rom_attrs_d[room_id] & 0x3F:02X}")
    print(f"  Extracted unique ID: 0x{extracted_attrs_d[room_id] & 0x3F:02X}")
    print(f"  ✓ They match!")
    
    # Check if this room aligns with any data boundaries
    print(f"  Room ID in hex: 0x{room_id:02X}")
    print(f"  Room ID in binary: {room_id:08b}")
    print(f"  Room ID * 16 (layout offset): 0x{room_id * 16:03X}")
    
    # Check if the room ID has any special properties
    if room_id % 16 == 3:
        print(f"  ✓ In column 3 (same as room 0x03)")
    if room_id % 32 == 3:
        print(f"  ✓ Room ID % 32 == 3")
    if room_id % 64 == 3:
        print(f"  ✓ Room ID % 64 == 3")
    if room_id % 128 == 3:
        print(f"  ✓ Room ID % 128 == 3")

print("\n" + "="*50)
print("Looking for patterns:")

# Check if these rooms align with 16-byte boundaries in the data
print("\n16-byte boundary analysis:")
for room_id in correct_rooms:
    byte_offset = room_id  # Each room is 1 byte in RoomAttrsOW_D
    print(f"  Room 0x{room_id:02X} is at byte offset 0x{byte_offset:02X}")
    print(f"    16-byte boundary: {byte_offset // 16} (remainder {byte_offset % 16})")

# Check the hex dump around these rooms in the extracted data
print("\nExtracted RoomAttrsOW_D around correct rooms:")
for room_id in correct_rooms:
    start = max(0, room_id - 8)
    end = min(128, room_id + 9)
    print(f"\nRoom 0x{room_id:02X} (bytes {start:02X}-{end-1:02X}):")
    
    line = ""
    for i in range(start, end):
        val = extracted_attrs_d[i] & 0x3F
        marker = " <--" if i == room_id else ""
        line += f"{val:02X}{marker} "
        if (i - start + 1) % 8 == 0:
            print(f"  {line}")
            line = ""
    if line:
        print(f"  {line}")

# Check if there's a pattern in the offsets that makes these rooms align
print("\n" + "="*50)
print("Offset pattern analysis:")

# Calculate offsets for all rooms
offsets = {}
for room_id in range(128):
    rom_val = rom_attrs_d[room_id] & 0x3F
    ext_val = extracted_attrs_d[room_id] & 0x3F
    offsets[room_id] = ext_val - rom_val

# Check if correct rooms have offset 0
print("Rooms with offset 0 (correct):")
zero_offset_rooms = [r for r, o in offsets.items() if o == 0]
print(f"  {zero_offset_rooms}")

# Check if there's a pattern in room IDs with offset 0
print("\nPattern in room IDs with offset 0:")
for room_id in zero_offset_rooms:
    print(f"  0x{room_id:02X}: {room_id:08b} (row {room_id//16}, col {room_id%16})")

# Check if these rooms are related by some transformation
print("\nRelationship between correct rooms:")
room_diff = correct_rooms[1] - correct_rooms[0]
print(f"  Difference: 0x{room_diff:02X} ({room_diff} decimal)")
print(f"  In binary: {room_diff:08b}")

# Check if the difference is significant (power of 2, multiple of 16, etc.)
if room_diff & (room_diff - 1) == 0:
    print(f"  ✓ Difference is a power of 2")
if room_diff % 16 == 0:
    print(f"  ✓ Difference is a multiple of 16")
if room_diff % 32 == 0:
    print(f"  ✓ Difference is a multiple of 32")
if room_diff % 64 == 0:
    print(f"  ✓ Difference is a multiple of 64")
