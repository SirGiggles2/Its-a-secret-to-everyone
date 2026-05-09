# Phase 7 Task 7.6 step 1 — Leever INIT pair ($0F / $10)

## Task header (Drain Rule D1)

- **NES source**: `Z_07.asm:5617` InitObject_JumpTable rows
                  $0F BlueLeever and $10 RedLeever both -> `InitLeever`
                  (.ADDR InitLeever twice). `InitLeever` body @
                  `Z_04.asm:1857-1862`:
                  ```
                  InitLeever:
                      LDA #$05
                      STA RedLeeverLongTimer
                      JMP ResetObjMetastateAndTimer
                  ```
                  (~3 lines: long-timer seed + per-slot metastate
                  reset).

- **Drained C**:  `enrt_init_leever` @
                  `src/oracle/enemies/enemy_walker_runtime.c:37`
                  (drained pre-Task 7.5).

- **Coverage**:   FULL on INIT for both $0F and $10. UPDATE rows still
                  unset (they need bridge bodies — separate steps).

- **Stance**:     ADOPT — drained twin reused as-is. No bridge edits,
                  no new TUs, no new externs (single line added in
                  enemy_loop.c).

## Wired dispatch (delta from Task 7.5 close)

INIT delta:

| Hex | NES type    | INIT row             | step |
|-----|-------------|----------------------|------|
| $0F | BlueLeever  | `enrt_init_leever`   | 1    |
| $10 | RedLeever   | `enrt_init_leever`   | 1    |

UPDATE delta: none (step 1 is INIT-only).

## Task 7.6 dispatch coverage end-state (after step 1)

INIT  table: 40 -> 42 wired rows (+2).
UPDATE table: 48 wired rows (no change).

## Build verification

`python tools/debug/build_debug.py` — clean post step 1 wire. Active
scope: `src/game/enemies/enemy_loop.c` only (extern + 2 INIT rows +
comment block). No new files, no bridge edits.

## Step 2 sequencing

Step 2 — BlueLeever UPDATE bridge ($0F).
NES `UpdateBlueLeever` @ `Z_04.asm:2599-2647` (~50 lines):
- ObjTurnRate=$A0 + Wanderer_TargetPlayer.
- UpdateBurrower fall-through (state machine + zora-special branch
  + state-cycle 0..5 + table lookup BlueLeeverStateQSpeeds /
  BlueLeeverStateTimes / BlueLeeverStateAnimTimes + animate /
  draw / collisions / red-leever-decrement).

Step 3 — RedLeever UPDATE bridge ($10).
NES `UpdateRedLeever` @ `Z_04.asm:2737-2950+` (~250 lines):
- State 0 spawn-from-Link + ActiveRedLeeverCount cap (max 2) +
  RedLeever_CycleStateDrawAndCheckCollisions + ReverseObjDir.
- State 3 shove / move / boundary / unwalkable-tile cycle.
- Other states fall through to AnimateAndCheckCollisions.

Step 4 — water/terrain constraints + per-special probe + family
close. Tektite/zora/bubble UPDATE rows already wired in Task 7.4 +
7.5; Task 7.6 close documents the family + ticks master plan.
