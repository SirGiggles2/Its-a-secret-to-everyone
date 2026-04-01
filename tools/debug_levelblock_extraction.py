#!/usr/bin/env python3
"""
Debug the LevelBlockOW extraction to see what data is actually being read.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

from pathlib import Path

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
rom_path = root / "Legend of Zelda, The (USA).nes"

prg = read_ines_rom(rom_path)

print("=== Debugging LevelBlockOW Extraction ===\n")

# Simulate what the extraction script does
LEVEL_BLOCK_SIZE = 0x0300  # 768 bytes
bank6_offset = 6 * 0x4000

# The extraction finds padding and then reads level blocks
# According to extraction output: "LevelBlockOW: ROM $18400, 768 bytes"
levelblock_ow_rom = 0x18400
levelblock_ow_start = levelblock_ow_rom - 0x10

# Read the block
ow_block = prg[levelblock_ow_start : levelblock_ow_start + LEVEL_BLOCK_SIZE]

print(f"LevelBlockOW extracted from ROM 0x{levelblock_ow_rom:05X}")
print(f"Block size: {len(ow_block)} bytes")
print()

# Check what's at offset 0x180 (RoomAttrsOW_D)
attrs_d = ow_block[0x180:0x200]
print(f"Data at offset 0x180 (RoomAttrsOW_D):")
print(f"  First 16 bytes: {' '.join(f'{b:02X}' for b in attrs_d[:16])}")
print(f"  Bytes 0x30-0x3F: {' '.join(f'{attrs_d[i]:02X}' for i in range(0x30, 0x40))}")
print()

# This should match the ROM data we verified earlier
print("Expected (from ROM verification):")
print(f"  First 16 bytes: 5A 83 62 43 0E E7 4E 00 47 8D 4D D0 D0 49 48 09")
print(f"  Bytes 0x30-0x3F: 1F 20 21 22 23 24 25 26 27 28 29 AA 2B AC 2D 2E")
print()

if attrs_d[:16] == bytes([0x5A, 0x83, 0x62, 0x43, 0x0E, 0xE7, 0x4E, 0x00, 0x47, 0x8D, 0x4D, 0xD0, 0xD0, 0x49, 0x48, 0x09]):
    print("✓ Extraction reads correct data from ROM")
    print("  Issue must be in how the data is written to the .inc file")
else:
    print("✗ Extraction reads WRONG data from ROM")
    print("  Issue is in how LevelBlockOW is located/read")
