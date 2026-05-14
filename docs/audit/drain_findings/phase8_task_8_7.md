# Phase 8 Task 8.7 — Gohma

- **NES source**: `reference/aldonunez/Z_07.asm:5295` UpdateObject_JumpTable
                  rows `$33` Blue Gohma / `$34` Red Gohma → `Z_04.asm:8207`
                  UpdateGohma. `Z_07.asm:5601` InitObject_JumpTable rows
                  `$33`/`$34` → `Z_04.asm:7814` InitGohma. Eye-state
                  machine sub-routines feed `Gohma_HandleWeaponCollision`
                  (`Z_01.asm`) which gates arrow-only damage on eye state
                  == 3 (closed). Fireball spawn: monster shot type 86
                  through `c_shoot_fireball`. Object cells per
                  `ObjVars.inc`: `Gohma_ObjEyeFrame`, eye-cycle timer,
                  shoot timer, ½-pixel movement accumulator, 0x20-pixel
                  sprint-reverse counter, RNG-reload entropy
                  (`0xC0 | RNG`).
- **Drained C**:  `src/oracle/enemies/enemy_boss_runtime.c:426` —
                  `enrt_init_gohma`; line 774 — `enrt_update_gohma` full
                  body: random-direction pick + 1/2-pixel movement
                  accumulator + 0x20-pixel sprint reverse + eye state
                  machine (open / half-open / closed cycle, 0xC0|RNG
                  reload) + shoot timer rollover spawning fireball type
                  86, tail-calling `c_gohma_animate_and_draw` +
                  `c_gohma_check_collisions` (asm shims). Drain PRIMARY
                  for the full Gohma body.
- **Coverage**:   FULL — UpdateGohma top-level + all per-state branches
                  drained. Arrow-only damage gate lives in
                  `Gohma_HandleWeaponCollision` (`Z_01.asm`) reachable
                  through the existing asm collision shim — gating on
                  eye state == 3 is faithful to NES.
- **Stance**:     ADOPT — drained Gohma primitives consumed verbatim.
                  Shims `c_reverse_obj_dir8`, `c_shoot_fireball`,
                  `c_gohma_animate_and_draw`, `c_gohma_check_collisions`
                  already linked via `c_shims.asm`. No bridge `.c`
                  needed — only the header marker at
                  `src/game/enemies/bosses/boss_gohma.h`.

## Wired pipeline (`src/game/enemies/enemy_loop.c`)

```
[0x33] = enrt_init_gohma,        /* Blue Gohma */
[0x34] = enrt_init_gohma,        /* Red Gohma */
[0x33] = enrt_update_gohma,      /* Blue Gohma */
[0x34] = enrt_update_gohma,      /* Red Gohma */
```

Two NES rows fan to the same INIT + UPDATE pair — preserved verbatim.

## Build verification

```
REQUIRE_GENERATED_ASSETS=1 python tools/debug/build_debug.py
→ builds/Debug.md
```

Clean build; only pre-existing `LINK_X` / `LINK_Y` redefinition warnings.

## Status

CLOSE — Task 8.7 Gohma drain-direct wired. ADOPT-stance forwarder; no
bridge required.
