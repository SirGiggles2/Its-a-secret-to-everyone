#!/usr/bin/env python3
"""
Find the offset pattern between ROM and extracted data.
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

print("=== Finding Data Offset Pattern ===\n")

# The pattern shows:
# Row 0: ROM=0x5A, Extracted=0x00 (ROM is 0x5A ahead)
# Row 1: ROM=0x00, Extracted=0x0F (Extracted is 0x0F ahead)
# Row 2: ROM=0x0F, Extracted=0x1F (Extracted is 0x10 ahead)
# Row 3: ROM=0x1F, Extracted=0x2F (Extracted is 0x10 ahead)

# It looks like the extracted data is shifted by 16 bytes (one row)!

print("Checking if extracted data is shifted by 16 bytes:")
print()

# Check if extracted[i] matches rom[i-16]
for offset in [-16, -15, -14, 16, 15, 14]:
    matches = 0
    for i in range(16, 112):  # Skip first/last 16 to avoid index errors
        rom_idx = i + offset
        if 0 <= rom_idx < 128 and rom_attrs_d[rom_idx] == extracted_attrs_d[i]:
            matches += 1
    
    if matches > 50:
        print(f"Offset {offset:+3d}: {matches}/96 matches")

print()
print("Detailed comparison (first 48 bytes):")
print("ROM:       " + " ".join(f"{rom_attrs_d[i]:02X}" for i in range(48)))
print("Extracted: " + " ".join(f"{extracted_attrs_d[i]:02X}" for i in range(48)))
