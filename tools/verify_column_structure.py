#!/usr/bin/env python3
"""
Verify the column data structure matches NES format
"""

from pathlib import Path
import re

root = Path(r"c:\Users\Jake Diggity\Documents/GitHub/VDP rebirth tools and asms/WHAT IF")
columns_path = root / "src" / "data" / "room_columns.inc"

print("COLUMN STRUCTURE VERIFICATION")
print("=" * 50)
print()

print("NES COLUMN FORMAT (from disassembly):")
print("-" * 30)
print("From 15BD8: Column Definitions for Overworld")
print("..xx xxxx  Tile Code")
print(".x.. ....  Tile is Repeated Once") 
print("x... ....  Start of a Column Definition")
print()
print("Each column starts with byte where bit 7 = 1 (start marker)")
print("Followed by 6-11 bytes of tile data")
print()

# Read our column data
columns_text = columns_path.read_text()

# Extract ColumnDirectoryOW offsets
match = re.search(r'ColumnDirectoryOW:\s*\n((?:\s*dc\.w.*\n)+)', columns_text)
directory_offsets = []
if match:
    dir_lines = match.group(1).strip().split('\n')
    for line in dir_lines:
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

print("OUR COLUMN DATA ANALYSIS:")
print("-" * 30)

# Check if our column data follows the NES format
print("Checking first few groups for NES format compliance:")

for group_idx in range(4):
    if group_idx >= len(directory_offsets):
        break
        
    group_offset = directory_offsets[group_idx]
    print(f"\nGroup {group_idx:02X} (offset 0x{group_offset:04X}):")
    
    if group_offset < len(heap_data):
        # Look for column start markers (bit 7 = 1)
        heap_pos = group_offset
        col_count = 0
        
        while heap_pos < len(heap_data) and col_count < 5:
            byte_val = heap_data[heap_pos]
            
            if byte_val >= 0x80:  # Start of column (bit 7 = 1)
                print(f"  Column {col_count}: Start at 0x{heap_pos:04X} with 0x{byte_val:02X}")
                
                # Decode the start byte according to NES format
                tile_code = byte_val & 0x3F  # ..xx xxxx
                repeat_once = (byte_val & 0x40) != 0  # .x.. ....
                print(f"    Tile Code: 0x{tile_code:02X}, Repeat Once: {repeat_once}")
                
                # Show column data (next bytes until next start marker)
                col_data = []
                heap_pos += 1
                data_start = heap_pos
                
                while heap_pos < len(heap_data) and heap_data[heap_pos] < 0x80:
                    col_data.append(heap_data[heap_pos])
                    heap_pos += 1
                    if len(col_data) >= 12:  # Limit to avoid runaway
                        break
                
                if col_data:
                    col_hex = ' '.join(f'{b:02X}' for b in col_data)
                    print(f"    Data ({len(col_data)} bytes): {col_hex}")
                    
                    # Check if data looks like tile codes
                    tile_codes = []
                    for byte_val in col_data:
                        if byte_val <= 0x3F:  # Valid tile code range
                            tile_codes.append(f"0x{byte_val:02X}")
                        else:
                            tile_codes.append(f"?{byte_val:02X}")
                    
                    print(f"    Tile codes: {' '.join(tile_codes)}")
                
                col_count += 1
            else:
                heap_pos += 1
            
            # Stop if we've gone too far
            if (group_idx + 1 < len(directory_offsets) and 
                heap_pos >= directory_offsets[group_idx + 1]):
                break

print()
print("ANALYSIS:")
print("-" * 30)
print("If the column data structure matches NES format, then the issue")
print("might be:")
print("1. Column data is corrupted during extraction")
print("2. Column directory offsets are wrong")
print("3. Genesis decompression logic has a bug")
print("4. Tile code interpretation is wrong")

print()
print("The fact that SOME tiles work suggests the basic structure is correct,")
print("but specific columns have wrong data or the lookup logic is flawed.")
