#!/usr/bin/env python3
"""
Find where the RoomAttrsOW_D offset error is occurring.

The extracted data is 0x10 (16 bytes) ahead of where it should be.
This means we're reading from the wrong offset within LevelBlockOW.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

from pathlib import Path

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
rom_path = root / "Legend of Zelda, The (USA).nes"

prg = read_ines_rom(rom_path)

print("=== Finding RoomAttrsOW_D Offset Error ===\n")

# LevelBlockOW starts at ROM 0x18400
levelblock_start = 0x18400 - 0x10

# Current extraction uses offset 0x180 for RoomAttrsOW_D
current_offset = 0x180
current_data = prg[levelblock_start + current_offset : levelblock_start + current_offset + 16]

print(f"Current extraction (offset 0x{current_offset:03X}):")
print(f"  First 16 bytes: {' '.join(f'{b:02X}' for b in current_data)}")
print()

# The correct RoomAttrsOW_D should be at offset 0x100 (as we found earlier)
# But we reverted that change. Let me check what offset gives us the correct data.

# We know room 0x37 should have value 0x26
# Current extraction has 0x36 at position 0x37
# So we're reading from 16 bytes too far ahead

correct_offset = current_offset - 0x10  # 0x180 - 0x10 = 0x170
correct_data = prg[levelblock_start + correct_offset : levelblock_start + correct_offset + 16]

print(f"Trying offset 0x{correct_offset:03X} (current - 0x10):")
print(f"  First 16 bytes: {' '.join(f'{b:02X}' for b in correct_data)}")
print()

# Check if this gives us the right value for room 0x37
test_val = prg[levelblock_start + correct_offset + 0x37]
print(f"Value at offset 0x{correct_offset:03X} + 0x37 = 0x{test_val:02X}")
print(f"Expected value for room 0x37 = 0x26")
print()

if test_val == 0x26:
    print("✓ Offset 0x170 gives correct value!")
    print(f"  RoomAttrsOW_D should be at offset 0x{correct_offset:03X}, not 0x{current_offset:03X}")
else:
    print("✗ Still not correct, trying other offsets...")
    for test_offset in [0x100, 0x110, 0x160, 0x190]:
        test_data = prg[levelblock_start + test_offset + 0x37]
        match = "✓" if test_data == 0x26 else "✗"
        print(f"  Offset 0x{test_offset:03X}: room 0x37 = 0x{test_data:02X} {match}")
