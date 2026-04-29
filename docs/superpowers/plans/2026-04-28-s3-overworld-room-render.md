# S3 — Overworld Room Render + Navigation Implementation Plan

**Reference spec:** [docs/superpowers/specs/2026-04-27-native-genesis-rewrite-design.md](../specs/2026-04-27-native-genesis-rewrite-design.md), Section 7 stage S3.
**Reference S2 close:** [docs/audit/s2_close.md](../../audit/s2_close.md).
**Tag baseline:** `s2-closed` (commit `969535b7`).

**Goal:** Native overworld renderer + 4-direction room-to-room navigation. Start room ($77) renders pixel-identical to NES. All 128 rooms render via batch probe with zero normalized tile/palette/attribute mismatch. D-pad press at a room edge scrolls to the adjacent room with NES-style smooth scroll.

## Spec acceptance (Section 7 S3)

- Start-room renders pixel-identical (RGB parity) to NES.
- `tools/probes/batch_room_render.py` renders all 128 overworld rooms from extracted data; zero normalized tile/palette/attribute mismatches across the full set.
- Four-direction scroll between rooms via native scroll API; transition probe captures scroll register progression frame-by-frame and matches NES.

## Phase plan

### Phase A — Room data consumer (~3 days)

A1. **Add `src/game/room/room_runtime.c` overworld variant.** New file (or revive existing one and clean) that:
   - Reads from `data/rooms/overworld.c` arrays (already shipped at S2.C2).
   - Decodes the column-encoded layout into a 16-column × 11-row tile grid per room.
   - Plane A is 64 × 32 in our H32 mode; the playfield is 32 × 22 tiles centered with a 2-tile HUD bar at top.
   - Calls `render_plane_a_write_row` (or new `render_plane_write_room`) to lay down the room.

A2. **Per-room verification probe.** `tools/probes/probe_room_render.py` takes a room id, instructs the ROM to render that room (via a debug-only entry hook), captures via `bizhawk_capture_gen.lua` + `normalize_gen.py`. Diff against NES capture from `bizhawk_capture_nes.lua` + `normalize_nes.py`.

A3. **Acceptance:** start room ($77) diff_normalized = 0 mismatched cells across `bg_tile`, `bg_palette`, `bg_priority`. Document any divergence -- column-encoded decode bugs are the likely cause.

### Phase B — Batch all-128 probe (~2 days)

B1. **`tools/probes/batch_room_render.py`** drives the ROM through every overworld room via Lua-scripted memory pokes (set `CurRoom` byte then trigger render). Captures + diffs each.

B2. **Output:** report listing per-room PASS/FAIL, with per-failed-room mismatch detail (first 10 cells).

B3. **Acceptance:** 128/128 PASS. Failures are real bugs, not skipped.

### Phase C — Room navigation (~3 days)

C1. **Room adjacency table.** NES overworld is a 16 × 8 grid; each room id `R` maps to `(col, row)` via `R = row * 16 + col`. Adjacency:
   - Left:  R-1 (wrap edges off-grid -> stay)
   - Right: R+1
   - Up:    R-16
   - Down:  R+16
   But: NES has explicit "exit blocked" flags per direction in room metadata. The adjacency must respect those.

C2. **Input handling.** Hook `joy_state` (already adapter-mediated since S1.D3) at the room-runtime tick. On D-pad press at a room edge, look up adjacency, transition.

C3. **Hard-cut transition (v1).** Display off, render new room, display on. Same pattern as intro_handoff for instant scene change. Acceptable for first-pass; matches NES less precisely but tests the navigation logic in isolation.

C4. **Acceptance:** Press right at room $77, screen shows room $78. Press up, room $67. Etc. Edge cases: off-grid rooms stay, blocked edges stay.

### Phase D — Smooth scroll transition (~3 days)

D1. **NES-style scroll.** When transitioning to an adjacent room, the NES animates a horizontal/vertical scroll over ~16 frames such that the new room slides in from the screen edge. The OLD room scrolls off, NEW room scrolls on, both visible during transition.

D2. **Implementation:** Pre-load both rooms into Plane A's 64 × 32 buffer (one room left half, other right half for horizontal scroll; double height for vertical). Animate `render_vscroll_set` / `render_hscroll_set` per frame.

D3. **Adapter additions:**
   - `render_hscroll_set(value)` -- horizontal scroll; not yet in adapter (vertical via `render_vscroll_set` exists).
   - Possibly `render_plane_room_load(plane_base_offset, room_id, ...)` if the column decode wants a target offset within plane.

D4. **Acceptance:** transition probe captures scroll register progression every frame during a known room transition; diff against NES capture matches frame-for-frame.

### Phase E — S3 close (~1 day)

E1. Run all probes (start room, batch 128, smooth-scroll transition). All PASS.
E2. Update canonical scenario probe: add new "overworld_start_room" scenario; lock baseline.
E3. Lint graduates `src/game/` MMIO writes warn -> fail per spec table 8.1 (game subsystems migrate alongside S3).
E4. `docs/audit/s3_close.md` written. Tag `s3-closed`.

## Dependencies

- Spec Section 5 ("pixel-perfect to NES on canonical screens") -- needs amendment to exempt title + FS (per memory `project_title_screen_goal.md`). Gameplay scenes (S3 onward) still parity-gated.
- Render adapter API likely needs:
   - `render_hscroll_set` (D)
   - Bulk per-room tilemap load helper (A or D)
- Joy adapter (`joy_read` from S1.D3) already exists; just consumed in C.
- `data/rooms/overworld.c` + `data/chr/overworld_bg.c` already shipped at S2.

## Acceptance per spec Section 7

- [ ] Start room (NES $77) RGB-parity to NES (`probe_room_render.py`).
- [ ] All 128 rooms render with zero normalized mismatch (`batch_room_render.py`).
- [ ] 4-direction scroll between rooms; per-frame scroll register progression matches NES (transition probe).

## Total estimate

~12 days focused. Spec Section 7 says "~3-4 wks" for S3; this plan compresses by reusing S2's data + S1's adapter API.

## Execution mode

Subagent-driven-development for B and D (mechanical batch + scroll animation). Inline for A1 (architectural; needs review of room-encoding format) and E (close-out). Hash drift expected as gameplay code lands -- regen baselines per `feedback_cutover_baseline_regen.md` pattern.

## Open questions for S3 start

1. **Where does the ROM enter overworld mode?** Currently after FS handoff there's no overworld; fs_main never returns. S3 either needs a new "fake" entry path (debug hook that boots straight into overworld) OR fs_main must learn to hand off to overworld on save-slot select. The latter is closer to game flow but bigger. Recommend debug hook for S3 acceptance, real handoff at S8a.

2. **Room metadata encoding.** S2 extracted column-encoded layout + attribute bytes. Verify that the decode logic to convert that into `bg_tile[col, row]` is documented somewhere (probably in `reference/aldonunez/` disasm). Replicate faithfully.

3. **Smooth scroll vs hard cut.** Plan calls for smooth scroll at D. If user wants hard-cut nav as MVP and defer smooth scroll, C ships first and D is optional polish.
