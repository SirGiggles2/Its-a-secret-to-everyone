#!/usr/bin/env python3
"""
Verify the RoomLayoutsOW extraction offset by checking known room layouts.

The starting room (0x77) uses unique ID from RoomAttrsOW_D.
If we know what the starting room should look like, we can verify
if the layout data is being extracted from the correct offset.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

from pathlib import Path

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
rom_path = root / "Legend of Zelda, The (USA).nes"

prg = read_ines_rom(rom_path)

print("=== Verifying RoomLayoutsOW Offset ===\n")

# Current extraction uses ROM 0x15818
# But let's check if this is actually correct

# The extraction script calculates:
# room_layouts_ow_start = cave0_pos - ROOM_LAYOUT_OW_SIZE
# where ROOM_LAYOUT_OW_SIZE = 0x0390 (912 bytes)

# Find Cave0 in bank 5
bank5_offset = 5 * 0x4000
bank5_data = prg[bank5_offset : bank5_offset + 0x4000]

# Cave0 pattern from NES ROM (first 16 bytes should be unique)
# Looking at the extraction output: "RoomLayoutsOW: bank 5 offset $1818 (ROM $15818)"
# This means Cave0 is at offset $1818 + $0390 = $1BA8

cave0_offset_in_bank = 0x1818 + 0x0390
print(f"Expected Cave0 at bank 5 offset: 0x{cave0_offset_in_bank:04X}")
print(f"Expected Cave0 at ROM offset: 0x{bank5_offset + cave0_offset_in_bank:05X}")
print()

# Check what's at that offset
cave0_data = bank5_data[cave0_offset_in_bank:cave0_offset_in_bank + 16]
print(f"Data at expected Cave0 location: {cave0_data.hex()}")
print()

# The NES disassembly shows RoomLayoutsOW should be 57 layouts (0x00-0x38)
# Each layout is 16 bytes, so 57 * 16 = 912 bytes = 0x390

# But maybe the size is wrong? Let me check different offsets
print("Checking different RoomLayoutsOW start offsets:")
for test_offset in [0x1808, 0x1818, 0x1828, 0x1838]:
    # Calculate where Cave0 would be
    cave0_test = test_offset + 0x0390
    data = bank5_data[cave0_test:cave0_test + 8]
    print(f"  Start 0x{test_offset:04X} -> Cave0 at 0x{cave0_test:04X}: {data.hex()}")

print()
print("The extraction currently uses offset 0x1818 (ROM 0x15818)")
print("This was calculated by working backward from Cave0")
