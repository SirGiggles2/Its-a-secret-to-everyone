# Phase 7 Task 7.5 step 4 — Wallmaster UPDATE bridge ($27)

## Task header (Drain Rule D1)

- **NES source**: `Z_07.asm:5295 UpdateObject_JumpTable` row $27 ->
                  `UpdateWallmaster` @ `Z_04.asm:4121-4413` (~292 lines:
                  state-0 trigger gating + `Wallmaster_CalcStartPosition`
                  + emergence setup + state-1 walking +
                  `L_Wallmaster_State1` shove/move/step-advance + 7-tile
                  end-of-trip + `Wallmaster_DrawAndCheckCollisions` +
                  `@DrawWithCapturedLink` + `@PatchSprites` keese-tile
                  fixup).

- **Drained C**:  No top-level `enrt_update_wallmaster` exists in
                  `src/oracle/enemies/`. Helpers ARE drained:
                  - `enrt_wallmaster_calc_start_position` @
                    `enemy_wallmaster_runtime.c:52`
                    (NES `Z_04.asm:4451`).
                  - `enrt_wallmaster_put_sprite_behind_bg_if_needed` @
                    `enemy_wallmaster_runtime.c:106`
                    (NES `Z_04.asm:4511`).
                  - `enrt_wallmaster_put_sprites_behind_bg_if_needed` @
                    `enemy_wallmaster_runtime.c:127`
                    (NES `Z_04.asm:4507`).
                  - `enrt_wallmaster_prepare_to_draw` @
                    `enemy_boss_runtime.c:400`
                    (NES `Z_04.asm:4415`).
                  - `c_obj_shove` @ `enemy_walker_bridge.c:252`.
                  - `c_check_monster_collisions` @
                    `enemy_walker_bridge.c:166`.
                  - `c_move_object` @ `enemy_projectile_bridge.c:16`
                    (-> `object_move_object`).
                  - `sprite_show_link_sprites_behind_horizontal_doors`
                    @ `world/sprite_dispatch.c:138`.
                  - `enemy_hide_sprites_over_link` @
                    `enemies/enemy_dispatch.c:29`.
                  - `draw_object_not_mirrored_with_frame` /
                    `draw_object_not_mirrored_over_link` @
                    `world/draw_dispatch.c`.
                  - `k_sprite_offsets[41]` (extern from `draw_dispatch.c`).

- **Coverage**:   FULL for $27 Wallmaster UPDATE — all NES code paths
                  covered (state-0 idle gating with 4-wall trigger
                  zones, `Wallmaster_CalcStartPosition` call + initial
                  X/Y from per-axis tables, dir from
                  `WallmasterDirsAndAttrs[ObjStep]`, timer/qspeed/anim
                  seed, INC ObjState; state-1 shove handle, magic
                  clock + stun skip, MoveObject with $0F dir scratch,
                  grid-aligned step advance with table-driven dir
                  refresh, 7-tile trip end + capture-Link unfurl
                  trigger; DrawAndCheckCollisions captured-vs-
                  uncaptured branch + RollingSpriteIndex save/restore
                  + Keese-tile $9C->$AC PatchSprites + behind-bg
                  priority; DrawWithCapturedLink Link reposition +
                  retick stub + ShowLinkSpritesBehindHorizontalDoors +
                  force frame=1 + DrawObjectNotMirroredOverLink +
                  hardcoded $40/$44 over-Link sprite offsets reused
                  by PatchSprites tail).

- **Stance**:     EXTEND. Top-level UPDATE body is not directly
                  drained; native bridge body in
                  `enemy_special_bridge.c` carries per-line NES
                  translation of `Z_04.asm:4121`. Same model as step
                  2 (LikeLike), step 3 (PolsVoice), and
                  `enemy_boss_bridge.c` (Aquamentus / Vire). All
                  composed primitives already linked into Debug.md;
                  step 4 adds `enemy_wallmaster_runtime.c` to the TU
                  list so `--gc-sections` can retain the three
                  drained helpers via the new $27 UPDATE wire.

## Native bridge body added (`enemy_special_bridge.c`)

| Function                              | NES source         | Lines (asm) |
|---------------------------------------|--------------------|-------------|
| `enrt_update_wallmaster`              | `Z_04.asm:4121`    | ~292        |
| `wm_link_end_move_and_animate_bank4_stub` | (STAGE-1)      | no-op       |

### NES RAM cell aliases (file-local, added in step 4 prep)

| NES name                  | NES addr | C macro                       |
|---------------------------|----------|-------------------------------|
| `ObjState`                | `$00AC`  | `WM_OBJ_STATE`                |
| `ObjShoveDir`             | `$00C0`  | `WM_OBJ_SHOVE_DIR`            |
| `ObjInputDir` (Link)      | `$03F8`  | `WM_OBJ_INPUT_DIR`            |
| `ObjTimer+1` (slot 1)     | `$0029`  | `WM_OBJ_TIMER_SLOT1`          |
| `InvClock`                | `$066C`  | `WM_INV_CLOCK`                |
| `ObjStunTimer`            | `$003D`  | `WM_OBJ_STUN_TIMER`           |
| `ObjGridOffset`           | `$0394`  | `WM_OBJ_GRID_OFFSET`          |
| `ObjQSpeedFrac`           | `$03BC`  | `WM_OBJ_QSPEED_FRAC`          |
| `ObjAnimCounter`          | `$03D0`  | `WM_OBJ_ANIM_COUNTER`         |
| `ObjAnimFrame`            | `$03E4`  | `WM_OBJ_ANIM_FRAME`           |
| `Wallmaster_ObjStep`      | `$0412`  | `WM_OBJ_STEP`                 |
| `Wallmaster_ObjTilesCrossed` | `$041F` | `WM_OBJ_TILES_CROSSED`       |
| `ObjCaptureTimer`         | `$042C`  | `WM_OBJ_CAPTURE_TIMER`        |
| `RollingSpriteIndex`      | `$0341`  | `WM_ROLLING_SPRITE_INDEX`     |
| `GameMode`                | `$0012`  | `WM_GAME_MODE`                |
| `GameSubmode`             | `$0013`  | `WM_GAME_SUBMODE`             |
| `IsUpdatingMode`          | `$0011`  | `WM_IS_UPDATING_MODE`         |
| `Sprites+off` ($0200+off) | `$0200`  | `WM_SPRITES(off)`             |
| `[02]` decrease-axis bit  | `$0002`  | `WM_SCRATCH_INSTR_AXIS`       |
| `[00]` Link minor coord   | `$0000`  | `WM_SCRATCH_LINK_MINOR`       |
| `[01]` Link major coord   | `$0001`  | `WM_SCRATCH_LINK_MAJOR`       |
| `[04]` init minor result  | `$0004`  | `WM_SCRATCH_INIT_MINOR_COORD` |
| `[00]` patch-left off     | `$0000`  | `WM_SCRATCH_PATCH_LEFT_OFFSET` |
| `[01]` patch-right off    | `$0001`  | `WM_SCRATCH_PATCH_RIGHT_OFFSET` |

`Wallmaster_ObjStep` ($0412) aliases `ENEMY_PUSH_TIMER` (used by
flyer/jumper); `Wallmaster_ObjTilesCrossed` ($041F) aliases
`ENEMY_AIR_SPEED`. The drained
`enrt_wallmaster_calc_start_position` already writes the step value
via `ENEMY_PUSH_TIMER(slot)`; this bridge reads it back through
`WM_OBJ_STEP(slot)`.

### Verbatim NES tables (from `Z_04.asm:4099-4119`)

| Table (NES name)              | Size | Notes                                |
|-------------------------------|------|--------------------------------------|
| `k_wallmaster_dirs_and_attrs` | 64   | Concatenation of 4 NES per-wall      |
|                               |      | tables (Left $0..$F, Right $10..$1F, |
|                               |      | Top $20..$2F, Bottom $30..$3F) so a  |
|                               |      | single ObjStep index reaches all 4   |
|                               |      | wall blocks (matches NES asm layout). |
| `k_wallmaster_initial_xs`     | 2    | $00, $F0 — emergence X for L/R walls |
| `k_wallmaster_initial_ys`     | 2    | $3D, $DD — emergence Y for T/B walls |

## State machine summary

`enrt_update_wallmaster(slot)`:

State 0 — idle inside wall (Z_04.asm:4126-4253):
1. `WM_OBJ_TIMER_SLOT1 != 0` -> exit (Link's frame timer active).
2. `WM_OBJ_STATE(0) != $40` -> exit (Link not stunned/halted).
3. Trigger zone gating:
   - If `link_x < $29 || link_x >= $C8`, then require
     `link_y` in `[$6D..$B5)`. Else early-exit.
4. Side-wall trigger: `link_x in {$20, $D0}`:
   - `[00] = link_y, [01] = link_x, [02] = $08` (decrease=up).
   - `idx = enrt_wallmaster_calc_start_position($00, $20, slot)`.
   - `ENEMY_Y(slot) = [04]`, `ENEMY_X(slot) = k_wallmaster_initial_xs[idx]`.
5. Else top/bottom trigger: `link_y in {$5D, $BD}`:
   - `[00] = link_x, [01] = link_y, [02] = $02` (decrease=left).
   - `idx = enrt_wallmaster_calc_start_position($20, $5D, slot)`.
   - `ENEMY_Y(slot) = k_wallmaster_initial_ys[idx]`,
     `ENEMY_X(slot) = [04]`.
   - Else (no trigger) -> exit.
6. SetUpToEmerge tail:
   - `ENEMY_DIR(slot) = k_wallmaster_dirs_and_attrs[ObjStep] & $0F`.
   - `WM_OBJ_TIMER_SLOT1 = $60`, `WM_OBJ_QSPEED_FRAC = $18`,
     `WM_OBJ_ANIM_COUNTER = $08`,
     `WM_OBJ_GRID_OFFSET / TILES_CROSSED / ANIM_FRAME = 0`.
   - `INC WM_OBJ_STATE` -> enter state 1.

State 1 — walking along wall (Z_04.asm:4255-4325):
1. `WM_OBJ_SHOVE_DIR != 0` -> `c_obj_shove` -> draw_and_check.
2. `WM_INV_CLOCK | WM_OBJ_STUN_TIMER != 0` -> draw_and_check.
3. `RAM($0F) = ENEMY_DIR(slot)`, `c_move_object(slot)`.
4. `WM_OBJ_GRID_OFFSET in {$10, $F0}` (square aligned):
   - `WM_OBJ_GRID_OFFSET = 0`.
   - `INC WM_OBJ_STEP`,
     `ENEMY_DIR(slot) = k_wallmaster_dirs_and_attrs[ObjStep] & $0F`.
   - `INC WM_OBJ_TILES_CROSSED`. If `< 7` -> draw_and_check.
   - End-of-trip:
     - If `WM_OBJ_CAPTURE_TIMER != 0`:
       `enemy_hide_sprites_over_link()`,
       `WM_GAME_MODE = 3`, `WM_OBJ_STATE(0) = 0`,
       `WM_IS_UPDATING_MODE = 0`, `WM_GAME_SUBMODE = 0`.
     - `WM_OBJ_STATE(slot) = 0` and return.
5. Else fall through to draw_and_check.

`draw_and_check_collisions` (Z_04.asm:4327-4385):
1. `WM_OBJ_CAPTURE_TIMER != 0` -> `draw_with_captured_link`.
2. `c_check_monster_collisions(slot)`.
3. Post-collision: if Link just got captured,
   `WM_OBJ_STATE(0) = $40`, `WM_OBJ_SHOVE_DIR(0) = 0`.
4. Save sprite cursor, `enrt_wallmaster_prepare_to_draw(slot)`,
   `draw_object_not_mirrored_with_frame(anim_frame, slot)`,
   restore cursor: `left_off = k_sprite_offsets[saved]`,
   `right_off = k_sprite_offsets[(saved + 1) & $3F]`.
5. `patch_sprites`:
   - `[00] = left_off, [01] = right_off`.
   - `enrt_wallmaster_put_sprites_behind_bg_if_needed()`.
   - If anim_frame == 0 -> exit.
   - Keese-tile fixup: probe `Sprites+1+left_off`. If $9C ->
     patch left tile to $AC; else patch right tile to $AC (handles
     horizontal-flip swap).

`draw_with_captured_link` (Z_04.asm:4387-4413):
1. `ENEMY_X(0) = ENEMY_X(slot)`, `ENEMY_Y(0) = ENEMY_Y(slot)`.
2. `wm_link_end_move_and_animate_bank4_stub()` (STAGE-1 no-op).
3. `sprite_show_link_sprites_behind_horizontal_doors()`.
4. `enrt_wallmaster_prepare_to_draw(slot)`.
5. `WM_OBJ_ANIM_FRAME(slot) = 1` (force closed-hand).
6. `draw_object_not_mirrored_over_link(1, slot)`.
7. Reuse `patch_sprites` with hardcoded `left_off=$40, right_off=$44`
   (over-Link sprites $10/$11).

## Wired dispatch (delta from step 3)

| Hex | NES type    | INIT row                              | UPDATE row                |
|-----|-------------|---------------------------------------|---------------------------|
| $27 | Wallmaster  | `core_reset_obj_metastate_and_timer`  | `enrt_update_wallmaster`  |

## Coverage advance

Task 7.5 dispatch coverage:
  INIT:   40 wired rows (no change).
  UPDATE: 47 -> 48 wired rows (+1: $27).

## Build verification

`python tools/debug/build_debug.py` — clean post step 4 wire. Active
scope:
- `src/game/enemies/enemy_special_bridge.c` (+1 native body
  `enrt_update_wallmaster`, +1 STAGE-1 stub
  `wm_link_end_move_and_animate_bank4_stub`, +1 64-byte table
  `k_wallmaster_dirs_and_attrs`, +2 size-2 tables).
- `src/game/enemies/enemy_loop.c` (+1 dispatch row + extern + comment
  block).
- `src/game/world/draw_dispatch.c` (+1 native body
  `draw_object_not_mirrored_over_link`, `k_sprite_offsets` promoted
  to extern linkage).
- `src/game/world/draw_dispatch.h` (+1 prototype + extern decl for
  `k_sprite_offsets`).
- `tools/debug/build_debug.py` (+1 TU
  `src/oracle/enemies/enemy_wallmaster_runtime.c` for the three
  drained Wallmaster helpers).

## STAGE-1 stub note

`Link_EndMoveAndAnimate_Bank4` (NES `Z_07.asm:4360`) is NOT drained.
Same model as `trap_init_mode_b_enter_cave_bank5` (cellar entry stub
in `trap_dispatch.h:75-86`). The captured-Link draw path repositions
Link onto the monster but does NOT retick Link's animation frame;
visually Link freezes at the prior frame while the hand sprite covers
him via `DrawObjectNotMirroredOverLink`. Native port deferred to
Phase 5 alongside the other Link_EndMoveAndAnimate STAGE-1 stubs
(uw_person_dispatch.c:336, cave_dispatch.c:603, trap_dispatch.c:342).

## Step 5 sequencing (next)

- step 5 — bubble UPDATE confirm. $2B/$2C/$2D wired Task 7.4 step 6d
  via `enrt_update_bubble`. Confirm dispatch + behavior.
- step 6 — vire split-behavior verify ($12 UPDATE wired Task 7.3
  step 7). Confirm spawn-keese-on-death state machine.
- step 7 — shield/rupee option ($52
  UnderworldPersonLifeOrMoney UPDATE) per master plan Phase 7
  closure list.
- step 8 — special-enemy family close (audit-doc rollup, coverage
  table refresh, master plan Task 7.5 mark).
