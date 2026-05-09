# Phase 7 Task 7.2 step 9 — c_shoot_if_wanted native (projectile hook)

## Task header (Drain Rule D1)

- **NES source**: `reference/aldonunez/Z_04.asm:11351 _ShootIfWanted`
                  + `Z_07.asm:5795 FindEmptyMonsterSlot`
                  + `Z_07.asm:5782 SetTypeAndClearObject`
                  + `Z_01.asm:4026 DestroyObject_WRAM`
- **Drained C**:  `src/game/enemies/enemy_walker_bridge.c::c_shoot_if_wanted`
                  (REPLACE — was step-6 stub returning 0)
- **Coverage**:   FULL (all 4 NES routines folded into single native body)
- **Stance**:     REPLACE — step-6 stub return-0 was a known placeholder;
                  Phase 7 Task 7.2 master-plan checklist item
                  "projectile hook" demands the real native.

## Why now

Step 8 multi-slot trace observed: octorok slot 1 was advancing only 1 px
in 120 frames (X=$80→$7F at frame ~70+), and moblin slot 2 didn't move at
all. Root cause: with the step-6 `c_shoot_if_wanted` stub returning
carry-clear for every call, `enrt_try_shooting` falls through the
shoot-delay loop without ever clearing `ObjWantsToShoot`. The wanderer
chain re-arms `ObjWantsToShoot=1` every frame, so the slot loops in
"trying to shoot" forever — and on most frames sets `ENEMY_WALK_SPEED=0`
(see `enrt_update_octorock` step 6 inlined try-shooting at
`enemy_walker_bridge.c:284-302` — the `qspeed=0` branch on
`new_timer != $10`).

Real native projectile spawn means the success branch fires occasionally,
clearing `ObjWantsToShoot` and letting the walker resume normal motion.

## What changed

`src/game/enemies/enemy_walker_bridge.c::c_shoot_if_wanted` — full body:

1. Gate `ENEMY_PUSH_TIMER (==ObjWantsToShoot==$0412)`. If 0, return 0.
2. `FindEmptyMonsterSlot`: scan slots $0B downto $01 for `ENEMY_TYPE==0`.
   None → return 0.
3. If `shot_type >= $53` (true projectile, not melee): cap-at-4 via
   `ENEMY_SHOT_COUNT (==$034C)`. Cap hit → return 0. Otherwise INC.
4. `SetTypeAndClearObject` + `DestroyObject_WRAM` composition: write
   `ENEMY_TYPE`, zero `ObjShoveDir/ObjShoveDistance/Timer/State/
   InvincibilityTimer`, set `Metastate=$01`, `ENEMY_ALIVE_FLAG=1`.
5. Shoot block: `STATE_TIMER=$10` (NES "shot active"), `MOVE_TIMER=0`,
   copy `DIR/X/Y` from shooter slot.
6. Return `CARRY_SET | empty_slot`.

## Verification — 10/10 PASS

Step 8 trace re-run with native shoot path:

```
slot 1 type=$07 alive 1->1 xy=(128,128)->(128,115) dir=$08 anim=5->4 draw=$03->$00 spd=$00->$20
slot 2 type=$03 alive 1->1 xy=(64,96)  ->( 52,96) dir=$02 anim=0->0 draw=$00     spd=$00->$20
slot 3 type=$05 alive 1->1 xy=(64,160) ->( 64,160) dir=$02 anim=0->0 draw=$00     spd=$00->$00
slot 4 type=$2A alive 1->1 xy=(192,96) ->(192,96) dir=$04 anim=237->182 draw=$00 spd=$00->$00
  PASS G1..G10 ALL PASS
>>> WALKER TICK TRACE: PASS <<<
```

Behavioral diff vs step 8 (same probe, same RNG seed, only this commit):

| slot | step 8 motion       | step 9 motion       | unblocked |
|------|---------------------|---------------------|-----------|
| 1 ($07 octorok) | (128,128)→(128,127) 1 px | (128,128)→(128,115) 13 px | YES |
| 2 ($03 moblin)  | (64,96)→(63,96) 1 px     | (64,96)→(52,96)   12 px   | YES |
| 3 ($05 goriya)  | (64,160) static          | (64,160) static           | no (boomerang path) |
| 4 ($2A stalfos) | (192,96) static          | (192,96) static           | no (different update path) |

Octorok + moblin walking is the milestone signal — both were stuck in
the shoot-delay→walk_speed=0 loop pre-step-9.

## Behavioral observations / TODO

1. **Shot UPDATE rows still NULL** — spawned shots ($53 etc) sit in
   their slots forever because `enemy_update_fns[$53]` = NULL. With
   `ENEMY_SHOT_COUNT` cap-at-4 + monotonic INC, octorok will stop
   shooting after 4 successful shoots until `ENEMY_SHOT_COUNT` is
   decremented (NES decrements on shot death — `_DestroyMonsterShot` at
   `Z_04.asm:913 DEC ActiveMonsterShots`). Step 10: drain shot UPDATE
   rows + death decrement.

2. **Goriya / Stalfos non-walking — different bottleneck** — goriya uses
   `enrt_walker_set_input_dir_and_try_shooting_boomerang` which calls
   the boomerang shoot path (different from rock); stalfos doesn't
   reach `_TryShooting` at all in its body. These still need per-type
   `WALK_SPEED` seed or upstream init wrapper. Old Task #16 deferred.

3. **Sprites still don't draw** — `enemy_loop_tick` lacks the central
   post-dispatch animate-and-draw hook. Octorok body has its own draw
   tail (`c_draw_object_not_mirrored_with_frame` at
   `enemy_walker_bridge.c:317+`) but moblin doesn't. Step 10+: central
   draw hook OR per-type draw tail.

## Rolled-forward TODOs (unchanged from step 8)

- Central post-dispatch animate/draw hook (or extend bare bodies).
- Walker_CheckTileCollision (room tile registry).
- Lynel ($01/$02) / Darknut ($0B/$0C) UPDATE drain.
- Rope ($29) / Gel ($2C) wiring (drains exist, just need rows).
- Blue-monster shoot-bypass branch in `enrt_try_shooting`.
- Shot UPDATE rows ($53, etc) — NEW for step 10.
- `c_obj_shove` native (combat damage hook) — still stubbed.
