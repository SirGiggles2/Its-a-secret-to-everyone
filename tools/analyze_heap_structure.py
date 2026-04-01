#!/usr/bin/env python3
"""
Analyze the actual ColumnHeapOWBlob structure
"""

from pathlib import Path
import re

root = Path(r"c:\Users\Jake Diggity\Documents/GitHub/VDP rebirth tools and asms/WHAT IF")
columns_path = root / "src" / "data" / "room_columns.inc"

print("COLUMNHEAPOWBLOB STRUCTURE ANALYSIS")
print("=" * 50)
print()

# Read column directory data
columns_text = columns_path.read_text()

# Extract ColumnDirectoryOW offsets
match = re.search(r'ColumnDirectoryOW:\s*\n((?:\s*dc\.w.*\n)+)', columns_text)
directory_offsets = []
if match:
    dir_lines = match.group(1).strip().split('\n')
    for line in dir_lines:
        # Extract offsets like "ColumnHeapOWBlob+$0000"
        offsets = re.findall(r'\$(\w+)', line)
        for offset in offsets:
            directory_offsets.append(int(offset, 16))

# Extract ColumnHeapOWBlob data
match = re.search(r'ColumnHeapOWBlob:\s*\n((?:\s*dc\.b.*\n)+)', columns_text)
heap_data = []
if match:
    blob_lines = match.group(1).strip().split('\n')
    for line in blob_lines:
        if 'dc.b' in line:
            hex_values = re.findall(r'\$(\w+)', line)
            heap_data.extend([int(h, 16) for h in hex_values])

print("ANALYZING HEAP STRUCTURE:")
print("-" * 30)

# Look at the first few groups to understand the structure
for group_idx in range(4):  # Check groups 0-3
    if group_idx >= len(directory_offsets):
        break
        
    group_offset = directory_offsets[group_idx]
    print(f"\nGroup {group_idx:02X} (offset 0x{group_offset:04X}):")
    
    if group_offset < len(heap_data):
        # Show first 32 bytes of this group
        group_data = heap_data[group_offset:group_offset + 32]
        hex_str = ''.join(f'{b:02X}' for b in group_data)
        print(f"  Data: {hex_str}")
        
        # Look for negative bytes (0x80+ = signed negative)
        print("  Negative bytes (column markers):")
        for i, byte_val in enumerate(group_data):
            if byte_val >= 0x80:  # Signed negative
                print(f"    Position {i:2d}: 0x{byte_val:02X}")
        
        # Try to find first few columns
        print("  Finding columns:")
        heap_pos = group_offset
        col_count = 0
        found_cols = 0
        
        while heap_pos < len(heap_data) and col_count < 32 and found_cols < 4:
            byte_val = heap_data[heap_pos]
            
            if byte_val >= 0x80:  # Found column start (negative byte)
                print(f"    Column {found_cols} at position 0x{heap_pos:04X}: 0x{byte_val:02X}")
                found_cols += 1
                
                # Show column data (next few bytes until next negative)
                col_data = []
                heap_pos += 1
                while heap_pos < len(heap_data) and heap_pos < group_offset + 32:
                    if heap_data[heap_pos] >= 0x80:
                        break
                    col_data.append(heap_data[heap_pos])
                    heap_pos += 1
                
                if col_data:
                    col_hex = ''.join(f'{b:02X}' for b in col_data[:8])  # First 8 bytes
                    print(f"      Data: {col_hex}")
            else:
                heap_pos += 1
            
            col_count += 1

print()
print("KEY INSIGHT:")
print("-" * 30)
print("Negative bytes (0x80+) mark column starts.")
print("The column data follows until the next negative byte.")
print("If layout bytes reference columns that don't exist,")
print("the Genesis code probably has fallback behavior.")

print()
print("TESTING SPECIFIC LOOKUPS:")
print("-" * 30)

# Test the specific lookups that were failing
test_lookups = [
    (0x62, "Room 0x03 layout byte"),
    (0x00, "Common layout byte"),
    (0xA9, "Problem layout byte"),
]

for layout_byte, desc in test_lookups:
    high_nibble = (layout_byte >> 4) & 0x0F
    low_nibble = layout_byte & 0x0F
    
    print(f"\n{desc}: 0x{layout_byte:02X} -> Group {high_nibble:X}, Index {low_nibble:X}")
    
    if high_nibble < len(directory_offsets):
        group_offset = directory_offsets[high_nibble]
        print(f"  Group {high_nibble:X} offset: 0x{group_offset:04X}")
        
        # Count columns in this group
        heap_pos = group_offset
        col_count = 0
        
        while heap_pos < len(heap_data):
            if heap_data[heap_pos] >= 0x80:
                col_count += 1
                heap_pos += 1
                # Skip to next column
                while heap_pos < len(heap_data) and heap_data[heap_pos] < 0x80:
                    heap_pos += 1
            else:
                heap_pos += 1
            
            # Stop if we've gone too far
            if heap_pos >= len(directory_offsets) or (high_nibble + 1 < len(directory_offsets) and heap_pos >= directory_offsets[high_nibble + 1]):
                break
        
        print(f"  Total columns in group: {col_count}")
        print(f"  Requested column index: {low_nibble}")
        
        if low_nibble < col_count:
            print(f"  ✓ Column {low_nibble} should exist")
        else:
            print(f"  ✗ Column {low_nibble} does not exist (max {col_count-1})")
    else:
        print(f"  ✗ Group {high_nibble:X} does not exist")
