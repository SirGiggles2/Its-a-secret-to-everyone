#!/usr/bin/env python3
"""
Check if the RoomAttrsOW_D extraction is correct.

The issue might not be RoomLayoutsOW, but rather the RoomAttrsOW_D table
that maps room IDs to unique layout IDs.

If this table is wrong, then even with correct layout data, rooms will
appear in the wrong places.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

from pathlib import Path

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
rom_path = root / "Legend of Zelda, The (USA).nes"
rooms_ow_path = root / "src" / "data" / "rooms_overworld.inc"

prg = read_ines_rom(rom_path)

print("=== Checking RoomAttrsOW_D Extraction ===\n")

# RoomAttrsOW_D is in bank 6, part of LevelBlockOW
# According to the extraction output, LevelBlockOW is at ROM $18400

# LevelBlockOW structure (from Z_06.asm):
# - 128 bytes for each of 3 attributes (A, B, D)
# - Total: 384 bytes per quest
# - We want the D attributes for quest 1

bank6_offset = 6 * 0x4000
levelblock_offset = 0x0400
attrs_d_offset = 128 * 2  # Skip A and B attributes

rom_offset = bank6_offset + levelblock_offset + attrs_d_offset
print(f"RoomAttrsOW_D should be at ROM offset: 0x{rom_offset:05X}")

# Read 128 bytes
rom_attrs_d = prg[rom_offset:rom_offset + 128]
print(f"First 16 bytes from ROM: {' '.join(f'{b:02X}' for b in rom_attrs_d[:16])}")
print()

# Read from extracted file
rooms_ow_text = rooms_ow_path.read_text()

# Find RoomAttrsOW_D in the file
import re
match = re.search(r'RoomAttrsOW_D:.*?\.byte\s+(.*?)(?=\n\n|\nRoom)', rooms_ow_text, re.DOTALL)
if match:
    bytes_str = match.group(1)
    # Parse the bytes
    extracted_bytes = []
    for line in bytes_str.split('\n'):
        if '.byte' in line:
            # Extract hex values
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            extracted_bytes.extend([int(h, 16) for h in hex_values])
    
    print(f"Extracted {len(extracted_bytes)} bytes from .inc file")
    print(f"First 16 bytes from .inc: {' '.join(f'{b:02X}' for b in extracted_bytes[:16])}")
    print()
    
    # Compare
    if rom_attrs_d[:len(extracted_bytes)] == bytes(extracted_bytes):
        print("✓ RoomAttrsOW_D extraction is CORRECT")
    else:
        print("✗ RoomAttrsOW_D extraction is WRONG")
        mismatches = sum(1 for i in range(min(len(rom_attrs_d), len(extracted_bytes))) 
                        if rom_attrs_d[i] != extracted_bytes[i])
        print(f"  {mismatches} byte mismatches found")
else:
    print("ERROR: Could not find RoomAttrsOW_D in extracted file")

print()
print("If RoomAttrsOW_D is correct, then the issue is definitely in RoomLayoutsOW.")
print("If RoomAttrsOW_D is wrong, that could explain why rooms appear in wrong positions.")
