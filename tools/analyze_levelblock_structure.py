#!/usr/bin/env python3
"""
Analyze the LevelBlock structure in the NES ROM to determine the correct size.

The extraction script uses 768 bytes per level block, but the attributes
are being read from wrong offsets. Need to determine the actual structure.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

rom_path = r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF\Legend of Zelda, The (USA).nes"
prg = read_ines_rom(rom_path)

print("=== LevelBlock Structure Analysis ===\n")

# According to extraction output:
# LevelBlockOW: ROM $18400, 768 bytes
# LevelBlockUW1Q1: ROM $18700, 768 bytes

# But we know RoomAttrsOW_D should be at ROM 0x18500
# And the extracted data is coming from ROM 0x18590

# Let's check what's actually at these offsets
print("Checking LevelBlockOW structure:")
print()

levelblock_start = 0x18400 - 0x10

# If LevelBlock is 768 bytes (0x300):
# Attrs A: 0x18400 + 0x000 = 0x18400
# Attrs B: 0x18400 + 0x080 = 0x18480
# Attrs C: 0x18400 + 0x100 = 0x18500
# Attrs D: 0x18400 + 0x180 = 0x18580
# Attrs E: 0x18400 + 0x200 = 0x18600
# Attrs F: 0x18400 + 0x280 = 0x18680

print("If LEVEL_BLOCK_SIZE = 768 bytes:")
print(f"  Attrs A at ROM 0x18400: {prg[0x18400-0x10:0x18400-0x10+16].hex()}")
print(f"  Attrs B at ROM 0x18480: {prg[0x18480-0x10:0x18480-0x10+16].hex()}")
print(f"  Attrs C at ROM 0x18500: {prg[0x18500-0x10:0x18500-0x10+16].hex()}")
print(f"  Attrs D at ROM 0x18580: {prg[0x18580-0x10:0x18580-0x10+16].hex()}")
print(f"  Attrs E at ROM 0x18600: {prg[0x18600-0x10:0x18600-0x10+16].hex()}")
print(f"  Attrs F at ROM 0x18680: {prg[0x18680-0x10:0x18680-0x10+16].hex()}")
print()

# The extraction script reads:
# ow_block[0x000:0x080] for RoomAttrsOW_A
# ow_block[0x080:0x100] for RoomAttrsOW_B
# ow_block[0x100:0x180] for RoomAttrsOW_C
# ow_block[0x180:0x200] for RoomAttrsOW_D
# ow_block[0x200:0x280] for RoomAttrsOW_E
# ow_block[0x280:0x300] for RoomAttrsOW_F

print("The extraction script reads RoomAttrsOW_D from ow_block[0x180:0x200]")
print(f"Which maps to ROM 0x18400 + 0x180 = 0x18580")
print(f"But the correct RoomAttrsOW_D is at ROM 0x18500")
print()
print(f"Difference: 0x18580 - 0x18500 = 0x{0x18580 - 0x18500:02X} bytes")
print()

# The issue: each attribute is 128 bytes, not 256 bytes
# So the offsets should be:
# Attrs A: 0x000-0x07F (128 bytes)
# Attrs B: 0x080-0x0FF (128 bytes)
# Attrs C: 0x100-0x17F (128 bytes)
# Attrs D: 0x180-0x1FF (128 bytes) - but this is wrong!

# Wait, let me check if there are actually 6 attributes or just 3
print("Checking if there are 3 or 6 attributes per level block:")
print()

# According to Z_06.asm comments, there should be attributes A, B, C, D, E, F
# But maybe they're organized differently?

# Let's check what comes after the supposed 768 bytes
next_block_start = 0x18700 - 0x10
print(f"Next block (LevelBlockUW1Q1) should start at ROM 0x18700:")
print(f"  First 16 bytes: {prg[next_block_start:next_block_start+16].hex()}")
print()

print("HYPOTHESIS: The level blocks are NOT 768 bytes each.")
print("The extraction script is reading too much data per block.")
print("Need to determine the actual size by examining the ROM structure.")
