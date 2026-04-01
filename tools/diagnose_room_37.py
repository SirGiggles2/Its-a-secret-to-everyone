#!/usr/bin/env python3
"""
Diagnose room 0x37 (4 rooms above starting screen).

User reports:
- Starting screen (0x77) is correct
- 3 rooms above (0x67, 0x57, 0x47) are correct
- 4th room above (0x37) is WRONG

This suggests the issue starts at row 3.
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

print("=== Diagnosing Room 0x37 ===\n")

# Read RoomAttrsOW_D from NES ROM
# LevelBlockOW starts at ROM 0x18400
# With LEVEL_BLOCK_SIZE=768, attributes are at:
# A: 0x000-0x080, B: 0x080-0x100, C: 0x100-0x180, D: 0x180-0x200

levelblock_start = 0x18400 - 0x10
attrs_d_offset = 0x180
attrs_d_rom = prg[levelblock_start + attrs_d_offset : levelblock_start + attrs_d_offset + 128]

print(f"NES ROM RoomAttrsOW_D[0x37] = 0x{attrs_d_rom[0x37]:02X}")
print(f"  Unique layout ID = 0x{attrs_d_rom[0x37] & 0x3F:02X}")
print()

# Read extracted RoomAttrsOW_D
import re
rooms_ow_text = rooms_ow_path.read_text()
match = re.search(r'RoomAttrsOW_D:\s*\n((?:\s*dc\.b.*\n)+)', rooms_ow_text)
if match:
    attrs_d_text = match.group(1)
    attrs_d_extracted = []
    for line in attrs_d_text.split('\n'):
        if 'dc.b' in line:
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            attrs_d_extracted.extend([int(h, 16) for h in hex_values])
    
    print(f"Extracted RoomAttrsOW_D[0x37] = 0x{attrs_d_extracted[0x37]:02X}")
    print(f"  Unique layout ID = 0x{attrs_d_extracted[0x37] & 0x3F:02X}")
    print()
    
    if attrs_d_rom[0x37] == attrs_d_extracted[0x37]:
        print("✓ RoomAttrsOW_D[0x37] matches NES ROM")
        print("  Issue must be in RoomLayoutsOW data")
    else:
        print("✗ RoomAttrsOW_D[0x37] does NOT match NES ROM")
        print(f"  Difference: ROM has 0x{attrs_d_rom[0x37]:02X}, extracted has 0x{attrs_d_extracted[0x37]:02X}")
        print("  Issue is in RoomAttrsOW_D extraction")

print()
print("Checking pattern across row 3:")
for col in range(16):
    room_id = 0x30 + col
    rom_val = attrs_d_rom[room_id]
    ext_val = attrs_d_extracted[room_id]
    match_str = "✓" if rom_val == ext_val else "✗"
    print(f"  Room 0x{room_id:02X}: ROM=0x{rom_val:02X} Extracted=0x{ext_val:02X} {match_str}")
