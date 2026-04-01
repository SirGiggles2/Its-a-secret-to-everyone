#!/usr/bin/env python3
"""
Check if the room ID system is working correctly.
"""

from pathlib import Path

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
rooms_ow_path = root / "src" / "data" / "rooms_overworld.inc"

print("=== Room ID System Analysis ===\n")

# Read the extracted RoomAttrsOW_D
import re
rooms_ow_text = rooms_ow_path.read_text()
match = re.search(r'RoomAttrsOW_D:\s*\n((?:\s*dc\.b.*\n)+)', rooms_ow_text)
extracted_attrs_d = []
if match:
    attrs_d_text = match.group(1)
    for line in attrs_d_text.split('\n'):
        if 'dc.b' in line:
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            extracted_attrs_d.extend([int(h, 16) for h in hex_values])

print("Checking room ID arithmetic:")
print()

# Check starting room 0x77
starting_room = 0x77
print(f"Starting room: 0x{starting_room:02X}")
print(f"  Row: {starting_room // 16}, Column: {starting_room % 16}")
print(f"  Unique layout ID: 0x{extracted_attrs_d[starting_room] & 0x3F:02X}")
print()

# Check rooms above starting room (moving north)
print("Rooms north of starting room (subtracting 0x10 each time):")
current_room = starting_room
for i in range(4):
    if i == 0:
        print(f"  Room {i}: 0x{current_room:02X} (starting)")
    else:
        current_room = (current_room - 0x10) & 0x7F  # NES-style wrapping
        print(f"  Room {i}: 0x{current_room:02X} (Row {current_room // 16}, Col {current_room % 16})")
        print(f"    Unique layout ID: 0x{extracted_attrs_d[current_room] & 0x3F:02X}")
print()

# Check the two rooms that ARE correct in P3.88
correct_rooms = [0x03, 0x5F]
print("Analysis of the two correct rooms in P3.88:")
for room_id in correct_rooms:
    row = room_id // 16
    col = room_id % 16
    unique_id = extracted_attrs_d[room_id] & 0x3F
    print(f"  Room 0x{room_id:02X}: Row {row}, Col {col} -> Unique ID 0x{unique_id:02X}")
    
    # Check if this room has any special relationship to room 77
    diff = room_id - starting_room
    print(f"    Difference from starting room: {diff:+3d}")
    
    # Check row/column relationship
    row_diff = row - (starting_room // 16)
    col_diff = col - (starting_room % 16)
    print(f"    Position diff: Row {row_diff:+3d}, Col {col_diff:+3d}")
print()

print("Hypothesis:")
print("- Maybe the room ID system is using a different coordinate system")
print("- Maybe room 0x77 is not actually the starting room in the extracted data")
print("- Maybe the Genesis code is applying some transformation to room IDs")
