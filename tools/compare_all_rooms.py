#!/usr/bin/env python3
"""
Compare all rooms between P3.88 and NES reference to see the pattern.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

from pathlib import Path
import re

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
rom_path = root / "Legend of Zelda, The (USA).nes"
rooms_ow_path = root / "src" / "data" / "rooms_overworld.inc"

prg = read_ines_rom(rom_path)

# Read the correct RoomAttrsOW_D from NES ROM
levelblock_start = 0x18400 - 0x10  # Account for stripped header
attrs_d_offset = 0x180
rom_attrs_d = prg[levelblock_start + attrs_d_offset : levelblock_start + attrs_d_offset + 128]

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

print("=== RoomAttrsOW_D Analysis: P3.88 vs NES ===\n")

correct_count = 0
wrong_rooms = []

for room_id in range(128):
    rom_value = rom_attrs_d[room_id] & 0x3F  # Low 6 bits = unique layout ID
    extracted_value = extracted_attrs_d[room_id] & 0x3F
    
    if rom_value == extracted_value:
        correct_count += 1
    else:
        wrong_rooms.append(room_id)

print(f"Correct rooms: {correct_count}/128 ({correct_count/128*100:.1f}%)")
print(f"Wrong rooms: {len(wrong_rooms)}/128 ({len(wrong_rooms)/128*100:.1f}%)")
print()

# Show pattern of wrong rooms
if wrong_rooms:
    print("Wrong rooms by row:")
    for row in range(8):
        row_rooms = [r for r in wrong_rooms if r // 16 == row]
        if row_rooms:
            print(f"  Row {row}: {len(row_rooms)} rooms wrong")
            # Show which columns in this row are wrong
            cols = [r % 16 for r in row_rooms]
            cols_str = ", ".join([f"{c:02X}" for c in cols])
            print(f"    Columns: {cols_str}")
    print()
    
    # Check if there's a pattern
    print("Pattern analysis:")
    row_counts = {}
    for room_id in wrong_rooms:
        row = room_id // 16
        row_counts[row] = row_counts.get(row, 0) + 1
    
    for row in range(8):
        count = row_counts.get(row, 0)
        if count > 0:
            print(f"  Row {row}: {count}/16 rooms wrong ({count/16*100:.1f}%)")
    
    print()
    
    # Check if it's contiguous blocks
    print("Contiguous blocks:")
    if wrong_rooms:
        blocks = []
        current_block = [wrong_rooms[0]]
        
        for room_id in wrong_rooms[1:]:
            if room_id == current_block[-1] + 1:
                current_block.append(room_id)
            else:
                blocks.append(current_block)
                current_block = [room_id]
        blocks.append(current_block)
        
        for block in blocks:
            if len(block) == 1:
                print(f"  Room 0x{block[0]:02X}")
            else:
                print(f"  Rooms 0x{block[0]:02X}-0x{block[-1]:02X} ({len(block)} rooms)")
else:
    print("All rooms are correct!")
