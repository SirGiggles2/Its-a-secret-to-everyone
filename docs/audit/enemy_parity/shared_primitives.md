# Shared-Primitive Dependency Graph

Bridge primitives consumed by multiple families. When a fix touches a
primitive in this list, every consumer across families must be
re-probed to catch cross-family regression — including out-of-scope
types ($07-$0A Octorok, $0D-$0E Tektite).

## enemy_loop_tick prefix (universal)

Runs once per slot per frame for ALL enemy types. Changes here affect
every wired type including out-of-scope.

| Symbol / site                                  | Touches                          |
|---                                             |---                               |
| `@CheckChaseTarget` port (enemy_loop.c:1292)   | `$0060`, `$0061`, `$0062`, `$004A` |
| ObjInvincibility decrement (enemy_loop.c:1334) | `$04F0+s` for all slots          |
| `native_init_obj_attr` (enemy_loop.c:90)       | `$04BF+s` at init                |
| `native_init_obj_hp` (enemy_loop.c:48)         | `$04B8+s` at init                |
| `clear_slot_scratch` (enemy_loop.c:1064)       | `$0028+s`, `$03BC+s`, `$03C8+s`, `$04D8+s` defaults |

**Audit gate**: any commit modifying enemy_loop.c prefix → re-probe
A3 baseline (Octorok + Tektite) BEFORE commit lands.

## Walker-family primitives (enemy_walker_bridge.c)

Consumers: $01-$06, $0B-$0C, $0F-$10, $12-$17, $1E, $21, $27, $28,
$2A-$2D, $30, $3F, $40 — AND out-of-scope $07-$0A.

| Symbol                                         | Consumers (families)                  |
|---                                             |---                                    |
| `c_walker_move`                                | walker + boss (Lamnola, Aquamentus)   |
| `Obj_Shove` gate (commit d6b534c8)             | every shove-capable type              |
| `c_check_monster_collisions`                   | universal — body bump damage          |
| `enrt_animate_and_draw_common_object`          | walker family + Gibdo + Bubble        |
| `z07_anim_advance_and_fetch`                   | walker + jumper + flyer + boss        |
| `z01_anim_set_sprite_desc_attrs`               | universal sprite draw                 |
| `z07_anim_set_obj_hflip`                       | walker + projectile                   |
| `enrt_octorock_common`                         | $07-$0A (OUT) + indirectly $21 Ghini  |
| `enrt_init_walker`                             | $01-$06, $12, $13, $14, $2A, $30      |
| `enrt_init_slow_octorock_or_ghini`             | $07, $09 (OUT), $21 Ghini             |
| `enrt_init_armos_or_flying_ghini`              | $1E + $22                             |
| `armos_draw_and_check_collisions`              | $1E Armos                             |
| `enrt_update_armos`                            | $1E                                   |
| `enrt_update_guard_fire`                       | $3F                                   |

**Audit gate**: walker-bridge fix → re-probe all walker types + Ghini
($21) + Vire spawned Keese ($1B) + Octorok+Tektite (A3 baseline).

## Wanderer primitives (enemy_wanderer_runtime.c, enemy_boss_bridge.c)

Consumers cross walker and boss families.

| Symbol                          | Consumers                                |
|---                              |---                                       |
| `enrt_update_common_wanderer`   | Ghini ($21), Moblin ($03/$04), Goriya ($05/$06), **Lamnola ($3A/$3B)**, **Gohma ($33/$34)** |
| `enrt_wanderer_target_player`   | Rope ($10/$28), BlueLeever ($0F)         |
| `z04_update_common_wanderer`    | Vire ($12), LikeLike ($17)               |

**Audit gate**: wanderer fix → re-probe both walker AND boss
consumers.

## Flyer-family primitives (enemy_flyer_bridge.c)

| Symbol                                | Consumers                            |
|---                                    |---                                   |
| `c_move_flyer`                        | Keese ($1B-$1D), Peahat ($1A), FlyingGhini ($22), GleeokHead ($46), Patra ($47/$48), PatraChild ($25/$26), Moldorm head ($41) |
| `c_control_keese_flight`              | Keese + Peahat states 0,2,3 + Patra states 2,3 + GleeokHead |
| `c_control_peahat_flight`             | Peahat ($1A)                         |
| `c_control_flying_ghini_flight`       | FlyingGhini ($22)                    |
| `c_flyer_chase`                       | Keese, Patra, Moldorm                |
| `c_flyer_wander`                      | Keese, Peahat                        |
| `c_turn_towards_player8`              | flyer + Manhandla ($3C)              |
| `z04_end_init_flyer`                  | every flyer init                     |
| `z04_flyer_set_flying_state`          | every flyer                          |
| `enrt_update_peahat`                  | $1A                                  |
| `enrt_update_flying_ghini`            | $22                                  |

**Audit gate**: flyer-bridge fix → re-probe all flyer types AND
boss-family consumers (Patra/Moldorm head/GleeokHead/Manhandla).

## Jumper / burrower (enemy_jumper_bridge.c)

| Symbol                                  | Consumers                       |
|---                                      |---                              |
| `c_update_burrower`                     | Zora ($11), BlueLeever ($0F)    |
| `c_bound_flyer`                         | Peahat ($1A) + Moldorm head     |
| `c_bound_direction_horizontally`        | Boulder ($20), Octorok shots (OUT) |
| `c_bound_direction_vertically`          | Boulder ($20), shot family      |
| `c_reverse_obj_dir8`                    | Gohma ($33/$34) + jumper        |
| `enrt_update_blue_leever`               | $0F                             |
| `enrt_update_red_leever`                | $10                             |

**Audit gate**: jumper-bridge fix → re-probe leever + Zora + boulder.

## Projectile (enemy_projectile_bridge.c)

| Symbol                                  | Consumers                      |
|---                                      |---                             |
| `c_move_object`                         | walker shots, boomerang        |
| `c_draw_object_not_mirrored`            | all shots                      |
| `c_draw_arrow`                          | $5B MonsterArrow               |
| `c_draw_sword_shot_or_magic_shot`       | $57, $58, $59, $5A             |
| `z01_check_link_collision`              | universal shot                 |
| `z01_get_directions_and_distances_to_target` | targeting (Manhandla shot, etc.) |
| `z07_destroy_monster`                   | universal end-of-life          |
| `z07_anim_fetch_obj_pos`                | universal sprite anim          |
| `z01_bound_by_room`                     | shots + jumper                 |

**Audit gate**: projectile-bridge fix → re-probe every shooting type
across all families.

## Special enemies (enemy_special_bridge.c)

Self-contained — $16 PolsVoice, $17 LikeLike, $27 Wallmaster bodies.
Little cross-family sharing. Lower regression risk.

## Boss-family primitives (enemy_boss_bridge.c, bosses/*.c)

| Symbol                                  | Consumers                       |
|---                                      |---                              |
| `z04_update_common_wanderer`            | Vire, LikeLike                  |
| `c_aquamentus_move/shoot/draw`          | Aquamentus only                 |
| `c_shoot_fireball`                      | Manhandla, Gohma, Wizzrobe, Gleeok |
| `z07_set_type_and_clear_object`         | universal slot reset (Patra spawn) |
| `boss_gleeok_init` / `boss_gleeok_update_head` | Gleeok                  |
| `boss_dodongo_update`                   | Dodongo                         |
| `boss_patra_update`                     | Patra                           |

**Audit gate**: boss-bridge fix → re-probe affected boss + any shared
consumer (e.g. c_shoot_fireball touches 4 bosses).

## Audit-time re-probe matrix

When a commit touches a primitive in the above tables, the re-probe set
expands beyond the family being audited:

| Primitive class           | Required re-probe coverage                  |
|---                        |---                                          |
| `enemy_loop_tick` prefix  | All in-scope types + A3 out-of-scope baseline |
| `c_walker_move`           | All walker types + bosses using walker prims + A3 |
| `enrt_update_common_wanderer` | Ghini, Moblin, Goriya, Lamnola, Gohma   |
| `c_move_flyer`            | All flyer + boss-flyer consumers            |
| `c_update_burrower`       | Leever + Zora                               |
| `c_shoot_fireball`        | Manhandla, Gohma, Wizzrobe, Gleeok, Zora    |
| Projectile draw/move      | All shooting types                          |
| Spawn / sub-spawn         | Per `spawn_graph.md` parent + child         |

For each commit, the commit message lists the re-probe set under
`Re-probed:`. If the set is empty, the change is per-type with no
shared touches.

## Tracking

A6 doc is the canonical map. When a new bridge primitive is added or
an existing one acquires a new consumer, update the relevant row here
before the commit lands.
