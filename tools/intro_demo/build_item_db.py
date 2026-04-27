#!/usr/bin/env python3
"""Build per-item database from nes_full dumps.
For each item slot we care about, find the best frame where its sprite is
visible, capture: tile, palette index, palette colors, CHR data."""
import os, sys, glob, json
from pathlib import Path
from collections import defaultdict, Counter

DUMP = Path(__file__).parent / "nes_full"

# Item IDs in scroll order (DemoLeftItemIds + DemoRightItemIds from Z_02.asm:391).
LEFT_IDS  = [0x22, 0x23, 0x18, 0x1F, 0x15, 0x01, 0x03, 0x1D, 0x00, 0x08, 0x06, 0x12, 0x14, 0x0C, 0x10, 0x19, 0x17]
RIGHT_IDS = [0x1A, 0x21, 0x0F, 0x20, 0x04, 0x02, 0x1C, 0x1E, 0x0A, 0x09, 0x07, 0x13, 0x05, 0x0D, 0x11, 0x0B, 0x16]

# Item-id -> slot (Z_01.asm:4264)
ID_TO_SLOT = [
    0x01, 0x00, 0x00, 0x00, 0x06, 0x05, 0x04, 0x04,
    0x02, 0x02, 0x03, 0x0D, 0x09, 0x0C, 0x1B, 0x1C,
    0x08, 0x0A, 0x0B, 0x0B, 0x0E, 0x0F, 0x10, 0x11,
    0x16, 0x17, 0x18, 0x1A, 0x1F, 0x1D, 0x1E, 0x07,
    0x07, 0x15, 0x19, 0x14,
]
# slot -> frame_offset (Z_01.asm:5193)
SLOT_TO_OFFSET = [
    0x00, 0x03, 0x07, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E,
    0x0F, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
    0x18, 0x17, 0x18, 0x17, 0x19, 0x1B, 0x1C, 0x1D,
    0x1E, 0x1F, 0x20, 0x21, 0x1C, 0x22, 0x22, 0x26,
    0x27, 0x28, 0x29, 0x2B, 0x2E,
]
# offset -> tile (Z_01.asm:5201)
OFFSET_TO_TILE = [
    0x20, 0x82, 0x3C, 0x34, 0x70, 0x72, 0x74, 0x28,
    0x86, 0x3C, 0x2A, 0x26, 0x24, 0x22, 0x40, 0x4A,
    0x8A, 0x6C, 0x42, 0x46, 0x76, 0x2C, 0x4E, 0x4C,
    0x6A, 0x50, 0x52, 0x66, 0x32, 0x2E, 0x68, 0xF3,
    0x6E, 0xF2, 0x36, 0x38, 0x3A, 0x3C, 0x56, 0x48,
    0x78, 0x20, 0x82, 0x7A, 0x7C, 0x30, 0x64, 0x62,
]

def expected_tile(item_id: int) -> int:
    slot = ID_TO_SLOT[item_id]
    off = SLOT_TO_OFFSET[slot]
    return OFFSET_TO_TILE[off]

def is_narrow(T: int) -> bool:
    return T == 0xF3 or 0x20 <= T < 0x62

# Walk all frames, for each frame parse OAM and extract sprite info.
frames = sorted(int(f.name.split('_')[1].split('.')[0])
                for f in DUMP.glob("oam_*.bin"))
print(f"frames: {len(frames)} (range {frames[0]}-{frames[-1]})")

# Map: tile -> list of (frame, x, y, attr, pal_idx)
tile_appearances = defaultdict(list)

for frame in frames:
    oam = (DUMP / f"oam_{frame}.bin").read_bytes()
    for i in range(64):
        y, tile, attr, x = oam[i*4:i*4+4]
        if y < 240 and y > 0:
            pal_idx = attr & 0x03
            tile_appearances[tile].append((frame, x, y, attr, pal_idx))

# For each expected item, find when it appeared and which palette
print("\n=== Per-item analysis ===")
all_items = []
for label, item_ids, col in [("LEFT", LEFT_IDS, 72), ("RIGHT", RIGHT_IDS, 176)]:
    for idx, item_id in enumerate(item_ids):
        T = expected_tile(item_id)
        # Find OAM appearances of tile T at column close to expected
        apps = [(f, x, y, attr, p) for (f, x, y, attr, p) in tile_appearances.get(T, [])
                if abs(x - col) <= 12]
        if not apps:
            print(f"  {label}#{idx} item_id=${item_id:02X} tile=${T:02X}: NO appearances at col {col}")
            continue
        # Pick frame in middle of appearances
        mid = apps[len(apps)//2]
        frame, x, y, attr, pal = mid
        narrow = is_narrow(T)
        print(f"  {label}#{idx} id=${item_id:02X} tile=${T:02X} pal={pal} "
              f"narrow={narrow} (visible at frame {frame}, {len(apps)} occurrences)")
        all_items.append({
            "label": label, "idx": idx, "item_id": item_id,
            "tile": T, "narrow": narrow, "pal_idx": pal,
            "best_frame": frame,
        })

# Save palette per frame snapshot at one good frame (mid-scroll)
mid_frame = frames[len(frames)//2]
palram = (DUMP / f"palram_{mid_frame}.bin").read_bytes()
print(f"\n=== Sprite palettes at frame {mid_frame} ===")
for p in range(4):
    colors = list(palram[16 + p*4:16 + p*4 + 4])
    print(f"  PAL{p}: {' '.join(f'${c:02X}' for c in colors)}")

# Output JSON for compose tool to read
OUT = Path(__file__).parent / "item_db.json"
db = {
    "items": all_items,
    "sprite_palettes_at_mid": [list(palram[16+p*4:16+p*4+4]) for p in range(4)],
    "mid_frame": mid_frame,
}
OUT.write_text(json.dumps(db, indent=2))
print(f"\nwrote {OUT}")
