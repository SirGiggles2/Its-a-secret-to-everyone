# Phase 8 Task 8.6 — Digdogger

- **NES source**: `reference/aldonunez/Z_07.asm:5295` UpdateObject_JumpTable
                  rows `$18` LittleDigdogger / `$38` Digdogger1 / `$39`
                  Digdogger2 → `Z_04.asm:5265` UpdateDigdogger umbrella.
                  `Z_07.asm:5601` InitObject_JumpTable rows `$38`/`$39` →
                  `Z_04.asm:4850` InitDigdogger1 / `Z_04.asm:4878`
                  InitDigdogger2. Sub-routines: `Z_04.asm:5164`
                  L_Digdogger_AfterFlute (flute state 1 turn / state 2
                  MakeChildren split), `Z_04.asm:5218` MakeChildren spawn
                  (re-calls InitDigdogger1 over slots 1..3 with
                  `Digdogger_ObjIsChild` + `Digdogger_ObjSpeedFlag` seeded),
                  `Z_04.asm:5261` L_Digdogger_TurnTowardLink + L_Digdogger_Move,
                  ChangeSpeed / Draw (big + little / DrawAsLittle inset) /
                  4-corner CheckBigDigdoggerCollisions. Object var layout
                  per `ObjVars.inc` `Digdogger_ObjIsChild` /
                  `Digdogger_ObjSpeedFlag` / `Digdogger_ObjSpeedFrac` /
                  `Digdogger_ObjTargetSpeedFrac` /
                  `Digdogger_ObjTargetSpeedWhole`.
- **Drained C**:  `src/oracle/enemies/enemy_boss_runtime.c` —
                  `enrt_init_digdogger1`, `enrt_init_digdogger2`,
                  `enrt_update_digdogger` umbrella + 6 statics
                  (ChangeSpeed, Move, Draw big + little, AfterFlute states
                  1 + 2, MakeChildren split, CheckBigDigdoggerCollisions
                  4-corner loop, L_Digdogger_DrawAsLittle inset draw).
                  Drain PRIMARY for entire Digdogger body.
- **Coverage**:   FULL — UpdateDigdogger umbrella + ChangeSpeed + Move +
                  Draw big + Draw little + AfterFlute (states 1 + 2) +
                  MakeChildren + CheckBigDigdoggerCollisions all drained.
                  Magic-clock / stun pre-gate from the umbrella shares
                  `enrt_play_boss_hit_cry_if_needed` /
                  `c_check_monster_collisions` with the rest of the boss
                  family.
- **Stance**:     ADOPT — drained Digdogger primitives consumed verbatim.
                  All callee primitives (`c_turn_towards_player8`,
                  `c_turn_randomly_dir8`, `c_bound_flyer`,
                  `c_check_monster_collisions`, `c_play_boss_death_cry`,
                  `c_draw_object_mirrored`, `c_draw_object_not_mirrored`,
                  `z07_anim_advance_and_fetch`, `z07_anim_fetch_obj_pos`,
                  `z01_anim_set_sprite_desc_attrs`,
                  `enrt_anim_set_sprite_desc_level_palette_row`) already
                  resolved by prior bridges (boss_manhandla, boss_dodongo,
                  flyer / jumper / projectile bridges). No new shims, no
                  bridge `.c` needed — only the header marker at
                  `src/game/enemies/bosses/boss_digdogger.h`.

## Wired pipeline (`src/game/enemies/enemy_loop.c`)

```
[0x38] = enrt_init_digdogger1,   /* Digdogger1 */
[0x39] = enrt_init_digdogger2,   /* Digdogger2 (2nd quest) */
[0x18] = enrt_update_digdogger,  /* LittleDigdogger (child) */
[0x38] = enrt_update_digdogger,  /* Digdogger1 (big) */
[0x39] = enrt_update_digdogger,  /* Digdogger2 (big, 2nd quest) */
```

INIT for `$18` LittleDigdogger is intentionally absent — child slots are
seeded by `MakeChildren` from inside `enrt_update_digdogger` (NES
`Z_04.asm:5218`), not the per-row InitObject_JumpTable.

## Build verification

```
REQUIRE_GENERATED_ASSETS=1 python tools/debug/build_debug.py
→ builds/Debug.md
```

Clean build; only pre-existing `LINK_X` / `LINK_Y` redefinition warnings.

## Status

CLOSE — Task 8.6 Digdogger drain-direct wired. Full UpdateDigdogger
behaviour available via the drained umbrella + 6 statics; bridge body
not required (ADOPT all-shims-resolved).
