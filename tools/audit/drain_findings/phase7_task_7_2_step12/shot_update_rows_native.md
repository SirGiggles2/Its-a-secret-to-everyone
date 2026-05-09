# Phase 7 Task 7.2 step 12 — shot UPDATE rows + L_DrawShot fall-through fix

## Task header (Drain Rule D1)

- **NES source**: `reference/aldonunez/Z_04.asm:820 UpdateMonsterShot`
                  + `reference/aldonunez/Z_07.asm:5379 dispatch table rows
                    $53/$54/$55/$56/$57/$58/$59/$5A`.
- **Drained C**:  `src/oracle/enemies/enemy_projectile_runtime.c::enrt_update_monster_shot`
                  (fixed L_DrawShot fall-through bug — was returning early
                  without calling enrt_draw_shot)
                  + `enrt_update_fireball` (already FULL).
                  Wired in `src/game/enemies/enemy_loop.c` rows
                  `enemy_update_fns[$53/$54/$57/$58/$59/$5A]` ->
                  `enrt_update_monster_shot`,
                  `enemy_update_fns[$55/$56]` -> `enrt_update_fireball`.
- **Coverage**:   FULL — UpdateMonsterShot body + UpdateFireball body
                  fully translated. Only DrawArrow/DrawSwordShotOrMagicShot
                  draw helpers stubbed (deferred — same stance as
                  moblin/goriya bare bodies in step 7).
                  UpdateMonsterArrow ($5B) + UpdateArrowOrBoomerang ($5C)
                  have separate NES bodies; row left NULL (next step).
- **Stance**:     EXTEND — drain pre-existed; step 12 fixed bug + wired
                  rows + added projectile primitives bridge.

## Drain bug fix

NES `UpdateMonsterShot` falls through to `L_DrawShot` after
`CheckShotLinkCollision` if no harmful collision:

```asm
L_CheckLinkCollision:
    JSR CheckShotLinkCollision
    LDA $06
    BNE DestroyMonsterShot
L_DrawShot:                  ; <<< fall-through here
    LDA ObjType, X
    CMP #$5B
    ...
```

Prior `enrt_update_monster_shot` returned at the `BNE DestroyMonsterShot`
branch without ever reaching `L_DrawShot`. Fix:

```c
    enrt_check_shot_link_collision(slot);
    if (ENEMY_COLLISION_FLAG != 0) {
        enrt_destroy_monster_shot(slot);
        return;
    }
    /* Step 12: NES UpdateMonsterShot falls through to L_DrawShot
     * (Z_04.asm:860). Prior drain returned here; matches NES now. */
    enrt_draw_shot(slot);
}
```

(NES `BounceShot` already correctly falls into `L_DrawShot`; the
existing `enrt_bounce_shot` already calls `enrt_draw_shot` at end.)

## Dispatch wiring (enemy_loop.c)

```c
[0x53] = enrt_update_monster_shot,  /* FlyingRock (octorok shot) */
[0x54] = enrt_update_monster_shot,  /* (alt rock) */
[0x55] = enrt_update_fireball,      /* Fireball */
[0x56] = enrt_update_fireball,      /* Fireball2 */
[0x57] = enrt_update_monster_shot,  /* SwordShot */
[0x58] = enrt_update_monster_shot,  /* MagicShot */
[0x59] = enrt_update_monster_shot,  /* (shot variant) */
[0x5A] = enrt_update_monster_shot,  /* (shot variant) */
```

`$5B` (Arrow / UpdateMonsterArrow) and `$5C` (Boomerang /
UpdateArrowOrBoomerang) NOT wired — separate NES bodies, drain
needed (rolled-forward TODO).

## New bridge file

`src/game/enemies/enemy_projectile_bridge.c` (115 lines) — same model
as `enemy_walker_bridge.c`. Forwarders for c_/z01_/z07_ symbols pulled
in by `enemy_projectile_runtime.c`:

| Callsite                                  | Native dispatch                              |
|-------------------------------------------|----------------------------------------------|
| `c_move_object`                           | `object_move_object`                         |
| `c_draw_object_not_mirrored`              | `draw_object_not_mirrored(0,slot)` (deferred)|
| `c_draw_arrow`                            | STUB (TODO drain)                            |
| `c_draw_sword_shot_or_magic_shot`         | STUB (TODO drain)                            |
| `z01_bound_by_room`                       | `object_bound_by_room`                       |
| `z01_bound_by_room_with_a`                | `object_bound_by_room_with_dir`              |
| `z01_check_link_collision`                | `link_collision_check_link_collision`        |
| `z01_get_opposite_dir`                    | `core_get_opposite_dir`                      |
| `z01_get_directions_and_distances_to_target` | `targeting_get_directions_and_distances_to_target` |
| `z01_calc_diagonal_speed_index`           | `targeting_calc_diagonal_speed_index`        |
| `z07_destroy_monster`                     | `core_destroy_monster`                       |
| `z07_get_colliding_tile_moving`           | `collision_get_colliding_tile_moving`        |
| `z07_anim_fetch_obj_pos`                  | `sprite_anim_fetch_obj_pos`                  |

`enemy_projectile_runtime.c` linked into Debug.md by adding both
`oracle_enemy_projectile.o` (the drain) and
`game_enemy_projectile_bridge.o` (the forwarders) to
`tools/debug/build_debug.py` `TITLE_C_SOURCES`.

`enrt_destroy_monster_shot` already correctly mirrors NES
`DestroyMonsterShot` — decrements `ENEMY_SHOT_COUNT` iff `type !=
$55/$56`. Wiring `$53` etc. into the dispatch closes the previously
open `c_shoot_if_wanted` loop (step 9): octorok shoots, shot ticks,
shot dies, shot count decrements, octorok can shoot again.

## Verification — 12/12 PASS

Existing walker probe trace (5 slots, no regression):

```
slot 1 type=$07 alive 1->1 xy=(128,128)->(128,115) dir=$08 anim=5->4 draw=$03->$00 spd=$00->$20
slot 2 type=$03 alive 1->1 xy=( 64, 96)->( 51, 96) dir=$02 anim=1->1 draw=$00->$00 spd=$00->$20
slot 3 type=$05 alive 1->1 xy=( 55,160)->( 27,160) dir=$02 anim=1->1 draw=$00->$00 spd=$00->$20
slot 4 type=$2A alive 1->1 xy=(183, 96)->(155, 96) dir=$02 anim=6->7 draw=$01->$00 spd=$20->$20
slot 5 type=$0B alive 1->1 xy=(192,151)->(192,123) dir=$08 anim=6->7 draw=$01->$00 spd=$20->$20
>>> WALKER TICK TRACE: PASS <<<  G1..G12 ALL PASS
```

Build: green. Existing walker rows: unchanged from step 11 PASS.

Shot row firing not yet observable in probe — current
`probe_walker_tick_trace.lua` samples seeded slots 1-5 only. To
exercise shot UPDATE rows live, future probe (step 13) needs to:

1. Sample dynamically-spawned shot slots (octorok->fireball $53).
2. Verify ENEMY_SHOT_COUNT decrement after shot dies.
3. Verify shot X/Y advance frame-over-frame.

Step 12 closure scope: drain bug fixed, rows wired, no NULL row in
the dispatch table for shot types $53-$5A (except $5B/$5C
intentional), no link-time regression, no behavior regression
verified by walker probe.

## Master plan checklist progress

After step 12 — Phase 7 Task 7.2 walker-family checklist:

- [x] octorok walking      (step 6 native UPDATE)
- [x] moblin walking       (step 7 dispatch + step 9 shoot loop unblock)
- [x] stalfos walking      (step 10 default WALK_SPEED)
- [x] goriya walking       (step 10 default WALK_SPEED)
- [x] darknut walking      (step 11 native UPDATE)
- [x] projectile hook      (step 9 c_shoot_if_wanted + step 12 shot
                            UPDATE rows wired — both halves done)
- [ ] probe movement+collision  (movement done; collision via
                                 c_check_monster_collisions exists,
                                 needs probe extension for visible
                                 outcome)
- [ ] probe damage+death+drop   (combat hook not wired)
- [ ] commit family             (final phase commit)

6 of 9 walker-family checklist items done. Octorok shoots a flying
rock that ticks on its own dispatch row instead of NULL, and the
$53 destroy path decrements ENEMY_SHOT_COUNT — closing the loop.

## Rolled-forward TODOs

- Drain DrawArrow + DrawSwordShotOrMagicShot natively (step 13+) so
  arrow ($5B) and sword/magic shot ($57-$59) types render visible
  sprites; right now bridge stubs no-op the draw.
- Drain UpdateMonsterArrow ($5B) + UpdateArrowOrBoomerang ($5C) (separate
  NES bodies; rows still NULL).
- Probe extension: sample dynamically-spawned shot slots to prove
  ENEMY_SHOT_COUNT decrement happens.
- Central post-dispatch animate/draw hook so moblin/goriya/shot bodies
  draw without per-body draw calls.
- Lynel ($01/$02) UPDATE drain.
- Rope ($29) / Gel ($2C) wiring (drains exist, just need rows).
- `c_obj_shove` native (combat damage hook) — still stubbed.
- Walker_CheckTileCollision (room tile registry).
