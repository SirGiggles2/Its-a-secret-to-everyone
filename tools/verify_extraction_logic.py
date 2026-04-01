#!/usr/bin/env python3
"""
Verify the extraction logic by examining the actual NES ROM structure.

The extraction script finds Cave0 and works backward. But we've tried:
- cave0_pos - 912 (ROM 0x15818) - WRONG
- cave0_pos - 912 + 16 (ROM 0x15828) - STILL WRONG

The issue: We don't know the actual size of RoomLayoutsOW.
The .INCBIN directive doesn't specify a size.

Solution: Look at the Z_05.asm structure more carefully to understand
what comes BEFORE RoomLayoutsOW.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

rom_path = r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF\Legend of Zelda, The (USA).nes"
prg = read_ines_rom(rom_path)

print("=== Extraction Logic Verification ===\n")

# The Z_05.asm file shows RoomLayoutsOW is in SEGMENT "BANK_05_00"
# But we don't know where in that segment it is

# Let's look at what the disassembly says comes BEFORE RoomLayoutsOW
print("According to Z_05.asm, RoomLayoutsOW is at line 4195")
print("What comes before it in the file?")
print()

# The disassembly shows various functions and data before RoomLayoutsOW
# But without knowing the actual assembled addresses, we can't determine the size

print("The problem:")
print("1. RoomLayoutsOW uses .INCBIN with no size specified")
print("2. We don't have the .dat file")
print("3. We don't have a linker map showing actual addresses")
print("4. Working backward from Cave0 has failed multiple times")
print()

print("Possible solutions:")
print("1. Extract the data from the NES ROM at runtime using an emulator")
print("2. Find a different disassembly that includes the data files")
print("3. Manually determine the size by examining the ROM structure")
print("4. Ask the user for the correct extraction offset")
print()

# Let's try one more thing: look at the actual NES ROM and see if there's
# a pattern that indicates where RoomLayoutsOW starts

cave0_pos = prg.find(bytes([0x00, 0x00, 0x95, 0x95, 0x95, 0x95, 0x95, 0xC2, 
                             0xC2, 0x95, 0x95, 0x95, 0x95, 0x95, 0x00, 0x00]))

print(f"Cave0 at ROM offset: 0x{cave0_pos + 0x10:05X}")
print()

# The NES ROM should have RoomLayoutsOW ending exactly at Cave0
# So we need to find where it STARTS

# One approach: Look for a pattern that indicates the start of layout data
# Layout data should consist of column descriptors (0x00-0xFF)
# that reference column heap entries

# Let's check if there's a recognizable pattern at the start
print("Checking for patterns that might indicate the start of RoomLayoutsOW:")
print()

# Try looking for the first layout (unique ID 0x00)
# This should be at the very start of RoomLayoutsOW
# Room 0x00 uses unique ID 0x00, so let's see what that layout should be

# From the user's reference image, room 0x00 is in the upper-left corner
# It should have specific terrain features

print("Without knowing what the first layout (unique ID 0x00) should contain,")
print("we can't determine where RoomLayoutsOW starts.")
print()
print("RECOMMENDATION: Ask the user for guidance on the correct extraction approach.")
