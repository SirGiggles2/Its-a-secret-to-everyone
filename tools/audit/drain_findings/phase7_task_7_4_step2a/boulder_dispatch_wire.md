# Phase 7 Task 7.4 step 2a — boulder dispatch wire ($1F + $20)

## Task header (Drain Rule D1)

- **NES source**: `Z_07.asm:5601 InitObject_JumpTable` rows $1F/$20
                  + `Z_07.asm:5295 UpdateObject_JumpTable` rows $1F/$20.
- **Drained C**:  INIT — `enemy_projectile_runtime.c:35` (`enrt_init_boulder`)
                  + `:40` (`enrt_init_boulder_set`).
                  UPDATE — `:98` (`enrt_update_boulder_set`)
                  + `enemy_boss_runtime.c:126` (`enrt_update_tektite_or_boulder`).
- **Coverage**:   FULL for $1F + $20. ($11 Zora deferred to step 2b —
                  needs UpdateBurrower drain chain reaching anim/draw
                  infra not yet linked into Debug.md.)
- **Stance**:     ADOPT (drained C linked verbatim) + EXTEND
                  (`src/game/enemies/enemy_jumper_bridge.c` carries the
                  primitives the boulder chain pulls past `--gc-sections`).

## Wired dispatch

| Hex | NES type   | INIT row             | UPDATE row                     | Drain |
|-----|------------|----------------------|--------------------------------|-------|
| $1F | BoulderSet | `enrt_init_boulder_set` | `enrt_update_boulder_set`     | enemy_projectile_runtime.c:40,98 |
| $20 | Boulder    | `enrt_init_boulder`     | `enrt_update_tektite_or_boulder` | enemy_projectile_runtime.c:35 + enemy_boss_runtime.c:126 |

## Bridge added

`src/game/enemies/enemy_jumper_bridge.c` (NEW) per WT-5 — never under
`RoomRom/`. Resolves the unresolved-at-link primitives the boulder
chain pulls in via `--gc-sections`:

| Primitive | Resolution | NES drain |
|-----------|------------|-----------|
| `TektiteStartingDirs[4]` | DATA drain — `$01 $02 $05 $0A` | Z_04.asm:1832 |
| `c_bound_flyer(slot)` | forwards to `enrt_bound_flyer` | enemy_flyer_runtime.c:205 |
| `c_bound_direction_horizontally(slot)` | NATIVE drain | Z_01.asm:3312 |
| `c_bound_direction_vertically(slot)` | NATIVE drain | Z_01.asm:3382 |
| `c_reverse_obj_dir8(slot)` | NATIVE drain (moldorm $41 branch trimmed) | Z_04.asm:11664 |
| `c_turn_towards_player8(void)` | NATIVE drain (added to `enemy_flyer_bridge.c`) | Z_04.asm:11724 |
| `z07_find_empty_monster_slot(void)` | NATIVE body | mirrors enemy_runtime.c:12 |

`c_turn_towards_player8` lives in `enemy_flyer_bridge.c` because
`flyer_chase` already drained the same algorithm body (lines 190-251
of that file). The new c_-named entry uses `ENEMY_THROWER_SLOT`
(= NES `CurObjIndex` at $0340), set per-slot by `enemy_loop_tick`.

## CurObjIndex write

`src/game/enemies/enemy_loop.c::enemy_loop_tick` now writes
`ENEMY_THROWER_SLOT = (unsigned char)slot` before invoking
`enemy_update_fns[t](slot)`. NES `UpdateObject` uses the X register
implicitly via `CurObjIndex`; drained C primitives that take no slot
argument (`c_turn_towards_player8`, `c_shoot`, `enrt_shoot`) read the
RAM cell instead.

This closes the **Task 7.3 known gap** (`ENEMY_THROWER_SLOT $0340 read
by enrt_shoot but unwritten by enemy_loop_tick per-slot`).

## Build verification

`python tools/debug/build_debug.py` — clean post step 2a wiring.
Active scope `src/game/enemies/**`. No new `RoomRom/` files per WT-5.

## Step 2 split rationale

The Task 7.4 step 1 audit proposed step 2 wire $11 Zora UPDATE +
$1F BoulderSet INIT/UPDATE + $20 Boulder INIT/UPDATE in a single
commit. Investigation during step 2 found that `enrt_update_zora` calls
`c_update_burrower` whose NES body
(`Z_04.asm:2603 UpdateBurrower` + `Burrower_AnimateDrawAndCheckCollisions`)
reaches deep into anim/draw infra (`Anim_AdvanceAnimCounterAndSetObjPosForSpriteDescriptor`,
`DrawObjectMirrored`, `BlueLeeverState{QSpeeds,Times,AnimTimes}`,
`ActiveRedLeeverCount`) that's not yet linked into `Debug.md`.

Drain Rule D1 forbids stubs. Splitting:

- **2a (this step)**: wire $1F/$20 only — drained chain reaches
  resolved primitives (after the new `enemy_jumper_bridge.c`).
  Lands the CurObjIndex write that also fixes Task 7.3 gap.
- **2b**: drain `c_update_burrower` chain natively (UpdateBurrower +
  Burrower_AnimateDrawAndCheckCollisions + 3 state tables + anim/draw
  bridges). Wire $11 Zora once the chain links clean. Likely a
  family-3 sub-task (zora is in projectile family but burrower body
  is shared across leever types $10/$0F/$11).

Steps 3..11 unchanged from step 1 audit doc sequencing.
