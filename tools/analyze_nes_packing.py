#!/usr/bin/env python3
"""
Analyze how NES actually packs tile codes in column data
"""

from pathlib import Path
import re

root = Path(r"c:\Users\Jake Diggity\Documents/GitHub/VDP rebirth tools and asms/WHAT IF")
columns_path = root / "src" / "data" / "room_columns.inc"

print("NES TILE CODE PACKING ANALYSIS")
print("=" * 50)
print()

print("From NES disassembly, we saw:")
print("- Column start byte: ..xx xxxx = Tile Code (6 bits)")
print("- Following bytes: Tile data")
print()
print("But our column data has bytes like 0x5B, 0x4E, 0x59")
print("These are > 0x3F, so they can't be raw tile codes.")
print()

print("POSSIBLE PACKING FORMATS:")
print("-" * 30)
print("1. Two 6-bit tile codes packed into one byte:")
print("   - Bits 7-2: First tile code (6 bits)")
print("   - Bits 1-0: Part of second tile code")
print()

print("2. 4-bit tile codes packed:")
print("   - Bits 7-4: First tile code (4 bits)")
print("   - Bits 3-0: Second tile code (4 bits)")
print()

print("3. Different format entirely")
print()

# Read our column data
columns_text = columns_path.read_text()

# Extract ColumnHeapOWBlob data
match = re.search(r'ColumnHeapOWBlob:\s*\n((?:\s*dc\.b.*\n)+)', columns_text)
heap_data = []
if match:
    blob_lines = match.group(1).strip().split('\n')
    for line in blob_lines:
        if 'dc.b' in line:
            hex_values = re.findall(r'\$(\w+)', line)
            heap_data.extend([int(h, 16) for h in hex_values])

print("TESTING PACKING HYPOTHESES:")
print("-" * 30)

# Test the first few bytes
test_bytes = heap_data[:10]
print(f"First 10 bytes: {[f'0x{b:02X}' for b in test_bytes]}")

print()
print("Hypothesis 1: Two 6-bit codes per byte:")
for i, byte_val in enumerate(test_bytes[:6]):
    high_6 = (byte_val >> 2) & 0x3F  # Bits 7-2
    low_2 = byte_val & 0x03          # Bits 1-0
    print(f"  0x{byte_val:02X}: High=0x{high_6:02X}, Low=0x{low_2:02X}")

print()
print("Hypothesis 2: Two 4-bit codes per byte:")
for i, byte_val in enumerate(test_bytes[:6]):
    high_4 = (byte_val >> 4) & 0x0F  # Bits 7-4
    low_4 = byte_val & 0x0F          # Bits 3-0
    print(f"  0x{byte_val:02X}: High=0x{high_4:02X}, Low=0x{low_4:02X}")

print()
print("ANALYSIS:")
print("-" * 30)
print("If Hypothesis 1 is correct:")
print("- 0x5B = High:0x16, Low:0x03 (both valid 6-bit)")
print("- 0x4E = High:0x13, Low:0x02 (both valid 6-bit)")
print("- 0x59 = High:0x16, Low:0x01 (both valid 6-bit)")
print()

print("If Hypothesis 2 is correct:")
print("- 0x5B = High:0x05, Low:0x0B (both valid 4-bit)")
print("- 0x4E = High:0x04, Low:0x0E (both valid 4-bit)")
print("- 0x59 = High:0x05, Low:0x09 (both valid 4-bit)")
print()

print("Both hypotheses produce valid tile codes!")
print("Need to check NES rendering code to see which is correct.")

print()
print("SIMPLIFIED FIX:")
print("-" * 30)
print("Instead of complex unpacking, let's try a simpler approach:")
print("Just mask to 6 bits but handle the packing correctly:")
print("- If byte is 0x5B, treat as two separate tile codes")
print("- Use row position to determine which tile code to use")
