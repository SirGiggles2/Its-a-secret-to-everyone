# Drain Finding — Phase 4 Task 4.11 (native port) — uw_person leaves

**Per Rule D1 Gate 1.** Drain MATCH proof + native port for 4 trivial
leaf functions in uw_person_runtime. Establishes
`src/game/cave/uw_person_dispatch.{h,c}` scaffold + `NATIVE_UW_PERSON`
cutover gate. Underworld person update is shop NPCs / grumble / hint
stones — the cave/UW dialogue surface.

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/cave/uw_person_dispatch.{h,c}` | `uw_person_update_life_or_money_state_0`, `uw_person_check_person_blocking`, `uw_person_flag_item_taken_and_advance_state`, `uw_person_update_grumble1` |
| Drain | `src/oracle/cave/uw_person_runtime.c` (88-91, 110-122, 124-131) |
| NES asm | `reference/aldonunez/Z_01.asm` (UpdateLifeOrMoneyState_0, CheckPersonBlocking, PersonFlagItemTakenAndAdvanceState, UpdateGrumble1) |
| State accessors | `src/state/cave_state.h`, `src/state/object_state.h`, `src/state/link_state.h`, `src/state/item_state.h` | `CAVE_DELAY_TIMER`, `OBJ_STATE`, `OBJ_TILE_Y`, `LINK_MOVING_DIR`, `ITEM_SFX_PRIMARY` |
| Cross-deps | `core_cue_transfer_buf_and_advance_state` (native), `progress_set_room_flag_uw_item_state` (native) |

## Stance

**REWRITE-MIRROR (drain MATCH).** Pure leaves; no c_/z01_/z07_ shims.

`uw_person_check_person_blocking` inlines `LINK_MOVING_DIR = 0` (the
1-store body of NES ResetMovingDir) instead of calling
`core_reset_moving_dir` because the latter doesn't exist as a native
function yet (one-call wrapper of trivial RAM write).

`uw_person_update_grumble1` -> `uw_person_flag_item_taken_and_advance_state`
intra-subsystem call works since both are native.

## Cutover

`tools/gen_wrappers/z_01_manifest.json` entries dropped:
`z01_update_uw_person_life_or_money_state_0`,
`z01_check_person_blocking`,
`z01_person_flag_item_taken_and_advance_state`,
`z01_update_grumble1`.

`src/gen/z_01.c` now hand-writes the 4 wrappers under `#ifdef
NATIVE_UW_PERSON`. Default OFF preserves Title.md byte-identical.

`RoomRom/build.bat` extended: compile + link
`uw_person_dispatch.o`. RoomRom.md links the native dispatch
unconditionally.

## Verification

- `build_all.ps1` green: Title.md + RoomRom.md both link.
- ROM Title.md checksum unchanged (NATIVE_UW_PERSON default OFF).

## Phase 4 cutover gate count

17 cutover gates → **18** with `NATIVE_UW_PERSON`. Surface remains
4/14 fns; bigger uw_person fns (full updaters, init_*, draw_*) defer
until c_draw_object_* / c_animate_item_object / c_update_person_state_textbox
land native.
