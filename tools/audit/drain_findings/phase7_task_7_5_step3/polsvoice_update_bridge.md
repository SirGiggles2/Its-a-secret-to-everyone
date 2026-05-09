# Phase 7 Task 7.5 step 3 — PolsVoice UPDATE bridge ($16)

## Task header (Drain Rule D1)

- **NES source**: `Z_07.asm:5295 UpdateObject_JumpTable` row $16 ->
                  `UpdatePolsVoice` @ `Z_04.asm:6533-6747`
                  (~215 lines: walking + jumping states +
                  `UpdatePolsVoiceState1_Jumping` + walkability probe).

- **Drained C**:  No top-level `enrt_update_pols_voice` exists in
                  `src/oracle/enemies/`. Helpers ARE drained:
                  - `enrt_pols_voice_move_x` @
                    `enemy_boss_runtime.c:395` (NES `Z_04.asm:6809`).
                  - `enrt_pols_voice_get_colliding_tile` @
                    `enemy_boss_runtime.c:494`
                    (NES `Z_04.asm:6792` `PolsVoice_GetCollidingTile`).
                  - `enrt_pols_voice_is_square_walkable` @
                    `enemy_boss_runtime.c:514`
                    (NES `Z_04.asm:6753` `PolsVoice_IsSquareWalkable`).
                  - `z07_anim_advance_and_fetch` (already drained).
                  - `c_check_monster_collisions` @
                    `enemy_walker_bridge.c:166`.
                  - `draw_object_mirrored_with_frame` @
                    `world/draw_dispatch.c:421` (already drained).

- **Coverage**:   FULL for $16 PolsVoice UPDATE — all NES code paths
                  covered (stun/clock fast-path, odd-frame fast-path,
                  state-0 walking with grid-offset decrement +
                  per-direction Y-speed + walkability probe + tile
                  block ($B0 / $F4..$FF) state-1 transition + dir
                  flip, state-1 jumping with $38 fractional accel +
                  carry into whole + target-Y reach detect + random
                  redirect + grid snap, edge guards (Y<$78 forces
                  down, Y>=$A8 forces up), draw + sword-only mask
                  $FE + collisions tail).

- **Stance**:     EXTEND. Top-level UPDATE body is not directly drained;
                  native bridge body in `enemy_special_bridge.c` carries
                  per-line NES translation of `Z_04.asm:6533`. Same
                  model as step 2 (LikeLike) and `enemy_boss_bridge.c`
                  (Aquamentus / Vire). All composed primitives already
                  linked into Debug.md. Symbol `PolsVoiceWalkSpeedsX`
                  promoted to extern-linkage in this TU so the
                  drained `enrt_pols_voice_move_x` resolves at link
                  (`enemy_runtime_private.h:44` already declares it
                  extern).

## Native bridge body added (`enemy_special_bridge.c`)

| Function                         | NES source         | Lines (asm) |
|----------------------------------|--------------------|-------------|
| `enrt_update_pols_voice`         | `Z_04.asm:6533`    | ~215        |

### NES RAM cell aliases (file-local, added in step 2 prep)

| NES name                  | NES addr | C macro                       |
|---------------------------|----------|-------------------------------|
| `ObjRemDistance`          | `$0394`  | `POLS_OBJ_REM_DISTANCE`       |
| `ObjState`                | `$00AC`  | `POLS_OBJ_STATE`              |
| `ObjStunTimer`            | `$003D`  | `POLS_STUN_TIMER`             |
| `PolsVoice_ObjSpeedWhole` | `$0412`  | `POLS_OBJ_SPEED_WHOLE`        |
| `PolsVoice_ObjLastTile`   | `$041F`  | `POLS_OBJ_LAST_TILE`          |
| `PolsVoice_ObjTargetY`    | `$042C`  | `POLS_OBJ_TARGET_Y`           |
| `PolsVoice_ObjSpeedFrac`  | `$0444`  | `POLS_OBJ_SPEED_FRAC`         |
| `InvClock`                | `$066C`  | `POLS_INV_CLOCK`              |
| `ObjInvincibilityMask`    | `$04B2`  | `POLS_INVINCIBILITY_MASK`     |
| `FrameCounter`            | `$0015`  | `POLS_FRAME_COUNTER`          |
| `Random`                  | `$0019`  | `POLS_RANDOM`                 |

`PolsVoice_ObjLastTile` ($041F) aliases `ENEMY_AIR_SPEED`;
`PolsVoice_ObjTargetY` ($042C) aliases `ObjCaptureTimer` (used by
LikeLike). Naming follows the pols-voice context for self-documentation;
underlying behavior is identical because the addresses match.

### Verbatim NES tables (from `Z_04.asm:6516-6531`)

| Table (NES name)                | Size | Notes                             |
|---------------------------------|------|-----------------------------------|
| `PolsVoiceWalkSpeedsX`          | 10   | Externally-linked — drain hits it |
| `k_pols_voice_walk_speeds_y`    | 10   | File-local; bridge-only           |
| `k_pols_voice_initial_jump_speeds` | 8 | File-local; bridge-only           |
| `k_pols_voice_destination_y_offsets` | 8 | File-local; bridge-only         |
| `k_pols_voice_directions`       | 4    | File-local; bridge-only           |

### Forwarders added (`enemy_projectile_bridge.c`, step 3 prep)

| Forwarder                          | Native body                                   |
|------------------------------------|-----------------------------------------------|
| `z07_get_collidable_tile`          | `collision_get_collidable_tile`               |
| `z07_get_collidable_tile_still`    | `collision_get_collidable_tile_still`         |

These are pulled in by `enrt_pols_voice_get_colliding_tile` (drain at
`enemy_boss_runtime.c:494`) and `enrt_wizzrobe_get_base_collidable_tile`
(:504) once `--gc-sections` retains them via the new $16 UPDATE wire.

## State machine summary

`enrt_update_pols_voice(slot)`:

Pre-pass (always — both states):
1. `POLS_INV_CLOCK != 0 || POLS_STUN_TIMER != 0` -> `draw_and_check`.
2. Odd `POLS_FRAME_COUNTER` (`& 1`) -> `draw_and_check`.
3. `enrt_pols_voice_move_x(slot)` (always).
4. Compute `dir_idx = ENEMY_DIR(slot) - 1` (mirrors NES `Y` register
   left in PolsVoice_MoveX).

Path A — `POLS_OBJ_STATE != 0` (jumping):
1. `POLS_OBJ_SPEED_FRAC += $38`, capture carry.
2. `POLS_OBJ_SPEED_WHOLE += carry`. Set `whole`.
3. `ENEMY_Y(slot) += whole`.
4. If `whole < $80` AND `ENEMY_Y(slot) >= POLS_OBJ_TARGET_Y(slot)` ->
   reach destination:
   - `POLS_OBJ_STATE = 0`, zero SpeedFrac/Whole.
   - `ENEMY_DIR = k_pols_voice_directions[Random & 3]`.
   - `POLS_OBJ_REM_DISTANCE = (Random & $40) + $30 + 1` ($31 or $71;
     +1 from carry left over from CMP target Y that didn't BCC).
   - `ENEMY_X = (X + 8) & $F0`, `ENEMY_Y = ((Y + 8) & $F0) - 3`.
5. Goto `check_walkability` (mirrors NES `JMP @CheckWalkability` after
   JSR returned).

Path B — `POLS_OBJ_STATE == 0` (walking):
1. `POLS_OBJ_REM_DISTANCE == 0` -> `set_state1`.
2. Else `--POLS_OBJ_REM_DISTANCE`.
3. `ENEMY_Y += k_pols_voice_walk_speeds_y[dir_idx]`.
4. Fall through to `check_walkability`.

`check_walkability`:
1. `walk = enrt_pols_voice_is_square_walkable(slot)` (two-hotspot
   probe at (X,Y) and (X+$E, Y+$6)).
2. `walk & CARRY_SET == 0` (walkable) -> `draw_and_check`.
3. `tile = POLS_OBJ_LAST_TILE & $FC`. If `$B0` or `>= $F4` ->
   `set_state1`.
4. Else flip direction:
   - Horizontal (`dir & $03 != 0`): `ENEMY_DIR = (dir & $03) ^ $03`,
     2x `enrt_pols_voice_move_x`.
   - Vertical (`dir & $03 == 0`): `ENEMY_DIR = dir ^ $0C`.
5. Goto `draw_and_check`.

`set_state1`:
1. If already `POLS_OBJ_STATE != 0` -> `draw_and_check`.
2. `POLS_OBJ_STATE = 1`.
3. `y_idx = ENEMY_DIR - 1`.
4. Edge guard: `ENEMY_Y < $78` -> `y_idx = 3` (down jump).
5. Edge guard: `ENEMY_Y >= $A8` -> `y_idx = 7` (up jump).
6. `POLS_OBJ_SPEED_WHOLE = k_pols_voice_initial_jump_speeds[y_idx]`.
7. `POLS_OBJ_TARGET_Y = ENEMY_Y + k_pols_voice_destination_y_offsets[y_idx]`.
8. `ENEMY_DIR = y_idx + 1`.

`draw_and_check`:
1. `z07_anim_advance_and_fetch(8, slot)`.
2. `draw_object_mirrored_with_frame(ENEMY_DRAW_FRAME(slot), slot)`.
3. `POLS_INVINCIBILITY_MASK = $FE` (sword-only damage; arrow special
   case lives outside).
4. `c_check_monster_collisions(slot)`.

## Wired dispatch (delta from step 2)

| Hex | NES type   | INIT row             | UPDATE row                |
|-----|------------|----------------------|---------------------------|
| $16 | PolsVoice  | `enrt_init_walker`   | `enrt_update_pols_voice`  |

## Coverage advance

Task 7.5 dispatch coverage:
  INIT:   40 wired rows (no change).
  UPDATE: 46 -> 47 wired rows (+1: $16).

## Build verification

`python tools/debug/build_debug.py` — clean post step 3 wire. Active
scope:
- `src/game/enemies/enemy_special_bridge.c` (+1 native body
  `enrt_update_pols_voice`, table `PolsVoiceWalkSpeedsX` promoted to
  extern linkage).
- `src/game/enemies/enemy_projectile_bridge.c` (+2 forwarders for
  `z07_get_collidable_tile{,_still}`).
- `src/game/enemies/enemy_loop.c` (+1 dispatch row + extern + comment
  block).

## Step 4 sequencing (next)

- step 4 — UpdateWallmaster bridge ($27 UPDATE). Largest of the three
  special-enemy state machines. Multi-state with Link-capture submode.
  Helpers already drained (`enrt_wallmaster_calc_start_position`,
  `enrt_wallmaster_put_sprites_behind_bg_if_needed`,
  `enrt_wallmaster_prepare_to_draw`).

- step 5+ — bubble UPDATE confirm (already wired Task 7.4 step 6d) +
  vire split-behavior verify (UPDATE wired Task 7.3 step 7) +
  shield/rupee option (UnderworldPersonLifeOrMoney $52) + family close.
