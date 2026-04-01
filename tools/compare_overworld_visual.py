#!/usr/bin/env python3
"""Compare runtime overworld against reference visually."""

import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

def main():
    root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
    
    probe_path = root / "builds" / "reports" / "bizhawk_phase3_overworld_full_probe.json"
    ref_path = root / "builds" / "reports" / "overworld_all_rooms_reference.json"
    
    probe_data = json.loads(probe_path.read_text())
    ref_data = json.loads(ref_path.read_text())
    
    probe_rooms = {int(r["room_id"]): r for r in probe_data["rooms"]}
    ref_rooms = {int(r["room_id"]): r for r in ref_data["rooms"]}
    
    print("=== Visual Comparison: Runtime vs Reference ===\n")
    
    # Check a few key rooms
    test_rooms = [0x00, 0x01, 0x10, 0x20, 0x50, 0x60, 0x70, 0x77]
    
    for room_id in test_rooms:
        if room_id not in probe_rooms or room_id not in ref_rooms:
            print(f"Room {room_id:02X}: MISSING from probe or reference")
            continue
        
        probe_room = probe_rooms[room_id]
        ref_room = ref_rooms[room_id]
        
        # Compare first tile of each room
        probe_tile = probe_room["room_rows"][0][0]
        ref_tile = ref_room["room_rows"][0][0]
        
        match = "MATCH" if probe_tile == ref_tile else "MISMATCH"
        print(f"Room {room_id:02X}: {match}")
        print(f"  Reference tile[0][0]: 0x{ref_tile:04X}")
        print(f"  Runtime   tile[0][0]: 0x{probe_tile:04X}")
        
        if probe_tile != ref_tile:
            # Show more context
            print(f"  Reference first row: {[f'{t:04X}' for t in ref_room['room_rows'][0][:8]]}")
            print(f"  Runtime   first row: {[f'{t:04X}' for t in probe_room['room_rows'][0][:8]]}")
        print()
    
    # Count total mismatches
    mismatch_count = 0
    for room_id in range(128):
        if room_id not in probe_rooms or room_id not in ref_rooms:
            continue
        
        probe_room = probe_rooms[room_id]
        ref_room = ref_rooms[room_id]
        
        for row_idx, (probe_row, ref_row) in enumerate(zip(probe_room["room_rows"], ref_room["room_rows"])):
            for col_idx, (probe_tile, ref_tile) in enumerate(zip(probe_row, ref_row)):
                if probe_tile != ref_tile:
                    mismatch_count += 1
                    if mismatch_count <= 20:  # Show first 20 mismatches
                        print(f"Room {room_id:02X} row {row_idx:02d} col {col_idx:02d}: ref=0x{ref_tile:04X} runtime=0x{probe_tile:04X}")
    
    print(f"\nTotal tile mismatches: {mismatch_count}")
    
    if mismatch_count == 0:
        print("SUCCESS: Runtime matches reference perfectly!")
    else:
        print(f"FAILURE: {mismatch_count} tile mismatches detected")

if __name__ == "__main__":
    main()
