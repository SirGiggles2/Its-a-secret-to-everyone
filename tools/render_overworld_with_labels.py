#!/usr/bin/env python3
"""
Render the overworld map with room ID labels for comparison.
"""

import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from tools.render_overworld_reference_all import (
    read_ines_rom,
    parse_asm_data_blocks,
    extract_room_data,
    decode_overworld_room,
    TILE_SIZE,
    ROOM_WIDTH,
    ROOM_HEIGHT,
    render_room_to_image,
)

def render_overworld_with_labels(output_path: Path):
    """Render the full overworld map with room ID labels."""
    
    root = Path(__file__).parent.parent
    rom_path = root / "Legend of Zelda, The (USA).nes"
    z05_path = root / "reference" / "aldonunez" / "Z_05.asm"
    
    prg = read_ines_rom(rom_path)
    z05_blocks = parse_asm_data_blocks(z05_path)
    
    room_data = extract_room_data(prg, z05_blocks)
    
    # Create image for 16 columns x 8 rows
    map_width = 16 * ROOM_WIDTH * TILE_SIZE
    map_height = 8 * ROOM_HEIGHT * TILE_SIZE
    
    map_image = Image.new('RGB', (map_width, map_height), color=(0, 0, 0))
    draw = ImageDraw.Draw(map_image)
    
    # Try to load a font for labels
    try:
        font = ImageFont.truetype("arial.ttf", 16)
    except:
        font = ImageFont.load_default()
    
    # Render each room
    for row in range(8):
        for col in range(16):
            room_id = row * 16 + col
            
            # Decode and render the room
            tiles, palettes = decode_overworld_room(room_id, **room_data)
            room_img = render_room_to_image(tiles, palettes)
            
            # Paste room into map
            x = col * ROOM_WIDTH * TILE_SIZE
            y = row * ROOM_HEIGHT * TILE_SIZE
            map_image.paste(room_img, (x, y))
            
            # Draw room ID label
            label = f"{room_id:02X}"
            # Draw label with black outline for visibility
            label_x = x + 2
            label_y = y + 2
            
            # Black outline
            for dx in [-1, 0, 1]:
                for dy in [-1, 0, 1]:
                    if dx != 0 or dy != 0:
                        draw.text((label_x + dx, label_y + dy), label, fill=(0, 0, 0), font=font)
            
            # White text
            draw.text((label_x, label_y), label, fill=(255, 255, 255), font=font)
            
            # Draw grid lines
            draw.rectangle([x, y, x + ROOM_WIDTH * TILE_SIZE - 1, y + ROOM_HEIGHT * TILE_SIZE - 1], 
                          outline=(128, 128, 128), width=1)
    
    map_image.save(output_path)
    print(f"Wrote {output_path}")

if __name__ == "__main__":
    root = Path(__file__).parent.parent
    output_path = root / "builds" / "reports" / "overworld_labeled.png"
    render_overworld_with_labels(output_path)
