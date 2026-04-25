#!/usr/bin/env python3
"""Compose a Genesis-format tilemap mirroring NES Zelda's "ALL OF TREASURES"
item-scroll. Items listed in pairs (left/right column) per the NES order
seen in attract demo capture. Output: intro_treasures_tilemap.c.

NES Zelda font encoding (BG pattern table tiles, used as text glyphs):
  0x00-0x09 = digits '0'-'9'
  0x0A-0x23 = letters 'A'-'Z'
  0x24      = space (blank)
  0x60-0x6F = special punctuation (apostrophe, dash, etc.) — partial set

Layout per item-pair row (5 cells tall total, 32 cells wide):
  row +0: blank spacer (vines on cols 0-1 and 30-31)
  row +1: ICON_L (cols 7-8) blank ICON_R (cols 20-21)
  row +2: ICON_L row 2                 ICON_R row 2
  row +3: NAME_L (centered ~col 4-13)  NAME_R (centered ~col 17-26)
  row +4: blank spacer

Header (rows 0-2):
  blank, "ALL OF TREASURES" (centered), blank

For v1 we skip sprite icons (rows +1/+2 are blank). Names + vines + header
gives a recognizable "scrolling item list" look. Sprite icons can be added
in v2 by extracting DemoSpritePatterns.dat and placing icon tile groups.
"""

import sys
import json
from pathlib import Path

OUT = Path(__file__).parent / "intro_treasures_tilemap.c"

# NES Zelda font: 'A' = tile 0x0A, etc.
def tile_for_char(ch: str) -> int:
    if ch == ' ': return 0x24
    if ch.isdigit(): return ord(ch) - ord('0')           # '0'..'9' = $00..$09
    if ch.isalpha(): return 0x0A + (ord(ch.upper()) - ord('A'))   # 'A'..'Z' = $0A..$23
    return 0x24  # unknown -> blank

def encode_name(name: str) -> list[int]:
    return [tile_for_char(c) for c in name]

def cell(palette: int, tile: int) -> int:
    return ((palette & 3) << 13) | (tile & 0x7FF)

# Vine border tiles from DemoBackgroundPatterns: $E2/$E3 (left), $E5/$E6 (right)
# These were observed in the working story tilemap for left+right columns.
VINE_L_A = 0x60E2  # palette 3, tile $E2
VINE_L_B = 0x60E3
VINE_R_A = 0x60E5
VINE_R_B = 0x60E6
BLANK    = 0x0024  # palette 0, blank tile

def make_row(left_text: str = "", right_text: str = "",
             palette_l: int = 0, palette_r: int = 0,
             vine_phase: int = 0) -> list[int]:
    row = [BLANK] * 32
    # NES item scroll has NO vines — solid black background.
    # Left text centered in cols 3-14 (12 cells)
    if left_text:
        text = left_text.upper()
        # Left column content area: cols 3-14
        start = 3 + max(0, (12 - len(text)) // 2)
        for i, ch in enumerate(text):
            if start + i <= 14:
                row[start + i] = cell(palette_l, tile_for_char(ch))
    # Right text centered in cols 17-28 (12 cells)
    if right_text:
        text = right_text.upper()
        start = 17 + max(0, (12 - len(text)) // 2)
        for i, ch in enumerate(text):
            if start + i <= 28:
                row[start + i] = cell(palette_r, tile_for_char(ch))
    return row

def make_centered_row(text: str, palette: int, vine_phase: int = 0) -> list[int]:
    row = [BLANK] * 32
    text = text.upper()
    start = max(0, (32 - len(text)) // 2)
    for i, ch in enumerate(text):
        if start + i < 32:
            row[start + i] = cell(palette, tile_for_char(ch))
    return row

# Item pairs as (left_item_id, left_lines, right_item_id, right_lines)
# item_id is the NES Zelda item slot used by Anim_ItemFrameOffsets to look up
# the sprite tile. Order matches DemoLeftItemIds / DemoRightItemIds in
# reference/aldonunez/Z_02.asm:391-399 (one row per scroll position).
ITEM_PAIRS = [
    (0x22, ["HEART"],              0x1A, ["CONTAINER", "HEART"]),
    (0x23, ["FAIRY"],              0x21, ["CLOCK"]),
    (0x18, ["RUPEE"],              0x0F, ["5 RUPEES"]),
    (0x1F, ["LIFE POTION"],        0x20, ["2ND POTION"]),
    (0x15, ["LETTER"],             0x04, ["FOOD"]),
    (0x01, ["SWORD"],              0x02, ["WHITE", "SWORD"]),
    (0x03, ["MAGICAL", "SWORD"],   0x1C, ["MAGICAL", "SHIELD"]),
    (0x1D, ["BOOMERANG"],          0x1E, ["MAGICAL", "BOOMERANG"]),
    (0x00, ["BOMB"],               0x0A, ["BOW"]),
    (0x08, ["ARROW"],              0x09, ["SILVER", "ARROW"]),
    (0x06, ["BLUE", "CANDLE"],     0x07, ["RED", "CANDLE"]),
    (0x12, ["BLUE", "RING"],       0x13, ["RED", "RING"]),
    (0x14, ["POWER", "BRACELET"],  0x05, ["RECORDER"]),
    (0x0C, ["RAFT"],               0x0D, ["STEPLADDER"]),
    (0x10, ["MAGICAL", "ROD"],     0x11, ["BOOK OF", "MAGIC"]),
    (0x19, ["KEY"],                0x0B, ["MAGICAL", "KEY"]),
    (0x17, ["MAP"],                0x16, ["COMPASS"]),
]

# NES Zelda item-id -> item-slot lookup (Z_01.asm:4264).
# Multiple item IDs can map to the same slot (e.g. blue/red ring share artwork).
ITEM_ID_TO_SLOT = [
    0x01, 0x00, 0x00, 0x00, 0x06, 0x05, 0x04, 0x04,   # 00-07
    0x02, 0x02, 0x03, 0x0D, 0x09, 0x0C, 0x1B, 0x1C,   # 08-0F
    0x08, 0x0A, 0x0B, 0x0B, 0x0E, 0x0F, 0x10, 0x11,   # 10-17
    0x16, 0x17, 0x18, 0x1A, 0x1F, 0x1D, 0x1E, 0x07,   # 18-1F
    0x07, 0x15, 0x19, 0x14,                            # 20-23
]

# slot -> frame offset (Z_01.asm:5193), then frame -> NES sprite tile (5201).
ANIM_ITEM_FRAME_OFFSETS = [
    0x00, 0x03, 0x07, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E,
    0x0F, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17,
    0x18, 0x17, 0x18, 0x17, 0x19, 0x1B, 0x1C, 0x1D,
    0x1E, 0x1F, 0x20, 0x21, 0x1C, 0x22, 0x22, 0x26,
    0x27, 0x28, 0x29, 0x2B, 0x2E,
]
ANIM_ITEM_FRAME_TILES = [
    0x20, 0x82, 0x3C, 0x34, 0x70, 0x72, 0x74, 0x28,
    0x86, 0x3C, 0x2A, 0x26, 0x24, 0x22, 0x40, 0x4A,
    0x8A, 0x6C, 0x42, 0x46, 0x76, 0x2C, 0x4E, 0x4C,
    0x6A, 0x50, 0x52, 0x66, 0x32, 0x2E, 0x68, 0xF3,
    0x6E, 0xF2, 0x36, 0x38, 0x3A, 0x3C, 0x56, 0x48,
    0x78, 0x20, 0x82, 0x7A, 0x7C, 0x30, 0x64, 0x62,
]

SPRITE_BASE_TILE = 256

# Per-item palettes from item_db.json (built by build_item_db.py from NES OAM dumps).
# Maps NES OAM pal_idx (0/1/2) -> Genesis palette index (1/2/3).
# Genesis pal 0 = text white; pals 1/2/3 = NES sprite pals 0/1/2.
_db_path = Path(__file__).parent / "item_db.json"
ITEM_PAL_BY_ID = {}
if _db_path.exists():
    _db = json.loads(_db_path.read_text())
    for it in _db["items"]:
        ITEM_PAL_BY_ID[it["item_id"]] = (it["pal_idx"] + 1) & 3  # 0->1, 1->2, 2->3

def icon_pal(item_id: int) -> int:
    return ITEM_PAL_BY_ID.get(item_id, 1)

def item_id_to_tile(item_id: int) -> int:
    """item_id -> slot -> frame offset -> NES sprite tile T.
       Per Z_07.asm:854 (LDA ItemIdToSlot,X) then DrawItemBySlot."""
    if item_id >= len(ITEM_ID_TO_SLOT):
        return None
    slot = ITEM_ID_TO_SLOT[item_id]
    if slot >= len(ANIM_ITEM_FRAME_OFFSETS):
        return None
    off = ANIM_ITEM_FRAME_OFFSETS[slot]
    if off >= len(ANIM_ITEM_FRAME_TILES):
        return None
    return ANIM_ITEM_FRAME_TILES[off]

def is_narrow_tile(T: int) -> bool:
    """Per Anim_WriteSpecificItemSprites at Z_01.asm:5279-5287:
       narrow if T == $F3 or $20 <= T < $62. Otherwise wide (2 sprites)."""
    if T == 0xF3:
        return True
    return 0x20 <= T < 0x62

def pair_for(T: int) -> tuple[int, int]:
    """In NES 8x16 sprite mode the tile pair is (T & ~1) top / (T | 1) bot,
       regardless of T's parity. Fix for odd tiles like $F3 (HEART)."""
    return (T & 0xFE, T | 0x01)

def place_icon(row_top: list[int], row_bot: list[int],
               col: int, item_id: int) -> None:
    """Place item icon. Narrow=1 cell wide, wide=2 cells wide. Each column is
       a single 8x16 sprite — pair = (T & ~1) top / (T | 1) bot."""
    T = item_id_to_tile(item_id)
    if T is None or T > 0xFF:
        return
    pal = icon_pal(item_id)
    top_l, bot_l = pair_for(T)
    row_top[col] = cell(pal, SPRITE_BASE_TILE + top_l)
    row_bot[col] = cell(pal, SPRITE_BASE_TILE + bot_l)
    if not is_narrow_tile(T):
        if T + 2 > 0xFF:
            return
        top_r, bot_r = pair_for(T + 2)
        row_top[col + 1] = cell(pal, SPRITE_BASE_TILE + top_r)
        row_bot[col + 1] = cell(pal, SPRITE_BASE_TILE + bot_r)

# Icon column positions
ICON_COL_L = 8   # left column center (narrow uses just this col)
ICON_COL_R = 22  # right column center

# Palette mapping: orange/gold (palette 3) for "highlight" items? NES has
# subtle palette variation. For simplicity, all names palette 0 (white).
NAME_PAL = 0

def build_tilemap() -> tuple[list[int], int]:
    cells: list[int] = []

    # Top spacing (a couple blank rows above header)
    for _ in range(2):
        cells.extend(make_row(vine_phase=len(cells) // 32))

    # Header: "ALL OF TREASURES" in palette 3 (gold/orange)
    cells.extend(make_row(vine_phase=len(cells) // 32))   # blank
    cells.extend(make_centered_row("ALL OF TREASURES", 3,
                                   vine_phase=len(cells) // 32))
    cells.extend(make_row(vine_phase=len(cells) // 32))   # blank

    # Item rows: 2 spacer rows + 2 icon rows + 1 gap row + N name rows + 2 spacer rows.
    for left_id, left_lines, right_id, right_lines in ITEM_PAIRS:
        cells.extend(make_row())                                # spacer
        cells.extend(make_row())                                # spacer
        # Two icon rows: 2x2 sprite-tile block per item at ICON_COL_L / ICON_COL_R.
        icon_top = [BLANK] * 32
        icon_bot = [BLANK] * 32
        place_icon(icon_top, icon_bot, ICON_COL_L, left_id)
        place_icon(icon_top, icon_bot, ICON_COL_R, right_id)
        cells.extend(icon_top)
        cells.extend(icon_bot)
        cells.extend(make_row())                                # gap between icon and name
        # Name rows
        n_name_rows = max(len(left_lines), len(right_lines))
        for i in range(n_name_rows):
            l = left_lines[i]  if i < len(left_lines)  else ""
            r = right_lines[i] if i < len(right_lines) else ""
            cells.extend(make_row(l, r, NAME_PAL, NAME_PAL))
        cells.extend(make_row())                                # bottom spacer
        cells.extend(make_row())                                # bottom spacer

    # Final centered: TRIFORCE (white text like other names)
    for _ in range(3):
        cells.extend(make_row())
    cells.extend(make_centered_row("TRIFORCE", NAME_PAL))
    for _ in range(3):
        cells.extend(make_row())

    # Final centered: PLEASE LOOK UP THE MANUAL FOR DETAILS
    cells.extend(make_centered_row("PLEASE LOOK UP", NAME_PAL,
                                   vine_phase=len(cells) // 32))
    cells.extend(make_centered_row("THE MANUAL",     NAME_PAL,
                                   vine_phase=len(cells) // 32))
    cells.extend(make_centered_row("FOR DETAILS",    NAME_PAL,
                                   vine_phase=len(cells) // 32))
    for _ in range(4):
        cells.extend(make_row(vine_phase=len(cells) // 32))

    rows = len(cells) // 32
    return cells, rows

def emit_c(cells: list[int], rows: int, path: Path):
    lines = ["/* Auto-generated by tools/intro_demo/compose_treasures_tilemap.py */\n",
             f"const unsigned short intro_treasures_tilemap_rows = {rows};\n",
             f"const unsigned short intro_treasures_tilemap[{rows * 32}] = {{\n"]
    for r in range(rows):
        row_cells = cells[r * 32:(r + 1) * 32]
        line = "    " + ", ".join(f"0x{c:04X}" for c in row_cells) + ","
        lines.append(line + "\n")
    lines.append("};\n")
    path.write_text("".join(lines))
    print(f"wrote {path}: {rows} rows ({len(cells)} cells)")

def main():
    cells, rows = build_tilemap()
    emit_c(cells, rows, OUT)
    return 0

if __name__ == "__main__":
    sys.exit(main())
