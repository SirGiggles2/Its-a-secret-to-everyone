#!/usr/bin/env python3
"""
Check what the new extraction with offset 0x190 actually produces.
"""

from pathlib import Path
import re

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
rooms_ow_path = root / "src" / "data" / "rooms_overworld.inc"

print("=== New Extraction Analysis (Offset 0x190) ===\n")

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

print("First 32 bytes of extracted RoomAttrsOW_D:")
for i in range(32):
    val = extracted_attrs_d[i] & 0x3F
    print(f"  0x{i:02X}: 0x{val:02X}")

print()
print("Checking if this looks like sequential unique layout IDs:")
sequential = True
for i in range(32):
    expected = i & 0x3F  # Wrap around at 64
    actual = extracted_attrs_d[i] & 0x3F
    if actual != expected:
        sequential = False
        break

if sequential:
    print("✓ Data looks sequential (00, 01, 02, ...)")
else:
    print("✗ Data is not sequential")
    
    # Show the pattern
    print("Actual pattern:")
    pattern = []
    for i in range(16):
        pattern.append(f"{extracted_attrs_d[i] & 0x3F:02X}")
    print(f"  {', '.join(pattern)}")

print()
print("Checking our anchor rooms:")
room_03 = extracted_attrs_d[0x03] & 0x3F
room_5f = extracted_attrs_d[0x5F] & 0x3F
print(f"  Room 0x03: 0x{room_03:02X} (should be 0x03)")
print(f"  Room 0x5F: 0x{room_5f:02X} (should be 0x0B)")

print()
print("Hypothesis:")
print("- Maybe the extracted data at offset 0x190 IS correct")
print("- But I'm comparing against the wrong NES reference")
print("- Maybe the actual NES ROM has different data than expected")
print("- Let's check if this extraction produces reasonable results")

# Check if the unique layout IDs are reasonable (< 0x40)
valid_count = sum(1 for val in extracted_attrs_d if (val & 0x3F) < 0x40)
print(f"\nValid unique layout IDs (< 0x40): {valid_count}/128 ({valid_count/128*100:.1f}%)")

# Check for duplicates
unique_ids = [val & 0x3F for val in extracted_attrs_d]
duplicates = len(unique_ids) - len(set(unique_ids))
print(f"Duplicate unique IDs: {duplicates}")

if duplicates > 0:
    print("Duplicate analysis:")
    from collections import Counter
    id_counts = Counter(unique_ids)
    for uid, count in id_counts.most_common(10):
        if count > 1:
            print(f"  ID 0x{uid:02X}: appears {count} times")
