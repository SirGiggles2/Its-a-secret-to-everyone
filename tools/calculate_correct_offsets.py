#!/usr/bin/env python3
"""Calculate the correct offsets for room attributes within LevelBlockOW."""

# LevelBlockOW starts at ROM 0x18400
# But has 16 bytes of padding (0xFF) at the start
# Actual data starts at ROM 0x18410

# The structure should be:
# - 16 bytes padding (0x000-0x00F)
# - 128 bytes RoomAttrsOW_A (0x010-0x08F)
# - 128 bytes RoomAttrsOW_B (0x090-0x10F)
# - 128 bytes RoomAttrsOW_C (0x110-0x18F)
# - 128 bytes RoomAttrsOW_D (0x190-0x20F) - but wait, this doesn't match!

# Let me check what the actual offsets should be based on ROM addresses:
# RoomAttrsOW_D is at ROM 0x18500
# LevelBlockOW starts at ROM 0x18400
# So RoomAttrsOW_D is at offset 0x100 within the block

print("=== Calculating Correct Attribute Offsets ===\n")

levelblock_start = 0x18400
attrs_d_rom = 0x18500

offset_d = attrs_d_rom - levelblock_start
print(f"RoomAttrsOW_D offset within LevelBlockOW: 0x{offset_d:03X} ({offset_d} bytes)")
print()

# If D is at offset 0x100, and each attribute is 128 bytes:
# A: 0x100 - 3*128 = 0x100 - 0x180 = -0x80 (NEGATIVE!)

# This means there's padding BEFORE the attributes, not between them
# Let's work backward from D:

print("Working backward from RoomAttrsOW_D:")
print(f"  D at offset 0x{offset_d:03X}")
print(f"  C at offset 0x{offset_d - 128:03X} (D - 128)")
print(f"  B at offset 0x{offset_d - 256:03X} (D - 256)")
print(f"  A at offset 0x{offset_d - 384:03X} (D - 384)")
print()

# But offset -0x80 is negative! This means the structure is different.

# Let me check if there are only 3 attributes, not 6:
print("If there are only 3 attributes (A, B, D) with no C, E, F:")
print(f"  D at offset 0x{offset_d:03X}")
print(f"  B at offset 0x{offset_d - 128:03X}")
print(f"  A at offset 0x{offset_d - 256:03X}")
print()

# Still negative! Let me reconsider the structure.

# Actually, looking at the ROM data:
# ROM 0x18400: FF FF FF... (padding)
# ROM 0x18410: actual data starts

# Maybe the attributes are:
# 0x00-0x7F: padding/unused (128 bytes)
# 0x80-0xFF: RoomAttrsOW_A (128 bytes)
# 0x100-0x17F: RoomAttrsOW_D (128 bytes)

print("Hypothesis: Attributes are NOT consecutive")
print("Let me check the actual ROM data to determine the structure...")
