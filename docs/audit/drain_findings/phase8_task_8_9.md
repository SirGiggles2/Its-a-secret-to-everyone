# Phase 8 Task 8.9 — Moldorm / Lanmola

- **NES source**: `reference/aldonunez/Z_07.asm:5295` UpdateObject_JumpTable
                  rows `$3A` Lamnola1 / `$3B` Lamnola2 → `Z_04.asm:9699`
                  UpdateLamnola; row `$41` Moldorm → `Z_04.asm:4907`
                  UpdateMoldorm. `Z_07.asm:5601` InitObject_JumpTable
                  rows `$3A`/`$3B` → InitLamnola; row `$41` → InitMoldorm.
                  Segment chain layout per `ObjVars.inc` (Lamnola
                  head/body segments + Moldorm 9-slot segmented tail).
                  Moldorm head-only flight lives on slots 5/$A; body
                  segments tail-swap into `$5D` dead-dummy on
                  metastate flip.
- **Drained C**:  `src/oracle/enemies/enemy_lamnola_runtime.c:44` —
                  `enrt_init_lamnola`, `enrt_update_lamnola` umbrella +
                  segment-propagation helpers. PRIMARY.
                  `src/oracle/enemies/enemy_moldorm_runtime.c:170` —
                  `enrt_init_moldorm`, `enrt_update_moldorm` umbrella +
                  `ControlMoldormFlight` + `Moldorm_Chase` +
                  `Moldorm_Wander` + `Moldorm_ChangeFlyingState` +
                  `Moldorm_PropagateDirs`. PRIMARY.
- **Coverage**:   FULL — both Lamnola and Moldorm fully drained. All
                  segment-chain bookkeeping (ObjPrevX[N]/ObjPrevY[N]
                  shifts, head metastate flip → dead-dummy tail swap)
                  preserved verbatim. Callees `c_flyer_chase`,
                  `c_flyer_wander`, `c_move_flyer`, `c_anim_write_sprite`,
                  `c_check_monster_collisions`,
                  `enrt_check_boss_hit_reaction`,
                  `enrt_flyer_moldorm_decide_state` already drained or
                  asm-shimmed.
- **Stance**:     ADOPT — drained Lamnola + Moldorm primitives consumed
                  verbatim. No bridge `.c` required.

## Wired pipeline (`src/game/enemies/enemy_loop.c`)

```
[0x3A] = enrt_init_lamnola,      /* Lamnola1 */
[0x3B] = enrt_init_lamnola,      /* Lamnola2 */
[0x41] = enrt_init_moldorm,      /* Moldorm */
[0x3A] = enrt_update_lamnola,    /* Lamnola1 */
[0x3B] = enrt_update_lamnola,    /* Lamnola2 */
[0x41] = enrt_update_moldorm,    /* Moldorm */
```

## Build verification

```
REQUIRE_GENERATED_ASSETS=1 python tools/debug/build_debug.py
→ builds/Debug.md
```

Clean build; only pre-existing `LINK_X` / `LINK_Y` redefinition warnings.

## Status

CLOSE — Task 8.9 Moldorm + Lanmola drain-direct wired. Both bodies fully
drained; no bridge body required.
