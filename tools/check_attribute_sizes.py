#!/usr/bin/env python3
"""
Check if attributes are actually 112 bytes with 16 bytes padding.

Looking at the extracted data:
- RoomAttrsOW_C ends with the correct RoomAttrsOW_D data
- This suggests attributes might be 112 bytes, not 128 bytes
- Or there's 16 bytes of padding between attributes
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

from pathlib import Path

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
rom_path = root / "Legend of Zelda, The (USA).nes"

prg = read_ines_rom(rom_path)

print("=== Checking Attribute Sizes ===\n")

# LevelBlockOW is at ROM 0x18400, but prg_data has header stripped
# So it's at prg_data[0x183F0]
levelblock_start = 0x18400 - 0x10

# The correct RoomAttrsOW_D data starts with: 5A 83 62 43...
# Let's find where this pattern is in the level block
correct_attrs_d_pattern = bytes([0x5A, 0x83, 0x62, 0x43, 0x0E, 0xE7, 0x4E, 0x00])

# Search in a 1024-byte window around the expected location
search_start = levelblock_start
search_end = search_start + 1024
search_data = prg[search_start:search_end]

pos = search_data.find(correct_attrs_d_pattern)
if pos >= 0:
    print(f"Found RoomAttrsOW_D pattern at offset 0x{pos:03X} within search window")
    print(f"Absolute ROM offset: 0x{0x18400 + pos:05X}")
    print(f"Offset from LevelBlockOW start: 0x{pos:03X}")
    print()
    
    # If attributes are 128 bytes each, D should be at offset 0x180
    # But we found it at a different offset
    expected_offset = 0x180
    actual_offset = pos
    difference = actual_offset - expected_offset
    
    print(f"Expected offset: 0x{expected_offset:03X}")
    print(f"Actual offset: 0x{actual_offset:03X}")
    print(f"Difference: {difference:+d} bytes (0x{abs(difference):02X})")
    print()
    
    if difference == -16:
        print("✓ Attributes are 16 bytes shorter than expected (112 bytes instead of 128)")
        print("  Or there's 16 bytes of padding AFTER each attribute")
    elif difference == 16:
        print("✓ Attributes are 16 bytes longer than expected")
        print("  Or there's 16 bytes of padding BEFORE each attribute")
else:
    print("ERROR: Could not find RoomAttrsOW_D pattern")
