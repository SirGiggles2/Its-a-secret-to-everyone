# RoomRom S4 — Edge-Triggered Room Transitions

**Date:** 2026-04-30
**Status:** Implemented (autonomous per "JUST GO" directive)
**Predecessor:** 2026-04-30-roomrom-s3-walk-animation-design.md (S3 closed at tag `roomrom-s3-closed`)
**Successors (planned):** S5 BG collision; later: door-aware UW transitions using `RoomRom/data/uw_level*_*.json` edge data.

## Goal

Walking Link off a room edge transitions to the adjacent room and places Link at the opposite edge. Both OW and UW use the same 16x8 grid (`room_id = (row<<4)|col`) so a single mechanism covers both scenes. No door-or-wall lookups in S4 — every edge is open. Collision (S5) will block walking through walls naturally; doors come later.

## Non-goals

- BG collision (S5)
- Door / locked-door logic in UW (later, using `data/uw_level*_*.json` edges)
- Stair / cellar transitions
- Transition fade / scroll animation (instant snap, like NES Zelda's overworld-to-cellar but without the cave fade)
- Wrapping at world edges (col=15+RIGHT clamps; doesn't wrap to col=0)

## Architecture

Single helper `edge_load_or_clamp()` in `RoomRom/src/main.c`. Called per frame after both NES and ALTTP movement update Link's `s_link_x` / `s_link_y`. Replaces the previous separate clamp blocks.

Decision flow:

1. Read `col = s_room_id & 0x0F`, `row = s_room_id >> 4`.
2. If `s_link_x < 0` and `col > 0` → decrement col, set `s_link_x = 232`, mark transitioned.
   - Else if `col == 0` → clamp `s_link_x = 0`.
3. Symmetric for right edge (`s_link_x > 240`).
4. Symmetric for top (`s_link_y < 56`, HUD-aware) and bottom (`s_link_y > 208`).
5. If transitioned: `s_room_id = (row<<4)|col`, `load_room(s_room_id)`, reset `s_link_pos_frac / subx / suby / grid_offset / anim_tick` so motion starts clean. **Keep** `s_link_dir` and `s_link_face` so motion feels continuous.

Entry coordinates were chosen so Link's center is just inside the playfield after transition:
- LEFT entry → `x = 232` (right side of new room minus sprite width)
- RIGHT entry → `x = 8`
- UP entry → `y = 200`
- DOWN entry → `y = 64` (HUD bottom + 8)

## Why this is "best practices long-term"

- **Single mechanism for both scenes.** OW and UW share the same room-id grid (verified: `data/uw_level*_*_rooms.json` lists rooms as `0xXY` matching `(row<<4)|col`). One code path, two payoffs.
- **Reuses existing `load_room` infrastructure.** No new render plumbing.
- **Style-agnostic.** NES (single-axis) and ALTTP (8-direction) both call the same helper after their position update.
- **Forward-compatible with door logic.** When S5+ adds the door/wall lookup, only `edge_load_or_clamp` changes — its caller stays the same.
- **No dependence on per-room neighbor tables.** Room id is the only state needed; transitions are computable.

## Verification

S4 done when:

1. Build clean.
2. Boot: Link in OW R0x77.
3. Walk Right past x=240: Link snaps into adjacent room (R0x78), x=8.
4. Walk Up past y=56: Link in R0x67, y=200.
5. Hit world boundaries (col=0+LEFT, col=15+RIGHT, row=0+UP, row=7+DOWN): clamp, no transition.
6. B-toggle to UW: same behavior across UW dungeon rooms.
7. ALTTP mode (Y): diagonal walk crosses two edges sequentially, transitioning twice in a few frames if needed.
8. TELEPORT mode (X): unchanged, still works.

## File-level changes

| File | Action |
|---|---|
| `RoomRom/src/main.c` | + `edge_load_or_clamp` helper, replace both per-style clamp blocks with calls |

## Risks

| Risk | Mitigation |
|---|---|
| Adjacent UW room may not exist in current dungeon level (room_id outside the level's rooms list) | The renderer falls back to a blank/default fill for unknown room ids — same as existing TELEPORT behavior into out-of-dungeon rooms. Not a regression. |
| ALTTP diagonal step crossing two edges in one frame | First-axis transition fires; second axis re-evaluated next frame. Acceptable; user may notice 1-frame "L-shape" routing. |
| Anim tick reset on every transition causes a visible "blink" | Acceptable in S4. S5+ may smooth via a transition state machine. |
