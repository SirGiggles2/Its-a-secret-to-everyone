# File Select mockup — paint instructions

**File:** `mockup_fs_full_BLANK.png` (1024×896, 4× upscale of 256×224 NES/Gen visible area)

## Yellow paint zone

Bottom 3 cell rows (r25, r26, r27 — y pixels 200–223 at native res). Paint
PLAYERS + OPTIONS UI here in any layout you want. Yellow tint marks the editable
area; grid shows 8×8 NES tile cells (32 px each at 4× scale).

## What I need from your mockup

1. **Text** — "PLAYERS  < N >" and "OPTIONS" exact strings + cell positions (column
   index, row index). Use existing white/text color (palette 0).
2. **Cursor positions** — paint a yellow heart marker (or any obvious dot) at the
   X/Y where the cursor sits when nav reaches PLAYERS row and OPTIONS row.
3. **Digit slot** — for the `< N >` cycler, mark the cell that holds the digit
   (so I know which NT cell to overwrite at L/R cycle).
4. **(Optional)** — if you want PLAYERS row to use a non-default palette (e.g.
   the same red/yellow as LIFE column), tint the cells with the target color.

## What I do with it

- Read pixel grid → derive 32×3 cell array of tile indices for new NT rows 25–27.
- Append to `fs_static_tilemap` (or generate `fs_extra_tilemap` overlay applied
  over the existing 5-row layout).
- Extend cursor Y table by 2 entries (PLAYERS, OPTIONS) using paint markers.
- Wire `fs_render_players_row(value)` to patch the digit cell with FONT digit tile.

## Quick path if you don't want to paint

Reply with text spec instead, e.g.:

```
r26: PLAYERS  < 1 >    cursor at col 0
r27: OPTIONS           cursor at col 0
digit at r26 col 12
both rows use palette 0 (default text)
```

I take that and skip the PNG round trip.
