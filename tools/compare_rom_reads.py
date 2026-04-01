#!/usr/bin/env python3
"""
Compare different ways of reading the ROM to find the discrepancy.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

from pathlib import Path

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
rom_path = root / "Legend of Zelda, The (USA).nes"

prg = read_ines_rom(rom_path)

print("=== Comparing ROM Reads ===\n")

# Method 1: Direct offset (what worked earlier)
levelblock_start = 0x18400 - 0x10
attrs_d_offset = 0x180
direct_read = prg[levelblock_start + attrs_d_offset : levelblock_start + attrs_d_offset + 16]

print(f"Method 1 - Direct read from ROM 0x18400 + 0x180:")
print(f"  {' '.join(f'{b:02X}' for b in direct_read)}")
print()

# Method 2: Via bank offset (what extraction uses)
bank6_offset = 6 * 0x4000
level_block_start = 0x0400
rom_offset = bank6_offset + level_block_start
ow_block = prg[rom_offset : rom_offset + 0x300]
bank_read = ow_block[0x180:0x180 + 16]

print(f"Method 2 - Via bank6_offset (0x{bank6_offset:05X}) + level_block_start (0x{level_block_start:04X}):")
print(f"  ROM offset: 0x{rom_offset:05X}")
print(f"  {' '.join(f'{b:02X}' for b in bank_read)}")
print()

# Check if they match
if direct_read == bank_read:
    print("✓ Both methods read the same data")
else:
    print("✗ Methods read DIFFERENT data!")
    print(f"  rom_offset (0x{rom_offset:05X}) != levelblock_start (0x{levelblock_start:05X})")
    print(f"  Difference: 0x{rom_offset - levelblock_start:05X}")

print()
print(f"Expected ROM offset for LevelBlockOW: 0x18400")
print(f"Actual ROM offset being used: 0x{rom_offset:05X}")
print(f"Difference: 0x{rom_offset - 0x18400:05X}")
