# RoomRom S5 — BG Collision (OW)

**Date:** 2026-04-30
**Status:** Implemented (autonomous)
**Predecessor:** 2026-04-30-roomrom-s4-edge-load-design.md (S4 closed at tag `roomrom-s4-closed`)
**Successors (planned):** S6 scroll transition; S5.5 UW collision (separate slice — UW renderer uses precomputed NT blob without exposed NES tile IDs).

## Goal

Block Link from walking through unwalkable BG tiles in OW (trees, water, walls, mountains, fences). Per-axis blocking enables wall-sliding for ALTTP-style 8-direction movement. UW unchanged in S5 (always walkable) — its renderer uses a precomputed Genesis-NT blob without per-cell NES tile IDs available, so classification needs a separate analysis pass.

## Non-goals

- UW collision (next slice)
- Hotspot adjustments per direction (NES uses different offsets for vertical vs horizontal motion; we use a single foot-center hotspot)
- Push-blocks, breakable rocks, secret stairs (later)
- Boundary tiles (e.g. doorway thresholds in UW)

## Architecture

**Where collision data lives:** the OW renderer owns it. During `roomrom_ow_room_render_fill_plane_a`, every metatile's NES primary tile ID is classified via `ow_walkable_primary()` and stored in `s_walkable[16][11]`. Public accessor:

```c
unsigned char roomrom_ow_room_render_walkable_at(unsigned char col, unsigned char row);
```

**Walkable classifier (NES tile IDs):** ports `Z_07.asm WalkableTiles` ($8D, $91, $9C, $AC, $AD, $CC, $D2, $D5, $DF) plus paths/sand/stairs/shore variants observed in `s_primary_squares` and `s_secondary_squares_redux` (e.g. $24, $26, $54, $56, $58, $5C, $6F, $70, $74-$77, $84). Allowlist style — anything not in the list blocks. Tunable.

**Hotspot:** Link's foot center at `(x+8, y+12)` mapped into the metatile grid:
- `col = (x+8) / 16`
- `row = ((y+12) - 56) / 16` (HUD reserves top 56 px, matches S3 clamp)

**Per-axis check:** after applying X step, sample destination tile. If unwalkable, restore old X. Same for Y. ALTTP gets wall-slide for free (unblocked axis still moves). NES single-axis movement just halts at walls.

## Why this is best practices long-term

- **Renderer owns its truth.** Collision data builds from the same source the renderer uses — no risk of drift between visual and gameplay.
- **Lookup is O(1).** 176-byte grid, indexed by simple division.
- **Per-axis check is style-agnostic.** Both NES and ALTTP movement paths share `link_walkable_at()` semantics.
- **Allowlist scales.** Adding walkable tiles is one switch case; mistakes never silently let Link through walls (unknown tiles default block).
- **UW deferred cleanly.** `link_walkable_at` returns 1 in UW today; replacing that with a UW classifier is a localized change.

## Verification

S5 done when:

1. Build clean.
2. Boot OW R0x77: Link can walk on the sand path freely.
3. Walk Link toward the trees (north/east/west borders): blocked, doesn't pass through.
4. Walk into the dark cave entrance tile: passable (cave entrances are walkable).
5. ALTTP mode (Y): walking diagonal into a wall slides along the wall.
6. NES mode: walking into a wall stops Link cleanly (no judder).
7. Cross-room edge transitions still work (S4 unaffected).
8. UW: walking still works through walls (deferred to S5.5).

## File-level changes

| File | Action |
|---|---|
| `RoomRom/src/ow_room_render_roomrom.h` | + `_walkable_at` decl |
| `RoomRom/src/ow_room_render_roomrom.c` | + `s_walkable[16][11]`, + `ow_walkable_primary` classifier, populate during `fill_plane_a` |
| `RoomRom/src/main.c` | + `link_walkable_at(x, y)` helper, per-axis revert in both NES + ALTTP movement |

## Risks

| Risk | Mitigation |
|---|---|
| Walkable allowlist incomplete (e.g. some shore tile blocks when shouldn't) | Easy fix — add to `ow_walkable_primary` switch. Iterate via play. |
| Hotspot too high/low for visual feel | Tunable `+12` constant. NES uses Y+11 for collision check (`Z_07.asm:2156` `ADC #$0B`). |
| Edge-load + collision interaction at room boundary | `edge_load_or_clamp` runs after motion; collision runs during motion. If a wall sits at the edge, collision blocks before edge-load fires. Correct per NES. |
| Secondary squares classified by TL tile only (rough) | Secondary squares are rare in OW; mostly path/edge. Acceptable approximation; refine if a specific room misbehaves. |
