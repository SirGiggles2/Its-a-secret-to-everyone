#!/usr/bin/env python3
"""
Check if there's a gap between RoomLayoutsOW and RoomLayoutOWCave0.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

import re
from pathlib import Path

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
rom_path = root / "Legend of Zelda, The (USA).nes"
z05_path = root / "reference" / "aldonunez" / "Z_05.asm"

prg = read_ines_rom(rom_path)

# Find RoomLayoutOWCave0 pattern in the reference
z05_text = z05_path.read_text()
match = re.search(r'RoomLayoutOWCave0:.*?\n((?:\s+\.byte.*?\n)+)', z05_text, re.DOTALL)
if match:
    cave0_bytes_text = match.group(1)
    cave0_bytes = []
    for line in cave0_bytes_text.split('\n'):
        if '.byte' in line:
            # Extract hex values
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            cave0_bytes.extend([int(h, 16) for h in hex_values])
    
    cave0_pattern = bytes(cave0_bytes[:16])  # First 16 bytes should be unique
    
    print("=== Checking Gap Between RoomLayoutsOW and Cave0 ===\n")
    print(f"Cave0 pattern (first 16 bytes): {cave0_pattern.hex()}")
    print()
    
    # Find Cave0 in ROM
    bank5_offset = 5 * 0x4000
    bank5_data = prg[bank5_offset : bank5_offset + 0x4000]
    
    cave0_pos = bank5_data.find(cave0_pattern)
    if cave0_pos >= 0:
        print(f"Found Cave0 at bank 5 offset 0x{cave0_pos:04X} (ROM 0x{bank5_offset + cave0_pos:05X})")
        print()
        
        # Calculate where RoomLayoutsOW should start (912 bytes before Cave0)
        ROOM_LAYOUT_OW_SIZE = 0x0390
        calculated_start = cave0_pos - ROOM_LAYOUT_OW_SIZE
        
        print(f"Calculated RoomLayoutsOW start: 0x{calculated_start:04X}")
        print(f"This is at ROM offset: 0x{bank5_offset + calculated_start:05X}")
        print()
        
        # Check what's actually at that position and just before Cave0
        print("Data just before Cave0 (16 bytes):")
        before_cave0 = bank5_data[cave0_pos - 16 : cave0_pos]
        print(f"  {before_cave0.hex()}")
        print()
        
        # Check if there are any 0xFF padding bytes
        gap_start = cave0_pos - 1
        while gap_start >= 0 and bank5_data[gap_start] == 0xFF:
            gap_start -= 1
        
        gap_size = cave0_pos - gap_start - 1
        if gap_size > 0:
            print(f"Found {gap_size} bytes of 0xFF padding before Cave0")
            print(f"Actual RoomLayoutsOW end: 0x{gap_start + 1:04X}")
            print(f"Adjusted RoomLayoutsOW start: 0x{gap_start + 1 - ROOM_LAYOUT_OW_SIZE:04X}")
        else:
            print("No padding found - RoomLayoutsOW directly precedes Cave0")
    else:
        print("ERROR: Could not find Cave0 pattern in bank 5")
