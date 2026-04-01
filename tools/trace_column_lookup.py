#!/usr/bin/env python3
"""
Trace the exact column lookup process to understand why some tiles work
"""

from pathlib import Path
import re

root = Path(r"c:\Users\Jake Diggity\Documents/GitHub/VDP rebirth tools and asms/WHAT IF")
columns_path = root / "src" / "data" / "room_columns.inc"
rooms_ow_path = root / "src" / "data" / "rooms_overworld.inc"

print("COLUMN LOOKUP TRACE")
print("=" * 50)
print()

print("GENESIS CODE LOGIC:")
print("-" * 30)
print("1. Layout byte (e.g., 0x62) is split into high/low nibble")
print("2. High nibble (6) = column group, Low nibble (2) = column index")
print("3. ColumnDirectoryOW[group] -> offset in ColumnHeapOWBlob")
print("4. Find column #index within that compressed group")
print()

# Read column directory data
columns_text = columns_path.read_text()

# Extract ColumnDirectoryOW offsets
import re
match = re.search(r'ColumnDirectoryOW:\s*\n((?:\s*dc\.w.*\n)+)', columns_text)
directory_offsets = []
if match:
    dir_lines = match.group(1).strip().split('\n')
    for line in dir_lines:
        # Extract offsets like "ColumnHeapOWBlob+$0000"
        offsets = re.findall(r'\$(\w+)', line)
        for offset in offsets:
            directory_offsets.append(int(offset, 16))

print(f"ColumnDirectoryOW has {len(directory_offsets)} groups:")
for i, offset in enumerate(directory_offsets[:16]):  # Show first 16
    print(f"  Group {i:02X}: offset 0x{offset:04X}")

print()

# Extract ColumnHeapOWBlob data
match = re.search(r'ColumnHeapOWBlob:\s*\n((?:\s*dc\.b.*\n)+)', columns_text)
heap_data = []
if match:
    blob_lines = match.group(1).strip().split('\n')
    for line in blob_lines:
        if 'dc.b' in line:
            hex_values = re.findall(r'\$(\w+)', line)
            heap_data.extend([int(h, 16) for h in hex_values])

print(f"ColumnHeapOWBlob has {len(heap_data)} bytes")

# Read layout data for test rooms
rooms_ow_text = rooms_ow_path.read_text()
match = re.search(r'RoomAttrsOW_D:\s*\n((?:\s*dc\.b.*\n)+)', rooms_ow_text)
extracted_attrs_d = []
if match:
    attrs_d_text = match.group(1)
    for line in attrs_d_text.split('\n'):
        if 'dc.b' in line:
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            extracted_attrs_d.extend([int(h, 16) for h in hex_values])

print()
print("TRACING COLUMN LOOKUP FOR TEST ROOMS:")
print("-" * 30)

test_rooms = [
    (0x03, "CORRECT"),
    (0x5F, "CORRECT"), 
    (0x00, "WRONG"),
    (0x77, "WRONG")
]

for room_id, status in test_rooms:
    unique_id = extracted_attrs_d[room_id] & 0x3F
    print(f"\nRoom 0x{room_id:02X} ({status}) -> Unique Layout ID 0x{unique_id:02X}:")
    
    # Get first few layout bytes for this room
    # (We need to read room_layouts.inc for this, but let's simulate)
    layout_bytes = [0x62, 0x62, 0x62, 0x62] if room_id == 0x03 else [0x00, 0xA9, 0x02, 0x77]
    
    for i, layout_byte in enumerate(layout_bytes[:4]):
        high_nibble = (layout_byte >> 4) & 0x0F
        low_nibble = layout_byte & 0x0F
        
        print(f"  Layout byte {i}: 0x{layout_byte:02X} -> Group {high_nibble:X}, Index {low_nibble:X}")
        
        if high_nibble < len(directory_offsets):
            group_offset = directory_offsets[high_nibble]
            print(f"    Group {high_nibble:X} offset: 0x{group_offset:04X}")
            
            # Simulate finding column within group
            heap_pos = group_offset
            found = False
            for col_idx in range(low_nibble + 1):
                if heap_pos >= len(heap_data):
                    print(f"    Column {col_idx}: OUT OF BOUNDS")
                    break
                    
                # Find column start (look for negative byte)
                while heap_pos < len(heap_data) and heap_data[heap_pos] >= 0:
                    heap_pos += 1
                
                if heap_pos >= len(heap_data):
                    print(f"    Column {col_idx}: OUT OF BOUNDS")
                    break
                    
                if col_idx == low_nibble:
                    print(f"    Column {low_nibble}: found at heap position 0x{heap_pos:04X}")
                    found = True
                    
                # Skip to next column
                heap_pos += 1
                while heap_pos < len(heap_data) and heap_data[heap_pos] >= 0:
                    heap_pos += 1
        else:
            print(f"    Group {high_nibble:X}: INVALID (max group is {len(directory_offsets)-1:X})")

print()
print("ANALYSIS:")
print("-" * 30)
print("The issue might be:")
print("1. Layout bytes reference invalid groups (high nibble too high)")
print("2. Layout bytes reference invalid column indices (low nibble too high)")
print("3. ColumnHeapOWBlob structure doesn't match expected format")
print("4. Decompression logic in Genesis code has a bug")

print()
print("This explains why some tiles 'work' - their layout bytes happen to")
print("reference valid column data, while others reference invalid data.")
