# Phase 7 Task 7.2 step 6 — Octorock native + walker family unblock

## Task header (Drain Rule D1)

- **NES source**: `reference/aldonunez/Z_04.asm:2966` UpdateOctorock
                  + `Z_04.asm:1975` _TryShooting (inlined)
- **Drained C**:  `src/game/enemies/enemy_walker_bridge.c::enrt_update_octorock`
                  (NEW step 6) + `c_obj_shove`, `c_shoot_if_wanted` stubs
- **Coverage**:   PARTIAL — projectile spawn deferred (c_shoot_if_wanted
                  stub returns 0/fail; shoot-delay loop runs but never
                  spawns rocks). Wanderer + boundary + animation +
                  collision check fully drained.
- **Stance**:     EXTEND — composes existing drained primitives
                  (enrt_wanderer_target_player, sprite_anim_fetch_obj_pos,
                  draw_object_mirrored_with_frame,
                  link_collision_check_monster_collisions) + step-6
                  native body for UpdateOctorock specifics.

## What changed

### `src/game/enemies/enemy_walker_bridge.c`

1. **`c_obj_shove(slot)` — TODO native stub.** Clears
   `OBJ(NES_OBJ_SHOVE_DIR, slot)` so callers (e.g.
   `enrt_update_common_wanderer`) don't loop forever. Real Obj_Shove
   knockback deferred to combat-damage hook (Phase 7 Task 7.4).

2. **`c_shoot_if_wanted(shot_type, slot)` — TODO native stub.** Always
   returns 0 (CARRY_CLEAR). Callers
   (`enrt_try_shooting` /
   `enrt_walker_set_input_dir_and_try_shooting_boomerang`) handle the
   failure path cleanly. Octorok / moblin / stalfos / goriya walk but
   never spawn projectiles. Real spawn deferred to next step
   ("projectile hook" per master plan checklist).

3. **`enrt_update_octorock(slot)` — NATIVE body.** Replaces the step-4
   stub mapping `enemy_update_fns[$07] = enrt_update_rope`. Direct port
   of NES UpdateOctorock at `Z_04.asm:2966`:

   - Step 1: `ENEMY_AIR_SPEED = $A0` (blue $09+) or `$70` (red $07/$08)
   - Step 2: `enrt_wanderer_target_player(slot)` — calls `c_walker_move`
     + targets Link + sets `ENEMY_PUSH_TIMER = 1` ("WantsToShoot")
   - Step 3: qspeed = `$20` (slow $07/$09) or `$40` (fast $08/$0A)
   - Step 4: inlined _TryShooting flying rock `$53` — mirror of static
     `enrt_try_shooting` in `enemy_walker_runtime.c`. ObjShootTimer
     ($0451) cycles $30→$00; at $10 calls `c_shoot_if_wanted` (stub
     fails, ENEMY_WALK_SPEED = qspeed for one frame); rest of cycle
     ENEMY_WALK_SPEED = 0
   - Step 5: `sprite_anim_fetch_obj_pos(slot)` — primes draw scratch +
     clears `ENEMY_FRAME_FLAGS` (ZP_TMPF / $000F)
   - Step 6: dir-based frame offset — UP=1, DOWN=2, LEFT=0,
     RIGHT=0+hflip (NES INC $0F)
   - Step 7: anim counter DEC; on 0 reload to 6 + toggle `DRAW_FRAME ^ 3`
   - Step 8: `final_frame = dir_offset + DRAW_FRAME`
   - Step 9: `draw_object_mirrored_with_frame` if `dir & $0C` else
     `draw_object_not_mirrored_with_frame`
   - Step 10: `link_collision_check_monster_collisions(slot)`

### `src/game/enemies/enemy_loop.c`

Rewired `enemy_update_fns[$07]` from `enrt_update_rope` (semantically
$29; leever-style speed-ramp is rope-only) to `enrt_update_octorock`
(per NES UpdateObject_JumpTable). Update extern + table comment.

## Verification

`probe_walker_tick_trace.lua` — all 6 gates PASS:

```
init probe magic = 'EL' (expect 'EL')
[t+  0] f= 19 alive=1/1 type=$07 x=$80 y=$80 dir=$08 anim=5 draw=$03 spd=$00
[t+ 10] f= 24 alive=1/1 type=$07 x=$80 y=$80 dir=$08 anim=6 draw=$00 spd=$00
[t+ 20] f= 29 alive=1/1 type=$07 x=$80 y=$80 dir=$08 anim=1 draw=$00 spd=$00
[t+ 30] f= 33 alive=1/1 type=$07 x=$80 y=$80 dir=$08 anim=3 draw=$03 spd=$20
[t+ 40] f= 38 alive=1/1 type=$07 x=$80 y=$7F dir=$08 anim=4 draw=$00 spd=$00
...
[t+120] f= 75 alive=1/1 type=$07 x=$80 y=$7F dir=$08 anim=3 draw=$00 spd=$00
  PASS  G1 magic 'TK' (publisher fired)
  PASS  G2 frame_counter advanced (19 -> 75)
  PASS  G3 ENEMY_ALIVE_FLAG(1) stays 1 across trace
  PASS  G4 ENEMY_TYPE(1) stays $07 across trace
  PASS  G5 anim_timer OR draw_frame advanced
  PASS  G6 X OR Y advanced (y_changed=true; first=128,128 last=128,127)
>>> WALKER TICK TRACE: PASS <<<
```

## Behavioral diff vs step 5

| Aspect       | Step 5 (enrt_update_rope)        | Step 6 (enrt_update_octorock)        |
|--------------|----------------------------------|--------------------------------------|
| Dispatch row | `[$07] = enrt_update_rope`       | `[$07] = enrt_update_octorock`       |
| Direction    | DIR=$02 LEFT, never turns        | DIR=$08 UP — wanderer targets Link   |
| Speed        | constant $20 every frame         | cycles $00 (shoot delay) / $20 (try) |
| Movement     | 0.5 px/frame steady              | ~1 px in 120 frames (shoot-fail loop)|
| Animation    | 10-frame anim cycle, palette 2   | 6-frame DEC w/ XOR, draw mirrored UP |
| Shoot path   | none                             | inlined _TryShooting w/ stub fail    |

The slower observed speed is **NES-correct given the stub**: real
ShootIfWanted would succeed periodically, clearing WantsToShoot and
unsticking the shoot-delay timer. Once the projectile-hook step lands
(next), octorok walks normally between shots.

## Deferred TODOs

1. **`c_shoot_if_wanted` native** — projectile spawn (master plan
   "projectile hook"). Need shot_object_init dispatch + free-slot
   search across slots $0B..$0E + shot type table ($53 rock / $5B
   arrow / $57 sword-shot / $5C boomerang / $55 fireball).

2. **`c_obj_shove` native** — knockback. Wire when combat-damage hook
   applies push-dir (Phase 7 Task 7.4 timeframe).

3. **Walker_CheckTileCollision** (carried over from step 5) — needs
   room tile registry. Octorok currently phases through walls.

4. **Blue-monster shoot-bypass** — NES UpdateMoblin _TryShooting has
   "if blue moblin / blue lynel / blue octorock then always-try"
   bypass that the C drain `enrt_try_shooting` is missing. Folded
   into native shoot path when projectile hook lands.

5. **Wire $03/$04 moblin, $05/$06 goriya, $0B/$0C darknut, $1F stalfos,
   $29 rope** — same family pattern as octorock now that `c_obj_shove`
   + `c_shoot_if_wanted` link cleanly. Each family's drained
   `enrt_update_*` body can be wired into `enemy_update_fns[]` row by
   row.
