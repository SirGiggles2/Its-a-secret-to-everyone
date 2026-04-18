"""Overlay room IDs on the Zelda 1 overworld map.
Map is 16 cols x 8 rows. Room $XY = (Y<<4)|X where X=col, Y=row.
Highlights edge-spawn rooms (bit-3 of RoomAttrsOW_F) in yellow."""
from PIL import Image, ImageDraw, ImageFont

SRC = r"D:\Emulation\Nintendo\NES\ZeldaOverworldMapQ1BG FINAl.png"
OUT = r"D:\Emulation\Nintendo\NES\ZeldaOverworldMap_numbered.png"

# Edge-spawn rooms (bit 3 of RoomAttrsOW_F — the P42-P47 fixture set)
EDGE_SPAWN = {0x5B, 0x5C, 0x5D, 0x61, 0x68, 0x71, 0x72, 0x73, 0x74, 0x78}
# Starting room
SPAWN = 0x77

img = Image.open(SRC).convert("RGBA")
W, H = img.size
print(f"Source: {W}x{H}")

COLS, ROWS = 16, 8
cw = W / COLS
rh = H / ROWS
print(f"Cell: {cw:.1f} x {rh:.1f}")

overlay = Image.new("RGBA", (W, H), (0,0,0,0))
draw = ImageDraw.Draw(overlay)

# Try to load a readable font — fall back to default
font = None
for p in (
    r"C:\Windows\Fonts\consolab.ttf",
    r"C:\Windows\Fonts\consola.ttf",
    r"C:\Windows\Fonts\arialbd.ttf",
    r"C:\Windows\Fonts\arial.ttf",
):
    try:
        font = ImageFont.truetype(p, size=int(rh * 0.25))
        break
    except Exception:
        pass
if font is None:
    font = ImageFont.load_default()

# Grid + labels
for row in range(ROWS):
    for col in range(COLS):
        x0 = col * cw
        y0 = row * rh
        x1 = x0 + cw
        y1 = y0 + rh
        room = (row << 4) | col

        # Highlight overlays
        if room == SPAWN:
            draw.rectangle([x0, y0, x1, y1], fill=(0, 255, 0, 70), outline=(0, 255, 0, 255), width=4)
        elif room in EDGE_SPAWN:
            draw.rectangle([x0, y0, x1, y1], fill=(255, 255, 0, 60), outline=(255, 128, 0, 255), width=3)
        else:
            draw.rectangle([x0, y0, x1, y1], outline=(255, 255, 255, 180), width=2)

        # Label (centered top-left of each cell)
        label = f"${room:02X}"
        pad = 8
        # black shadow
        for dx, dy in ((-2,0),(2,0),(0,-2),(0,2),(-2,-2),(2,-2),(-2,2),(2,2)):
            draw.text((x0 + pad + dx, y0 + pad + dy), label, fill=(0,0,0,255), font=font)
        # white text
        fill = (0,255,0,255) if room == SPAWN else ((255,200,0,255) if room in EDGE_SPAWN else (255,255,255,255))
        draw.text((x0 + pad, y0 + pad), label, fill=fill, font=font)

result = Image.alpha_composite(img, overlay)
result.convert("RGB").save(OUT, "PNG", optimize=True)
print(f"Wrote: {OUT}")

# Also make a tmp copy for display
OUT_TMP = r"C:\tmp\overworld_numbered.png"
result.convert("RGB").save(OUT_TMP, "PNG", optimize=True)
print(f"Also: {OUT_TMP}")
