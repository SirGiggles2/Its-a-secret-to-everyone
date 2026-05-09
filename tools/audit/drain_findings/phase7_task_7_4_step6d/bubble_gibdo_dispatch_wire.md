# Phase 7 Task 7.4 step 6d — bubble + gibdo UPDATE wires

## Task header (Drain Rule D1)

- **NES source**: `Z_07.asm:5295 UpdateObject_JumpTable` rows
                  $2B BlueBubble / $2C RedBubble / $2D BlueBubble2 ->
                  `UpdateBubble`, and $30 Gibdo -> `UpdateGibdo`. Both
                  share the wanderer-common chain (`UpdateCommonWanderer`
                  + animate-and-draw-common-object + check-link /
                  monster collisions).
- **Drained C**:  Existing oracle drains, no new bodies.
                  - Bubble: `enrt_update_bubble` @
                    `src/oracle/enemies/enemy_walker_runtime.c:14`.
                  - Gibdo:  `enrt_update_gibdo`  @
                    `src/oracle/enemies/enemy_common_runtime.c:22`.
- **Coverage**:   PARTIAL for $2B/$2C/$2D (UPDATE only — bubbles have
                  no special INIT row in `Z_07.asm:5601`; default scratch
                  init applies). FULL for $30 (gibdo has no init row in
                  `Z_07.asm:5601` either; default scratch init applies).
                  Per `Z_07.asm:5601` `InitObject_JumpTable` both
                  families fall through to the no-op default.
- **Stance**:     ADOPT — drained bodies linked verbatim. No bridge
                  edits needed; every primitive resolves through bridges
                  already wired by Tasks 7.2 / 7.3.

## RAM cell map (NES Variables.inc -> state/enemy_state.h)

| NES name                | NES addr   | C macro                       |
|-------------------------|------------|-------------------------------|
| `ObjType`               | `$034F`    | `ENEMY_TYPE`                  |
| `BubbleEffect`          | (RAM ext)  | `ENEMY_BUBBLE_EFFECT`         |
| `BubbleStatus`          | (RAM ext)  | `ENEMY_BUBBLE_STATUS`         |
| `CurSpriteAttrRow`      | (RAM ext)  | `ENEMY_CUR_SPRITE_ATTR_ROW`   |
| `ObjCollisionFlag`      | (RAM ext)  | `ENEMY_COLLISION_FLAG`        |

Bubble palette select:
- BlueBubble ($2B): palette = `CurSpriteAttrRow & 3` (cycling).
- RedBubble  ($2C): palette = $01 (fixed by `obj_type - $2B`).
- BlueBubble2 ($2D): palette = $02.

Gibdo: no palette select; uses `c_draw_object_not_mirrored_with_frame(0)`.

## Wired dispatch

| Hex  | NES type    | INIT row | UPDATE row           | Drain |
|------|-------------|----------|----------------------|-------|
| $2B  | BlueBubble  | (none)   | `enrt_update_bubble` | `enemy_walker_runtime.c:14` |
| $2C  | RedBubble   | (none)   | `enrt_update_bubble` | `enemy_walker_runtime.c:14` |
| $2D  | BlueBubble2 | (none)   | `enrt_update_bubble` | `enemy_walker_runtime.c:14` |
| $30  | Gibdo       | (none)   | `enrt_update_gibdo`  | `enemy_common_runtime.c:22` |

## Native primitives composed (already linked)

| Primitive                                 | Native body                                     |
|-------------------------------------------|-------------------------------------------------|
| `wanderer_update_common(rate, slot)`      | `enemy_wanderer_runtime.c` (Task 7.2 base)      |
| `enrt_update_common_wanderer(rate, slot)` | `enemy_wanderer_runtime.c:44`                   |
| `z01_anim_set_sprite_desc_attrs(pal)`     | `enemy_walker_bridge.c:206`                     |
| `enrt_animate_and_draw_common_object`     | `enemy_walker_bridge.c:195`                     |
| `z01_check_link_collision(slot)`          | `enemy_projectile_bridge.c:53`                  |
| `c_check_monster_collisions(slot)`        | `combat/link_collision_dispatch.c`              |
| `z07_anim_advance_and_fetch(val, slot)`   | `enemy_walker_bridge.c:182`                     |
| `z07_anim_set_obj_hflip(slot)`            | `enemy_walker_bridge.c:187`                     |
| `c_draw_object_not_mirrored_with_frame`   | `world/draw_dispatch.c`                         |

## Build verification

`python tools/debug/build_debug.py` — clean post step 6d wire. Active
scope `src/game/enemies/**`. No new `RoomRom/` files per WT-5.

## Why a separate step

Steps 6a / 6b closed $22 / $1E (FlyingGhini / Armos UPDATE rows).
Step 6c (deferred) blocks on `ChangeTileObjTiles` native drain for
the shared `InitArmosOrFlyingGhini` body.

Step 6d picks up the *unblocked* drained-but-unwired UPDATE rows that
sit in adjacent dispatch positions but require no new bridge work:
$2B/$2C/$2D bubbles and $30 gibdo. All composed primitives were
already resolved by Tasks 7.2 / 7.3 bridge work; the only edit is the
4 dispatch rows + 2 externs in `enemy_loop.c`.

This advances Task 7.4 dispatch coverage from 23 → 27 wired UPDATE
rows without taking on the deferred ChangeTileObjTiles drain.
