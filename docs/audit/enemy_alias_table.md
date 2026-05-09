# Enemy state alias table — Phase 7 Task 7.1 framework

**Generated:** 2026-05-09 from `src/state/enemy_state.h` + `reference/aldonunez/ObjVars.inc`.
**Verdict source:** [Phase 7 Task 7.1 debate synthesis](../../debates/2026-05-09-phase7-task-7-1-framework/synthesis.md) — Q1=(c) flat byte-slot + accessor macros, 4-of-4 unanimous.

NES Zelda 1 deliberately overlays object scratch RAM: the same byte means
different things depending on which enemy family owns the slot. Family
agents (Tasks 7.2-7.7) MUST grep this table BEFORE claiming a byte for
new behavior — silent collision is the #1 enemy-port failure mode.

## Aliased byte clusters (NES $0380..$04FF object scratch)

| NES addr | Aliases | NES asm site | Notes |
|----------|---------|--------------|-------|
| `$0380` | `ENEMY_BOSS_HP_PHASE` \| `ENEMY_GOHMA_SHOOT_TIMER` | `Z_04.asm:8207` (Gohma) | Boss-only |
| `$03BC` | `ENEMY_WALK_SPEED` (= `NES_OBJ_QSPD_FRAC`) | walker dispatch | All walkers |
| `$03D0` | `ENEMY_ANIM_TIMER` | shared | All animated |
| `$03E4` | `ENEMY_DRAW_FRAME` | shared | All drawn |
| `$03F8` | `ENEMY_PUSH_DIR_SCRATCH` | `Z_04.asm:6470` (BeginShove) | Shove math |
| `$0405` | `ENEMY_METASTATE` | shared | Lifecycle |
| **`$0412`** | **`ENEMY_PUSH_TIMER`** \| **`ENEMY_FLYER_SPEED_FRAC`** \| **`ENEMY_JUMPER_VSPEED_HI`** \| **`ENEMY_GOHMA_DIST_TRAVELED`** | `Z_04.asm:691-716,11495-11597` + `ObjVars.inc:7,24` | **134 in-scope collisions** per master plan. Hottest alias byte. |
| `$041F` | `ENEMY_AIR_SPEED` \| `ENEMY_JUMPER_VSPEED_LO` \| `ENEMY_GOHMA_MOVE_ACCUM` | flyer/jumper | Speed-fraction trio |
| `$042C` | `ENEMY_TURN_TIMER` \| `ENEMY_GOHMA_NEXT_OPEN_EYE` | wanderer/Gohma | |
| `$0437` | `ENEMY_FLAP_PHASE` | flyer-only | |
| **`$0444`** | `ENEMY_AI_STATE` \| `ENEMY_JUMPER_TARGET_Y` \| `ENEMY_GOHMA_OPEN_EYE_TIMER` | `Z_04.asm:8207` | Multi-family AI byte |
| `$0451` | `ENEMY_JUMPER_REVERSALS` \| `ENEMY_MANHANDLA_FRAME_ACCUM` \| `ENEMY_GOHMA_GO_STRAIGHT` | jumper/Manhandla/Gohma | |
| `$045E` | `ENEMY_BLOATED_TIMER` \| `ENEMY_GOHMA_SPRINTS` | zol/Gohma | |
| `$046B` | `ENEMY_FLYER_X_FINE` \| `ENEMY_GOHMA_EYE_FRAME` | flyer/Gohma | |
| **`$0478`** | `ENEMY_BOUNCE_FLAGS` \| `ENEMY_FLYER_Y_FINE` \| `ENEMY_MANHANDLA_FRAME_ATTR` \| `ENEMY_GOHMA_CLOSED_EYE_CNTR` | multi | 4-way alias |
| `$0485` | `ENEMY_CHARGE_SPEED` | charger-only | Lynel/Moblin |
| `$0492` | `ENEMY_ALIVE_FLAG` | shared | Lifecycle |
| `$049E` | `ENEMY_COLLIDED_TILE` | shared | Collision |
| `$04B2` | `ENEMY_INVINCIBILITY` | shared | Damage |
| `$04F0` | `ENEMY_HIT_REACTION` | shared | Damage |

## Boss segment overlays (Gleeok / Patra / Manhandla)

| NES addr | Aliases | Notes |
|----------|---------|-------|
| `$0072` | `ENEMY_GLEEOK_SEG_X` (= `OBJ($72, slot)`) | Per-segment |
| `$0073` | `ENEMY_GLEEOK_SEG_X_TARGET` | |
| `$0086` | `ENEMY_GLEEOK_SEG_Y` | |
| `$0087` | `ENEMY_GLEEOK_SEG_Y_TARGET` | |

Bosses load their per-segment data into working slot 1..6 area; see
`src/state/enemy_state.h:117-122` for the `ZP_TMP*` neck-pointer slots.

## Workflow rules for family agents

1. Before adding a new `ENEMY_*` macro to `roomrom_enemy_state.h`, grep
   this table for the byte address. If the byte already has aliases,
   add yours and document the family-disjoint condition that makes the
   alias safe (e.g., "Gohma is a boss enemy, never in a slot that runs
   walker push-timer logic").
2. NES asm site is the tiebreaker. Cite the `Z_04.asm` line where your
   family's logic uses the byte.
3. If two same-family enemies need the same byte for different things,
   you have an actual bug — fix in your family runtime, not by widening.
4. Bytes flagged **bold** above are high-collision; require Sonnet+Codex
   review before adding a new alias.

## See also

- [enemy_parity_matrix.md](enemy_parity_matrix.md) — per-enemy spawn /
  RNG / hitbox / drop / probe matrix.
- `RoomRom/src/roomrom_enemy_state.h` — accessor macros (canonical).
- `src/state/enemy_state.h` — substrate drain (PRIMARY per Drain Rule D1).
- `reference/aldonunez/ObjVars.inc` — NES symbol table (SECONDARY, wins ties).
