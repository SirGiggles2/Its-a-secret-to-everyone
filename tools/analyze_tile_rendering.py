#!/usr/bin/env python3
"""
Analyze why some tiles render correctly while others don't

The key insight: if some tiles work and others don't, the issue is likely
in tile rendering logic, not data extraction.
"""

from pathlib import Path
import re

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms/WHAT IF")
rooms_ow_path = root / "src" / "data" / "rooms_overworld.inc"
layouts_path = root / "src" / "data" / "room_layouts.inc"

print("TILE RENDERING ANALYSIS")
print("=" * 50)
print()

print("KEY INSIGHT:")
print("-" * 30)
print("If SOME tiles render correctly and others don't, then:")
print("1. Data extraction is probably working")
print("2. Layout data is probably correct")
print("3. The issue is in TILE RENDERING LOGIC")
print("4. Something about how individual tiles are interpreted/rendered")
print()

# Read layout data
layouts_text = layouts_path.read_text()
match = re.search(r'RoomLayoutsOW:\s*\n((?:\s*dc\.b.*\n)+)', layouts_text)
room_layouts = []
if match:
    layouts_data = match.group(1)
    for line in layouts_data.split('\n'):
        if 'dc.b' in line:
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            room_layouts.extend([int(h, 16) for h in hex_values])

print("ANALYZING TILE PATTERNS:")
print("-" * 30)

# Look at the layout that room 0x03 uses (this was correct in P3.88)
rooms_ow_text = rooms_ow_path.read_text()
match = re.search(r'RoomAttrsOW_D:\s*\n((?:\s*dc\.b.*\n)+)', rooms_ow_text)
extracted_attrs_d = []
if match:
    attrs_d_text = match.group(1)
    for line in attrs_d_text.split('\n'):
        if 'dc.b' in line:
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            extracted_attrs_d.extend([int(h, 16) for h in hex_values])

# Compare layouts from "correct" vs "incorrect" rooms
correct_rooms = [0x03, 0x5F]
wrong_rooms = [0x00, 0x77]  # Start with a clearly wrong room

print("Layout data for CORRECT rooms:")
for room_id in correct_rooms:
    unique_id = extracted_attrs_d[room_id] & 0x3F
    layout_start = unique_id * 16
    layout_end = layout_start + 16
    if layout_end <= len(room_layouts):
        layout_data = room_layouts[layout_start:layout_end]
        hex_str = ''.join(f'{b:02X}' for b in layout_data)
        print(f"  Room 0x{room_id:02X} -> Layout 0x{unique_id:02X}: {hex_str}")

print()
print("Layout data for WRONG rooms:")
for room_id in wrong_rooms:
    unique_id = extracted_attrs_d[room_id] & 0x3F
    layout_start = unique_id * 16
    layout_end = layout_start + 16
    if layout_end <= len(room_layouts):
        layout_data = room_layouts[layout_start:layout_end]
        hex_str = ''.join(f'{b:02X}' for b in layout_data)
        print(f"  Room 0x{room_id:02X} -> Layout 0x{unique_id:02X}: {hex_str}")

print()
print("TILE RENDERING HYPOTHESES:")
print("-" * 30)
print("Hypothesis 1: Tile Type Interpretation")
print("- Some tile bytes are interpreted as wrong tile types")
print("- e.g., a 0x01 byte should be grass but renders as water")

print()
print("Hypothesis 2: Tile Palette Issues")
print("- Some tiles use wrong palette colors")
print("- Tiles render but with incorrect colors")

print()
print("Hypothesis 3: Tile Pattern/Arrangement")
print("- Layout bytes are correct but tile arrangement is wrong")
print("- e.g., tiles appear in wrong positions within room")

print()
print("Hypothesis 4: Column Data Issues")
print("- Room columns (which define tile graphics) are wrong")
print("- Layout data is correct but column lookup fails")

print()
print("Hypothesis 5: VRAM/Rendering Pipeline")
print("- Layout data reaches renderer correctly")
print("- But VRAM writing or tile mapping is wrong")

print()
print("INVESTIGATION APPROACH:")
print("-" * 30)
print("1. Check if layout bytes have meaning (tile types, patterns)")
print("2. Verify column data extraction and indexing")
print("3. Examine Genesis rendering code for tile interpretation")
print("4. Compare tile patterns between working and broken rooms")

print()
print("The fact that SOME tiles work suggests the basic pipeline works.")
print("The issue is likely in tile-specific interpretation or rendering.")
