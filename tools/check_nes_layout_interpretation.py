#!/usr/bin/env python3
"""
Check how NES actually interprets layout bytes vs Genesis
"""

from pathlib import Path
import re

root = Path(r"c:\Users\Jake Diggity\Documents/GitHub/VDP rebirth tools and asms/WHAT IF")

print("NES LAYOUT BYTE INTERPRETATION ANALYSIS")
print("=" * 50)
print()

print("CURRENT GENESIS INTERPRETATION:")
print("-" * 30)
print("Layout byte 0x62 -> High nibble 6, Low nibble 2")
print("High nibble = column group, Low nibble = column index")
print("This may be WRONG!")
print()

print("POSSIBLE NES INTERPRETATIONS:")
print("-" * 30)
print("1. Layout byte = direct column index (0-255)")
print("2. Layout byte = different bit field split")
print("3. Layout byte = needs transformation before lookup")
print("4. Layout byte interpretation is completely different")
print()

print("KEY QUESTION:")
print("-" * 30)
print("What does the NES ROM actually do with layout bytes?")
print("How does it map layout byte 0x62 to actual column data?")
print()

# Let's check the reference assembly for clues
print("CHECKING NES REFERENCE CODE:")
print("-" * 30)

# Look at the reference files for layout byte interpretation
ref_dir = root / "reference" / "aldonunez"
for ref_file in ref_dir.glob("*.asm"):
    if ref_file.stat().st_size < 50000:  # Skip huge files
        try:
            content = ref_file.read_text()
            # Look for layout or column related code
            if any(keyword in content.upper() for keyword in ['LAYOUT', 'COLUMN', 'ROOM', 'TILE']):
                print(f"\nChecking {ref_file.name}...")
                # Look for specific patterns
                lines = content.split('\n')
                for i, line in enumerate(lines):
                    if any(keyword in line.upper() for keyword in ['LAYOUT', 'COLUMN', 'ROOM']):
                        # Show surrounding context
                        start = max(0, i-2)
                        end = min(len(lines), i+3)
                        print(f"  Lines {start+1}-{end}:")
                        for j in range(start, end):
                            print(f"    {j+1:3d}: {lines[j]}")
                        print()
                        break
        except Exception as e:
            pass

print()
print("HYPOTHESIS:")
print("-" * 30)
print("The Genesis code might be interpreting layout bytes incorrectly.")
print("Instead of splitting into nibbles, maybe:")
print("1. Layout byte should be used directly as column index")
print("2. Layout byte should be AND-masked differently")
print("3. Layout byte should be transformed before column lookup")
print()

print("This would explain why some tiles work (layout bytes that happen")
print("to work with the wrong interpretation) and others don't.")
