#!/usr/bin/env python3
"""
Find RoomLayoutsOW by examining the complete structure of bank 5.

According to Z_05.asm, the structure is:
1. RoomLayoutsOW (.INCBIN - unknown size)
2. RoomLayoutOWCave0 (16 bytes) - we can find this
3. RoomLayoutOWCave1 (16 bytes)
4. RoomLayoutOWCave2 (16 bytes)
5. ColumnHeapOW0 (variable size)
6. ... more column heaps ...
7. RoomLayoutsUW (.INCBIN - unknown size)
8. RoomLayoutUWCellar0 (16 bytes) - we can find this

The key insight: RoomLayoutsOW must END exactly where Cave0 begins.
So we need to find where it STARTS.

The only way to know the size is to examine the data itself and look for
patterns that indicate the boundary between RoomLayoutsOW and whatever comes before it.
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

print("=== Finding RoomLayoutsOW by Structure Analysis ===\n")
print(f"RoomLayoutOWCave0 at ROM offset: 0x{cave0_pos + 0x10:05X}")
print()

# RoomLayoutsOW contains column descriptors
# Column descriptors are bytes that index into ColumnDirectoryOW
# ColumnDirectoryOW has entries, so valid descriptors are in a certain range

# Let's examine the data before Cave0 and look for patterns
print("Examining data before Cave0 to find the start of RoomLayoutsOW:")
print()

# Check every 16-byte boundary going backward
for offset in range(16, 2048, 16):
    start = cave0_pos - offset
    if start < 0:
        break
    
    # Read 16 bytes
    data = prg[start:start + 16]
    rom_offset = start + 0x10
    
    # Check if this looks like layout data (column descriptors)
    # Column descriptors should be reasonable byte values
    # Look for patterns that might indicate the start of the data
    
    # Calculate some statistics
    avg = sum(data) / len(data)
    unique_count = len(set(data))
    
    # Print every 16th entry to avoid too much output
    if offset % 256 == 0:
        print(f"ROM 0x{rom_offset:05X} (-{offset:4d}): avg={avg:5.1f} unique={unique_count:2d} data={data[:8].hex()}...")

print()
print("Strategy:")
print("1. RoomLayoutsOW should have relatively consistent byte patterns")
print("2. The data before it might have different characteristics")
print("3. Look for a boundary where the pattern changes")
print()
print("However, without knowing the actual size, this is still guesswork.")
print("The REAL solution is to check what the NES game actually uses at runtime.")
