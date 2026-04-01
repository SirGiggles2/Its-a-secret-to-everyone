#!/usr/bin/env python3
"""Map the actual LevelBlockOW structure by examining the ROM."""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

rom_path = r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF\Legend of Zelda, The (USA).nes"
prg = read_ines_rom(rom_path)

print("=== Mapping LevelBlockOW Structure ===\n")

# We know:
# - LevelBlockOW starts at ROM 0x18400
# - LevelBlockOW is 752 bytes (0x2F0)
# - RoomAttrsOW_D is at ROM 0x18500 (confirmed correct data)

levelblock_start = 0x18400 - 0x10
levelblock_size = 752

# Extract the entire block
block_data = prg[levelblock_start:levelblock_start + levelblock_size]

print(f"LevelBlockOW: ROM 0x18400, {levelblock_size} bytes")
print()

# Find where RoomAttrsOW_D is within the block
attrs_d_rom = 0x18500 - 0x10
attrs_d_offset = attrs_d_rom - levelblock_start

print(f"RoomAttrsOW_D at ROM 0x18500")
print(f"Offset within block: 0x{attrs_d_offset:03X} ({attrs_d_offset} bytes)")
print()

# The correct RoomAttrsOW_D data starts with: 73 87 5F 03 0F 66 5A 42...
correct_attrs_d = prg[attrs_d_rom:attrs_d_rom + 16]
print(f"Correct RoomAttrsOW_D (first 16 bytes): {correct_attrs_d.hex()}")
print()

# Now let's figure out where the other attributes are
# If D is at offset 0x100, and each attribute is 128 bytes:
# The structure must be:
# 0x000-0x07F: RoomAttrsOW_A (128 bytes)
# 0x080-0x0FF: RoomAttrsOW_B (128 bytes)
# 0x100-0x17F: RoomAttrsOW_D (128 bytes)
# 0x180-0x1FF: RoomAttrsOW_C (128 bytes)
# 0x200-0x27F: RoomAttrsOW_E (128 bytes)
# 0x280-0x2FF: RoomAttrsOW_F (128 bytes) - but this exceeds 752 bytes!

# 752 bytes = 0x2F0, so we can only fit:
# 0x000-0x07F: RoomAttrsOW_A (128 bytes)
# 0x080-0x0FF: RoomAttrsOW_B (128 bytes)
# 0x100-0x17F: RoomAttrsOW_D (128 bytes)
# 0x180-0x1FF: RoomAttrsOW_C (128 bytes)
# 0x200-0x27F: RoomAttrsOW_E (128 bytes)
# 0x280-0x2EF: RoomAttrsOW_F (112 bytes) - TRUNCATED!

# Or maybe the order is different? Let me check what's at each offset:
print("Data at each 128-byte boundary:")
for i in range(0, 752, 128):
    data = block_data[i:i+16]
    print(f"  Offset 0x{i:03X}: {data.hex()}")

print()
print("The correct extraction offsets should be:")
print(f"  RoomAttrsOW_A: 0x000-0x07F")
print(f"  RoomAttrsOW_B: 0x080-0x0FF")
print(f"  RoomAttrsOW_D: 0x100-0x17F (CONFIRMED at ROM 0x18500)")
print(f"  RoomAttrsOW_C: 0x180-0x1FF")
print(f"  RoomAttrsOW_E: 0x200-0x27F")
print(f"  RoomAttrsOW_F: 0x280-0x2EF (only 112 bytes)")
