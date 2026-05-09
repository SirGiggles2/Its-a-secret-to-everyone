# Phase 7 Task 7.2 step 5 — Walker_Move native drain

## Task header (Drain Rule D1)

- **NES source**: `reference/aldonunez/Z_07.asm:2555` Walker_Move
- **Drained C**:  `src/game/world/object_dispatch.c` (object_bound_by_room,
                  object_move_object, object_bound_direction_*)
                  + new composer in `src/game/enemies/enemy_walker_bridge.c`
- **Coverage**:   PARTIAL — Obj_Shove + Walker_CheckTileCollision branches
                  deferred (TODO markers; gated by absent combat/room hooks
                  in Phase 7 Task 7.2 scope). All other branches drained.
- **Stance**:     EXTEND — composes existing drained primitives
                  (object_bound_by_room, object_move_object, core_get_opposite_dir).

## What changed

`src/game/enemies/enemy_walker_bridge.c::c_walker_move` replaced the
PLACEHOLDER stub (returned without moving) with a 7-step native body
mirroring NES Walker_Move for the non-Link path:

1. `Obj_Shove` gate (deferred — no combat hooked yet → ObjShoveDir=0)
2. `CheckStunned` — `(InvClock | ObjStunTimer[slot]) != 0` → return
3. `FilterInput` — single-direction pick using
   `core_get_opposite_dir` + ReverseDirections table
4. `SetMovingDir` — mask `$0F` into `RAM(NES_OBJ_DIR)` ($000F)
5. Clear `RAM($000E)` (NES_SHOT_COLLISION_FLAG; doorway scratch)
6. `CheckBoundary` → `object_bound_by_room(slot)`
7. `MoveObject` → `object_move_object((unsigned short)slot)`

Walker_CheckTileCollision deferred — without room tile data wired into
Debug.md, tile collision would freeze octoroks against arbitrary
in-memory bytes. Octorok still respects room bounds (left/right/top/
bottom from `RAM(NES_BOUND_*)`).

## Verification

`probe_walker_tick_trace.lua` (extended G6 gate) — all 6 gates PASS:

```
init probe magic = 'EL' (expect 'EL')
[t+  0] f=   19 alive=1/1 type=$07 x=$76 y=$80 dir=$02 anim= 7 spd=$20
[t+ 10] f=   24 alive=1/1 type=$07 x=$74 y=$80 dir=$02 anim= 2 spd=$20
[t+ 20] f=   29 alive=1/1 type=$07 x=$71 y=$80 dir=$02 anim= 7 spd=$20
[t+ 30] f=   33 alive=1/1 type=$07 x=$6F y=$80 dir=$02 anim= 3 spd=$20
[t+ 40] f=   38 alive=1/1 type=$07 x=$6D y=$80 dir=$02 anim= 8 spd=$20
[t+ 50] f=   42 alive=1/1 type=$07 x=$6B y=$80 dir=$02 anim= 4 spd=$20
[t+ 60] f=   47 alive=1/1 type=$07 x=$68 y=$80 dir=$02 anim= 9 spd=$20
[t+ 70] f=   52 alive=1/1 type=$07 x=$66 y=$80 dir=$02 anim= 4 spd=$20
[t+ 80] f=   56 alive=1/1 type=$07 x=$64 y=$80 dir=$02 anim=10 spd=$20
[t+ 90] f=   61 alive=1/1 type=$07 x=$61 y=$80 dir=$02 anim= 5 spd=$20
[t+100] f=   66 alive=1/1 type=$07 x=$5F y=$80 dir=$02 anim=10 spd=$20
[t+110] f=   70 alive=1/1 type=$07 x=$5D y=$80 dir=$02 anim= 6 spd=$20
[t+120] f=   75 alive=1/1 type=$07 x=$5A y=$80 dir=$02 anim= 1 spd=$20
  PASS  G1 magic 'TK' (publisher fired)
  PASS  G2 frame_counter advanced (19 -> 75)
  PASS  G3 ENEMY_ALIVE_FLAG(1) stays 1 across trace
  PASS  G4 ENEMY_TYPE(1) stays $07 across trace
  PASS  G5 anim_timer OR draw_frame advanced (anim_changed=true draw_changed=true)
  PASS  G6 X OR Y advanced (x_changed=true y_changed=false; first=118,128 last=90,128)
>>> WALKER TICK TRACE: PASS <<<
```

## NES-parity speed check

Speed seed `ENEMY_WALK_SPEED(1)=$20` = `NES_OBJ_QSPD_FRAC=$20`.
NES MoveObject runs the inner accumulator 4× per frame; with $20 fract
add per pass, fraction overflows once per ~3.2 passes → ~0.5 px/frame
average. Observed: 28 px in 56 frames = 0.5 px/frame. **Matches NES**.

DIR=$02 (left), Y unchanged: matches NES single-axis Walker_Move.

## Deferred TODOs

- Obj_Shove (z_07.asm:305) — fires on damage knockback; wire when
  combat damage applies push-dir.
- Walker_CheckTileCollision — needs room tile registry hooked into
  Debug.md so octorok bounces off walls instead of phasing.

Both are tracked under Phase 7 Task 7.2 successor steps (octorok
projectile → Phase 7 next-task → moblin → stalfos → goriya → darknut).
