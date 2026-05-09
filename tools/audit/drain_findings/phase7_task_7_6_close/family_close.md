# Phase 7 Task 7.6 step 4 — aquatic / terrain family close

## Task header (Drain Rule D1)

- **NES source**: `Z_07.asm:5601 InitObject_JumpTable` and
                  `Z_07.asm:5295 UpdateObject_JumpTable` rows for
                  $0D-$0E tektite, $0F-$10 leever, $11 zora,
                  $2B-$2D bubble (terrain-bound burrower / water /
                  jump enemies).

- **Drained C**:  - `enrt_init_leever`        @ `enemy_walker_runtime.c:37`
                  - `enrt_update_blue_leever` @ `enemy_jumper_bridge.c`
                  - `enrt_update_red_leever`  @ `enemy_jumper_bridge.c`
                  - `enrt_init_tektite`       @ `enemy_boss_runtime.c:119`
                  - `enrt_update_tektite_or_boulder` (Task 7.4 step 2a).
                  - `enrt_update_zora`        @ Task 7.4 step 2b.
                  - `enrt_init_bubble`        @ `enemy_walker_runtime.c:66`
                  - `enrt_update_bubble`      @ `enemy_walker_runtime.c:14`.

- **Coverage**:   FULL for all aquatic/terrain rows.
                  Water/terrain constraints are inherent to:
                  - `object_bound_by_room` (room boundary).
                  - `collision_get_collidable_tile_still` /
                    `_moving` vs `ObjectFirstUnwalkableTile`
                    (per-tile spawn / move gate).
                  - `c_update_burrower` state machine (mound emerge /
                    burrow / walk / retreat).
                  - Tektite jumper Y-cell wrap via `c_bound_flyer`.
                  No extra per-tile water/terrain enforcement is
                  needed beyond these primitives.

- **Stance**:     EXTEND ($0F BlueLeever, $10 RedLeever bridges) +
                  ADOPT (everything else — drained twins reused).

## Wired dispatch (Task 7.6 net delta vs Task 7.5 close baseline)

INIT delta:

| Hex | NES type    | INIT row                   | step |
|-----|-------------|----------------------------|------|
| $0F | BlueLeever  | `enrt_init_leever`         | 1    |
| $10 | RedLeever   | `enrt_init_leever`         | 1    |

UPDATE delta:

| Hex | NES type    | UPDATE row                | step |
|-----|-------------|---------------------------|------|
| $0F | BlueLeever  | `enrt_update_blue_leever` | 2    |
| $10 | RedLeever   | `enrt_update_red_leever`  | 3    |

Confirm-only (already wired in earlier tasks):

| Hex     | NES type       | INIT/UPDATE rows                                    | wired by         |
|---------|----------------|-----------------------------------------------------|------------------|
| $0D-$0E | Tektite        | `enrt_init_tektite` + `enrt_update_tektite_or_boulder` | 7.4 step 2a/6e |
| $11     | Zora           | `core_reset_obj_metastate_and_timer` + `enrt_update_zora` | 7.4 step 2b/11 |
| $2B-$2D | Bubble triple  | `enrt_init_bubble` + `enrt_update_bubble`           | 7.4 step 6d/6e   |

## Task 7.6 dispatch coverage end-state

INIT  table: 40 -> 42 wired rows (+2).
UPDATE table: 48 -> 50 wired rows (+2).

## Out-of-scope — deferred from Task 7.6

| Hex | NES type     | Status                | Owner task |
|-----|--------------|-----------------------|------------|
| —   | (none)       | aquatic/terrain family complete | — |

The "water/terrain constraints" master-plan checkbox is satisfied by
the room-boundary + walkable-tile primitives already drained — no
per-special override needed. Tektite + Zora use `c_bound_flyer`
+ `c_update_burrower`'s state-3 boundary check. Leevers use the
spawn-tile + move-tile + bound-by-room triple-gate. Bubbles use the
walker-style move + boundary chain via `enrt_update_bubble`.

## New native bodies in `src/game/enemies/`

`enemy_jumper_bridge.c` (extended steps 2 + 3):
- `enrt_update_blue_leever(slot)`        — step 2 (3-line bridge:
  ENEMY_AIR_SPEED=$A0 + Wanderer_TargetPlayer + UpdateBurrower).
- `enrt_update_red_leever(slot)`         — step 3 (full state machine).
- Static helpers (step 3):
  * `burrower_animate_draw_and_check_collisions` (shared post-cycle).
  * `red_leever_animate_and_check_collisions`.
  * `red_leever_cycle_state_draw_and_check_collisions`.
- 3 NES data tables: `RedLeeverStateQSpeeds`, `RedLeeverStateTimes`,
  `RedLeeverStateAnimTimes`.

No new TUs, no new bridge files.

## Helpers / data already linked from prior tasks

These are reused by step 2/3 bridge bodies:
- `c_update_burrower` (Task 7.4 step 2b) — uses
  `BlueLeeverStateAnimTimes` + zora-special branch.
- `enrt_wanderer_target_player` (drained twin) — turn-toward-Link AI.
- `core_reverse_obj_dir` (Phase 7 promotion).
- `collision_get_collidable_tile_still` /
  `collision_get_colliding_tile_moving` (Phase 4 promotion).
- `object_bound_by_room` (Phase 4 promotion).
- `c_obj_shove`, `c_move_object` (Phase 4 promotion).
- `sprite_anim_advance_and_fetch`, `draw_object_mirrored`,
  `link_collision_check_monster_collisions` (Phase 4 sprite/combat).

Stance compliance: every wire uses ADOPT or EXTEND. No GREENFIELD
violations.

## Build verification

`python tools/debug/build_debug.py` — clean post step 1, 2, 3 wires
(verified per-step). Step 4 close = audit + plan tick only, no
build-affecting edits.

## Phase 7 Task 7.6 closure summary

Steps 1..4 net delta vs Task 7.5 close baseline:
- INIT  rows: 40 -> 42 wired (+2 — $0F/$10 leever).
- UPDATE rows: 48 -> 50 wired (+2 — $0F/$10 leever).
- New native bodies: `enrt_update_blue_leever` +
  `enrt_update_red_leever` + 3 static helpers + 3 data tables in
  `enemy_jumper_bridge.c`.
- No new files in `RoomRom/`. Sole-target `builds/Debug.md` only.

## Step 5 sequencing (Task 7.7 hand-off)

Task 7.7 picks up Enemy Room Matrix — load enemy tables for all
overworld + dungeon rooms, verify spawn positions, room-clear opens
shutter doors, drops, etc. UW persons family ($4B-$52) lands here too
(deferred from Task 7.5 step 7).

Task 7.7 prerequisites in place after step 4:
- 50 UPDATE rows + 42 INIT rows wired across 6 enemy families.
- `core_reset_obj_metastate_and_timer` available for INIT shells.
- `c_find_empty_monster_slot` / `z07_find_empty_monster_slot`
  primitives already drained (used by spawn-on-death chains).
