# Phase 7 Task 7.4 step 2b — zora dispatch wire ($11) + UpdateBurrower drain

## Task header (Drain Rule D1)

- **NES source**: `Z_07.asm:5601 InitObject_JumpTable` row $11 (=
                  `ResetObjMetastateAndTimer`) +
                  `Z_07.asm:5295 UpdateObject_JumpTable` row $11 (=
                  `UpdateZora` @ `Z_04.asm:1920`).
                  Inner chain: `UpdateBurrower` @ `Z_04.asm:2603` +
                  `Burrower_AnimateDrawAndCheckCollisions` @ `Z_04.asm:2661`
                  + 3 state tables (`BlueLeeverState{QSpeeds,Times,AnimTimes}`
                  @ `Z_04.asm:2590..2598`).
- **Drained C**:  INIT — `core_reset_obj_metastate_and_timer` already
                  drained @ `src/game/core/core_dispatch.c:455`.
                  UPDATE — `enrt_update_zora` @
                  `src/oracle/enemies/enemy_walker_runtime.c:174` calls
                  `c_update_burrower(slot)` + zora-specific shoot/destroy
                  tail. `c_update_burrower` is now a NATIVE drain at
                  `src/game/enemies/enemy_jumper_bridge.c` (this step).
- **Coverage**:   FULL for $11 zora INIT/UPDATE. Burrower body is shared
                  with $0F BlueLeever / $10 RedLeever (NOT yet wired —
                  those rows go through `UpdateBlueLeever` /
                  `UpdateRedLeever` wrappers that prefix-set turn rate
                  and call `Wanderer_TargetPlayer` before falling into
                  `UpdateBurrower`; deferred to a later step).
- **Stance**:     ADOPT (UPDATE drain linked verbatim, INIT drain reused
                  via existing `core_reset_obj_metastate_and_timer`) +
                  EXTEND (`c_update_burrower` translated NES-asm to C
                  per Rule D1 because the legacy bank
                  `c_shims.asm:4625 c_update_burrower` is not linked
                  into `Debug.md`).

## RAM cell map (NES Variables.inc -> state/enemy_state.h)

| NES name              | NES addr | C macro              |
|-----------------------|----------|----------------------|
| `ObjTimer`            | `$0028`  | `ENEMY_MOVE_TIMER`   |
| `ObjState`            | `$00AC`  | `ENEMY_STATE_TIMER`* |
| `ObjY`                | `$0084`  | `ENEMY_Y`            |
| `ObjDir`              | `$0098`  | `ENEMY_DIR`          |
| `ObjType`             | `$034F`  | `ENEMY_TYPE`         |
| `ObjQSpeedFrac`       | `$03BC`  | `ENEMY_WALK_SPEED`   |
| `ObjAnimFrame`        | `$03E4`  | `ENEMY_DRAW_FRAME`   |
| `ObjMetastate`        | `$0405`  | `ENEMY_METASTATE`    |
| `ActiveRedLeeverCount`| `$0510`  | `RAM(0x0510)` (raw)** |

\* Name "STATE_TIMER" is misleading — `ENEMY_STATE_TIMER` IS NES
  `ObjState`. Verified via `reference/aldonunez/Variables.inc:53`
  (`ObjState := $AC`). The cell that's named `ENEMY_AI_STATE` ($0444)
  is a different cell (NES `ObjStateTimer`).

\** `RAM(0x0510)` is also aliased as `ENEMY_GLEEOK_ANIM_CNTR` —
  shared cell across non-coexisting subsystems (gleeok / red-leever
  rooms are mutually exclusive on NES).

## Wired dispatch

| Hex | NES type | INIT row                            | UPDATE row          | Drain |
|-----|----------|-------------------------------------|---------------------|-------|
| $11 | Zora     | `core_reset_obj_metastate_and_timer`| `enrt_update_zora`  | core_dispatch.c:455 + enemy_walker_runtime.c:174 (+ jumper_bridge.c::c_update_burrower) |

## Native primitives composed

`c_update_burrower` body composes already-linked native bodies:

| Primitive                                  | Native body                            |
|--------------------------------------------|----------------------------------------|
| `sprite_anim_advance_and_fetch(val, slot)` | `src/game/world/sprite_dispatch.c:105` |
| `draw_object_mirrored(frame, slot)`        | `src/game/world/draw_dispatch.c:404`   |
| `link_collision_check_monster_collisions(slot)` | `src/game/combat/link_collision_dispatch.c:263` |

Plus 3 NES data tables transcribed verbatim:

```c
BlueLeeverStateQSpeeds[6]  = { $08, $0A, $10, $20, $10, $0A }; // Z_04.asm:2590
BlueLeeverStateTimes[6]    = { $80, $20, $0F, $FF, $10, $60 }; // Z_04.asm:2593
BlueLeeverStateAnimTimes[6]= { $10, $0B, $01, $05, $01, $0B }; // Z_04.asm:2596
```

## State machine summary (NES UpdateBurrower)

```
if ObjTimer != 0:
    skip cycle, go @Animate
else:
    if zora and state == 1:
        ObjDir = (ObjY[slot] < player_Y) ? 2 : 3   // front/back frame
    state = (state + 1) % 6
    ObjQSpeedFrac = BlueLeeverStateQSpeeds[state]
    ObjTimer      = BlueLeeverStateTimes[state]
@Animate:
    sprite_anim_advance_and_fetch(BlueLeeverStateAnimTimes[state], slot)
    if state == 0: return
    if zora and state in {2,3,4}:
        frame = ObjDir          // front/back saved earlier
    else:
        frame = (state - 1) * 2 + ObjAnimFrame
    draw_object_mirrored(frame, slot)
    if zora:
        if state in {2, 4}: do_collisions
    if state == 3: do_collisions
    if !do_collisions: return
    link_collision_check_monster_collisions(slot)
    if dying and type == RedLeever ($10):
        ActiveRedLeeverCount--
```

## Build verification

`python tools/debug/build_debug.py` — clean post step 2b wire.
Active scope `src/game/enemies/**`. No new `RoomRom/` files per WT-5.

## Step 2 split close

Step 2a (commit `ce5baca1`) wired $1F BoulderSet + $20 Boulder.
Step 2b (this step) wires $11 Zora and lands the `c_update_burrower`
native drain. Master plan step 2 (per Task 7.4 step 1 audit) is now
fully closed.

Steps 3..11 unchanged from step 1 audit doc sequencing.
