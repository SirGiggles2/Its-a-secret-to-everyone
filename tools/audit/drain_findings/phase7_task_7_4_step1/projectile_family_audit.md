# Phase 7 Task 7.4 step 1 — projectile-family audit

## Task header (Drain Rule D1)

- **NES source**: `reference/aldonunez/Z_07.asm:5601 InitObject_JumpTable`
                  + `reference/aldonunez/Z_07.asm:5295 UpdateObject_JumpTable`
                  rows for projectile-family carriers ($11 Zora, $1F
                  BoulderSet, $20 Boulder, $21 Ghini, $22 FlyingGhini,
                  $23 BlueWizzrobe, $24 RedWizzrobe, $2E Whirlwind) +
                  shot rows ($53/$54 monster-shots, $55/$56 fireballs,
                  $57-$5A magic/sword/shot variants, $5B MonsterArrow,
                  $5C ArrowOrBoomerang).
- **Drained C**:  `src/oracle/enemies/enemy_projectile_runtime.c`
                  (carries init/update/destroy/draw bodies for shot +
                  boulder + fireball) +
                  `src/oracle/enemies/enemy_walker_runtime.c::enrt_update_zora`
                  + `enemy_boss_runtime.c::enrt_update_tektite_or_boulder`
                  + `enemy_boss_runtime.c::enrt_update_statues`.
- **Coverage**:   PARTIAL — shot UPDATE rows ($53/$54/$55/$56/$57-$5A)
                  already wired Task 7.2 step 12. Carrier types and
                  arrow/boomerang/wizzrobe rows still pending.
- **Stance**:     ADOPT (drains linked verbatim) + EXTEND (per-call
                  bridges in `src/game/enemies/enemy_*_bridge.c`).

## Existing wiring (from Task 7.2 step 12)

| Hex | UPDATE row             | Status |
|-----|------------------------|--------|
| $53 | `enrt_update_monster_shot` | wired step 12 |
| $54 | `enrt_update_monster_shot` | wired step 12 |
| $55 | `enrt_update_fireball`     | wired step 12 |
| $56 | `enrt_update_fireball`     | wired step 12 |
| $57 | `enrt_update_monster_shot` | wired step 12 |
| $58 | `enrt_update_monster_shot` | wired step 12 |
| $59 | `enrt_update_monster_shot` | wired step 12 |
| $5A | `enrt_update_monster_shot` | wired step 12 |

INIT rows for shot types ($53-$5A) are NOT wired — shots spawn via
`c_shoot` / `enrt_init_monster_shot` writing the type byte directly,
bypassing the dispatch jump-table on init. That matches NES `Shoot`
behavior (Z_07.asm:5685+ shows `InitMonsterShot` is the init body but
NES `Shoot` calls it directly via X-reg, not through the table).

## Drain coverage for unwired projectile-family types

| Hex | NES type      | INIT body                          | UPDATE body                          | Drain status |
|-----|---------------|------------------------------------|--------------------------------------|--------------|
| $11 | Zora          | `ResetObjMetastateAndTimer`        | `UpdateZora`                         | UPDATE drained @ `enemy_walker_runtime.c:174` (`enrt_update_zora`); INIT via existing `core_reset_obj_metastate_and_timer` forwarder |
| $1F | BoulderSet    | `InitBoulderSet`                   | `UpdateBoulderSet`                   | both drained @ `enemy_projectile_runtime.c:40,98` |
| $20 | Boulder       | `InitBoulder`                      | `UpdateTektiteOrBoulder`             | INIT drained @ `enemy_projectile_runtime.c:35`; UPDATE drained @ `enemy_boss_runtime.c:126` (`enrt_update_tektite_or_boulder`) |
| $21 | Ghini         | `InitSlowOctorockOrGhini` (shared) | `UpdateGhini`                        | INIT shared with octorok (already wired Task 7.2); UPDATE NOT drained |
| $22 | FlyingGhini   | `InitArmosOrFlyingGhini`           | `UpdateFlyingGhini`                  | NEITHER drained |
| $23 | BlueWizzrobe  | `ResetObjMetastateAndTimer`        | `UpdateBlueWizzrobe`                 | UPDATE NOT drained |
| $24 | RedWizzrobe   | `ResetObjMetastateAndTimer`        | `UpdateRedWizzrobe`                  | UPDATE NOT drained |
| $2E | Whirlwind     | `ResetObjMetastateAndTimer`        | `UpdateWhirlwind`                    | UPDATE NOT drained |
| $5B | MonsterArrow  | `InitMonsterShot`                  | `UpdateMonsterArrow`                 | UPDATE NOT drained |
| $5C | ArrowOrBoomerang | `InitMonsterShot`               | `UpdateArrowOrBoomerang`             | UPDATE NOT drained |

Statue fireballs are spawned by the room-mode hook, not via dispatch:
`enrt_update_statues` is drained at `enemy_boss_runtime.c:285` but
expects to be called once per frame with no slot argument, gated by
ROOM_MODE / room layout. Task 7.4 needs a wire-in path that fires it
each frame from `enemy_loop_tick` when the room template flags it.

## Already-resolved primitives

These are usable today via existing bridges / drains:

```
c_update_burrower               — c_shims.asm:4625 (Title-side ABI)
enrt_shoot_fireball             — enemy_projectile_runtime.c:67 (linked)
z07_destroy_monster             — drained native (verified Task 7.2)
z07_reset_obj_metastate_and_timer — enemy_flyer_bridge.c:121 forwarder
core_reset_obj_metastate_and_timer — game/core/core_dispatch.c:455
enrt_init_boulder               — projectile_runtime.c:35 (linked)
enrt_init_boulder_set           — projectile_runtime.c:40 (linked)
enrt_update_boulder_set         — projectile_runtime.c:98 (linked)
enrt_update_tektite_or_boulder  — boss_runtime.c:126 (linked)
enrt_update_zora                — walker_runtime.c:174 (linked)
```

## Step 2+ sequencing (proposed)

Mirror of Task 7.3 step 3..N family-by-family bridge cadence:

1. **Step 2 — wire ready rows** ($11 Zora UPDATE / $1F BoulderSet
   INIT+UPDATE / $20 Boulder INIT+UPDATE). All drains exist + all
   primitives resolved; should be a single dispatch row commit.
   *(Updated step 2a: investigation showed `c_update_burrower` chain is
   not yet linked. Split into:
   - 2a: $1F + $20 only + jumper_bridge — DONE
   - 2b: drain UpdateBurrower chain + wire $11 Zora.)*
2. **Step 3 — drain UpdateGhini** (Z_04.asm) → wire $21.
3. **Step 4 — drain UpdateMonsterArrow** ($5B; small) +
   `UpdateArrowOrBoomerang` ($5C; small) → wire shot rows.
4. **Step 5 — drain UpdateBlueWizzrobe + UpdateRedWizzrobe**
   ($23/$24) — these spawn $58 magic shots; wire INIT+UPDATE.
5. **Step 6 — drain UpdateFlyingGhini + UpdateArmos** ($1E/$22) +
   wire `enrt_init_armos_or_flying_ghini` rows.
6. **Step 7 — drain UpdateWhirlwind** ($2E) — wire row.
7. **Step 8 — wire `enrt_update_statues`** as a room-mode hook from
   `enemy_loop_tick` (statues spawn fireballs $55/$56).
8. **Step 9 — wire shield/Link projectile collision** —
   `enrt_check_shot_link_collision` integration via shot-tick path.
9. **Step 10 — multi-slot probe** mirroring Task 7.3 step 8 pattern
   (8/8 family-functional gates).
10. **Step 11 — Task 7.4 commit family** close.

## Build verification

`Debug.bat` clean post Task 7.3 close (`1642659b`). Active scope
`src/game/enemies/**`. No new RoomRom files per WT-5.

## Why bracketing wiring now

Per Drain Rule D1 we cannot stub UPDATE bodies — would silently no-op
NES behavior. Step 2 wires only the rows whose UPDATE bodies are
already drained AND whose primitives are already resolved (3 rows + 2
INIT). Step 3+ drains each missing UPDATE body before wiring its row.
