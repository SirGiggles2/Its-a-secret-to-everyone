#!/usr/bin/env python3
"""
The RoomAttrsOW_D extraction is wrong!

Extracted: 00 01 02 03 04 85 86 07 06 08 09 0A 0B 0C 0D 0E
ROM:       00 42 42 1F C1 E6 E4 02 1F 00 01 10 CE CE 00 00

This explains why the overworld is completely scrambled - the room-to-layout
mapping is incorrect!

The extraction script must be reading from the wrong offset in bank 6.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

rom_path = r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF\Legend of Zelda, The (USA).nes"
prg = read_ines_rom(rom_path)

print("=== RoomAttrsOW_D Extraction Error ===\n")

# According to the extraction output:
# LevelBlockOW: ROM $18400, 768 bytes

# LevelBlockOW contains 3 attributes (A, B, D) for 128 rooms each
# Structure: 128 bytes A, 128 bytes B, 128 bytes D

bank6_offset = 6 * 0x4000  # 0x18000
levelblock_offset = 0x0400  # 0x18400

# Attrs A at 0x18400
# Attrs B at 0x18480
# Attrs D at 0x18500

attrs_d_rom_offset = 0x18500
attrs_d_data = prg[attrs_d_rom_offset - 0x10:attrs_d_rom_offset - 0x10 + 128]

print(f"Correct RoomAttrsOW_D at ROM 0x{attrs_d_rom_offset:05X}:")
print(f"First 16 bytes: {' '.join(f'{b:02X}' for b in attrs_d_data[:16])}")
print()

# What the extraction currently has
extracted = bytes([0x00,0x01,0x02,0x03,0x04,0x85,0x86,0x07,0x06,0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E])
print(f"Currently extracted:")
print(f"First 16 bytes: {' '.join(f'{b:02X}' for b in extracted)}")
print()

# Find where the extracted data actually is in the ROM
extracted_pos = prg.find(extracted)
if extracted_pos >= 0:
    print(f"The extracted data is actually from ROM offset: 0x{extracted_pos + 0x10:05X}")
    print(f"This is WRONG - it should be from 0x{attrs_d_rom_offset:05X}")
else:
    print("The extracted data doesn't match anything in the ROM!")
    print("This suggests the extraction script is generating incorrect data.")

print()
print("SOLUTION: Fix the extraction script to read RoomAttrsOW_D from the correct offset.")
