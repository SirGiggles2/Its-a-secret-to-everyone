#!/usr/bin/env python3
"""
Analyze the pattern of correct vs wrong rooms.

User reports:
- Row 7 (starting screen 0x77): CORRECT
- Row 6 (0x67): CORRECT  
- Row 5 (0x57): CORRECT
- Row 4 (0x47): CORRECT
- Row 3 (0x37): WRONG

This suggests rows 5-7 are correct, but row 3 (and possibly 0-2) are wrong.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

from pathlib import Path
import re

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
rom_path = root / "Legend of Zelda, The (USA).nes"
rooms_ow_path = root / "src" / "data" / "rooms_overworld.inc"

prg = read_ines_rom(rom_path)

# Read ROM RoomAttrsOW_D
levelblock_start = 0x18400 - 0x10
attrs_d_offset = 0x180
rom_attrs_d = prg[levelblock_start + attrs_d_offset : levelblock_start + attrs_d_offset + 128]

# Read extracted RoomAttrsOW_D
rooms_ow_text = rooms_ow_path.read_text()
match = re.search(r'RoomAttrsOW_D:\s*\n((?:\s*dc\.b.*\n)+)', rooms_ow_text)
extracted_attrs_d = []
if match:
    attrs_d_text = match.group(1)
    for line in attrs_d_text.split('\n'):
        if 'dc.b' in line:
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            extracted_attrs_d.extend([int(h, 16) for h in hex_values])

print("=== Analyzing Row Pattern ===\n")
print("Checking each row (16 rooms per row):\n")

for row in range(8):
    row_start = row * 16
    row_end = row_start + 16
    
    matches = sum(1 for i in range(row_start, row_end) if rom_attrs_d[i] == extracted_attrs_d[i])
    status = "✓ CORRECT" if matches == 16 else f"✗ WRONG ({matches}/16 match)"
    
    print(f"Row {row} (rooms 0x{row_start:02X}-0x{row_end-1:02X}): {status}")
    
    if matches < 16:
        # Show first mismatch
        for i in range(row_start, row_end):
            if rom_attrs_d[i] != extracted_attrs_d[i]:
                print(f"  First mismatch at 0x{i:02X}: ROM=0x{rom_attrs_d[i]:02X} Extracted=0x{extracted_attrs_d[i]:02X}")
                break

print()
print("Summary:")
correct_rows = [row for row in range(8) if all(rom_attrs_d[row*16 + i] == extracted_attrs_d[row*16 + i] for i in range(16))]
wrong_rows = [row for row in range(8) if row not in correct_rows]

print(f"  Correct rows: {correct_rows}")
print(f"  Wrong rows: {wrong_rows}")
