#!/usr/bin/env python3
"""Compare the generated overworld against the NES reference to identify specific differences."""

from pathlib import Path
from PIL import Image

def main():
    root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
    
    # Load the generated map
    generated_path = root / "builds" / "reports" / "overworld_all_rooms_reference.png"
    
    if not generated_path.exists():
        print(f"ERROR: Generated map not found at {generated_path}")
        return 1
    
    generated = Image.open(generated_path)
    
    print("=== Overworld Map Analysis ===\n")
    print(f"Generated map size: {generated.size}")
    print(f"Expected: 16 columns × 8 rows of rooms")
    print()
    
    # The starting room in Zelda 1 is room 0x77 (row 7, col 7)
    # This is where Link spawns at the beginning of the game
    print("Starting room should be:")
    print("  Room ID: 0x77")
    print("  Position: Row 7, Column 7 (bottom-middle area)")
    print("  Features: Should have a cave entrance at the top")
    print()
    
    # Key landmarks to check:
    print("Key landmarks to verify:")
    print("  - Room 0x77 (7,7): Starting cave")
    print("  - Room 0x00 (0,0): Upper-left corner")
    print("  - Room 0x0F (0,15): Upper-right corner")
    print("  - Room 0x70 (7,0): Lower-left corner")
    print("  - Room 0x7F (7,15): Lower-right corner")
    print()
    
    print("The issue reported:")
    print("  1. Overworld layout is wrong")
    print("  2. Starting position is wrong")
    print()
    print("This suggests the room layouts themselves are incorrect,")
    print("not just the extraction offset.")
    
    return 0

if __name__ == "__main__":
    exit(main())
