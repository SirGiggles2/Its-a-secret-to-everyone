# Phase 7 Task 7.4 step 6b — $1E Armos UPDATE wire

## Task header (Drain Rule D1)

- **NES source**: `Z_07.asm:5295 UpdateObject_JumpTable` row $1E =
                  `UpdateArmos` @ `Z_04.asm:3302`. Inner chain:
                  `UpdateGoriya` @ `Z_04.asm` (drained as
                  `enrt_update_goriya` at `enemy_wanderer_runtime.c:169`)
                  + `DrawArmosAndCheckCollisions` @ `Z_04.asm:3332`
                  (drained inline as static
                  `armos_draw_and_check_collisions` in
                  `enemy_walker_bridge.c`).
- **Drained C**:  UPDATE — `enrt_update_armos` @
                  `src/game/enemies/enemy_walker_bridge.c` (this step,
                  appended). Composes `enrt_update_goriya` +
                  static helper `armos_draw_and_check_collisions` +
                  ObjShoveDir / ObjAnimCounter gates.
- **Coverage**:   PARTIAL for $1E. UPDATE wired here. INIT row
                  ($1E + $22 = `InitArmosOrFlyingGhini` @
                  `Z_04.asm:3150`) still deferred — body reaches
                  `ChangeTileObjTiles` + `SecretArmosRoomIds[7]` +
                  `MapScreenPosToPpuAddr` + `ChangePlayMapSquareOW` +
                  `GetRoomFlagUWItemState` + `PlaySecretFoundTune`,
                  none of which have native drains in `Debug.md`.
                  `c_change_tile_obj_tiles` only resolves via
                  `c_shims.asm:4669` (legacy bank, not linked).
- **Stance**:     ADOPT (UpdateGoriya linked verbatim from drain) +
                  EXTEND (`enrt_update_armos` +
                  `armos_draw_and_check_collisions` translated
                  NES-asm to C per Rule D1).

## RAM cell map (NES Variables.inc -> state/enemy_state.h)

| NES name        | NES addr | C macro              |
|-----------------|----------|----------------------|
| `ObjShoveDir`   | `$00C0`  | `OBJ(0x00C0, slot)` (`NES_OBJ_SHOVE_DIR`) |
| `ObjAnimCounter`| `$03B5`  | `ENEMY_ANIM_TIMER`   |
| `ObjAnimFrame`  | `$03E4`  | `ENEMY_DRAW_FRAME`   |
| `ObjDir`        | `$0098`  | `ENEMY_DIR`          |
| `ObjTimer`      | `$0028`  | `ENEMY_MOVE_TIMER`   |
| `ObjMetastate`  | `$0405`  | `ENEMY_METASTATE`    |
| `ObjType`       | `$034F`  | `ENEMY_TYPE`         |

## Wired dispatch

| Hex | NES type | INIT row              | UPDATE row          | Drain |
|-----|----------|-----------------------|---------------------|-------|
| $1E | Armos    | (deferred — see 6c)   | `enrt_update_armos` | `src/game/enemies/enemy_walker_bridge.c` (step 6b) |

## Native primitives composed

`enrt_update_armos` body composes already-linked native / drained
bodies:

| Primitive                                  | Native body                                    |
|--------------------------------------------|------------------------------------------------|
| `enrt_update_goriya(slot)`                 | `enemy_wanderer_runtime.c:169`                 |
| `sprite_anim_advance_and_fetch(0, slot)`   | `world/sprite_dispatch.c:105`                  |
| `draw_object_not_mirrored_with_frame`      | `world/draw_dispatch.c:426`                    |
| `link_collision_check_link_collision`      | `combat/link_collision_dispatch.c`             |
| `link_collision_check_monster_collisions`  | `combat/link_collision_dispatch.c:263`         |

## State machine summary (NES UpdateArmos)

```
UpdateGoriya(slot)                          # walker AI + boomerang
if ObjShoveDir != 0:
    goto draw_and_check
ObjAnimCounter -= 1
if ObjAnimCounter != 0:
    goto draw_and_check
ObjAnimCounter = 6                          # 6-frame pose hold
ObjAnimFrame ^= 2                           # advance pose pair
draw_and_check:
    sprite_anim_advance_and_fetch(0, slot)
    frame = (ObjDir == 8 ? 1 : 0) + ObjAnimFrame
    DrawObjectNotMirrored(frame)
    if ObjTimer != 0:
        CheckLinkCollision(slot)            # fading-in: link contact only
    else:
        CheckMonsterCollisions(slot)        # full: weapon damage allowed
        if ObjMetastate != 0:
            ObjType = $5D                    # convert to DeadDummy
```

## Build verification

`python tools/debug/build_debug.py` — clean post step 6b wire. Active
scope `src/game/enemies/**`. No new `RoomRom/` files per WT-5.

## Step 6 split close

- 6a (commit `4dc8466a`): wired $22 FlyingGhini UPDATE.
- 6b (this step):         wires $1E Armos UPDATE.
- 6c (next):              drain `c_change_tile_obj_tiles` natively +
                          drain `InitArmosOrFlyingGhini` fully + wire
                          $1E + $22 INIT rows. Audit-doc step 6 closes
                          when 6c lands.

Steps 7..11 unchanged from step 1 audit doc sequencing.
