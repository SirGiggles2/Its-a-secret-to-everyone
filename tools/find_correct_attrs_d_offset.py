#!/usr/bin/env python3
"""
Find the correct offset for RoomAttrsOW_D by searching for the known pattern.

We know room 0x37 should have value 0x26 (unique layout ID 0x26).
Let's search the LevelBlockOW for where this pattern exists.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

from pathlib import Path

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
rom_path = root / "Legend of Zelda, The (USA).nes"

prg = read_ines_rom(rom_path)

print("=== Finding Correct RoomAttrsOW_D Offset ===\n")

# LevelBlockOW starts at ROM 0x18400, size 768 bytes
levelblock_start = 0x18400 - 0x10
levelblock_size = 768

# Extract the entire block
levelblock = prg[levelblock_start : levelblock_start + levelblock_size]

# We know the correct values for row 3:
# Room 0x30 should be 0x1F, 0x31 should be 0x20, etc.
# Room 0x37 should be 0x26

# Search for this pattern in the level block
target_pattern = bytes([0x1F, 0x20, 0x21, 0x22, 0x23, 0x24, 0x25, 0x26])

pos = levelblock.find(target_pattern)
if pos >= 0:
    print(f"Found pattern starting at offset 0x{pos:03X} within LevelBlockOW")
    print(f"This is where room 0x30-0x37 data is located")
    print()
    
    # The pattern starts at room 0x30, so RoomAttrsOW_D starts at pos - 0x30
    attrs_d_offset = pos - 0x30
    print(f"RoomAttrsOW_D should start at offset 0x{attrs_d_offset:03X}")
    print(f"Current extraction uses offset 0x180")
    print(f"Difference: 0x{0x180 - attrs_d_offset:03X} bytes")
    print()
    
    # Verify by checking a few more rooms
    print("Verification:")
    for room_id in [0x00, 0x10, 0x20, 0x37, 0x40, 0x50, 0x77]:
        correct_val = levelblock[attrs_d_offset + room_id]
        current_val = levelblock[0x180 + room_id]
        match = "✓" if correct_val == current_val else "✗"
        print(f"  Room 0x{room_id:02X}: correct=0x{correct_val:02X} current=0x{current_val:02X} {match}")
else:
    print("Pattern not found! Searching for individual room 0x37 value (0x26)...")
    # Search for 0x26 at position 0x37 within a 128-byte block
    for offset in range(0, levelblock_size - 128, 16):
        if levelblock[offset + 0x37] == 0x26:
            print(f"  Found 0x26 at offset 0x{offset:03X} + 0x37")
