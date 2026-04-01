#!/usr/bin/env python3
"""
Add room ID labels to the existing overworld map image.
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(r"c:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF")
input_path = root / "builds" / "reports" / "overworld_all_rooms_reference.png"
output_path = root / "builds" / "reports" / "overworld_labeled.png"

# Load the existing map
map_image = Image.open(input_path)
draw = ImageDraw.Draw(map_image)

# Calculate room dimensions from image size
# Map is 16 columns x 8 rows
map_width, map_height = map_image.size
room_width = map_width // 16
room_height = map_height // 8

# Try to load a font for labels
try:
    font = ImageFont.truetype("arial.ttf", 20)
except:
    try:
        font = ImageFont.truetype("C:\\Windows\\Fonts\\arial.ttf", 20)
    except:
        font = ImageFont.load_default()

# Add labels and grid lines for each room
for row in range(8):
    for col in range(16):
        room_id = row * 16 + col
        
        # Calculate room position
        x = col * room_width
        y = row * room_height
        
        # Draw room ID label
        label = f"{room_id:02X}"
        label_x = x + 4
        label_y = y + 4
        
        # Black outline for visibility
        for dx in [-1, 0, 1]:
            for dy in [-1, 0, 1]:
                if dx != 0 or dy != 0:
                    draw.text((label_x + dx, label_y + dy), label, fill=(0, 0, 0), font=font)
        
        # Yellow text for high visibility
        draw.text((label_x, label_y), label, fill=(255, 255, 0), font=font)
        
        # Draw grid lines
        draw.rectangle([x, y, x + room_width - 1, y + room_height - 1], 
                      outline=(255, 0, 0), width=2)

# Save the labeled map
map_image.save(output_path)
print(f"Created labeled map: {output_path}")
print(f"Map dimensions: {map_width}x{map_height}")
print(f"Room dimensions: {room_width}x{room_height}")
print(f"Grid: 16 columns x 8 rows (rooms 0x00-0x7F)")
