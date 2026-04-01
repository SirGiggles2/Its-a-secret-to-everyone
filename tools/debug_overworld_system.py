#!/usr/bin/env python3
"""
Systematic Overworld Debug System

This tool helps us understand the data flow from NES ROM to Genesis screen
and identify exactly where the overworld map issue occurs.
"""

def read_ines_rom(rom_path):
    with open(rom_path, "rb") as f:
        f.seek(16)
        return f.read(0x20000)

from pathlib import Path
import re

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
rom_path = root / "Legend of Zelda, The (USA).nes"
rooms_ow_path = root / "src" / "data" / "rooms_overworld.inc"
layouts_path = root / "src" / "data" / "room_layouts.inc"

prg = read_ines_rom(rom_path)

print("=" * 60)
print("SYSTEMATIC OVERWORLD DEBUG SYSTEM")
print("=" * 60)
print()

# Step 1: Document current state
print("STEP 1: CURRENT STATE DOCUMENTATION")
print("-" * 40)
print("P3.88 was 'king' despite 98.4% wrong rooms")
print("P3.89+ broke things by creating inconsistency")
print("Current build: P3.93 (reverted to P3.88 state)")
print()

# Step 2: Analyze data flow
print("STEP 2: DATA FLOW ANALYSIS")
print("-" * 40)

# Read NES ROM data
print("2.1 NES ROM Data:")
levelblock_start = 0x18400 - 0x10  # Account for stripped header
attrs_d_offset = 0x180
rom_attrs_d = prg[levelblock_start + attrs_d_offset : levelblock_start + attrs_d_offset + 128]

# Read extracted data
rooms_ow_text = rooms_ow_path.read_text()
match = re.search(r'RoomAttrsOW_D:\s*\n((?:\s*dc\.b.*\n)+)', rooms_ow_text)
extracted_attrs_d = []
if match:
    attrs_d_text = match.group(1)
    for line in attrs_d_text.split('\n'):
        if 'dc.b' in line:
            hex_values = re.findall(r'\$([0-9A-Fa-f]{2})', line)
            extracted_attrs_d.extend([int(h, 16) for h in hex_values])

print(f"  ROM RoomAttrsOW_D: {len(rom_attrs_d)} bytes")
print(f"  Extracted RoomAttrsOW_D: {len(extracted_attrs_d)} bytes")
print()

# Step 3: Identify discrepancy pattern
print("STEP 3: DISCREPANCY PATTERN ANALYSIS")
print("-" * 40)

offset_counts = {}
correct_rooms = []
wrong_rooms = []

for room_id in range(128):
    rom_val = rom_attrs_d[room_id] & 0x3F
    ext_val = extracted_attrs_d[room_id] & 0x3F
    
    if rom_val == ext_val:
        correct_rooms.append(room_id)
    else:
        offset = ext_val - rom_val
        offset_counts[offset] = offset_counts.get(offset, 0) + 1
        wrong_rooms.append(room_id)

print(f"Correct rooms: {len(correct_rooms)}/128 ({len(correct_rooms)/128*100:.1f}%)")
print(f"Wrong rooms: {len(wrong_rooms)}/128 ({len(wrong_rooms)/128*100:.1f}%)")
print()

if offset_counts:
    print("Offset pattern:")
    for offset, count in sorted(offset_counts.items()):
        print(f"  Offset {offset:+3d}: {count} rooms ({count/128*100:.1f}%)")
print()

# Step 4: Focus on key rooms
print("STEP 4: KEY ROOM ANALYSIS")
print("-" * 40)

key_rooms = [0x77, 0x03, 0x5F]  # Starting room and the two correct rooms from P3.88

for room_id in key_rooms:
    rom_val = rom_attrs_d[room_id] & 0x3F
    ext_val = extracted_attrs_d[room_id] & 0x3F
    offset = ext_val - rom_val
    status = "✓" if rom_val == ext_val else "✗"
    
    print(f"Room 0x{room_id:02X}:")
    print(f"  Position: Row {room_id // 16}, Col {room_id % 16}")
    print(f"  ROM unique ID: 0x{rom_val:02X}")
    print(f"  Extracted unique ID: 0x{ext_val:02X}")
    print(f"  Offset: {offset:+3d} {status}")
    print()

# Step 5: Hypothesis generation
print("STEP 5: HYPOTHESIS GENERATION")
print("-" * 40)

hypotheses = []

# Hypothesis 1: Simple offset
if len(offset_counts) == 1:
    offset = list(offset_counts.keys())[0]
    hypotheses.append(f"H1: Simple {offset:+3d} offset in RoomAttrsOW_D extraction")

# Hypothesis 2: Complex pattern
if len(offset_counts) > 1:
    hypotheses.append("H2: Complex pattern - not a simple offset")

# Hypothesis 3: Room-specific issues
if correct_rooms:
    hypotheses.append(f"H3: Room-specific - rooms {correct_rooms} work for unknown reason")

# Hypothesis 4: Data structure issue
hypotheses.append("H4: Data structure - RoomAttrsOW_D not at expected offset")

for i, hypothesis in enumerate(hypotheses, 1):
    print(f"{i}. {hypothesis}")
print()

# Step 6: Test recommendations
print("STEP 6: TEST RECOMMENDATIONS")
print("-" * 40)

print("To debug systematically:")
print("1. Test P3.93 in emulator - confirm it maintains 'king' status")
print("2. Compare visual output to NES reference for key rooms")
print("3. If P3.93 works, accept current extraction as baseline")
print("4. If P3.93 fails, investigate Genesis code interpretation")
print("5. Create visual comparison tool for room-by-room analysis")
print()

# Step 7: Next steps
print("STEP 7: NEXT STEPS")
print("-" * 40)

print("Immediate actions:")
print("1. STOP making random changes to extraction")
print("2. Test current P3.93 build thoroughly")
print("3. Document what works vs what doesn't")
print("4. Only change one variable at a time")
print("5. Create reproducible test cases")
print()

print("Long-term strategy:")
print("1. Understand WHY P3.88 was 'king'")
print("2. Determine if 'correct' data actually breaks the game")
print("3. Consider that the 'wrong' extraction might be intentional")
print("4. Focus on functional correctness over data correctness")

print()
print("=" * 60)
print("DEBUG SYSTEM READY")
print("=" * 60)
