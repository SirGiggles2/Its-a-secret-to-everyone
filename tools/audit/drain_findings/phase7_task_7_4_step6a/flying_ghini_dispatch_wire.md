# Phase 7 Task 7.4 step 6a — $22 FlyingGhini UPDATE wire

## Task header (Drain Rule D1)

- **NES source**: `Z_07.asm:5295 UpdateObject_JumpTable` row $22 =
                  `UpdateFlyingGhini` @ `Z_04.asm:3967`. Inner chain:
                  `ControlFlyingGhiniFlight` @ `Z_04.asm:3984` +
                  `Flyer_GhiniDecideState` @ `Z_04.asm:3995` +
                  `Flyer_SetFlyingStateAnd6Turns` @ `Z_04.asm:4081` +
                  `MoveFlyer` + `Anim_FetchObjPosForSpriteDescriptor` +
                  `DrawGhiniAndCheckCollisions` @ `Z_04.asm:3093`.
- **Drained C**:  UPDATE — `enrt_update_flying_ghini` @
                  `src/game/enemies/enemy_flyer_bridge.c` (this step,
                  appended). Composes already-drained primitives:
                  `c_control_flying_ghini_flight` (this step) +
                  `c_move_flyer` + `enrt_draw_ghini_and_check_collisions`
                  (`src/oracle/enemies/enemy_walker_runtime.c:295`).
                  State-1 decision via existing
                  `enrt_flyer_ghini_decide_state` @
                  `src/oracle/enemies/enemy_flyer_runtime.c:44`.
- **Coverage**:   PARTIAL for $22. UPDATE wired here. INIT row
                  ($22 = `InitArmosOrFlyingGhini` @ `Z_04.asm:3150`)
                  deferred to step 6b — body is shared with $1E armos
                  and reaches `ChangeTileObjTiles` +
                  `SecretArmosRoomIds[7]` + `SecretArmosXs[7]` +
                  `GetRoomFlagUWItemState` + `PlaySecretFoundTune`.
                  `c_change_tile_obj_tiles` only resolves via
                  `c_shims.asm:4669` (legacy bank, not linked into
                  `Debug.md`).
- **Stance**:     ADOPT (`enrt_draw_ghini_and_check_collisions` linked
                  verbatim from drain, `enrt_flyer_ghini_decide_state`
                  reused) + EXTEND (`c_control_flying_ghini_flight` +
                  `enrt_update_flying_ghini` translated NES-asm to C
                  per Rule D1 because the chain is not in `Debug.md`'s
                  legacy bank).

## RAM cell map (NES Variables.inc -> state/enemy_state.h)

| NES name              | NES addr | C macro              |
|-----------------------|----------|----------------------|
| `Flyer_ObjFlyingState`| `$0444`  | `ENEMY_AI_STATE`     |
| `Flyer_ObjTurns`      | `$043C`  | `ENEMY_TURN_TIMER`   |
| `Flyer_ObjDistTraveled`| `$0437` | `ENEMY_FLAP_PHASE`   |
| `InvClock`            | `$066C`  | `ENEMY_PAUSE_FLAG`   |
| `Random+1`            | `$XX+1`  | `ENEMY_RNG_A` (slot) |

`Flyer_GhiniDecideState` keys off Random+1 (RNG_A) with thresholds
$A0 / $08, vs keese on RNG_B with $A0 / $20 and peahat on RNG_A with
$B0 / $20. All three are already drained as separate `enrt_flyer_*_decide_state`
oracle bodies.

## Wired dispatch

| Hex | NES type    | INIT row          | UPDATE row                | Drain |
|-----|-------------|-------------------|---------------------------|-------|
| $22 | FlyingGhini | (deferred to 6b)  | `enrt_update_flying_ghini`| `src/game/enemies/enemy_flyer_bridge.c` (step 6a) |

## Native primitives composed

`enrt_update_flying_ghini` body composes already-linked native /
drained bodies:

| Primitive                                  | Native body                                    |
|--------------------------------------------|------------------------------------------------|
| `c_control_flying_ghini_flight(slot)`      | `enemy_flyer_bridge.c` (step 6a)               |
| `c_move_flyer(slot)`                       | `enemy_flyer_bridge.c:74`                      |
| `enrt_draw_ghini_and_check_collisions`     | `enemy_walker_runtime.c:295`                   |

`c_control_flying_ghini_flight` 6-row dispatch composes:

| State | Body                          | Source                                    |
|-------|-------------------------------|-------------------------------------------|
| 0     | `enrt_flyer_speed_up`         | `enemy_flyer_runtime.c:22`                |
| 1     | `enrt_flyer_ghini_decide_state` | `enemy_flyer_runtime.c:44`              |
| 2     | `flyer_chase` (static)        | `enemy_flyer_bridge.c:171`                |
| 3     | `flyer_wander` (static)       | `enemy_flyer_bridge.c:257`                |
| 4     | `enrt_flyer_slow_down`        | `enemy_flyer_runtime.c:17`                |
| 5     | `enrt_flyer_delay`            | `enemy_flyer_runtime.c:126`               |

## State machine summary (NES UpdateFlyingGhini)

```
if InvClock == 0:
    ControlFlyingGhiniFlight(slot)    # state-table 0..5
    MoveFlyer(slot)                   # apply velocity to ObjX/ObjY
DrawGhiniAndCheckCollisions(slot)     # frame select + DrawObjectNotMirrored
                                      # + CheckLinkCollision
```

## Build verification

`python tools/debug/build_debug.py` — clean post step 6a wire. Active
scope `src/game/enemies/**`. No new `RoomRom/` files per WT-5.

## Step 6 split rationale

The Task 7.4 step 1 audit doc proposed step 6 wire $22 + $1E INIT/UPDATE
in a single commit. Investigation during step 6 found that
`InitArmosOrFlyingGhini` reaches `ChangeTileObjTiles` (Z_07.asm:1114) +
`SecretArmosRoomIds[7]` + `MapScreenPosToPpuAddr` +
`ChangePlayMapSquareOW` — substantial NES-asm chain not yet drained
into `Debug.md`'s native build. `c_change_tile_obj_tiles` only resolves
via `c_shims.asm:4669` (legacy bank).

Drain Rule D1 forbids stubs. Splitting:

- **6a (this step)**: wire $22 UPDATE only — drained chain reaches
  resolved primitives (after the new bridge add). $22 INIT row left
  NULL; spawn-time AI cells default to scratch (ENEMY_DIR=0,
  ENEMY_AIR_SPEED=0, MAX_AIR_SPEED unset). State machine begins at
  state 0 = Flyer_SpeedUp which seeds AIR_SPEED via the speed-ramp
  itself.
- **6b**: drain `c_change_tile_obj_tiles` natively (Z_07.asm:1114) +
  drain `InitArmosOrFlyingGhini` fully + wire $22 INIT + $1E
  Armos INIT/UPDATE rows.

Steps 7..11 unchanged from step 1 audit doc sequencing.
