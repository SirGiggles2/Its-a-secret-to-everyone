#!/usr/bin/env python3
"""
Verify if the extracted RoomLayoutsOW data is correct by checking specific rooms.

Now that RoomAttrsOW_D is correct, we can verify if the layout data produces
the correct room visuals.
"""

from pathlib import Path

# Read the extracted RoomAttrsOW_D
root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
rooms_ow_path = root / "src" / "data" / "rooms_overworld.inc"

rooms_ow_text = rooms_ow_path.read_text()

# Extract RoomAttrsOW_D
import re
match = re.search(r'RoomAttrsOW_D:\s*\n((?:\s*dc\.b.*\n)+)', rooms_ow_text)
if match:
    attrs_d_text = match.group(1)
    # Parse the bytes
    attrs_d = []
    for line in attrs_d_text.split('\n'):
        if 'dc.b' in line:
            # Extract hex values
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            attrs_d.extend([int(h, 16) for h in hex_values])
    
    print("=== Verifying RoomLayoutsOW Correctness ===\n")
    print(f"Extracted {len(attrs_d)} bytes from RoomAttrsOW_D")
    print(f"First 16 bytes: {' '.join(f'{b:02X}' for b in attrs_d[:16])}")
    print()
    
    # Check the starting room (0x77)
    room_77_attrs_d = attrs_d[0x77]
    unique_id_77 = room_77_attrs_d & 0x3F
    
    print(f"Starting room 0x77:")
    print(f"  RoomAttrsOW_D[0x77] = 0x{room_77_attrs_d:02X}")
    print(f"  Unique layout ID = 0x{unique_id_77:02X}")
    print()
    
    # The starting room should have a cave entrance
    # If the layout data is correct, unique ID 0x32 should produce
    # a room with a cave at the top
    
    print("The starting room should have:")
    print("  - Cave entrance at the top")
    print("  - Specific terrain matching the NES starting screen")
    print()
    
    # Check room 0x00 (upper-left corner)
    room_00_attrs_d = attrs_d[0x00]
    unique_id_00 = room_00_attrs_d & 0x3F
    
    print(f"Room 0x00 (upper-left corner):")
    print(f"  RoomAttrsOW_D[0x00] = 0x{room_00_attrs_d:02X}")
    print(f"  Unique layout ID = 0x{unique_id_00:02X}")
    print()
    
    print("Without running the game or having a known-good reference,")
    print("we can't verify if the layout data is correct.")
    print()
    print("The user's reference image shows the correct NES overworld.")
    print("Since the generated map doesn't match, the RoomLayoutsOW")
    print("extraction is still wrong.")
    
else:
    print("ERROR: Could not parse RoomAttrsOW_D from extracted file")
