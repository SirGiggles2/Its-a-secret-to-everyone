# Phase 7 Task 7.5 step 1 — special-enemy INIT wins

## Task header (Drain Rule D1)

- **NES source**: `Z_07.asm:5601 InitObject_JumpTable` rows:
                  - $16 PolsVoice  -> `InitWalker` (bare walker init).
                  - $17 LikeLike   -> `InitWalker` (bare walker init).
                  - $27 Wallmaster -> `ResetObjMetastateAndTimer`
                                      (1-line clear scratch + timer).

- **Drained C**:  - `enrt_init_walker` @
                    `src/oracle/enemies/enemy_walker_runtime.c`
                    (already extern'd in enemy_loop.c since Task 7.2
                    step 7; reused for $01-$06 / $12 / $13 / $14 / $2A /
                    $30 dispatch rows).
                  - `core_reset_obj_metastate_and_timer` @
                    `src/game/core/core_dispatch.c`
                    (already extern'd since Task 7.4 step 2b; reused
                    for $11 Zora dispatch row).

- **Coverage**:   FULL for $16/$17 INIT (both reuse walker init seed
                  the same way NES does — full state machine for
                  PolsVoice + LikeLike lives in their UPDATE bodies).
                  FULL for $27 Wallmaster INIT (NES State 0 entry
                  re-derives all spawn coords from Link's position
                  during UpdateWallmaster, so init only needs the
                  metastate/timer clear).
                  UPDATE rows for $16/$17/$27 still pending — bigger
                  bridge work because UpdatePolsVoice (~140 lines, two
                  states + walkability), UpdateLikeLike (~30 lines but
                  pulls UpdateCommonWanderer + DrawObjectMirrored), and
                  UpdateWallmaster (~200+ lines, multi-state with
                  Link-capture submode). Helpers already drained:
                    * `enrt_pols_voice_move_x` @ enemy_boss_runtime.c:395
                    * `enrt_pols_voice_get_colliding_tile` @ :494
                    * `enrt_pols_voice_is_square_walkable` @ :514
                    * `enrt_wallmaster_calc_start_position` @
                      enemy_wallmaster_runtime.c:52
                    * `enrt_wallmaster_put_sprite_behind_bg_if_needed` @ :106
                    * `enrt_wallmaster_put_sprites_behind_bg_if_needed` @ :127
                    * `enrt_wallmaster_prepare_to_draw` @
                      enemy_boss_runtime.c:400

- **Stance**:     ADOPT — three single-row table-deltas, no new TUs /
                  bridges / externs. Closes the cheap end of the
                  Special Enemy Family INIT side; UPDATE rows handled
                  in subsequent steps with bridge work.

## Wired dispatch (delta from Task 7.4 step 11)

| Hex | NES type   | INIT row                              | UPDATE row |
|-----|------------|---------------------------------------|------------|
| $16 | PolsVoice  | `enrt_init_walker`                    | (pending)  |
| $17 | LikeLike   | `enrt_init_walker`                    | (pending)  |
| $27 | Wallmaster | `core_reset_obj_metastate_and_timer`  | (pending)  |

## Coverage advance

Task 7.5 dispatch coverage:
  INIT:   37 -> 40 wired rows (+3: $16, $17, $27).
  UPDATE: 45 wired rows (no change).

## Build verification

`python tools/debug/build_debug.py` — clean post step 1 wire. Active
scope: `src/game/enemies/enemy_loop.c` only (+3 INIT rows + comment
block). No new files, no bridge edits, no new externs.

## Step 2 sequencing (next)

- step 2 — UpdateLikeLike bridge ($17 UPDATE). Smallest of the three
  remaining special-enemy UPDATE bodies (~30 lines NES asm). Pulls
  UpdateCommonWanderer (already drained as
  `z04_update_common_wanderer`), Anim_FetchObjPosForSpriteDescriptor,
  DrawObjectMirrored, CheckMonsterCollisions, plus the 4-frame anim
  cycle (vs the 2-frame default most monsters use), plus
  ObjCaptureTimer-driven Link-capture path.

- step 3 — UpdatePolsVoice bridge ($16 UPDATE). State machine with
  jumping path (PolsVoice_State1_Jumping at Z_04.asm:6675), uses
  already-drained `enrt_pols_voice_move_x` /
  `enrt_pols_voice_is_square_walkable`.

- step 4 — UpdateWallmaster bridge ($27 UPDATE). Largest body —
  multi-state with Link-capture submode. Helpers already drained
  (`enrt_wallmaster_calc_start_position`,
  `enrt_wallmaster_put_sprites_behind_bg_if_needed`,
  `enrt_wallmaster_prepare_to_draw`).

- step 5 — bubble UPDATE confirm ($2B/$2C/$2D — already wired in
  Task 7.4 step 6d). Audit-only sweep, no code change expected.

- step 6 — vire split-behavior verify. Vire UPDATE wired Task 7.3
  step 7. Probe split path under combat hit.

- step 7 — shield consumption / rupee option (UpdateUnderworldPersonLifeOrMoney
  family, $52). Likely a separate dispatch row, not an enemy-family
  member proper.

- step 8 — special-family close + Task 7.5 hand-off doc.
