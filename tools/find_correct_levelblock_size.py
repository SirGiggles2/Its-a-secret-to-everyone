#!/usr/bin/env python3
"""
Find the correct size of LevelBlockOW by examining where the next block starts.

The extraction script assumes 768 bytes per block, but this might be wrong.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

rom_path = r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF\Legend of Zelda, The (USA).nes"
prg = read_ines_rom(rom_path)

print("=== Finding Correct LevelBlock Size ===\n")

# According to extraction output:
# LevelBlockOW: ROM $18400
# LevelBlockUW1Q1: ROM $18700

# This suggests each block is 0x300 (768) bytes

# But let's verify by looking at the actual data
levelblock_ow_start = 0x18400 - 0x10
levelblock_uw1q1_start = 0x18700 - 0x10

# Check what's at the supposed start of LevelBlockOW
print(f"LevelBlockOW starts at ROM 0x18400:")
print(f"  First 32 bytes: {prg[levelblock_ow_start:levelblock_ow_start+32].hex()}")
print()

# The first bytes are FF FF FF... which is padding
# Let's find where the actual data starts
actual_start = levelblock_ow_start
while actual_start < len(prg) and prg[actual_start] == 0xFF:
    actual_start += 1

print(f"Actual data starts at ROM 0x{actual_start + 0x10:05X} (after {actual_start - levelblock_ow_start} bytes of padding)")
print(f"  First 32 bytes: {prg[actual_start:actual_start+32].hex()}")
print()

# Now check where LevelBlockUW1Q1 starts
print(f"LevelBlockUW1Q1 starts at ROM 0x18700:")
print(f"  First 32 bytes: {prg[levelblock_uw1q1_start:levelblock_uw1q1_start+32].hex()}")
print()

# Calculate the actual size
actual_size = levelblock_uw1q1_start - actual_start
print(f"Actual LevelBlockOW size: {actual_size} bytes (0x{actual_size:03X})")
print(f"Extraction script uses: 768 bytes (0x300)")
print()

if actual_size != 768:
    print(f"ERROR: Size mismatch! Actual size is {actual_size}, not 768")
    print(f"This explains why the attribute offsets are wrong.")
else:
    print("Size is correct, but the offsets within the block must be wrong.")

print()
print("Checking attribute structure:")
print(f"  If there are 6 attributes × 128 bytes = 768 bytes total")
print(f"  Then RoomAttrsOW_D should be at offset 0x180 (384)")
print(f"  But the correct data is at ROM 0x18500")
print(f"  Which is offset {0x18500 - 0x18400} from the block start")
print()
print(f"  Difference: {0x18500 - 0x18400} - 0x180 = {(0x18500 - 0x18400) - 0x180} bytes")
