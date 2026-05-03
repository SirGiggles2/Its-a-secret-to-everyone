# Drain Finding — Phase 4 Task 4.4 (native port) — progress room-flag pair

**Per Rule D1 Gate 1.** Drain MATCH proof + native port for the
room-flag persistence pair. **Unblocks Phase 3 cave Phase 4 stubs**:
`progrt_set_room_flag_uw_item_state` was the deferred call in
`cave_update_talk_shop_or_door_charge` and
`cave_update_hint_or_money_game` (state 7B branch). With the native
version landed and gated, those stubs can promote to real calls.

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/world/progress_dispatch.{h,c}` | `progress_set_room_flag_uw_item_state`, `progress_get_room_flag_uw_item_state`, file-static `progress_read_room_flags_inline` |
| Drain | `src/oracle/world/progress_runtime.c` | 32-48 |
| Drain helper | `src/oracle/room/room_runtime.c` | 14-22 (`roomrt_get_room_flags`) |
| NES asm | `reference/aldonunez/Z_07.asm` | GetRoomFlags + SetRoomFlagUWItemState + GetRoomFlagUWItemState |
| NES vars | `reference/aldonunez/Variables.inc` + `CaveVars.inc` | `RoomId := $00EB` (= CUR_ROOM_ID), SRAM ROOM_FLAGS_PTR_LO/HI at $6BAF/$6BB0 |
| State accessors | `src/state/save_state.h`, `progress_state.h`, `world_state.h`, `platform_abi.h` | various |

## Drain MATCH proof — `progrt_set_room_flag_uw_item_state`

| NES (Z_07.asm SetRoomFlagUWItemState) | Drain (32-38) | Verdict |
|---------------------------------------|---------------|---------|
| `JSR GetRoomFlags` (returns A = current flag byte; sets ZP $00/$01 = ptr) | `flags = z07_get_room_flags()` (calls roomrt_get_room_flags which sets SAVEFILE_PTR_LO/HI) | **MATCH** |
| `ORA #$10` | `flags \|= 0x10` | **MATCH** |
| `LDY CUR_ROOM_ID / STA (ZP),Y` | `ptr = (SAVEFILE_PTR_HI << 8) \| SAVEFILE_PTR_LO; nes_ram[ptr + CUR_ROOM_ID] = flags` | **MATCH** |

## Drain MATCH proof — `progrt_get_room_flag_uw_item_state`

| NES (Z_07.asm GetRoomFlagUWItemState) | Drain (40-48) | Verdict |
|---------------------------------------|---------------|---------|
| `LDA SAVE_ROOM_FLAGS_PTR_LO / STA SAVEFILE_MASK_LO` | `ptr_lo = SAVE_ROOM_FLAGS_PTR_LO; SAVEFILE_MASK_LO = ptr_lo` | **MATCH** |
| `LDA SAVE_ROOM_FLAGS_PTR_HI / STA SAVEFILE_MASK_HI` | `ptr_hi = SAVE_ROOM_FLAGS_PTR_HI; SAVEFILE_MASK_HI = ptr_hi` | **MATCH** |
| `LDY CUR_ROOM_ID / LDA (ZP),Y / AND #$10` | `ptr = (ptr_hi << 8) \| ptr_lo; return nes_ram[ptr + CUR_ROOM_ID] & 0x10` | **MATCH** |

**Drain verdict: 2 functions FULL MATCH** vs NES (with `roomrt_get_room_flags` also FULL MATCH for the helper read; inlined into native to avoid src/oracle/ shim).

## Native port

| Function | Drain | Native | Verdict |
|----------|-------|--------|---------|
| read_room_flags helper | `z07_get_room_flags()` shim → `roomrt_get_room_flags` | `static inline` reads SRAM ptr + derefs (drain pattern inlined) | **MATCH** |
| set_room_flag_uw_item_state | drain | drop-in (uses inline helper) | **MATCH** |
| get_room_flag_uw_item_state | drain | drop-in | **MATCH** |

**Native verdict: FULL MATCH** for both. No deferred TODOs.

Side-effect preservation: drain stashes the SRAM pointer into
SAVEFILE_PTR_LO/HI (set path) and SAVEFILE_MASK_LO/HI (get path);
native preserves both side effects.

## Cutover gate

- New gate: `NATIVE_PROGRESS` (independent from `NATIVE_SPRITE`,
  `NATIVE_OBJECT`, `NATIVE_WORLD`).
- 2 hand-written z01_* wrappers in src/gen/z_01.c.
- Default OFF → oracle drain.
- Defined ON → native (drop-in FULL MATCH).
- RoomRom links progress_dispatch.o unconditionally beside the
  prior phase 4 .o files.

## Phase 3 cave deferral status

With this commit, `progress_set_room_flag_uw_item_state` is available
to native callers. Phase 3 cave native ports
(`cave_update_talk_shop_or_door_charge`,
`cave_update_hint_or_money_game`) had `TODO Phase 4: native
progrt_set_room_flag_uw_item_state();` stubs at the corresponding
NES sites. Those can now be replaced with `progress_set_room_flag_uw_item_state()`
calls, unblocking the cave gate cutover for those branches. **Follow-
up commit will fill the stubs and re-file the cave findings as
fewer-deferral-MATCH.**

## Stance update

Phase 4 Task 4.4 (Stance: ADOPT) — first progress batch. 2/12
functions of `src/oracle/world/progress_runtime.c` ported. Remaining:
palette-row replacers, reset_room_tile_obj_info, update_bomb_flash_effect,
update_position_marker (+ player variant), update_world_curtain_effect
(+ bank2 variant), fetch_file_a_address_set, check_tile_objects_blocking,
check_power_triforce_fanfare. Most are larger and depend on additional
state surfaces (CUR_LEVEL, MAP_MARKER_*, CUR_INV_TILE, FRAME_COUNTER,
HUD_DIRTY_FLAG). Next batch: simple palette-row + reset_room_tile_obj_info.

## Provenance

- 2026-05-03. Author: Claude Opus.
- Variables.inc + CaveVars.inc cited.
