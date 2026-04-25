#!/usr/bin/env python3
"""Compose GameCube-version story scroll tilemap.

Lines (per user dictation):
  0: THE LEGEND OF ZELDA  (header)
  1: LONG AGO,  GANON,  PRINCE
  2: OF DARKNESS,  STOLE THE
  3: TRIFORCE OF POWER.
  4: PRINCESS ZELDA OF HYRULE
  5: BROKE THE TRIFORCE OF
  6: WISDOM INTO EIGHT PIECES
  7: AND HID THEM FROM GANON
  8: BEFORE SHE WAS KIDNAPPED
  9: BY GANON'S MINIONS.
  10: LINK,  YOU MUST FIND THE
  11: PIECES AND SAVE  ZELDA.

Per-word color highlights:
  GANON / GANON'S  : pal 3 (orange)
  PRINCESS / ZELDA : pal 2 (blue)
  LINK             : pal 3 (closest available; would need new palette for green)
  THE LEGEND OF ZELDA header : pal 3 (orange)
  Body text default: pal 0 (white)

NES font tile lookup: A=$0A..Z=$23, '.'=$63, ' '=$24, '0'-'9'=$00-$09.
Custom tiles for ',' and ''' uploaded separately at Genesis tile 512/513."""

import sys
from pathlib import Path

OUT = Path(__file__).parent / "intro_story_tilemap_gc.c"

# Tile mappings
TILE_SPACE   = 0x24
TILE_PERIOD  = 0x63
TILE_COMMA_GEN   = 512   # Custom Gen tile (uploaded by build)
TILE_APOSTR_GEN  = 513   # Custom Gen tile

def cell(palette: int, tile: int, hflip: bool = False) -> int:
    base = ((palette & 3) << 13) | (tile & 0x7FF)
    if hflip:
        base |= (1 << 11)
    return base

def tile_for_char(ch: str):
    """Return (tile_idx, is_custom). Custom = use cell-pal-but-tile-already-Gen-index."""
    if ch == ' ': return (TILE_SPACE, False)
    if ch == '.': return (TILE_PERIOD, False)
    if ch == ',': return (TILE_COMMA_GEN, True)
    if ch == "'": return (TILE_APOSTR_GEN, True)
    if ch.isdigit(): return (ord(ch) - ord('0'), False)
    if ch.isalpha(): return (0x0A + (ord(ch.upper()) - ord('A')), False)
    return (TILE_SPACE, False)

# Vine pattern from existing story tilemap (extracted from NES). Single-tile
# vines on cols 2 (left, alternating $E2/$E3) and 29 (right, alternating).
def vine_l(phase: int) -> int:
    return cell(3, 0xE2 if phase % 2 == 0 else 0xE3)
def vine_r(phase: int) -> int:
    return cell(3, 0xE3 if phase % 2 == 0 else 0xE2)

# Header row matches story title row 4 of NES tilemap pattern:
#   blank, blank, $E6, $E4, $E5, blank, [text 6-25], blank, $E5, $E4, $E5, $E6, blank, blank
def make_header_row(text: str, pal: int) -> list[int]:
    row = [cell(0, TILE_SPACE)] * 32
    # Left vine cluster (cols 2-4)
    row[2] = cell(3, 0xE6)
    row[3] = cell(3, 0xE4)
    row[4] = cell(3, 0xE5)
    # Right vine cluster (cols 27-29)
    row[27] = cell(3, 0xE5)
    row[28] = cell(3, 0xE4)
    row[29] = cell(3, 0xE6)
    # Center text in cols 6-25 (20 chars)
    text = text.upper()
    start = 6 + max(0, (20 - len(text)) // 2)
    for i, ch in enumerate(text):
        if start + i > 25: break
        tile, is_custom = tile_for_char(ch)
        row[start + i] = cell(pal, tile)
    return row

# Body row: text + side vines.
def make_body_row(text: str, default_pal: int, pal_overrides: dict, phase: int) -> list[int]:
    """pal_overrides: dict mapping word substrings to palette overrides."""
    row = [cell(0, TILE_SPACE)] * 32
    row[2] = vine_l(phase)
    row[29] = vine_r(phase)
    # Center text in cols 3-28 (26 wide)
    text = text.upper()
    if len(text) > 26:
        text = text[:26]
    start = 3 + max(0, (26 - len(text)) // 2)
    # Determine per-char palette via override-word matching
    char_pals = [default_pal] * len(text)
    for word, pal in pal_overrides.items():
        word_up = word.upper()
        idx = text.find(word_up)
        while idx >= 0:
            for k in range(len(word_up)):
                if idx + k < len(char_pals):
                    char_pals[idx + k] = pal
            idx = text.find(word_up, idx + 1)
    for i, ch in enumerate(text):
        col = start + i
        if col >= 32: break
        tile, _ = tile_for_char(ch)
        row[col] = cell(char_pals[i], tile)
    return row

# Empty body row with vines (for spacing between text rows).
def make_empty_vine_row(phase: int) -> list[int]:
    row = [cell(0, TILE_SPACE)] * 32
    row[2] = vine_l(phase)
    row[29] = vine_r(phase)
    return row

# Header decoration row (blank with single vine cluster on each side, no text).
def make_blank_header_decor(phase: int) -> list[int]:
    return make_empty_vine_row(phase)

LINES = [
    "LONG AGO,  GANON,  PRINCE",
    "OF DARKNESS,  STOLE THE",
    "TRIFORCE OF POWER.",
    "PRINCESS ZELDA OF HYRULE",
    "BROKE THE TRIFORCE OF",
    "WISDOM INTO EIGHT PIECES",
    "AND HID THEM FROM GANON",
    "BEFORE SHE WAS KIDNAPPED",
    "BY GANON'S MINIONS.",
    "LINK,  YOU MUST FIND THE",
    "PIECES AND SAVE  ZELDA.",
]

# Per-line palette overrides: word -> pal index
OVERRIDES = {
    "GANON":    1,   # red
    "PRINCESS": 2,   # blue
    "ZELDA":    2,   # blue
    "LINK":     3,   # green
}

def build_tilemap() -> tuple[list[int], int]:
    cells = []
    # Header row with vine ornament (no extra vines above)
    cells.extend(make_header_row("THE LEGEND OF ZELDA", 1))
    # Empty row between header and body
    cells.extend(make_empty_vine_row(0))
    cells.extend(make_empty_vine_row(1))
    # Paragraph groups (blank vine row between paragraphs).
    PARAGRAPHS = [
        LINES[0:3],   # LONG AGO ... TRIFORCE OF POWER.
        LINES[3:9],   # PRINCESS ZELDA ... BY GANON'S MINIONS.
        LINES[9:11],  # LINK ... PIECES AND SAVE ZELDA.
    ]
    phase = 0
    for pi, para in enumerate(PARAGRAPHS):
        for line in para:
            cells.extend(make_body_row(line, 0, OVERRIDES, phase))
            phase += 1
            cells.extend(make_empty_vine_row(phase))   # spacing row between every line
            phase += 1
        # extra blank between paragraphs
        cells.extend(make_empty_vine_row(phase))
        phase += 1
    # Trailing rows
    while len(cells) // 32 < 30:
        cells.extend(make_empty_vine_row(len(cells) // 32))
    rows = len(cells) // 32
    return cells, rows

def emit_c(cells, rows, path: Path):
    lines = ["/* Auto-generated by tools/intro_demo/compose_story_tilemap.py */\n",
             f"const unsigned short intro_story_tilemap_rows = {rows};\n",
             f"const unsigned short intro_story_tilemap[{rows*32}] = {{\n"]
    for r in range(rows):
        row = cells[r*32:(r+1)*32]
        lines.append("    " + ", ".join(f"0x{c:04X}" for c in row) + ",\n")
    lines.append("};\n")
    path.write_text("".join(lines))
    print(f"wrote {path}: {rows} rows")

def main():
    cells, rows = build_tilemap()
    emit_c(cells, rows, OUT)

if __name__ == "__main__":
    main()
