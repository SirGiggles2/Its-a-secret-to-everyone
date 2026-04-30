# RoomRom S6 — Room Transition Animation (v1: blank-flash)

**Date:** 2026-04-30
**Status:** Implemented (v1, autonomous)
**Predecessor:** 2026-04-30-roomrom-s5-collision-design.md (S5 closed at tag `roomrom-s5-closed`)
**Successors (planned):** S6.5 — true scrolling transition (NES-style 64-frame slide with side-by-side render).

## Goal

Replace S4's instant room swap with a brief screen-blank transition so the room change reads as deliberate. v1 ships the smallest visible improvement; v2 (S6.5) does the real BG scroll.

## Non-goals (v1)

- True BG scroll (deferred to S6.5)
- Link sliding across the seam during scroll
- Variable-length transitions per direction
- UW-specific transitions (entering caves had different fade in NES)

## Architecture

State machine in main.c:

```c
static u8    s_transition_timer  = 0;   /* 0 = no transition; counts down to 0 */
static u8    s_transition_target = 0;   /* staged room_id */
static short s_transition_link_x = 0;
static short s_transition_link_y = 0;
```

Triggered from `edge_load_or_clamp()`. Instead of immediately calling `load_room`, the helper:
1. Stages target room + Link spawn coords.
2. Sets `s_transition_timer = TRANSITION_TOTAL_FRAMES (= 16)`.
3. Calls `VDP_setEnable(FALSE)` to blank the display immediately.
4. Resets sub-pixel/grid/anim state so motion starts clean post-swap.

Main loop top runs the timer:
- Each frame, decrement.
- At midpoint (`timer == 8`): swap `s_room_id`, place Link at staged coords, call `load_room` (re-renders BG + reloads palettes including PAL3).
- At end (`timer == 1`): `VDP_setEnable(TRUE)` to restore display.
- During transition: input swallowed (`joy_prev = 0`) so a held D-pad doesn't immediately re-trigger another transition.

Total visible blank: 16 frames (~0.27 sec at 60 Hz).

## Why this is best practices long-term

- **State-machine boundary.** All transition complexity is one block at the top of the main loop. v2 (real scroll) replaces just that block.
- **Renderer untouched.** `load_room` works identically; the transition is pure state + display-enable toggling.
- **Idempotent against multiple-axis transitions.** ALTTP diagonal that crosses two edges only triggers one transition (timer guards re-entry).
- **No CRAM thrash.** Display blank uses VDP register, not palette writes — no race with palette reload at midpoint.

## Verification

1. Build clean.
2. Walk Link off any room edge in OW: screen blanks for ~0.27 sec, new room appears, Link at correct opposite-edge entry coord.
3. Hold D-pad across the transition: input is swallowed; Link doesn't double-transition.
4. UW edge cross: same behavior.
5. TELEPORT mode (X) doesn't trigger transition (load_room called directly, no edge crossing involved).
6. Toggle WALK/TELEPORT/Y/style during a room: no spurious transitions.

## File-level changes

| File | Action |
|---|---|
| `RoomRom/src/main.c` | + `s_transition_*` state, transition state-machine block at loop top, `edge_load_or_clamp` defers room swap |

## Risks

| Risk | Mitigation |
|---|---|
| 16-frame blank feels too long | Tune `TRANSITION_TOTAL_FRAMES`; 16 is conservative. |
| Mid-transition the user toggles X/Y/B — confusing | Toggles run from `pressed` mask which is gated by `s_transition_timer == 0` (whole input handler skipped). |
| `VDP_setEnable(FALSE)` blanks HUD too | Acceptable for a flash transition; HUD restores at frame 1 along with BG. |
| Real BG scroll (S6.5) needs renderer offset support | Out of scope here. v1 keeps renderer untouched. |
