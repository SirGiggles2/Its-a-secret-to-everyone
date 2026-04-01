#!/usr/bin/env python3
"""
Test the extraction directly by simulating what extract_rooms.py does.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

from pathlib import Path

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
rom_path = root / "Legend of Zelda, The (USA).nes"

prg_data = read_ines_rom(rom_path)

# Simulate the extraction
LEVEL_BLOCK_SIZE = 0x0300
bank6_offset = 6 * 0x4000
level_block_start = 0x0400  # From extraction output

rom_offset = bank6_offset + level_block_start
ow_block = prg_data[rom_offset : rom_offset + LEVEL_BLOCK_SIZE]

print(f"Reading LevelBlockOW from ROM offset 0x{rom_offset:05X}")
print(f"Block size: {len(ow_block)} bytes")
print()

# Check RoomAttrsOW_D at offset 0x180
attrs_d = ow_block[0x180:0x200]
print(f"RoomAttrsOW_D (offset 0x180):")
print(f"  First 16 bytes: {' '.join(f'{b:02X}' for b in attrs_d[:16])}")
print(f"  Room 0x37: 0x{attrs_d[0x37]:02X}")
print()

# Now write it to a test file using the same function
def data_to_inc_bytes(data, label, bytes_per_line=16):
    lines = [f"; {label} - {len(data)} bytes", f"{label}:"]
    for i in range(0, len(data), bytes_per_line):
        chunk = data[i : i + bytes_per_line]
        lines.append("    dc.b " + ",".join(f"${byte:02X}" for byte in chunk))
    return "\n".join(lines)

output = data_to_inc_bytes(attrs_d, "RoomAttrsOW_D")
test_file = root / "test_attrs_d.inc"
test_file.write_text(output)

print(f"Wrote test file: {test_file}")
print("First few lines:")
for line in output.split('\n')[:5]:
    print(f"  {line}")
