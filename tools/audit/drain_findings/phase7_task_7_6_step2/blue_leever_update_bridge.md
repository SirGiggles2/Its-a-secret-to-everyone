# Phase 7 Task 7.6 step 2 — BlueLeever UPDATE bridge ($0F)

## Task header (Drain Rule D1)

- **NES source**: `Z_04.asm:2599-2647 UpdateBlueLeever` (~50 lines):
                  ```
                  UpdateBlueLeever:
                      LDA #$A0
                      STA ObjTurnRate, X       ; $041F = ENEMY_AIR_SPEED
                      JSR Wanderer_TargetPlayer
                  UpdateBurrower:                ; fall-through
                      ; ... (see step 2 c_update_burrower, already drained)
                  ```

- **Drained C**:  - Wanderer_TargetPlayer @
                    `src/oracle/enemies/enemy_wanderer_runtime.c:63`
                    (`enrt_wanderer_target_player`, drained Task 7.x).
                  - UpdateBurrower @ `enemy_jumper_bridge.c:267`
                    (`c_update_burrower`, drained Task 7.4 step 2b).
                  - New body `enrt_update_blue_leever` @
                    `enemy_jumper_bridge.c` (this step) — 3-line bridge:
                    ```c
                    void enrt_update_blue_leever(unsigned int slot) {
                        ENEMY_AIR_SPEED(slot) = 0xA0u;
                        enrt_wanderer_target_player(slot);
                        c_update_burrower(slot);
                    }
                    ```

- **Coverage**:   FULL on UPDATE for $0F BlueLeever — INIT wired step 1,
                  UPDATE wired this step.

- **Stance**:     EXTEND — bridge body composes drained twins; no new
                  primitives.

## Wired dispatch (delta from step 1)

UPDATE delta:

| Hex | NES type   | UPDATE row              | step |
|-----|------------|-------------------------|------|
| $0F | BlueLeever | `enrt_update_blue_leever` | 2    |

INIT delta: none (already wired step 1).

## Task 7.6 dispatch coverage end-state (after step 2)

INIT  table: 42 wired rows (no change since step 1).
UPDATE table: 48 -> 49 wired rows (+1).

## Build verification

`python tools/debug/build_debug.py` — clean post step 2 wire. Active
scope: `src/game/enemies/enemy_jumper_bridge.c` (1 new bridge body +
1 extern) + `src/game/enemies/enemy_loop.c` (1 extern + 1 dispatch
row + comment block). No new files, no new TUs.

## Step 3 sequencing

Step 3 — RedLeever UPDATE bridge ($10).
NES `UpdateRedLeever` @ `Z_04.asm:2737-2950+` (~250 lines, much bigger
than BlueLeever):
- State 0 spawn-from-Link: gates on RedLeeverLongTimer + ActiveRedLeeverCount
  (max 2). If safe to spawn: places leever at Link's X/Y + offset $28/$D8,
  validates safe tile via GetCollidableTileStill, INC ActiveRedLeeverCount,
  ResetAnimCounter, ASL into RedLeeverLongTimer, jump
  RedLeever_CycleStateDrawAndCheckCollisions, ReverseObjDir.
- State 3 shove/move/boundary cycle.
- Other states fall through to AnimateAndCheckCollisions.

State machine reuses `c_update_burrower` for state-cycle-and-draw
once the spawn gating clears (RedLeever_CycleStateDrawAndCheckCollisions
shape mirrors BlueLeever but with own state tables).

Step 4 — Task 7.6 family close:
- Confirm-only $11 Zora UPDATE (already wired Task 7.4 step 2b),
  $0D/$0E Tektite UPDATE (Task 7.4 step 2a), $2B-$2D Bubble UPDATE
  (Task 7.4 step 6d).
- Audit-doc rollup, master plan tick.
