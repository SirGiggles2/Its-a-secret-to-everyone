#!/usr/bin/env python3
"""
Check room column data extraction and indexing

If layout bytes are correct but column lookup fails, then the issue
is in room column data extraction or indexing.
"""

from pathlib import Path
import re

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms/WHAT IF")
columns_path = root / "src" / "data" / "room_columns.inc"
layouts_path = root / "src" / "data" / "room_layouts.inc"
rooms_ow_path = root / "src" / "data" / "rooms_overworld.inc"

print("ROOM COLUMN DATA ANALYSIS")
print("=" * 50)
print()

print("HYPOTHESIS:")
print("-" * 30)
print("Layout bytes are correct, but column lookup fails.")
print("Room 0x03 works because its layout bytes (62, F7) happen to")
print("map to correct column graphics.")
print("Room 0x00 fails because its layout bytes (00, A9, 02, 77) map to")
print("wrong or missing column graphics.")
print()

# Read room column data
columns_text = columns_path.read_text()
match = re.search(r'RoomColumnsOW:\s*\n((?:\s*dc\.b.*\n)+)', columns_text)
room_columns = []
if match:
    columns_data = match.group(1)
    for line in columns_data.split('\n'):
        if 'dc.b' in line:
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            room_columns.extend([int(h, 16) for h in hex_values])

print("ROOM COLUMN DATA:")
print("-" * 30)
print(f"Total column bytes: {len(room_columns)}")
print(f"Expected: ~2560 bytes (256 columns * 10 bytes each)")
print()

# Show first few columns
print("First 5 columns (50 bytes):")
for col_idx in range(5):
    start = col_idx * 10
    end = start + 10
    if end <= len(room_columns):
        col_data = room_columns[start:end]
        hex_str = ''.join(f'{b:02X}' for b in col_data)
        print(f"  Column {col_idx:02d}: {hex_str}")

print()

# Read layout data for our test rooms
layouts_text = layouts_path.read_text()
match = re.search(r'RoomLayoutsOW:\s*\n((?:\s*dc\.b.*\n)+)', layouts_text)
room_layouts = []
if match:
    layouts_data = match.group(1)
    for line in layouts_data.split('\n'):
        if 'dc.b' in line:
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            room_layouts.extend([int(h, 16) for h in hex_values])

# Get layout data for test rooms
rooms_ow_text = rooms_ow_path.read_text()
match = re.search(r'RoomAttrsOW_D:\s*\n((?:\s*dc\.b.*\n)+)', rooms_ow_text)
extracted_attrs_d = []
if match:
    attrs_d_text = match.group(1)
    for line in attrs_d_text.split('\n'):
        if 'dc.b' in line:
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            extracted_attrs_d.extend([int(h, 16) for h in hex_values])

print("COLUMN LOOKUP ANALYSIS:")
print("-" * 30)

# Test the column lookup for correct vs wrong rooms
test_rooms = [
    (0x03, "CORRECT"),
    (0x5F, "CORRECT"), 
    (0x00, "WRONG"),
    (0x77, "WRONG")
]

for room_id, status in test_rooms:
    unique_id = extracted_attrs_d[room_id] & 0x3F
    layout_start = unique_id * 16
    layout_end = layout_start + 16
    
    if layout_end <= len(room_layouts):
        layout_data = room_layouts[layout_start:layout_end]
        print(f"\nRoom 0x{room_id:02X} ({status}) -> Layout 0x{unique_id:02X}:")
        print(f"  Layout bytes: {[f'0x{b:02X}' for b in layout_data[:8]]}")
        
        # Check if these layout bytes have valid column data
        valid_columns = 0
        for i, layout_byte in enumerate(layout_data[:8]):
            col_start = layout_byte * 10
            col_end = col_start + 10
            if col_end <= len(room_columns):
                col_data = room_columns[col_start:col_end]
                # Check if column data looks valid (not all zeros)
                if any(b != 0 for b in col_data):
                    valid_columns += 1
                else:
                    print(f"    Column 0x{layout_byte:02X}: EMPTY/ZEROS")
            else:
                print(f"    Column 0x{layout_byte:02X}: OUT OF BOUNDS")
        
        print(f"  Valid columns: {valid_columns}/8")

print()
print("COLUMN EXTRACTION VERIFICATION:")
print("-" * 30)
print("Need to check:")
print("1. RoomColumnsOW extraction offset")
print("2. Column data structure (10 bytes per column?)")
print("3. Column indexing (layout byte -> column mapping)")
print("4. Whether column data matches NES ROM structure")

print()
print("If column data is wrong, that would explain why some tiles work")
print("(layout bytes that happen to map to valid columns) and others don't")
print("(layout bytes that map to invalid/missing columns).")
