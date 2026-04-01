#!/usr/bin/env python3
"""Debug the extraction offset calculation."""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

rom_path = r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF\Legend of Zelda, The (USA).nes"
prg = read_ines_rom(rom_path)

# Simulate what the extraction script does
bank5_offset = 5 * 0x4000
bank5_data = prg[bank5_offset : bank5_offset + 0x4000]

# Find Cave0
cave0_pattern = bytes([0x00, 0x00, 0x95, 0x95, 0x95, 0x95, 0x95, 0xC2, 
                       0xC2, 0x95, 0x95, 0x95, 0x95, 0x95, 0x00, 0x00])
cave0_pos = bank5_data.find(cave0_pattern)

print(f"bank5_offset: 0x{bank5_offset:05X}")
print(f"cave0_pos (within bank5_data): 0x{cave0_pos:04X}")
print(f"cave0 ROM offset: 0x{bank5_offset + cave0_pos:05X}")
print()

ROOM_LAYOUT_OW_SIZE = 0x0390  # 912 bytes
room_layouts_ow_start = cave0_pos - ROOM_LAYOUT_OW_SIZE

print(f"ROOM_LAYOUT_OW_SIZE: 0x{ROOM_LAYOUT_OW_SIZE:04X} ({ROOM_LAYOUT_OW_SIZE} bytes)")
print(f"room_layouts_ow_start (within bank5_data): 0x{room_layouts_ow_start:04X}")
print(f"RoomLayoutsOW ROM offset: 0x{bank5_offset + room_layouts_ow_start:05X}")
print()

# What we should have
correct_rom_offset = 0x15828
print(f"Correct ROM offset should be: 0x{correct_rom_offset:05X}")
print(f"Actual ROM offset we're using: 0x{bank5_offset + room_layouts_ow_start:05X}")
print(f"Difference: {(bank5_offset + room_layouts_ow_start) - correct_rom_offset} bytes")
print()

# Check the data at both locations
print("Data at ROM 0x15818 (what we're extracting):")
print(f"  {prg[0x15818-0x10:0x15818-0x10+32].hex()}")
print()
print("Data at ROM 0x15828 (what we should extract):")
print(f"  {prg[0x15828-0x10:0x15828-0x10+32].hex()}")
