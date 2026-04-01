#!/usr/bin/env python3
"""
Analyze the starting room (0x77) to understand what the correct layout should be.

The NES starting room is 0x77 (row 7, col 7). This room should have:
- A cave entrance at the top
- Specific terrain layout

By examining what layout data produces the correct starting room, we can
work backward to find where RoomLayoutsOW actually is.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

# RoomAttrsOW_D from the extraction
ROOM_ATTRS_D = [
    0x00,0x01,0x02,0x03,0x04,0x85,0x86,0x07,0x06,0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,
    0x0F,0x90,0x11,0x92,0x13,0x94,0x15,0x16,0x17,0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,
    0x1F,0x20,0x21,0x22,0x23,0x24,0x25,0x26,0x27,0x28,0x29,0xAA,0x2B,0xAC,0x2D,0x2E,
    0x2F,0x30,0xB1,0x32,0x33,0x34,0x35,0x36,0xB7,0x38,0xB9,0x3A,0x0A,0x3B,0xBC,0x3D,
    0x3E,0x3F,0x38,0x38,0x40,0x41,0x42,0x43,0x44,0xC5,0x46,0x47,0xC8,0x49,0x4A,0xCB,
    0x4C,0x4D,0xCE,0xCF,0xD0,0x51,0x52,0xD3,0xD4,0x55,0x56,0xD7,0x58,0x59,0x5A,0xCB,
    0xDB,0x5C,0x5D,0xDE,0xDF,0xE0,0xE1,0x62,0x63,0x64,0xE5,0xE6,0x67,0x68,0xE9,0xEA,
    0x6B,0x6C,0xED,0x6E,0x6F,0xF0,0x71,0x72,0x73,0x74,0x06,0x75,0x76,0x76,0x77,0x78
]

rom_path = r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF\Legend of Zelda, The (USA).nes"
prg = read_ines_rom(rom_path)

print("=== Starting Room Analysis ===\n")

# Room 0x77 is the starting room
room_id = 0x77
unique_id = ROOM_ATTRS_D[room_id] & 0x3F

print(f"Starting room: 0x{room_id:02X}")
print(f"Unique layout ID: 0x{unique_id:02X}")
print(f"Layout should be at offset: {unique_id * 16} in RoomLayoutsOW")
print()

# The layout for unique ID 0x38 should be 16 bytes
# These 16 bytes are column descriptors that index into ColumnDirectoryOW

# Check what we currently have extracted at ROM 0x15828
current_extraction_offset = 0x15828 - 0x10
layout_offset = current_extraction_offset + (unique_id * 16)
current_layout = prg[layout_offset:layout_offset + 16]

print(f"Current extraction (ROM 0x15828):")
print(f"  Layout for unique 0x{unique_id:02X} at offset {unique_id * 16}:")
print(f"  {' '.join(f'{b:02X}' for b in current_layout)}")
print()

# Try other possible extraction offsets
print("Trying other possible extraction offsets:")
for test_offset in [0x157B8, 0x15808, 0x15838, 0x15848]:
    test_layout = prg[test_offset - 0x10 + (unique_id * 16) : test_offset - 0x10 + (unique_id * 16) + 16]
    print(f"  ROM 0x{test_offset:05X}: {' '.join(f'{b:02X}' for b in test_layout)}")

print()
print("The correct layout should produce a room with:")
print("  - Cave entrance at the top")
print("  - Specific terrain matching the NES starting screen")
print()
print("Without knowing what the correct column descriptors should be,")
print("we need to either:")
print("  1. Extract the data from a known-good source")
print("  2. Compare against the actual NES game output")
print("  3. Find documentation on the correct ROM structure")
