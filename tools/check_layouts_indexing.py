#!/usr/bin/env python3
"""
Check RoomLayoutsOW indexing for the visual split issue
"""

from pathlib import Path
import re

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
rooms_ow_path = root / "src" / "data" / "rooms_overworld.inc"
layouts_path = root / "src" / "data" / "room_layouts.inc"

print("ROOMLAYOUTSOW INDEXING ANALYSIS")
print("=" * 50)
print()

# Read extracted RoomAttrsOW_D
rooms_ow_text = rooms_ow_path.read_text()
match = re.search(r'RoomAttrsOW_D:\s*\n((?:\s*dc\.b.*\n)+)', rooms_ow_text)
extracted_attrs_d = []
if match:
    attrs_d_text = match.group(1)
    for line in attrs_d_text.split('\n'):
        if 'dc.b' in line:
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            extracted_attrs_d.extend([int(h, 16) for h in hex_values])

# Read RoomLayoutsOW
layouts_text = layouts_path.read_text()
match = re.search(r'RoomLayoutsOW:\s*\n((?:\s*dc\.b.*\n)+)', layouts_text)
room_layouts = []
if match:
    layouts_data = match.group(1)
    for line in layouts_data.split('\n'):
        if 'dc.b' in line:
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            room_layouts.extend([int(h, 16) for h in hex_values])

print("ROOMLAYOUTSOW DATA:")
print("-" * 30)
print(f"Total layouts: {len(room_layouts)} bytes")
print(f"Expected: 912 bytes (57 layouts * 16 bytes)")
print()

# Check first few layouts
print("First 4 layouts (64 bytes):")
for layout_idx in range(4):
    start = layout_idx * 16
    end = start + 16
    layout_data = room_layouts[start:end]
    hex_str = ''.join(f'{b:02X}' for b in layout_data)
    print(f"  Layout {layout_idx:02d}: {hex_str}")

print()

# Check unique layout IDs for visually wrong vs correct rooms
print("UNIQUE LAYOUT ID ANALYSIS:")
print("-" * 30)

wrong_rooms = list(range(0x00, 0x40))  # 00-3F
correct_rooms = list(range(0x40, 0x80))  # 40-7F

print("Unique layout IDs for visually WRONG rooms (00-3F):")
wrong_unique_ids = set()
for room_id in wrong_rooms:
    unique_id = extracted_attrs_d[room_id] & 0x3F
    wrong_unique_ids.add(unique_id)
print(f"  {sorted(wrong_unique_ids)}")
print(f"  Count: {len(wrong_unique_ids)} unique IDs")
print()

print("Unique layout IDs for visually CORRECT rooms (40-7F):")
correct_unique_ids = set()
for room_id in correct_rooms:
    unique_id = extracted_attrs_d[room_id] & 0x3F
    correct_unique_ids.add(unique_id)
print(f"  {sorted(correct_unique_ids)}")
print(f"  Count: {len(correct_unique_ids)} unique IDs")
print()

# Check overlap
overlap = wrong_unique_ids & correct_unique_ids
print(f"Overlap between wrong and correct: {sorted(overlap)}")
print()

# Check if layout data exists for these unique IDs
print("LAYOUT DATA AVAILABILITY:")
print("-" * 30)
all_unique_ids = wrong_unique_ids | correct_unique_ids
for unique_id in sorted(all_unique_ids):
    layout_start = unique_id * 16
    layout_end = layout_start + 16
    if layout_end <= len(room_layouts):
        layout_data = room_layouts[layout_start:layout_end]
        # Check if layout is all zeros (empty/invalid)
        is_empty = all(b == 0 for b in layout_data)
        status = "EMPTY" if is_empty else "VALID"
        print(f"  Layout {unique_id:02d}: {status}")
    else:
        print(f"  Layout {unique_id:02d}: OUT OF BOUNDS")

print()

# Focus on the key insight: visual split at room 0x40
print("KEY INSIGHT - VISUAL SPLIT AT ROOM 0x40:")
print("-" * 30)
print("Room 0x3F (last wrong room):")
room_3f_id = extracted_attrs_d[0x3F] & 0x3F
print(f"  Unique ID: 0x{room_3f_id:02X}")
if room_3f_id * 16 + 16 <= len(room_layouts):
    layout_3f = room_layouts[room_3f_id * 16 : room_3f_id * 16 + 16]
    print(f"  Layout data: {''.join(f'{b:02X}' for b in layout_3f)}")

print()
print("Room 0x40 (first correct room):")
room_40_id = extracted_attrs_d[0x40] & 0x3F
print(f"  Unique ID: 0x{room_40_id:02X}")
if room_40_id * 16 + 16 <= len(room_layouts):
    layout_40 = room_layouts[room_40_id * 16 : room_40_id * 16 + 16]
    print(f"  Layout data: {''.join(f'{b:02X}' for b in layout_40)}")

print()
print("HYPOTHESIS:")
print("-" * 30)
print("The visual split at room 0x40 suggests:")
print("1. RoomLayoutsOW extraction might be split/segmented")
print("2. Layouts for unique IDs used by rooms 00-3F might be wrong")
print("3. Layouts for unique IDs used by rooms 40-7F might be correct")
print("4. Check RoomLayoutsOW extraction offset or structure")
