#!/usr/bin/env python3
"""
Check if LevelBlockOW is being read from the correct ROM offset.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

from pathlib import Path

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
rom_path = root / "Legend of Zelda, The (USA).nes"

prg = read_ines_rom(rom_path)

print("=== LevelBlockOW Offset Check ===\n")

# The extraction script now says: "LevelBlockOW: ROM $18410, 768 bytes"
# But prg_data has the header stripped, so it reads from prg_data[0x18400]
# Let's check what's actually at that location

expected_rom_offset = 0x18410
prg_data_offset = expected_rom_offset - 0x10  # Account for stripped header

print(f"Expected ROM offset: 0x{expected_rom_offset:05X}")
print(f"Reading from prg_data offset: 0x{prg_data_offset:05X}")
print()

# Read the first 64 bytes of LevelBlockOW
levelblock_data = prg[prg_data_offset : prg_data_offset + 64]
print(f"First 64 bytes at expected location:")
print(f"  {levelblock_data.hex()}")
print()

# Check if this looks like valid RoomAttrsOW data
# RoomAttrsOW_A should start with reasonable palette/door bits
print("Expected pattern for RoomAttrsOW_A (first 16 bytes):")
print("  Should be palette bytes (0x00-0xFF) with door/exit bits")

# Let's also check a few other possible offsets
print("\nChecking other possible offsets:")
for offset in [0x183F0, 0x183E0, 0x183D0, 0x18410, 0x18420]:
    test_data = prg[offset : offset + 16]
    print(f"  0x{offset:05X}: {test_data.hex()}")

print()
print("The correct LevelBlockOW should contain RoomAttrsOW_A through RoomAttrsOW_F")
print("Each attribute table is 128 bytes, so total should be 768 bytes (6 * 128)")
