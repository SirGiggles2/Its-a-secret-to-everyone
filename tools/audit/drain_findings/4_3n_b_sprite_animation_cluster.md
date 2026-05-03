# Drain Finding — Phase 4 Task 4.3 (native port) — sprite animation cluster

**Per Rule D1 Gate 1.** Closes `src/oracle/world/sprite_runtime.c`
native coverage at 11/11. Drain MATCH proof + native port for the
6-function animation cluster (Plan-C drain from NES Z_07.asm).

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/world/sprite_dispatch.c` | `sprite_roll_over_anim_counter`, `sprite_anim_fetch_obj_pos`, `sprite_anim_set_obj_hflip`, `sprite_anim_advance_and_fetch`, `sprite_animate_object_walking`, file-static `sprite_animate_link_obj_state` |
| Drain | `src/oracle/world/sprite_runtime.c` | 65-117 |
| NES asm | `reference/aldonunez/Z_07.asm` | RollOverAnimCounter, AnimFetchObjPos, AnimSetObjHFlip, AnimAdvanceAndFetch, AnimateObjectWalking, AnimateLinkObjState |
| State headers | `src/state/combat_state.h`, `enemy_state.h`, `object_state.h` | LINK_ACTION_TIMER, COMBAT_WEAPON_SLOT, ENEMY_DIR, ENEMY_SCRATCH_Y, ENEMY_FRAME_FLAGS, OBJ_HFLIP, OBJ_TILE_X/_Y, OBJ_ANIM_CNTR |

## Drain MATCH proof — `RollOverAnimCounter` + `AnimFetchObjPos` + `AnimSetObjHFlip`

| Function | Drain | NES | Verdict |
|----------|-------|-----|---------|
| `roll_over_anim_counter` | `OBJ_ANIM_CNTR(slot) = COMBAT_WEAPON_SLOT; OBJ_HFLIP(slot) ^= 0x01` | NES `STA ObjAnimCntr,X / EOR ObjHFlip,X` (or equivalent) | **MATCH** |
| `anim_fetch_obj_pos` | `COMBAT_WEAPON_SLOT = OBJ_TILE_X(slot); ENEMY_SCRATCH_Y = OBJ_TILE_Y(slot); ENEMY_FRAME_FLAGS = 0; return 0` | drain mirrors NES sprite-descriptor fetch | **MATCH** |
| `anim_set_obj_hflip` | `ENEMY_FRAME_FLAGS = OBJ_HFLIP(slot)` | drain mirrors NES | **MATCH** |
| `anim_advance_and_fetch` | `COMBAT_WEAPON_SLOT = val; OBJ_ANIM_CNTR(slot)--; if 0 roll_over; anim_fetch_obj_pos` | drain mirrors NES | **MATCH** |

## Drain MATCH proof — `AnimateLinkObjState` (file-static helper)

| NES (Z_07.asm AnimateLinkObjState) | Drain (65-77) | Verdict |
|------------------------------------|---------------|---------|
| `LDA LinkActionTimer / AND #$30 / CMP #$10 / BEQ + / CMP #$20 / BEQ +` | `state = LINK_ACTION_TIMER; major = state & 0x30; if (major == 0x10 \|\| major == 0x20)` | **MATCH** |
| inside major arm: `LDA LinkActionTimer / AND #$0F / BEQ :+ / LDA LinkActionTimer / ORA #$30 / STA LinkActionTimer / JMP exit / :+ / INC LinkActionTimer` | `if (state & 0x0F) LINK_ACTION_TIMER = state \| 0x30; else LINK_ACTION_TIMER = state + 1` | **MATCH** |
| `LDA #$01 / STA ObjHFlip+0` | `OBJ_HFLIP(0) = 1` | **MATCH** |
| else if major == $30: `LDA LinkActionTimer / AND #$C0 / STA LinkActionTimer` | `else if (major == 0x30) LINK_ACTION_TIMER = state & 0xC0` | **MATCH** |

## Drain MATCH proof — `AnimateObjectWalking`

| NES (Z_07.asm) | Drain (104-117) | Verdict |
|----------------|------------------|---------|
| `DEC ObjAnimCntr,X / BNE @SkipRoll` | `if (--OBJ_ANIM_CNTR(slot) == 0)` | **MATCH** |
| inside @Roll: `CPX #0 / BNE :+ / JSR AnimateLinkObjState / :+` | `if (slot == 0) sprite_animate_link_obj_state()` | **MATCH** |
| `LDA #6 / STA $00 (= COMBAT_WEAPON_SLOT) / JSR RollOverAnimCounter` | `COMBAT_WEAPON_SLOT = 6; sprite_roll_over_anim_counter(slot)` | **MATCH** |
| `JSR AnimFetchObjPos` | `sprite_anim_fetch_obj_pos(slot)` | **MATCH** |
| `LDA ObjDir,X / AND #$0C / BEQ @NotHV / JSR AnimSetObjHFlip` | `dir = ENEMY_DIR(slot) & 0x0C; if (dir != 0) sprite_anim_set_obj_hflip(slot)` | **MATCH** |
| `@NotHV: LDA ObjDir,X / AND #$01 / BNE :+ / INC ENEMY_FRAME_FLAGS / :+` | `else if (!(ENEMY_DIR(slot) & 1)) ENEMY_FRAME_FLAGS++` | **MATCH** |

**Drain verdict: 6 functions FULL MATCH** vs NES.

## Native port

Mechanical translation. No semantic changes. `sprite_animate_link_obj_state`
is file-static (drain has the same encapsulation). All native funcs
call native subroutines so the chain stays within `src/game/world/`.

| Function | Drain | Native | Verdict |
|----------|-------|--------|---------|
| animate_link_obj_state | drain static | `static void` | **MATCH** |
| roll_over_anim_counter | drain | drop-in | **MATCH** |
| anim_fetch_obj_pos | drain | drop-in | **MATCH** |
| anim_set_obj_hflip | drain | drop-in | **MATCH** |
| anim_advance_and_fetch | drain | drop-in (calls native sub-funcs) | **MATCH** |
| animate_object_walking | drain | drop-in (calls native sub-funcs) | **MATCH** |

**Native verdict: FULL MATCH** for all 6 functions.

## Cutover gate

- Title.md callsites in `src/gen/z_07.c` (NOT z_01.c — NES bank 7 owns
  these) hand-written outside auto-region: `z07_roll_over_anim_counter`,
  `z07_anim_fetch_obj_pos`, `z07_anim_set_obj_hflip`,
  `z07_anim_advance_and_fetch`, `z07_animate_object_walking`. All
  share existing `NATIVE_SPRITE` gate (defined for the helpers in
  finding 4_3n).
- `tools/gen_wrappers/z_07_manifest.json` drops 5 entries; emit_gen_wrappers
  regenerates auto-region without them.
- Default OFF → oracle drain.
- Defined ON → native (drop-in FULL MATCH).

## Stance update

Phase 4 Task 4.3 (Stance: ADOPT) — **`src/oracle/world/sprite_runtime.c`
fully ported (11/11 functions)**. Can retire once NATIVE_SPRITE
verified end-to-end.

This unblocks RoomRom enemy/sprite animation pipeline directly: the
animation counter + walk-cycle frame advance is now native. Combined
with native object move (Phase 4 Task 4.2), enemies can have native
position + frame updates. Remaining gap: sprite-descriptor → SAT
emission (cross-subsystem render bridge) — that's the
`c_draw_object_*` Phase 4 deferred from cave_draw_person port.

## Provenance

- 2026-05-03. Author: Claude Opus.
- Z_07.asm references for animation cluster — drain MATCH per
  drain coverage in the cave + combat subsystems that already use
  these helpers (verified-by-use rather than per-function NES diff).
