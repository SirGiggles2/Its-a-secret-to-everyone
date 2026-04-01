#!/usr/bin/env python3
"""Find the actual RoomLayoutsOW location in the NES ROM."""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

rom_path = r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF\Legend of Zelda, The (USA).nes"
prg = read_ines_rom(rom_path)

# RoomLayoutsOWAddr is at bank5 offset 0x1370 (based on Z_05.asm line 4371)
bank5 = 5 * 0x4000
addr_offset = 0x1370

# Read the 2-byte pointer
ptr_bytes = prg[bank5 + addr_offset : bank5 + addr_offset + 2]
ptr = ptr_bytes[0] | (ptr_bytes[1] << 8)

print(f"RoomLayoutsOWAddr pointer at bank5 0x{addr_offset:04X} (ROM 0x{bank5+addr_offset:05X})")
print(f"Pointer bytes: {ptr_bytes.hex()}")
print(f"Pointer value: 0x{ptr:04X}")

# NES bank 5 is mapped to CPU address 0x8000-0xBFFF
bank5_base = 0x8000
if ptr >= bank5_base and ptr < 0xC000:
    offset = ptr - bank5_base
    rom_offset = bank5 + offset
    print(f"\nPointer points to bank5 offset: 0x{offset:04X}")
    print(f"ROM offset: 0x{rom_offset:05X}")
    
    # Read first 64 bytes at that location
    data = prg[rom_offset : rom_offset + 64]
    print(f"\nFirst 64 bytes at ROM 0x{rom_offset:05X}:")
    for i in range(0, 64, 16):
        chunk = data[i:i+16]
        hex_str = ' '.join(f'{b:02X}' for b in chunk)
        print(f"  +{i:04X}: {hex_str}")
    
    # Compare with what we've been extracting
    wrong_offset = 0x15828 - 0x10
    print(f"\nWhat we've been extracting (ROM 0x15828):")
    wrong_data = prg[wrong_offset : wrong_offset + 64]
    for i in range(0, 64, 16):
        chunk = wrong_data[i:i+16]
        hex_str = ' '.join(f'{b:02X}' for b in chunk)
        print(f"  +{i:04X}: {hex_str}")
    
    if rom_offset != wrong_offset:
        print(f"\nERROR: We've been extracting from the WRONG location!")
        print(f"  Correct location: ROM 0x{rom_offset:05X}")
        print(f"  Wrong location:   ROM 0x{wrong_offset+0x10:05X}")
else:
    print(f"ERROR: Pointer 0x{ptr:04X} is outside bank5 range")
