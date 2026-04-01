#!/usr/bin/env python3
"""Check what data the NES reads for unique IDs 0x39-0x3F."""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

rom_path = r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF\Legend of Zelda, The (USA).nes"
prg = read_ines_rom(rom_path)

# Layout data starts at ROM 0x15828 (bank5 0x1818)
start = 0x15828 - 0x10

print("What the NES reads for unique IDs 0x39-0x3F:")
print("(These IDs have no actual layout data - NES reads past end of table)\n")

for uid in range(0x39, 0x40):
    offset = uid * 16
    data = prg[start+offset:start+offset+16]
    print(f"Unique 0x{uid:02X} (offset {offset:4d} = 0x{offset:03X}): {data.hex()}")
    
    # Identify what this data actually is
    if offset == 912:
        print("  -> This is RoomLayoutOWCave0 (cave layout, not room layout!)")
    elif offset == 928:
        print("  -> This is RoomLayoutOWCave1 (cave layout, not room layout!)")
    elif offset == 944:
        print("  -> This is RoomLayoutOWCave2 (cave layout, not room layout!)")
    elif offset >= 960:
        print("  -> This is ColumnHeapOW data (column heap, not room layout!)")

print("\nConclusion:")
print("The NES ROM has a data bug where 7 rooms reference non-existent layouts.")
print("When these rooms are loaded, the NES reads cave/heap data as room layouts,")
print("resulting in corrupted/garbage room rendering.")
print("\nThese rooms are likely UNUSED or INACCESSIBLE in the actual game.")
