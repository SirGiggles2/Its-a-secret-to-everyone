#!/usr/bin/env python3
"""
Find the correct RoomLayoutsOW by examining the NES ROM structure.

The issue: We've been extracting from ROM 0x15818 (bank5 0x1818), but the
visual output is wrong. This means we're extracting from the wrong location.

Strategy: Look at the NES ROM banks and find where the actual overworld
layout data is stored. The data should be in bank 5 or bank 6.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

rom_path = r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF\Legend of Zelda, The (USA).nes"
prg = read_ines_rom(rom_path)

print("=== Searching for RoomLayoutsOW in NES ROM ===\n")

# The NES ROM has 8 banks of 16KB each
# Bank 5 is at offset 0x14000-0x17FFF
# Bank 6 is at offset 0x18000-0x1BFFF

# According to the disassembly, RoomLayoutsOW is in bank 5
# and is followed by RoomLayoutOWCave0

# Find RoomLayoutOWCave0
cave0_pattern = bytes([0x00, 0x00, 0x95, 0x95, 0x95, 0x95, 0x95, 0xC2, 
                       0xC2, 0x95, 0x95, 0x95, 0x95, 0x95, 0x00, 0x00])
cave0_pos = prg.find(cave0_pattern)
print(f"RoomLayoutOWCave0 found at ROM offset: 0x{cave0_pos + 0x10:05X}")
print(f"Bank 5 offset: 0x{cave0_pos - 0x14000:04X}")
print()

# The extraction script assumes RoomLayoutsOW is 912 bytes before Cave0
# But maybe it's a different size or at a different location

# Let's check if there's a pattern that indicates the start of layout data
# Layout data should consist of column descriptors (values 0x00-0xFF)
# that reference column heap entries

# Check what's at various offsets before Cave0
print("Checking data before RoomLayoutOWCave0:")
for offset in [400, 500, 600, 700, 800, 900, 912, 1000, 1024, 1100, 1200]:
    start = cave0_pos - offset
    if start < 0:
        continue
    data = prg[start:start+16]
    print(f"  -{offset:4d} bytes: {data.hex()}")

print()
print("The correct RoomLayoutsOW should:")
print("1. Be exactly before RoomLayoutOWCave0")
print("2. Contain column descriptor bytes (0x00-0xFF)")
print("3. Have a size that's a multiple of 16 (one layout = 16 column descriptors)")
print()
print("Based on the data, the most likely candidates are:")
print("  - 912 bytes (57 layouts) at ROM 0x15828")
print("  - 1024 bytes (64 layouts) at ROM 0x157B8")
print()
print("The extraction is currently using 912 bytes at ROM 0x15818.")
print("But wait - 0x15818 != 0x15828!")
print(f"Difference: 0x15828 - 0x15818 = {0x15828 - 0x15818} bytes")
print()
print("This might be the issue - we're extracting from 0x15818 but should be at 0x15828!")
