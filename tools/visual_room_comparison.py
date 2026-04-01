#!/usr/bin/env python3
"""
Visual Room Comparison Tool

This tool helps compare the visual output to the NES reference
based on what the user actually saw, not data extraction.
"""

from pathlib import Path
import re

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
rooms_ow_path = root / "src" / "data" / "rooms_overworld.inc"

print("VISUAL ROOM COMPARISON ANALYSIS")
print("=" * 50)
print()
print("Based on user's visual comparison of labeled maps:")
print()

# User said: "00-3F are ALL incorrect. Everything else appears correct"
wrong_visual_rooms = list(range(0x00, 0x40))  # 0x00 to 0x3F
correct_visual_rooms = list(range(0x40, 0x80))  # 0x40 to 0x7F

print("VISUALLY WRONG ROOMS (64 total):")
print("-" * 30)
for room_id in wrong_visual_rooms:
    row = room_id // 16
    col = room_id % 16
    print(f"  Room 0x{room_id:02X} (Row {row}, Col {col})")

print()
print("VISUALLY CORRECT ROOMS (64 total):")
print("-" * 30)
for room_id in correct_visual_rooms:
    row = room_id // 16
    col = room_id % 16
    print(f"  Room 0x{room_id:02X} (Row {row}, Col {col})")

print()
print("ANALYSIS:")
print("-" * 30)
print("This is a perfect 64-room split!")
print("- Rooms 00-3F (rows 0-3): ALL wrong visually")
print("- Rooms 40-7F (rows 4-7): ALL correct visually")
print()

# Read the extracted data to see if there's a pattern
rooms_ow_text = rooms_ow_path.read_text()
match = re.search(r'RoomAttrsOW_D:\s*\n((?:\s*dc\.b.*\n)+)', rooms_ow_text)
extracted_attrs_d = []
if match:
    attrs_d_text = match.group(1)
    for line in attrs_d_text.split('\n'):
        if 'dc.b' in line:
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            extracted_attrs_d.extend([int(h, 16) for h in hex_values])

print("EXTRACTED DATA PATTERN FOR VISUALLY WRONG ROOMS:")
print("-" * 30)
wrong_unique_ids = []
for room_id in wrong_visual_rooms:
    unique_id = extracted_attrs_d[room_id] & 0x3F
    wrong_unique_ids.append(unique_id)

print(f"Unique IDs for rooms 00-3F: {[f'0x{id:02X}' for id in wrong_unique_ids[:16]]}")
print(f"Pattern: {wrong_unique_ids[:16]}")
print()

print("EXTRACTED DATA PATTERN FOR VISUALLY CORRECT ROOMS:")
print("-" * 30)
correct_unique_ids = []
for room_id in correct_visual_rooms:
    unique_id = extracted_attrs_d[room_id] & 0x3F
    correct_unique_ids.append(unique_id)

print(f"Unique IDs for rooms 40-7F: {[f'0x{id:02X}' for id in correct_unique_ids[:16]]}")
print(f"Pattern: {correct_unique_ids[:16]}")
print()

print("HYPOTHESIS:")
print("-" * 30)
print("The visual split suggests:")
print("1. Rooms 00-3F are getting wrong layout data")
print("2. Rooms 40-7F are getting correct layout data")
print("3. This could be a RoomLayoutsOW indexing issue")
print("4. Or a unique layout ID to actual layout mapping issue")
print()

print("NEXT STEPS:")
print("-" * 30)
print("1. Check if rooms 00-3F and 40-7F use different layout data sources")
print("2. Verify RoomLayoutsOW extraction and indexing")
print("3. Check if unique layout IDs 00-3F map to correct layouts")
print("4. Focus on visual rendering pipeline, not data extraction")
