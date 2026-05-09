# Phase 7 Task 7.6 step 3 — RedLeever UPDATE bridge ($10)

## Task header (Drain Rule D1)

- **NES source**: `Z_04.asm:2737-2961 UpdateRedLeever` (~225 lines):
                  - State 0 spawn-from-Link gating block
                    (RedLeeverLongTimer + ActiveRedLeeverCount cap-2 +
                    horizontal/vertical placement + safe-tile gate +
                    long-timer + cycle-state + reverse-dir).
                  - @CheckOtherStates state-3 shove/move/boundary
                    branch + fall-through @AnimateIfTime.
                  - RedLeever_CycleStateDrawAndCheckCollisions (Z_04.asm:2935).
                  - RedLeever_AnimateAndCheckCollisions (Z_04.asm:2958)
                    -> JMP `Burrower_AnimateDrawAndCheckCollisions`.
                  - Tables RedLeeverState{QSpeeds,Times,AnimTimes}
                    (Z_04.asm:2728-2735).

- **Drained C**:  - `enrt_update_red_leever` @ `enemy_jumper_bridge.c`
                    (this step) — full state machine.
                  - `red_leever_cycle_state_draw_and_check_collisions`
                    + `red_leever_animate_and_check_collisions` static
                    helpers in same TU.
                  - `burrower_animate_draw_and_check_collisions` static
                    helper — shared post-cycle path
                    (parameterized on `anim_rollover_val` so RedLeever
                    passes its own table value).
                  - Tables `RedLeeverStateQSpeeds[6]`,
                    `RedLeeverStateTimes[6]`,
                    `RedLeeverStateAnimTimes[6]` — verbatim NES.

- **Coverage**:   FULL on UPDATE for $10 RedLeever. INIT wired step 1.

- **Stance**:     EXTEND. Native bridge body, composes drained twins:
                  - `core_reverse_obj_dir` (NES ReverseObjDir)
                  - `collision_get_collidable_tile_still`
                    + `collision_get_colliding_tile_moving`
                  - `object_bound_by_room`
                  - `c_obj_shove`, `c_move_object`
                  - `sprite_anim_advance_and_fetch`,
                    `draw_object_mirrored`,
                    `link_collision_check_monster_collisions`.

## RAM cell aliasing notes

Per NES Variables.inc:
- `RedLeeverLongTimer := $4D`  -> `ENEMY_LEEVER_TIMER` /
  `RAM(0x004D)` (ENEMY_LEEVER_TIMER alias is the canonical name).
- `ActiveRedLeeverCount := $510` -> `RAM(0x0510)`. Note the existing
  `ENEMY_GLEEOK_ANIM_CNTR` alias overlaps the same cell — they're
  semantically distinct uses (gleeok in $42-$46 vs leever in $10).
- `ObjectFirstUnwalkableTile := $34A` -> `RAM(0x034A)`.
- `InvClock := $66C` -> `ENEMY_PAUSE_FLAG`.
- `ObjStunTimer := $3D` -> `ENEMY_STUN_TIMER(slot)`.

## State-machine summary

| State | NES behavior                                                    |
|-------|------------------------------------------------------------------|
| 0     | Spawn-from-Link gate. Bumps count + cycles to state 1.          |
| 1     | Mound emerge (timer $10). Animate only.                         |
| 2     | Burrowing (timer $08). Animate only.                            |
| 3     | Walking toward Link. Move/shove/boundary handling. Collisions.  |
| 4     | Burrowing (timer $08). Animate only.                            |
| 5     | Mound retreat (timer $10). Cycle to 0 -> DEC count.             |

## Wired dispatch (delta from step 2)

UPDATE delta:

| Hex | NES type   | UPDATE row              | step |
|-----|------------|-------------------------|------|
| $10 | RedLeever  | `enrt_update_red_leever`| 3    |

INIT delta: none (already wired step 1).

## Task 7.6 dispatch coverage end-state (after step 3)

INIT  table: 42 wired rows (no change since step 1).
UPDATE table: 49 -> 50 wired rows (+1).

Family $0F BlueLeever / $10 RedLeever both INIT + UPDATE now wired.

## Build verification

`python tools/debug/build_debug.py` — clean post step 3 wire. Active
scope: `src/game/enemies/enemy_jumper_bridge.c` (~210 line bridge
section + 3 tables + static helpers) + `src/game/enemies/enemy_loop.c`
(1 extern + 1 dispatch row + comment block). No new files.

## Step 4 sequencing — Task 7.6 family close

Task 7.6 family includes:
- $0F BlueLeever — INIT (step 1) + UPDATE (step 2) wired.
- $10 RedLeever  — INIT (step 1) + UPDATE (step 3) wired.
- $11 Zora      — INIT + UPDATE already wired Task 7.4 step 11/2b.
- $0D BlueTektite + $0E RedTektite — INIT + UPDATE wired Task 7.4
  step 6e/2a.
- $2B BlueBubble + $2C RedBubble + $2D BlueBubble2 — INIT + UPDATE
  wired Task 7.4 step 6e/6d.

Step 4 = audit-doc rollup + master plan tick. Water/terrain
constraints are subsumed by `c_update_burrower`'s state-3 boundary
gate (object_bound_by_room) + the per-leever spawn-tile gate
(collision_get_collidable_tile_still vs ObjectFirstUnwalkableTile).
Per-special probe deferred to phase-7-close batch.
