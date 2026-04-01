#!/usr/bin/env python3
"""Examine the actual layout data in the NES ROM."""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

rom_path = r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF\Legend of Zelda, The (USA).nes"
prg = read_ines_rom(rom_path)

# Layout data starts at ROM 0x15828 (bank5 0x1818)
start = 0x15828 - 0x10

print("Examining ROM data structure:")
print(f"Layout data starts at ROM 0x15828 (bank5 0x1818)")
print(f"First 16 bytes: {prg[start:start+16].hex()}")
print()

# Check what's at various offsets
for offset in [912, 928, 944, 960, 976, 992, 1008, 1024]:
    data = prg[start+offset:start+offset+16]
    print(f"At +{offset:4d} (0x{offset:03X}): {data.hex()}")

print()
print("Cave0 pattern should be: 0000959595959595c2c295959595950000")
print(f"Data at +912: {prg[start+912:start+912+16].hex()}")
print()

# The 912-byte block contains layouts 0x00-0x38 (57 layouts)
# Check if there's more layout data after offset 912
print("Checking if bytes 912-1023 look like layout data or something else:")
chunk = prg[start+912:start+1024]
print(f"Bytes 912-927:  {chunk[0:16].hex()}")
print(f"Bytes 928-943:  {chunk[16:32].hex()}")
print(f"Bytes 944-959:  {chunk[32:48].hex()}")
print(f"Bytes 960-975:  {chunk[48:64].hex()}")
print(f"Bytes 976-991:  {chunk[64:80].hex()}")
print(f"Bytes 992-1007: {chunk[80:96].hex()}")
print(f"Bytes 1008-1023: {chunk[96:112].hex()}")
