# Phase 7 Task 7.2 step 10 — room-init default WALK_SPEED=$20

## Task header (Drain Rule D1)

- **NES source**: `reference/aldonunez/Z_05.asm:1684-1699` (per-slot
                  init loop, run for slots $B..1 BEFORE
                  `InitObject_JumpTable[ObjType,X]`)
- **Drained C**:  `src/game/enemies/enemy_loop.c::clear_slot_scratch`
                  (REPLACE — was zeroing WALK_SPEED/ANIM_TIMER/METASTATE,
                  wrong vs NES)
- **Coverage**:   FULL — all NES room-init defaults that touch the
                  walker AI loop are now mirrored
- **Stance**:     REPLACE (drain bug; init defaults must match NES exactly)

## What NES does (Z_05.asm:1684-1699)

```asm
LDX #$0B
:    DEC ObjUninitialized, X        ; $0492 -- $FF -> $FE then -> 0 by init
     JSR ResetShoveInfo             ; ObjShoveDir=0 + ObjShoveDistance=0
     STA ObjState, X                ; $00AC = 0   (A=0 from ResetShoveInfo)
     STA ObjDir, X                  ; $0098 = 0
     STA ObjStunTimer, X            ; $003D = 0
     INC ObjAnimCounter, X          ; $03D0 = 1   (was 0, INC -> 1)
     INC ObjMetastate, X            ; $0405 = 1   "first cloud state"
     LDA #$20                       ;
     STA ObjQSpeedFrac, X           ; $03BC = $20  *** DEFAULT SPEED ***
     DEX
     BNE :-
```

Then per-type init runs (e.g. `InitSlowOctorockOrGhini` at Z_04.asm:1864
overrides `ObjQSpeedFrac=$20` keeping it; `InitFastOctorock` overrides
to `$30`; `InitDarknut` overrides to `$20`/`$28`). Bare `InitWalker`
(Z_04.asm:209) used by walker types `$01-$06` + `$2A` does NOT touch
QSpeedFrac — so those types inherit the room-init default `$20`.

## Drain bug (pre-step-10)

`clear_slot_scratch` zeroed everything:

```c
ENEMY_METASTATE(slot)   = 0u;   // wrong: NES = 1
ENEMY_WALK_SPEED(slot)  = 0u;   // wrong: NES = $20
ENEMY_ANIM_TIMER(slot)  = 0u;   // wrong: NES = 1
ENEMY_STATE_TIMER(slot) = slot; // wrong: NES = 0 (slot goes in MOVE_TIMER)
```

Octorok ($07/$09 slow, $08/$0A fast) + Darknut ($0B/$0C) had per-type
init wrappers that re-seeded WALK_SPEED, masking the bug. Walker types
$01-$06 + $2A had no wrapper, so they inherited WALK_SPEED=0, never
moved.

## Step 10 fix

`clear_slot_scratch` now matches NES room-init line by line:

```c
ENEMY_DIR(slot)            = 0u;
ENEMY_STATE_TIMER(slot)    = 0u;        /* was: slot — wrong */
ENEMY_METASTATE(slot)      = 1u;        /* was: 0  — NES "first cloud state" */
...
ENEMY_WALK_SPEED(slot)     = 0x20u;     /* was: 0  — NES Z_05.asm:1696 */
ENEMY_ANIM_TIMER(slot)     = 1u;        /* was: 0  — NES INC from 0 */
...
ENEMY_STUN_TIMER(slot)     = 0u;        /* added — Z_05.asm:1693 */
ENEMY_OBJ_SHOVE_DIR(slot)  = 0u;        /* added — ResetShoveInfo */
OBJ(0x00D3u, slot)         = 0u;        /* added — ObjShoveDistance */
ENEMY_MOVE_TIMER(slot)     = (uchar)slot; /* added — InitObject preamble */
ENEMY_ALIVE_FLAG(slot)     = 1u;
```

## Verification — 10/10 PASS

Multi-slot trace, same probe seed as steps 8/9:

```
slot 1 type=$07 alive 1->1 xy=(128,128)->(128,115) dir=$08 anim=5->4   draw=$03->$00 spd=$00->$20
slot 2 type=$03 alive 1->1 xy=( 64, 96)->( 51, 96) dir=$02 anim=1->1   draw=$00->$00 spd=$00->$20
slot 3 type=$05 alive 1->1 xy=( 55,160)->( 27,160) dir=$02 anim=1->1   draw=$00->$00 spd=$20->$20
slot 4 type=$2A alive 1->1 xy=(183, 96)->(155, 96) dir=$02 anim=6->7   draw=$01->$00 spd=$20->$20
>>> WALKER TICK TRACE: PASS <<<
```

Walker motion delta vs step 9 baseline:

| slot | walker | step 9 motion        | step 10 motion        | delta |
|------|--------|----------------------|------------------------|-------|
| 1    | $07 octorock  | (128,128)→(128,115) 13px | (128,128)→(128,115) 13px | unchanged |
| 2    | $03 moblin    | (64,96)→(52,96)     12px | (64,96)→(51,96)     13px | +1 |
| 3    | $05 goriya    | (64,160) STATIC          | (55,160)→(27,160)   28px | UNBLOCKED |
| 4    | $2A stalfos   | (192,96) STATIC          | (183,96)→(155,96)   28px | UNBLOCKED |

Slots 3 + 4 first-sample X already drifted from seed (55 not 64;
183 not 192) because clear_slot_scratch now seeds WALK_SPEED=$20
immediately, so they walked during the boot+settle frames before the
first trace sample.

## Master plan checklist progress

After step 10 — Phase 7 Task 7.2 walker-family checklist:

- [x] octorok walking      (step 6 native UPDATE)
- [x] moblin walking       (step 7 dispatch + step 9 shoot loop unblock)
- [x] stalfos walking      (step 10 default WALK_SPEED)
- [x] goriya walking       (step 10 default WALK_SPEED)
- [ ] darknut walking      (need $0B/$0C UPDATE drain)
- [x] projectile hook      (step 9 c_shoot_if_wanted native, partial —
                            shot UPDATE rows still NULL)
- [ ] probe movement+collision  (movement done; collision via
                                 c_check_monster_collisions exists,
                                 needs probe extension)
- [ ] probe damage+death+drop   (combat hook not wired)
- [ ] commit family             (final phase commit)

## Rolled-forward TODOs

- Central post-dispatch animate/draw hook (or extend bare bodies) —
  goriya/moblin still don't draw sprites.
- Walker_CheckTileCollision (room tile registry).
- Lynel ($01/$02) UPDATE drain.
- Darknut ($0B/$0C) UPDATE drain.
- Rope ($29) / Gel ($2C) wiring (drains exist, just need rows).
- Shot UPDATE rows ($53 flying rock, $5B arrow, $57 sword shot, $5C
  boomerang) + DestroyMonsterShot decrement of ENEMY_SHOT_COUNT.
- `c_obj_shove` native (combat damage hook) — still stubbed.
