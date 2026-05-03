# Drain Finding — Phase 3 cave_init RAM-coherency fix

**Per Rule D1 Gate 1.** Bug fix on the existing native `cave_init` from
debate 006 D2 (commit `e07ec0ec`).

## Bug

The D2 native `cave_init` populated a file-static `CaveState g_cave_state`
typed struct but did NOT write to NES RAM. Drain consumers (cavert_*
functions in src/oracle/cave/cave_runtime.c) read state via the legacy
`CAVE_*` macros which expand to `RAM($XXX)`. With the typed struct
populated but RAM untouched, defining `NATIVE_CAVE` in Title.md would
have been silently broken — drain code chained from cavert_update_cave_person
would have read stale RAM bytes instead of the freshly-initialized
cave_id.

This violated the state_contract.md "two views coexist" guarantee:
both views must be coherent, otherwise their producers diverge.

## Fix

Drop the local `g_cave_state` instance. Rewrite `cave_init` and
`cave_exit` to write through the RAM-backed bridge accessors
(`cave_room_type_set`, `cave_flags_set`) and the legacy macros
(`CAVE_PERSON_STATE`, `CAVE_TEXT_SELECTOR`, etc.) which are inline-defined
in `src/state/cave_state.h` to expand to `RAM($XXX)`.

Now drain reads via macro and native reads via accessor see the same
byte. NATIVE_CAVE Title.md cutover is now meaningfully equivalent to
the oracle path for the state-init step.

## Per-cell coherency table

| Symbol (drain) | NES RAM | Native write |
|----------------|---------|--------------|
| `CAVE_ROOM_TYPE` | `$0350` | `cave_room_type_set(cave_id)` |
| `CAVE_PERSON_STATE` | `$00AD` | `CAVE_PERSON_STATE = 0u` |
| `CAVE_FLAGS` | `$0413` | `cave_flags_set(0u)` |
| `CAVE_TEXT_SELECTOR` | `$0415` | `CAVE_TEXT_SELECTOR = 0u` |
| `CAVE_TEXT_CHAR_INDEX` | `$0416` | `CAVE_TEXT_CHAR_INDEX = 0u` |
| `CAVE_DELAY_TIMER` | `$0029` | `CAVE_DELAY_TIMER = 0u` |
| `CAVE_LINK_ACTION_TIMER` | `$00AC` | `CAVE_LINK_ACTION_TIMER = 0u` |
| `CAVE_LINK_INPUT_FLAGS` | `$00F8` | `CAVE_LINK_INPUT_FLAGS = 0u` |

`g_active_cave` retained as the "is a cave currently active?" sentinel
exposed via `cave_current_id()`. Native code shouldn't shadow RAM with
its own struct — the RAM-backed view IS the typed state during
promotion (Phase 3-12). When the typed struct fully replaces RAM
(post-Phase 12), this can revisit.

## Cutover gate

No new gate. Existing `NATIVE_CAVE` (from `9fe0ea42`) now actually
works.

## RoomRom probe

`RoomRom/probe_scene_cave_toggle.lua` exercises SCENE_CAVE wiring
introduced in this commit. Capture sequence:

  01_boot_uw      — RoomRom default scene = UW L1 start room.
  02_ow           — START toggles to overworld.
  03_in_cave      — C+START chord enters SCENE_CAVE. cave_tick stub
                    runs each frame. Visual stays on previous OW frame
                    (no native cave render until Phase 4 object_draw).
  04_post_exit    — C+START exits back to SCENE_OW. Render resumes.

EmuHawk did not crash through ~250 frames. SCENE_CAVE branch reachable
without hang.

## Provenance

- 2026-05-03. Author: Claude Opus.
- Bug introduced in `e07ec0ec` (debate 006 D2). Fixed before NATIVE_CAVE
  is ever expected to be enabled in Title.md.
