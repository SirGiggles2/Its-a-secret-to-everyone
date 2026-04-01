#!/usr/bin/env python3
"""
Determine the correct size of RoomLayoutsOW by examining the NES ROM structure.

The NES has 128 overworld rooms (0x00-0x7F) that map to unique layout IDs.
Each unique layout is 16 bytes (16 column descriptors).

The question: How many unique layouts are there?

From RoomAttrsOW_D analysis, we know:
- 64 unique IDs are referenced (0x00-0x3F)
- But the NES ROM might not have data for all of them

Let's check what size makes sense by examining the ROM structure.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

rom_path = r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF\Legend of Zelda, The (USA).nes"
prg = read_ines_rom(rom_path)

# Find Cave0
cave0_pattern = bytes([0x00, 0x00, 0x95, 0x95, 0x95, 0x95, 0x95, 0xC2, 
                       0xC2, 0x95, 0x95, 0x95, 0x95, 0x95, 0x00, 0x00])
cave0_pos = prg.find(cave0_pattern)

print("=== Determining Correct RoomLayoutsOW Size ===\n")
print(f"Cave0 at ROM offset: 0x{cave0_pos + 0x10:05X}")
print()

# Try different sizes and see which one makes sense
sizes_to_try = [
    (57 * 16, "57 layouts"),
    (64 * 16, "64 layouts"),
    (128 * 16, "128 layouts (one per room)"),
]

print("Testing different possible sizes:")
print()

for size, description in sizes_to_try:
    start = cave0_pos - size
    if start < 0:
        print(f"{description} ({size} bytes): INVALID (would be before ROM start)")
        continue
    
    rom_offset = start + 0x10
    data_start = prg[start:start+16]
    data_end = prg[start+size-16:start+size]
    
    print(f"{description} ({size} bytes = 0x{size:03X}):")
    print(f"  Would start at ROM 0x{rom_offset:05X}")
    print(f"  First 16 bytes: {data_start.hex()}")
    print(f"  Last 16 bytes:  {data_end.hex()}")
    print()

print("The correct size should:")
print("1. Start at a reasonable offset in bank 5")
print("2. Contain column descriptor bytes (0x00-0xFF)")
print("3. End exactly where Cave0 begins")
print()

# Check what comes before the 912-byte block
start_912 = cave0_pos - 912
before_912 = prg[start_912-32:start_912]
print(f"32 bytes BEFORE the 912-byte block (ROM 0x{start_912-32+0x10:05X}):")
print(f"  {before_912.hex()}")
print()

# Check what comes before the 1024-byte block
start_1024 = cave0_pos - 1024
before_1024 = prg[start_1024-32:start_1024]
print(f"32 bytes BEFORE the 1024-byte block (ROM 0x{start_1024-32+0x10:05X}):")
print(f"  {before_1024.hex()}")
print()

print("Without knowing what comes before RoomLayoutsOW in the ROM,")
print("we can't definitively determine the correct size.")
