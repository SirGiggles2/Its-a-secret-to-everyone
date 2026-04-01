#!/usr/bin/env python3
"""
Simple comparison: what do working rooms have that broken rooms don't?
"""

from pathlib import Path
import re

root = Path(r"c:\Users\Jake Diggity\Documents/GitHub/VDP rebirth tools and asms/WHAT IF")
rooms_ow_path = root / "src" / "data" / "rooms_overworld.inc"
columns_path = root / "src" / "data" / "room_columns.inc"

print("SIMPLE COMPARISON: Working vs Broken Rooms")
print("=" * 50)
print()

print("WORKING ROOMS: 0x03, 0x5F")
print("BROKEN ROOMS: 0x00, 0x77 (and most others)")
print()

# Read layout data
rooms_ow_text = rooms_ow_path.read_text()
match = re.search(r'RoomAttrsOW_D:\s*\n((?:\s*dc\.b.*\n)+)', rooms_ow_text)
extracted_attrs_d = []
if match:
    attrs_d_text = match.group(1)
    for line in attrs_d_text.split('\n'):
        if 'dc.b' in line:
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            extracted_attrs_d.extend([int(h, 16) for h in hex_values])

# Read column data
columns_text = columns_path.read_text()
match = re.search(r'ColumnDirectoryOW:\s*\n((?:\s*dc\.w.*\n)+)', columns_text)
directory_offsets = []
if match:
    dir_lines = match.group(1).strip().split('\n')
    for line in dir_lines:
        offsets = re.findall(r'\$(\w+)', line)
        for offset in offsets:
            directory_offsets.append(int(offset, 16))

match = re.search(r'ColumnHeapOWBlob:\s*\n((?:\s*dc\.b.*\n)+)', columns_text)
heap_data = []
if match:
    blob_lines = match.group(1).strip().split('\n')
    for line in blob_lines:
        if 'dc.b' in line:
            hex_values = re.findall(r'\$(\w+)', line)
            heap_data.extend([int(h, 16) for h in hex_values])

print("CURRENT GENESIS INTERPRETATION:")
print("-" * 30)
print("Layout byte -> AND #$3F -> tile code")
print()

# Check what the working rooms actually get
test_rooms = [
    (0x03, "WORKING"),
    (0x5F, "WORKING"), 
    (0x00, "BROKEN"),
    (0x77, "BROKEN")
]

for room_id, status in test_rooms:
    unique_id = extracted_attrs_d[room_id] & 0x3F
    print(f"\nRoom 0x{room_id:02X} ({status}):")
    print(f"  Unique Layout ID: 0x{unique_id:02X}")
    
    # Get first layout byte (simplified - just check first byte)
    # In reality this would come from room_layouts.inc
    layout_byte = 0x62 if room_id == 0x03 else (0x0B if room_id == 0x5F else (0x00 if room_id == 0x00 else 0x32))
    print(f"  First Layout Byte: 0x{layout_byte:02X}")
    
    # Current Genesis interpretation
    tile_code = layout_byte & 0x3F
    print(f"  Current Interpretation: 0x{layout_byte:02X} & 0x3F = 0x{tile_code:02X}")
    
    # Check if this is a valid tile code
    if tile_code <= 0x3F:
        print(f"  ✓ Valid tile code (0x00-0x3F)")
    else:
        print(f"  ✗ Invalid tile code (> 0x3F)")
    
    # What if the interpretation is wrong?
    print(f"  Alternative interpretations:")
    high_nibble = (layout_byte >> 4) & 0x0F
    low_nibble = layout_byte & 0x0F
    print(f"    High nibble: 0x{high_nibble:02X}")
    print(f"    Low nibble: 0x{low_nibble:02X}")
    print(f"    Raw byte: 0x{layout_byte:02X}")

print()
print("KEY INSIGHT:")
print("-" * 30)
print("The working rooms might have layout bytes that, when AND-masked")
print("with 0x3F, happen to produce valid tile codes.")
print("The broken rooms might have layout bytes that produce invalid codes.")
print()

print("SIMPLE HYPOTHESIS:")
print("-" * 30)
print("Maybe the layout byte interpretation is completely different.")
print("Maybe it should be:")
print("1. High nibble only (0x62 -> 0x06)")
print("2. Low nibble only (0x62 -> 0x02)")
print("3. Raw byte with different masking")
print("4. Something else entirely")

print()
print("The fact that SOME rooms work suggests the basic pipeline is correct.")
print("Just the final byte interpretation is wrong.")
