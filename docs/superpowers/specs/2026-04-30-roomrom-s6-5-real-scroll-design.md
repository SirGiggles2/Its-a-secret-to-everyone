# RoomRom S6.5 — Real BG Scroll Transition

**Date:** 2026-04-30
**Status:** Implemented (autonomous)
**Predecessor:** 2026-04-30-roomrom-s6-transition-design.md (S6 v1 was blank-flash)
**Successors (planned):** S6.6 vertical scroll (HUD-aware, requires per-row VSCROLL split or HUD on BG_B).

## Goal

Replace S6 v1's screen-blank between rooms with a real horizontal BG scroll for left/right transitions. New room slides in from the appropriate edge while the old room slides off. ~64 frames (~1 sec). Vertical transitions stay on blank-flash for v1; that's a separate slice.

## Architecture

**Plane upgrade.** BG_A bumped from 32x32 to 64x32. The two halves of the plane (cols 0..31 and cols 32..63) host two rooms. `s_active_half` (0 or 1) tracks which half currently shows the active room.

**Per-column rendering.** Both renderers gain `_fill_one_col(room_id, src_col, dst_col)` that renders one source metatile column from a room into any destination plane metatile column (0..31, both halves). OW palette logic uses src coords (so attribute lookup matches the source room) but writes to dst coords. `fill_plane_a` becomes a wrapper around 16 calls.

**HSCROLL split.** `VDP_setScrollingMode(HSCROLL_TILE, ...)` enables per-tile-row HSCROLL. HUD rows (0..6) always get scroll = 0 so the HUD stays anchored. Playfield rows (7..27) get the animated scroll value. Helper: `set_split_hscroll(play_scroll)`.

**Scroll FSM (`s_scroll_state`).**

| State | Trigger | Behavior |
|---|---|---|
| `SCROLL_NONE` | normal play | nothing |
| `SCROLL_H_RIGHT` | Link crossed right edge | render new room into inactive half, animate HSCROLL toward it over 64 frames, swap active half on completion |
| `SCROLL_H_LEFT` | Link crossed left edge | symmetric |
| `SCROLL_BLANK_FLASH` | Link crossed top/bottom | 16-frame screen-blank fallback |

During scroll: input swallowed, Link sprite held at staged target coords, HSCROLL animates 4 px/frame.

**At scroll completion (frame 64):** active_half toggles, room state commits, palette/HUD/walkable reload, HSCROLL anchored on new active half.

## Why this is best practices long-term

- **Renderer doesn't need a scroll-mode branch.** Both `fill_plane_a` (full room) and `fill_one_col` (single column) emit the same plane writes; scroll just composes them differently.
- **Plane wrap not needed.** Two distinct halves keep old and new rooms cleanly separated. Easier to reason about than wrap-trick rewriting.
- **HUD stays put** via per-row HSCROLL, no copy or BG_B kludge.
- **State machine boundary clean.** Scroll all lives in one block at the top of the main loop; movement code below is unchanged.
- **Forward-compatible with vertical scroll.** Adding `SCROLL_V_*` states is straightforward once per-row VSCROLL or BG_B HUD is in place.

## Verification

S6.5 done when:

1. Build clean.
2. Walk Link off right edge: 64-frame smooth scroll, new room slides in, HUD stays anchored, Link visible at opposite edge after scroll.
3. Same for left edge.
4. Vertical (top/bottom): blank-flash, room swap, blank ends. (v1 fallback.)
5. Multiple H transitions in a row work — second transition's "new" half is the previous transition's "old" half.
6. World boundary clamps prevent transition (col=0+LEFT, col=15+RIGHT).
7. UW: same scroll mechanism (uses `_fill_one_col` against blob).

## File-level changes

| File | Action |
|---|---|
| `RoomRom/src/ow_room_render_roomrom.[ch]` | + `_fill_one_col` API; `write_tile`/`write_square` gain src-vs-dst tile coord separation |
| `RoomRom/src/uw_room_render_roomrom.[ch]` | + `_fill_one_col` (blits one metacol from blob) |
| `RoomRom/src/main.c` | plane bumped to 64x32; HSCROLL_TILE mode; `set_split_hscroll`; `render_room_into_half`; `s_scroll_state` FSM in main loop top; `edge_load_or_clamp` stages scroll |

## Risks

| Risk | Mitigation |
|---|---|
| 64x32 plane affects SGDK SAT/HSCROLL VRAM layout | SGDK auto-relocates (`VDP_setPlaneSize(..., TRUE)`). Verified by clean build + visible HUD post-scroll. |
| Vertical scroll not implemented | Documented as v1 limit; falls back to blank-flash. S6.6 adds it. |
| HSCROLL_TILE writes 28 shorts per frame | Cheap (~56 bytes) on a Genesis frame. |
| Multiple consecutive scrolls | FSM gates re-entry: `edge_load_or_clamp` returns early if `s_scroll_state != NONE`. |
| Link sprite snaps mid-scroll | Held at staged target during scroll. v2 could slide him with the BG. |
