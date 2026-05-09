# Phase 7 Task 7.4 step 11 — projectile family close

## Task header (Drain Rule D1)

- **NES source**: `Z_07.asm:5601 InitObject_JumpTable` rows:
                  - $11 Zora  -> `ResetObjMetastateAndTimer`
                                @ `Z_07.asm` (1-line clear scratch + timer).
                  - $21 Ghini -> `InitSlowOctorockOrGhini`
                                @ `Z_04.asm` (same body as $07/$09;
                                slot $21 reuses per dispatch table).

- **Drained C**:  - `core_reset_obj_metastate_and_timer` @
                    `src/game/core/core_dispatch.c` (already extern'd
                    in enemy_loop.c since 7.4 step 2b for chain reuse).
                  - `enrt_init_slow_octorock_or_ghini` @
                    `src/oracle/enemies/enemy_walker_runtime.c`
                    (already extern'd + wired for $07/$09 since
                    Task 7.3 step 7).

- **Coverage**:   FULL for $11 Zora — UPDATE wired in 7.4 step 2b
                  (`enrt_update_zora`), INIT wired here.
                  FULL for $21 Ghini — UPDATE wired in 7.4 step 3
                  (`enrt_update_ghini`), INIT wired here.

- **Stance**:     ADOPT — both INIT bodies already drained + linked.
                  Single-row table-deltas, no new TUs / bridges /
                  externs. Step 11 closes the projectile-enemy
                  dispatch family with no remaining unwired pairs in
                  the NES Z_07.asm:5601 table where both INIT and
                  UPDATE bodies have drained twins available.

## Wired dispatch (delta from step 10)

| Hex | NES type | INIT row                           | UPDATE row              |
|-----|----------|-------------------------------------|--------------------------|
| $11 | Zora     | `core_reset_obj_metastate_and_timer`| `enrt_update_zora`       |
| $21 | Ghini    | `enrt_init_slow_octorock_or_ghini`  | `enrt_update_ghini`      |

## Task 7.4 dispatch coverage end-state

INIT  table: 37 wired rows (was 35).
UPDATE table: 45 wired rows (no change — step 11 only adds INIT).

Wired INIT rows (sorted):
$01-$06 walker family (Lynel/Moblin/Goriya).
$07-$0A octorock family (slow/fast variants).
$0B-$0C darknut family.
$0D-$0E tektite.
$11    Zora.                       ← step 11.
$12    Vire.
$13-$15 zol/gel family.
$1A    Peahat.
$1B-$1D keese family.
$1E    Armos.
$1F-$20 boulder family.
$21    Ghini.                      ← step 11.
$22    FlyingGhini.
$28    Rope.
$2A    Stalfos.
$2B-$2D bubble family.
$30    Gibdo.                       ← step 9.
$3D    Aquamentus.                  ← step 10.
$49-$4A Trap.

Wired UPDATE rows (sorted):
$03-$06 (3+4 moblin / 5+6 goriya).
$07-$0A octorock.
$0B-$0C darknut.
$0D-$0E tektite.
$11 Zora. $12 Vire. $13-$15 zol/gel.
$1A peahat. $1B-$1D keese. $1E armos.
$1F-$20 boulder. $21 ghini. $22 flying ghini.
$28 rope. $2A stalfos. $2B-$2D bubble.
$2E whirlwind. $30 gibdo. $3D aquamentus.
$3F-$40 fire-shooter pair.
$49-$4A trap.
$53-$5A monster shots / fireballs.

## Out-of-scope rows (deferred to Task 7.5+)

These NES InitObject_JumpTable rows have drained twins or simple
NES bodies but are NOT projectile-family — boss / NPC clusters that
belong in subsequent tasks:

| Hex | NES type        | Status            | Owner task |
|-----|------------------|-------------------|------------|
| $0F-$10 | Leever       | Drain TBD         | 7.5        |
| $16-$17 | (walker var) | Drain TBD         | 7.5        |
| $1B (alt) BlueKeese full INIT | drained but uses InitWalker only here, full-init lives elsewhere | 7.5 |
| $31-$32 | Dodongo      | Boss family       | 7.5 / 7.6  |
| $33-$34 | Gohma        | Boss family       | 7.5 / 7.6  |
| $36     | Grumble      | NPC family        | 7.7        |
| $37     | Zelda        | NPC family        | 7.7        |
| $38-$39 | Digdogger    | Boss family       | 7.5 / 7.6  |
| $3A-$3B | Lamnola      | Boss family       | 7.5 / 7.6  |
| $3C     | Manhandla    | Boss family       | 7.5 / 7.6  |
| $3E     | Ganon        | Boss family       | 7.5 / 7.6  |
| $41     | Moldorm      | Boss family       | 7.5 / 7.6  |
| $42-$46 | Gleeok       | Boss family       | 7.5 / 7.6  |
| $47-$48 | Patra        | Boss family       | 7.5 / 7.6  |
| $4B-$52 | UnderworldPerson | NPC family    | 7.7        |
| $53-$5A | (shot INIT)  | Drained but UPDATE-only path; INIT NES = InitMonsterShot — INIT for new shot spawn lives in shooter callers, not the dispatch table | 7.5 |
| $5B-$5E | (sentinel/end-of-table types) | TBD | 7.5 |

Rows $0F/$10 Leever and $16-$17 simple-walker are the next
projectile-family candidates if Task 7.5 needs more easy wins
before transitioning to boss-family work.

## Build verification

`python tools/debug/build_debug.py` — clean post step 11 wire. Active
scope: `src/game/enemies/enemy_loop.c` only (+2 INIT rows + comment
block). No new files, no bridge edits, no new externs.

## Phase 7 Task 7.4 closure summary

Steps 1..11 net delta vs Task 7.3 baseline:
- INIT  rows: 21 -> 37 wired (+16).
- UPDATE rows: 22 -> 45 wired (+23).
- New native bodies in `src/game/enemies/`:
  * `enemy_walker_bridge.c`: octorock UPDATE specialization,
    DrawArmosAndCheckCollisions, enrt_update_armos, enrt_update_guard_fire.
  * `enemy_flyer_bridge.c`: peahat / flying-ghini UPDATE.
  * `enemy_jumper_bridge.c`: c_update_burrower (Zora) +
    z07_find_empty_monster_slot.
  * `enemy_boss_bridge.c`: c_aquamentus_{move,shoot,draw} +
    c_shoot_fireball forwarder + 4 verbatim-NES data tables.
  * `enemy_projectile_bridge.c`: z07_animate_object_walking forwarder.
- New native primitives in `src/game/world/`:
  * `draw_dispatch.c`: draw_arrow, draw_sword_shot_or_magic_shot,
    draw_write_boss_sprite.
  * `trap_dispatch.c`: full whirlwind/trap chain (Phase 4 promotion).

Stance compliance: every row uses ADOPT or EXTEND. No GREENFIELD
violations — all wires either reuse drained C twins or carry native
bridge bodies translated per-line from NES asm with audit trail.

## Step 12 sequencing (Task 7.5 hand-off)

Task 7.5 picks up the boss-family wiring (Dodongo / Gohma / Manhandla
/ Gleeok / Ganon) where each NES INIT/UPDATE pair pulls in its own
data tables + 100-300 line state machines. Bigger-step granularity
than 7.4 — multi-step bridge work per boss, not single-row deltas.

Task 7.5 prerequisites already in place after step 11:
- `draw_write_boss_sprite` primitive available for any 6-sprite
  boss render.
- `enrt_shoot_fireball_55` linked + accessible to bridge.
- `c_shoot_fireball` forwarder pattern established.
- `core_set_type_and_clear_object` + `z07_find_empty_monster_slot`
  + `c_find_empty_monster_slot` all native, not c_shims-dependent.
