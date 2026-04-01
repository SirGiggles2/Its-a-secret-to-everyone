#!/usr/bin/env python3
"""
Find the actual offset of RoomAttrsOW_D within LevelBlockOW.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

from pathlib import Path
import re

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms/WHAT IF")
rom_path = root / "Legend of Zelda, The (USA).nes"
rooms_ow_path = root / "src" / "data" / "rooms_overworld.inc"

prg = read_ines_rom(rom_path)

print("=== Finding Actual RoomAttrsOW_D Offset ===\n")

# Read the extracted RoomAttrsOW_D
rooms_ow_text = rooms_ow_path.read_text()
match = re.search(r'RoomAttrsOW_D:\s*\n((?:\s*dc\.b.*\n)+)', rooms_ow_text)
extracted_attrs_d = []
if match:
    attrs_d_text = match.group(1)
    for line in attrs_d_text.split('\n'):
        if 'dc.b' in line:
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            extracted_attrs_d.extend([int(h, 16) for h in hex_values])

# We know rooms 0x03 and 0x5F are correct in the extraction
# Let's use these as anchors to find where the actual RoomAttrsOW_D should be

# Room 0x03 should have unique layout ID 0x03
# Room 0x5F should have unique layout ID 0x0B

target_data = bytearray(128)
target_data[0x03] = 0x03
target_data[0x5F] = 0x0B

print("Known correct values:")
print(f"  Room 0x03 should have unique ID 0x03")
print(f"  Room 0x5F should have unique ID 0x0B")
print()

# Search the entire LevelBlockOW for this pattern
levelblock_start = 0x18400 - 0x10  # Account for stripped header
levelblock_data = prg[levelblock_start : levelblock_start + 768]

print(f"Searching LevelBlockOW (ROM 0x18400, prg_data 0x{levelblock_start:05X}) for RoomAttrsOW_D pattern...")
print()

# Look for the pattern where byte 3 == 0x03 and byte 95 == 0x0B
matches = []
for offset in range(len(levelblock_data) - 128):
    if levelblock_data[offset + 0x03] & 0x3F == 0x03 and levelblock_data[offset + 0x5F] & 0x3F == 0x0B:
        matches.append(offset)

print(f"Found {len(matches)} potential offsets:")
for offset in matches:
    rom_offset = 0x18400 + offset
    print(f"  prg_data offset 0x{offset:03X} (ROM 0x{rom_offset:05X})")

if matches:
    print("\nChecking which offset gives the best overall match:")
    
    for offset in matches[:5]:  # Check first 5 matches
        print(f"\nTesting offset 0x{offset:03X}:")
        
        # Extract RoomAttrsOW_D from this offset
        test_attrs_d = levelblock_data[offset : offset + 128]
        
        # Count how many rooms match expected values
        correct_count = 0
        for room_id in range(128):
            # We don't know all expected values, but we can check consistency
            # For now, just check our two anchor rooms
            if room_id == 0x03 and (test_attrs_d[room_id] & 0x3F) == 0x03:
                correct_count += 1
            elif room_id == 0x5F and (test_attrs_d[room_id] & 0x3F) == 0x0B:
                correct_count += 1
        
        print(f"  Anchor rooms correct: {correct_count}/2")
        
        # Show the first few bytes
        print(f"  First 16 bytes: {test_attrs_d[:16].hex()}")
        
        # Check if this looks like valid RoomAttrsOW_D data
        # (should have reasonable values 0x00-0x3F for unique layout IDs)
        unique_ids = [b & 0x3F for b in test_attrs_d]
        valid_count = sum(1 for uid in unique_ids if uid < 0x40)
        print(f"  Valid unique IDs (< 0x40): {valid_count}/128 ({valid_count/128*100:.1f}%)")

print()
print("Current extraction uses offset 0x180 within LevelBlockOW")
print(f"Current offset: prg_data 0x{levelblock_start + 0x180:05X} (ROM 0x18400 + 0x180 = 0x18580)")

# Check what the current extraction produces
current_data = levelblock_data[0x180 : 0x180 + 128]
print(f"Current first 16 bytes: {current_data[:16].hex()}")

# Check if our anchor rooms are correct in current extraction
room_03_correct = (current_data[0x03] & 0x3F) == 0x03
room_5f_correct = (current_data[0x5F] & 0x3F) == 0x0B
print(f"Current extraction - Room 0x03 correct: {room_03_correct}")
print(f"Current extraction - Room 0x5F correct: {room_5f_correct}")
