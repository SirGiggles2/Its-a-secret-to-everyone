#!/usr/bin/env python3
"""Analyze overworld room ID to unique layout ID mapping."""

import os
import sys
from pathlib import Path

# RoomAttrsOW_D table extracted from rooms_overworld.inc
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

def get_unique_room_id(room_id):
    """Get unique layout ID for a given room ID (NES: low 6 bits of RoomAttrsOW_D)."""
    return ROOM_ATTRS_D[room_id] & 0x3F

def main():
    print("=== Overworld Room ID to Unique Layout ID Mapping ===\n")
    
    # Show mapping for all rows
    for row in range(8):
        print(f"Row {row} (rooms 0x{row*16:02X}-0x{row*16+15:02X}):")
        for col in range(16):
            room_id = row * 16 + col
            unique_id = get_unique_room_id(room_id)
            print(f"  Room {room_id:02X} -> unique {unique_id:02X}")
        print()
    
    # Find duplicate mappings
    print("=== Rooms sharing the same unique layout ID ===\n")
    unique_to_rooms = {}
    for room_id in range(128):
        unique_id = get_unique_room_id(room_id)
        unique_to_rooms.setdefault(unique_id, []).append(room_id)
    
    duplicates = {k: v for k, v in unique_to_rooms.items() if len(v) > 1}
    print(f"Found {len(duplicates)} unique IDs shared by multiple rooms:\n")
    
    for unique_id in sorted(duplicates.keys()):
        rooms = duplicates[unique_id]
        room_strs = [f"0x{r:02X}" for r in rooms]
        print(f"  Unique {unique_id:02X}: {', '.join(room_strs)}")
    
    # Count total unique layouts
    total_unique = len(set(get_unique_room_id(i) for i in range(128)))
    print(f"\nTotal unique layout IDs used: {total_unique}")
    print(f"RoomLayoutsOW should contain: {total_unique * 16} bytes ({total_unique} layouts * 16 column descriptors)")
    
    # Check if all unique IDs are sequential
    used_unique_ids = sorted(set(get_unique_room_id(i) for i in range(128)))
    print(f"\nUnique IDs range: 0x{min(used_unique_ids):02X} to 0x{max(used_unique_ids):02X}")
    
    missing = []
    for i in range(max(used_unique_ids) + 1):
        if i not in used_unique_ids:
            missing.append(i)
    
    if missing:
        print(f"WARNING: Missing unique IDs in sequence: {[f'0x{m:02X}' for m in missing]}")
    else:
        print("All unique IDs are sequential (no gaps)")

if __name__ == "__main__":
    main()
