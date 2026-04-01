#!/usr/bin/env python3
"""
Check if rooms where room ID == unique layout ID are correct.
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

print("=== Testing Hypothesis: Room ID == Unique Layout ID ===\n")

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

print("Checking rooms where ROM unique layout ID == room ID:")
matches = []
for room_id in range(128):
    rom_unique = rom_attrs_d[room_id] & 0x3F
    if rom_unique == room_id:
        matches.append(room_id)

print(f"Rooms where ROM unique ID == room ID: {matches}")
print(f"Count: {len(matches)}")

print("\nChecking if these rooms are correct in the extraction:")
correct_matches = []
for room_id in matches:
    extracted_unique = extracted_attrs_d[room_id] & 0x3F
    is_correct = (extracted_unique == rom_unique)
    status = "✓" if is_correct else "✗"
    print(f"  Room 0x{room_id:02X}: ROM 0x{rom_unique:02X}, Extracted 0x{extracted_unique:02X} {status}")
    if is_correct:
        correct_matches.append(room_id)

print(f"\nCorrect matches: {correct_matches}")
print(f"This should be [0x03, 0x5F] if the hypothesis is correct")

# Let's also check the inverse - rooms that are correct in extraction
print("\n" + "="*50)
print("Rooms that are correct in extraction:")
correct_rooms = []
for room_id in range(128):
    rom_val = rom_attrs_d[room_id] & 0x3F
    ext_val = extracted_attrs_d[room_id] & 0x3F
    if rom_val == ext_val:
        correct_rooms.append(room_id)

print(f"Correct rooms: {correct_rooms}")

# Check if these rooms have room ID == unique layout ID
print("\nChecking if correct rooms have room ID == unique layout ID:")
for room_id in correct_rooms:
    rom_unique = rom_attrs_d[room_id] & 0x3F
    matches_id = (rom_unique == room_id)
    status = "✓" if matches_id else "✗"
    print(f"  Room 0x{room_id:02X}: ROM unique 0x{rom_unique:02X} == room ID 0x{room_id:02X}? {status}")

# Check the offset pattern for these rooms
print("\n" + "="*50)
print("Offset analysis for correct rooms:")
for room_id in correct_rooms:
    rom_val = rom_attrs_d[room_id] & 0x3F
    ext_val = extracted_attrs_d[room_id] & 0x3F
    offset = ext_val - rom_val
    print(f"  Room 0x{room_id:02X}: offset {offset:+3d}")

print("\nHypothesis:")
print("- If room ID == unique layout ID, then the extraction works correctly")
print("- This would explain why rooms 0x03 and 0x5F are correct")
print("- The issue might be in how the extraction handles rooms where room ID != unique layout ID")
