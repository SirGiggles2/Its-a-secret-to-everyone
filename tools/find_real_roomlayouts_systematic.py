#!/usr/bin/env python3
"""
Systematically search for the real RoomLayoutsOW data in the NES ROM.

The problem: We've been guessing at the location by working backward from Cave0,
but this approach has failed multiple times. We need a different strategy.

Strategy: The NES disassembly shows RoomLayoutsOW uses .INCBIN to include external
data. We need to find the actual size and location by examining the ROM structure.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

rom_path = r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF\Legend of Zelda, The (USA).nes"
prg = read_ines_rom(rom_path)

print("=== Systematic Search for RoomLayoutsOW ===\n")

# Find Cave0 as our anchor point
cave0_pattern = bytes([0x00, 0x00, 0x95, 0x95, 0x95, 0x95, 0x95, 0xC2, 
                       0xC2, 0x95, 0x95, 0x95, 0x95, 0x95, 0x00, 0x00])
cave0_pos = prg.find(cave0_pattern)
print(f"RoomLayoutOWCave0 at ROM offset: 0x{cave0_pos + 0x10:05X}")
print()

# The NES disassembly shows:
# - RoomLayoutsOW (unknown size, uses .INCBIN)
# - RoomLayoutOWCave0 (16 bytes)
# - RoomLayoutOWCave1 (16 bytes)
# - RoomLayoutOWCave2 (16 bytes)
# - ColumnHeapOW0 (starts after Cave2)

# Find Cave1 and Cave2 to verify structure
cave1_pattern = bytes([0x00, 0x00, 0x95, 0x95, 0x95, 0xF8, 0x95, 0xC2,
                       0xF8, 0x95, 0x95, 0xF8, 0x95, 0x95, 0x00, 0x00])
cave2_pattern = bytes([0x00, 0xA9, 0x64, 0x66, 0x02, 0x53, 0x54, 0xD1,
                       0x54, 0x54, 0x56, 0x02, 0x64, 0x66, 0xA8, 0x00])

cave1_pos = prg.find(cave1_pattern)
cave2_pos = prg.find(cave2_pattern)

print(f"RoomLayoutOWCave1 at ROM offset: 0x{cave1_pos + 0x10:05X}")
print(f"RoomLayoutOWCave2 at ROM offset: 0x{cave2_pos + 0x10:05X}")
print()

# Verify they're consecutive
if cave1_pos == cave0_pos + 16 and cave2_pos == cave1_pos + 16:
    print("✓ Cave layouts are consecutive (16 bytes each)")
else:
    print("✗ Cave layouts are NOT consecutive - unexpected structure")
print()

# ColumnHeapOW0 should start after Cave2
heap_start = cave2_pos + 16
print(f"ColumnHeapOW0 should start at ROM offset: 0x{heap_start + 0x10:05X}")
print(f"Data at that location: {prg[heap_start:heap_start+16].hex()}")
print()

# Now work backward from Cave0 to find RoomLayoutsOW
# The question is: how many bytes back?
print("Checking various offsets before Cave0:")
for offset in [16, 32, 48, 64, 80, 96, 112, 128, 256, 512, 768, 896, 912, 928, 1024]:
    start = cave0_pos - offset
    if start < 0:
        continue
    data = prg[start:start+16]
    rom_offset = start + 0x10
    print(f"  -{offset:4d} bytes (ROM 0x{rom_offset:05X}): {data.hex()}")

print()
print("The correct RoomLayoutsOW should:")
print("1. Contain column descriptor bytes (values that index into ColumnDirectoryOW)")
print("2. Be organized as 16-byte chunks (one layout = 16 column descriptors)")
print("3. End exactly where Cave0 begins")
print()
print("Based on previous attempts:")
print("  - 912 bytes back (ROM 0x15828) was tried - still wrong")
print("  - 896 bytes back (ROM 0x15818) was tried - wrong")
print()
print("Need to examine the actual NES ROM binary structure more carefully.")
