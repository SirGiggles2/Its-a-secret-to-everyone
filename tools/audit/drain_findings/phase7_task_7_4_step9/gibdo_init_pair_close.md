# Phase 7 Task 7.4 step 9 — Gibdo INIT pair-close ($30)

## Task header (Drain Rule D1)

- **NES source**: `Z_07.asm:5601 InitObject_JumpTable`:
                  - row $30 Gibdo -> `InitWalker` @
                    `Z_04.asm:6995 InitWalker` (bare walker init).

- **Drained C**:  `enrt_init_walker` @
                  `src/oracle/enemies/enemy_walker_runtime.c:42`. Already
                  linked into Debug.md (used by $01-$06/$2A walker
                  family + $12 Vire / $13/$14 Zol since Task 7.3).

- **Coverage**:   FULL for $30 Gibdo — UPDATE wired in step 6d
                  (`enrt_update_gibdo`), INIT now wired here. Closes
                  the gibdo dispatch pair.

- **Stance**:     ADOPT — drained body, no native rewrite. Single
                  table-row delta, no new TU / bridge edits.

## Wired dispatch (delta from step 8)

| Hex | NES type | INIT row           | UPDATE row          |
|-----|----------|--------------------|---------------------|
| $30 | Gibdo    | `enrt_init_walker` | `enrt_update_gibdo` |

## Why a separate, narrow step

Step 9 originally bundled $3D Aquamentus boss INIT + UPDATE alongside
the Gibdo INIT close. Build verification surfaced three undefined
references in the linker:

```
enemy_boss_runtime.c:(.text.enrt_update_aquamentus+0x10): undefined reference to `c_aquamentus_move'
enemy_boss_runtime.c:(.text.enrt_update_aquamentus+0x18): undefined reference to `c_aquamentus_shoot'
enemy_boss_runtime.c:(.text.enrt_update_aquamentus+0x22): undefined reference to `c_aquamentus_draw'
```

`c_aquamentus_{move,shoot,draw}` are declared in
`src/c_shims.asm:5302-5304` as legacy-bank trampolines — that file is
NOT linked into `Debug.md` (legacy bank is a transpiled fallback used
only by the prior dual-ROM build). NES bodies live at `Z_04.asm:5612 /
5684 / 5764`, total ~250 lines, plus they pull `ShootFireball` (>100
lines) + `WriteBossSprite` (>60 lines) + `AquamentusTiles` /
`AquamentusSpriteOffsetsX` / `AquamentusSpriteOffsetsY` data tables.

That's a full bridge step on its own. Aquamentus deferred to a
dedicated step (10) so this commit stays at the "single-row
table-delta" granularity that matches steps 6d / 7 / 8.

## Build verification

`python tools/debug/build_debug.py` — clean post-step 9 wire. Active
scope: `src/game/enemies/enemy_loop.c` only (+1 INIT row, +1 comment
block). No new files, no bridge edits, no externs (enrt_init_walker
already extern'd at line 34 since step 7).

## Coverage advance

Task 7.4 dispatch coverage:
  UPDATE: 34 -> 34 wired rows (no change).
  INIT:   25 -> 26 wired rows (+1: $30).

## Step 10 / 11 sequencing

- step 10 — Aquamentus family (boss INIT + UPDATE):
            * native bridge for c_aquamentus_move / c_aquamentus_shoot
              / c_aquamentus_draw in src/game/enemies/enemy_boss_bridge.c
              (~3 native bodies translated from Z_04.asm:5612-5840).
            * native ShootFireball drain (Z_04.asm:786) — promoted
              into core_dispatch.c as `core_shoot_fireball` (already
              referenced by other monster shots).
            * native WriteBossSprite drain (Z_04.asm:5844) — promoted
              into draw_dispatch.c as `draw_boss_sprite`.
            * AquamentusTiles + sprite-offset tables ADOPTed verbatim
              into the bridge file.
            * dispatch rows $3D INIT + UPDATE.
- step 11 — family close (multi-slot probe + Drain Rule D1 audit
            sweep across the projectile-enemy family).
