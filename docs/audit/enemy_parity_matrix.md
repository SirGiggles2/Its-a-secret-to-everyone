# Enemy Parity Matrix — Phase 7 Task 7.1 framework skeleton

**Generated:** 2026-05-09 from `reference/aldonunez/Z_04.asm` `Init*` /
`Update*` label grep. This is a SKELETON — probe ids and capture-derived
fields are `PROBE_PENDING` until Phase 1.5 captures + first family
runtime land. Family agents fan out against this matrix; rows grow
column-by-column as work progresses.

**Verdict source:** [Phase 7 Task 7.1 debate synthesis](../../debates/2026-05-09-phase7-task-7-1-framework/synthesis.md) — Q3=(b) skeleton-generate then incrementally fill, 4-of-4 unanimous.

**Master plan contract** (`docs/superpowers/plans/2026-05-02-...-master-plan.md:1257`):
per enemy: source room(s), spawn rule, RNG seed positions, movement
timer cadence, hitbox dimensions, damage value, drop table, required
probe id from Phase 1.5 captures.

## Column key

- `id`: NES enemy id from `reference/aldonunez/dat/ObjListAddrs.inc` lookup or `enemy_dispatch.c` table
- `family`: 7.2-walker / 7.3-flyer-jumper / 7.4-projectile / 7.5-special / 7.6-aquatic-terrain
- `nes_init`: `Z_04.asm` Init label + line
- `nes_update`: `Z_04.asm` Update label + line
- `source_rooms`: dungeon level + room id list (PROBE_PENDING)
- `spawn_rule`: explicit spawn / room-load / dropped (PROBE_PENDING)
- `rng_uses`: which `Random[i]` reads in this enemy's path (PROBE_PENDING)
- `move_timer`: cadence (frames between updates, PROBE_PENDING)
- `hitbox`: WxH px (PROBE_PENDING)
- `damage`: per-touch HP cost to Link (PROBE_PENDING)
- `drop_table`: which group A/B/C from `Z_04.asm` drop logic at `:11209`
- `probe_id`: regression-matrix probe id (PROBE_PENDING)

## Walkers (Task 7.2)

| id | nes_init | nes_update | source_rooms | spawn_rule | rng_uses | move_timer | hitbox | damage | drop_table | probe_id |
|----|----------|-----------|--------------|-----------|----------|------------|--------|--------|-----------|----------|
| Walker (generic) | `:209` | (via CommonWanderer) | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| CommonWanderer | — | `:281` | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| Goriya | — | `:424` | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| Moblin | — | `:1956` | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| Lynel | — | `:1965` | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| Octorock (slow) | `:1864` | `:2966` | PROBE_PENDING | PROBE_PENDING | `Random,X` for dir | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| Octorock (fast) | `:1869` | `:2966` | PROBE_PENDING | PROBE_PENDING | `Random,X` for dir | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| Leever | `:1857` | (via Burrower) | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| BlueLeever | — | `:2599` | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| RedLeever | — | `:2737` | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| Burrower (shared) | — | `:2603` | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| Zol | `:1376` (Gel) | `:1235`, `:1250` | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| Gel | `:1376` | `:1381`, `:1475` | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| Stalfos | — | `:4670` | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| Rope | `:4536` | `:4549` | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| Darknut | `:6448` | `:6474` | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| Gibdo | — | `:6464` | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| LikeLike | — | `:6818` | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| PolsVoice | — | `:6533` | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| Wallmaster | — | `:4121` | PROBE_PENDING | PROBE_PENDING | `Random,X` for spawn side | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |

## Flyer / Jumper (Task 7.3)

| id | nes_init | nes_update | source_rooms | spawn_rule | rng_uses | move_timer | hitbox | damage | drop_table | probe_id |
|----|----------|-----------|--------------|-----------|----------|------------|--------|--------|-----------|----------|
| BlueKeese | `:1095` | `:1180` | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| RedKeese / BlackKeese | `:1110` | `:1180` | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| Bubble | `:1090` | `:1118` | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| Tektite | `:1842` | `:2251` | PROBE_PENDING | PROBE_PENDING | `Random,X` jump dir | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| Peahat | `:1892` | `:4014` | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| Ghini | — | `:3067` | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| FlyingGhini | `:3150` | `:3967` | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| Armos | `:3150` | `:3302` | PROBE_PENDING | room-load on touch | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| Vire | — | `:6918`, `:6953` | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |

## Projectile (Task 7.4)

| id | nes_init | nes_update | source_rooms | spawn_rule | rng_uses | move_timer | hitbox | damage | drop_table | probe_id |
|----|----------|-----------|--------------|-----------|----------|------------|--------|--------|-----------|----------|
| MonsterShot | `:197` | `:820` | PROBE_PENDING | spawned-by-enemy | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | n/a | PROBE_PENDING |
| MonsterArrow | — | `:2102` | PROBE_PENDING | spawned-by-enemy | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | n/a | PROBE_PENDING |
| Fireball | — | `:982` | PROBE_PENDING | spawned-by-enemy | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | n/a | PROBE_PENDING |
| Boulder | `:1840` (Set: `:1835`) | `:2168`, `:2251` | OW only | overhead drop | `Random,X` for X spawn | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | n/a | PROBE_PENDING |
| StandingFire | — | `:257` | PROBE_PENDING | candle/wand spawn | n/a | PROBE_PENDING | PROBE_PENDING | n/a | n/a | PROBE_PENDING |
| GuardFire | — | `:9684` | L9 only | Ganon-room spawn | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | n/a | PROBE_PENDING |

## Special (Task 7.5 — bosses + unique behaviors)

| id | nes_init | nes_update | source_rooms | spawn_rule | rng_uses | move_timer | hitbox | damage | drop_table | probe_id |
|----|----------|-----------|--------------|-----------|----------|------------|--------|--------|-----------|----------|
| Aquamentus | `:4835` | `:5596` | L1 boss | room-load | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | n/a | PROBE_PENDING |
| Dodongo | `:4893` | `:5856`, `:5868` | L2 boss | room-load | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | n/a | PROBE_PENDING |
| Manhandla | `:7747` | `:7842` | L3 boss | room-load | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | n/a | PROBE_PENDING |
| Gleeok | `:7649` | `:8527`, `:8601`, `:7832` | L4/6/8 boss | room-load | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | n/a | PROBE_PENDING |
| Digdogger | — | `:5265` | L5/7 boss | room-load | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | n/a | PROBE_PENDING |
| Gohma (Blue/Red) | `:7814` | `:8207` | L6/9 boss | room-load | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | n/a | PROBE_PENDING |
| Moldorm | `:4763` | `:4907` | L6 boss | room-load | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | n/a | PROBE_PENDING |
| Lamnola | `:9502` | `:9699` | L7 boss | room-load | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | n/a | PROBE_PENDING |
| Patra | `:9552` | `:10070`, `:10164` | L8 boss | room-load | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | n/a | PROBE_PENDING |
| Ganon | `:9599` | `:10321` | L9 final | room-load | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | n/a | PROBE_PENDING |
| Zelda | `:9481` | `:9617` | L9 ending | room-load | n/a | n/a | PROBE_PENDING | n/a | n/a | PROBE_PENDING |
| BlueWizzrobe | — | `:7034` | UW | PROBE_PENDING | `Random,X` align (`:8218`) | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| RedWizzrobe | — | `:7474` | UW | PROBE_PENDING | `Random,X` align | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING |
| Statues | — | `:1592` | UW | room-load | PROBE_PENDING | PROBE_PENDING | n/a | n/a | n/a | PROBE_PENDING |
| Block (push) | — | `:618` | UW | room-load | PROBE_PENDING | PROBE_PENDING | n/a | n/a | n/a | PROBE_PENDING |

## Aquatic / terrain (Task 7.6)

| id | nes_init | nes_update | source_rooms | spawn_rule | rng_uses | move_timer | hitbox | damage | drop_table | probe_id |
|----|----------|-----------|--------------|-----------|----------|------------|--------|--------|-----------|----------|
| Zora | — | `:1920` | OW water | timer | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | PROBE_PENDING | n/a | PROBE_PENDING |
| PondFairy | `:1906` | `:3365` | OW pond | room-load | PROBE_PENDING | PROBE_PENDING | n/a | n/a | n/a | PROBE_PENDING |
| RockOrGravestone | — | `:3560` | OW | room-load | PROBE_PENDING | n/a | PROBE_PENDING | n/a | n/a | PROBE_PENDING |
| RockWall | — | `:3705` | OW | bomb-trigger | n/a | n/a | n/a | n/a | n/a | PROBE_PENDING |
| Tree | — | `:3735` | OW | candle-trigger | n/a | n/a | n/a | n/a | n/a | PROBE_PENDING |
| Dock | — | `:3854` | OW | raft pickup | n/a | n/a | n/a | n/a | n/a | PROBE_PENDING |
| Candle | — | `:11426` | UW | placed | n/a | n/a | n/a | n/a | n/a | PROBE_PENDING |
| FairyObject | — | `:11505` | OW/UW | room-load | PROBE_PENDING | PROBE_PENDING | n/a | n/a | n/a | PROBE_PENDING |
| Item (drop) | — | `:11236` | any | drop-spawn | PROBE_PENDING | PROBE_PENDING | n/a | n/a | n/a | PROBE_PENDING |

## Phase 1.5 capture priority

Family agents add probes in this order — highest-RNG-dependency first:

1. Wizzrobe align timer (`:8218`) — multi-byte `Random,X` slot read
2. Octorock direction pick (`:2966`) — `Random,X` per-frame
3. Leever burrow timer (`:2603`) — `Random,X` for re-emerge cadence
4. Tektite jump direction (`:2251`) — `Random,X` for diagonal pick
5. Boulder spawn X (`:2168`) — `Random,X` for overhead column

These five probes alone validate ~80% of NES Random[] usage and unblock
Tasks 7.2-7.6 RNG-dependent rows.

## Update protocol

When a family agent lands its first probe + drained Init/Update for an
enemy, replace `PROBE_PENDING` cells with concrete values and cite the
NES asm line + drained C site. Do NOT mass-fill from guesses; let the
matrix grow row-by-row from real evidence.

## See also

- [enemy_alias_table.md](enemy_alias_table.md) — RAM byte alias clusters
- `RoomRom/src/roomrom_enemy_state.h` — accessor macros
- `RoomRom/src/roomrom_rng.h` — `Random[]` port (`rng_seed/next/peek`)
- [debate synthesis](../../debates/2026-05-09-phase7-task-7-1-framework/synthesis.md)
