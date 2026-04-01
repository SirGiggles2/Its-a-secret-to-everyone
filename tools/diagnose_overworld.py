#!/usr/bin/env python3
"""Diagnose overworld layout issues by comparing extracted data against NES ROM."""

import os
import sys
from pathlib import Path

def read_ines_rom(rom_path):
    """Read NES ROM and return PRG data."""
    with open(rom_path, "rb") as f:
        header = f.read(16)
        prg_size = header[4] * 0x4000
        return f.read(prg_size)

def main():
    root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
    rom_path = root / "Legend of Zelda, The (USA).nes"
    inc_path = root / "src" / "data" / "room_layouts.inc"
    
    # Read NES ROM
    prg_data = read_ines_rom(rom_path)
    
    # Find RoomLayoutsOW in ROM
    # Based on extraction output: bank 5 offset $1818 (ROM $15818)
    bank5_offset = 5 * 0x4000
    room_layouts_offset = 0x1818
    rom_offset = bank5_offset + room_layouts_offset
    
    print("=== Overworld Layout Diagnostic ===\n")
    print(f"ROM path: {rom_path}")
    print(f"RoomLayoutsOW in ROM: offset 0x{rom_offset:05X}\n")
    
    # Read 1024 bytes from ROM
    rom_layouts = prg_data[rom_offset:rom_offset + 1024]
    print(f"Read {len(rom_layouts)} bytes from ROM")
    print(f"First 32 bytes: {rom_layouts[:32].hex()}")
    print(f"Last 32 bytes:  {rom_layouts[-32:].hex()}\n")
    
    # Read extracted .inc file
    inc_text = inc_path.read_text()
    
    # Parse RoomLayoutsOW from .inc
    lines = inc_text.split('\n')
    start_idx = next(i for i, line in enumerate(lines) if line.strip() == 'RoomLayoutsOW:')
    
    extracted_bytes = []
    for line in lines[start_idx + 1:]:
        line = line.strip()
        if not line.startswith('dc.b'):
            if line and not line.startswith(';'):
                break
            continue
        
        # Parse hex values
        hex_part = line.split('dc.b', 1)[1].strip()
        for val_str in hex_part.split(','):
            val_str = val_str.strip().replace('$', '0x')
            if val_str:
                extracted_bytes.append(int(val_str, 16))
    
    print(f"Extracted {len(extracted_bytes)} bytes from .inc file")
    print(f"First 32 bytes: {bytes(extracted_bytes[:32]).hex()}")
    print(f"Last 32 bytes:  {bytes(extracted_bytes[-32:]).hex()}\n")
    
    # Compare
    if len(rom_layouts) != len(extracted_bytes):
        print(f"ERROR: Size mismatch!")
        print(f"  ROM has {len(rom_layouts)} bytes")
        print(f"  .inc has {len(extracted_bytes)} bytes")
        return 1
    
    mismatches = []
    for i, (rom_byte, inc_byte) in enumerate(zip(rom_layouts, extracted_bytes)):
        if rom_byte != inc_byte:
            mismatches.append((i, rom_byte, inc_byte))
    
    if mismatches:
        print(f"ERROR: {len(mismatches)} byte mismatches found!")
        for i, rom_byte, inc_byte in mismatches[:20]:
            print(f"  Offset 0x{i:03X}: ROM=0x{rom_byte:02X} .inc=0x{inc_byte:02X}")
        if len(mismatches) > 20:
            print(f"  ... and {len(mismatches) - 20} more")
        return 1
    
    print("SUCCESS: Extracted data matches ROM perfectly!")
    
    # Now check if the data makes sense
    print("\n=== Layout Structure Analysis ===\n")
    
    # Each unique room has 16 column descriptors
    for unique_id in [0x00, 0x10, 0x20, 0x30, 0x3F]:
        offset = unique_id * 16
        descriptors = extracted_bytes[offset:offset + 16]
        print(f"Unique room 0x{unique_id:02X} column descriptors:")
        print(f"  {' '.join(f'{b:02X}' for b in descriptors)}")
    
    return 0

if __name__ == "__main__":
    sys.exit(main())
