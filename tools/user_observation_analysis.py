#!/usr/bin/env python3
"""
User Observation Analysis Tool

Instead of making assumptions, let's document exactly what the user observes
and work backwards to understand the real issue.
"""

from pathlib import Path
import re

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms/WHAT IF")
rooms_ow_path = root / "src" / "data" / "rooms_overworld.inc"

print("USER OBSERVATION ANALYSIS")
print("=" * 50)
print()

print("DOCUMENTING WHAT WE KNOW:")
print("-" * 30)
print("1. P3.88 was 'king' - user considered it the best build")
print("2. User said 'rooms 00-3F are ALL incorrect. Everything else appears correct'")
print("3. This was based on VISUAL comparison of labeled maps")
print("4. My attempts to fix it (P3.89+) made things worse")
print("5. User said current P3.95 (reverted to P3.88) is now 'worse'")
print()

print("KEY QUESTIONS FOR USER:")
print("-" * 30)
print("1. What exactly made P3.88 'king'? What worked correctly?")
print("2. What specific visual issues do you see in current P3.95?")
print("3. Are the issues in the same rooms (00-3F) or different?")
print("4. Is the problem still the visual split at room 0x40?")
print("5. Did P3.88 have the visual split but other things worked better?")
print()

# Read current data to document state
rooms_ow_text = rooms_ow_path.read_text()
match = re.search(r'RoomAttrsOW_D:\s*\n((?:\s*dc\.b.*\n)+)', rooms_ow_text)
extracted_attrs_d = []
if match:
    attrs_d_text = match.group(1)
    for line in attrs_d_text.split('\n'):
        if 'dc.b' in line:
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            extracted_attrs_d.extend([int(h, 16) for h in hex_values])

print("CURRENT DATA STATE (P3.95):")
print("-" * 30)
print("RoomAttrsOW_D unique layout IDs for key rooms:")
key_rooms = [0x77, 0x03, 0x5F, 0x47, 0x40]
for room_id in key_rooms:
    unique_id = extracted_attrs_d[room_id] & 0x3F
    row = room_id // 16
    col = room_id % 16
    desc = ""
    if room_id == 0x77: desc = " (STARTING ROOM)"
    elif room_id == 0x03: desc = " (was correct in P3.88)"
    elif room_id == 0x5F: desc = " (was correct in P3.88)"
    elif room_id == 0x47: desc = " (4 rooms above start)"
    elif room_id == 0x40: desc = " (first room in 'correct' half)"
    
    print(f"  Room 0x{room_id:02X} (Row {row}, Col {col}) -> Unique ID 0x{unique_id:02X}{desc}")

print()
print("HYPOTHESIS - WHY P3.88 WAS 'KING':")
print("-" * 30)
print("Possibility 1: P3.88 had consistent wrongness")
print("- All rooms were wrong in the same predictable way")
print("- User learned to work with the consistent errors")
print("- My fixes created inconsistency which was worse")

print()
print("Possibility 2: P3.88 had some other working aspect")
print("- Maybe room transitions worked better")
print("- Maybe enemy placement was correct")
print("- Maybe other game systems compensated for the visual issues")

print()
print("Possibility 3: The 'wrong' data is actually correct")
print("- Maybe my NES reference comparison is wrong")
print("- Maybe the extracted data matches what the game expects")
print("- Maybe the visual issues are elsewhere in the rendering pipeline")

print()
print("NEXT STEP - USER GUIDANCE NEEDED:")
print("-" * 30)
print("I need to stop making assumptions and learn from your observations.")
print("Please tell me:")
print("1. What specific visual issues you see in P3.95")
print("2. How this differs from what you remember in P3.88")
print("3. Which rooms/areas are most problematic")
print("4. What aspects (if any) still work correctly")

print()
print("Only with your guidance can I understand the real problem and fix it systematically.")
