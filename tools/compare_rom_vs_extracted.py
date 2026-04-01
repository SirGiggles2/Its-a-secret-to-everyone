#!/usr/bin/env python3
"""
Compare ROM data vs extracted data for RoomAttrsOW_D.

The ROM verification shows correct, but the extracted file has wrong values.
This means the extraction is reading from the right place in ROM, but
something is going wrong during the extraction or file generation.
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

print("=== Comparing ROM vs Extracted RoomAttrsOW_D ===\n")

# Read from ROM at the correct offset
levelblock_start = 0x18400 - 0x10
attrs_d_offset = 0x180
rom_attrs_d = prg[levelblock_start + attrs_d_offset : levelblock_start + attrs_d_offset + 128]

# Read from extracted file
rooms_ow_text = rooms_ow_path.read_text()
match = re.search(r'RoomAttrsOW_D:\s*\n((?:\s*dc\.b.*\n)+)', rooms_ow_text)
if match:
    attrs_d_text = match.group(1)
    extracted_attrs_d = []
    for line in attrs_d_text.split('\n'):
        if 'dc.b' in line:
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            extracted_attrs_d.extend([int(h, 16) for h in hex_values])
    
    print(f"ROM data (first 16 bytes):       {' '.join(f'{b:02X}' for b in rom_attrs_d[:16])}")
    print(f"Extracted data (first 16 bytes): {' '.join(f'{b:02X}' for b in extracted_attrs_d[:16])}")
    print()
    
    # Check row 3 specifically
    print("Row 3 (rooms 0x30-0x3F):")
    print(f"ROM:       {' '.join(f'{rom_attrs_d[i]:02X}' for i in range(0x30, 0x40))}")
    print(f"Extracted: {' '.join(f'{extracted_attrs_d[i]:02X}' for i in range(0x30, 0x40))}")
    print()
    
    # Count mismatches
    mismatches = []
    for i in range(128):
        if rom_attrs_d[i] != extracted_attrs_d[i]:
            mismatches.append(i)
    
    print(f"Total mismatches: {len(mismatches)} out of 128 bytes")
    if mismatches:
        print(f"First 10 mismatches:")
        for i in mismatches[:10]:
            print(f"  Room 0x{i:02X}: ROM=0x{rom_attrs_d[i]:02X} Extracted=0x{extracted_attrs_d[i]:02X}")
        
        # Check if there's a pattern
        if len(mismatches) > 10:
            print(f"\nPattern analysis:")
            # Check if it's a consistent offset
            offsets = [extracted_attrs_d[i] - rom_attrs_d[i] for i in mismatches[:10]]
            if all(o == offsets[0] for o in offsets):
                print(f"  Consistent offset: +0x{offsets[0]:02X}")
            else:
                print(f"  Offsets vary: {[f'{o:+d}' for o in offsets]}")
