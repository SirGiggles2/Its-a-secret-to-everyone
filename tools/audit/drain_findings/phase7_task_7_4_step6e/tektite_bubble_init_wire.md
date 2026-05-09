# Phase 7 Task 7.4 step 6e — tektite UPDATE + bubble/tektite INIT wires

## Task header (Drain Rule D1)

- **NES source**: `Z_07.asm:5295 UpdateObject_JumpTable` rows $0D/$0E ->
                  `UpdateTektiteOrBoulder` (Tektite branch).
                  `Z_07.asm:5601 InitObject_JumpTable` rows $0D/$0E ->
                  `InitTektite`, $2B/$2C/$2D -> `InitBubble`.
- **Drained C**:  Existing oracle drains, no new bodies:
                  - `enrt_update_tektite_or_boulder` @
                    `src/oracle/enemies/enemy_boss_runtime.c:126`
                    (already wired for $20 Boulder in step 2a; tektite
                     branch at line 228 keys off `obj_type != 0x0D`).
                  - `enrt_init_tektite` @
                    `src/oracle/enemies/enemy_boss_runtime.c:119`.
                  - `enrt_init_bubble` @
                    `src/oracle/enemies/enemy_walker_runtime.c:66`.
- **Coverage**:   FULL for $0D/$0E (UPDATE + INIT wired). PARTIAL for
                  $2B/$2C/$2D (UPDATE wired in step 6d; INIT wired here).
                  Step 6 family closes after step 6c (deferred,
                  ChangeTileObjTiles native drain pending).
- **Stance**:     ADOPT — drained bodies linked verbatim. No bridge
                  edits; all primitives already resolved by Tasks
                  7.2/7.3 + earlier 7.4 steps.

## RAM cell map (NES Variables.inc -> state/enemy_state.h)

| NES name           | NES addr | C macro              |
|--------------------|----------|----------------------|
| `ObjType`          | `$034F`  | `ENEMY_TYPE`         |
| `ObjDir`           | `$0098`  | `ENEMY_DIR`          |
| `ObjTimer`         | `$0028`  | `ENEMY_MOVE_TIMER`   |
| `Random+1`         | `RNG`    | `ENEMY_RNG_B`        |
| `ObjWalkSpeed`     | (per-slot)| `ENEMY_WALK_SPEED`  |

`enrt_init_tektite` body: `dir = TektiteStartingDirs[RNG_B & 3]; MOVE_TIMER = dir << 2`.

`TektiteStartingDirs` data lives in `src/game/enemies/enemy_jumper_bridge.c`
(linked since Task 7.4 step 2a).

## Wired dispatch (delta from step 6d)

| Hex | NES type    | INIT row             | UPDATE row                      |
|-----|-------------|----------------------|---------------------------------|
| $0D | BlueTektite | `enrt_init_tektite`  | `enrt_update_tektite_or_boulder`|
| $0E | RedTektite  | `enrt_init_tektite`  | `enrt_update_tektite_or_boulder`|
| $2B | BlueBubble  | `enrt_init_bubble`   | `enrt_update_bubble` (step 6d)  |
| $2C | RedBubble   | `enrt_init_bubble`   | `enrt_update_bubble` (step 6d)  |
| $2D | BlueBubble2 | `enrt_init_bubble`   | `enrt_update_bubble` (step 6d)  |

## Native primitives composed (already linked)

`enrt_update_tektite_or_boulder` chain (linked since step 2a):
- `c_turn_towards_player8` -> `enemy_jumper_bridge.c`.
- `c_bound_flyer` -> `enemy_jumper_bridge.c`.
- `enrt_jumper_animate_and_check_collisions` -> `enemy_boss_runtime.c`.
- `enrt_jumper_point_boulder_downward` -> `enemy_boss_runtime.c:243`.
- `enrt_jumper_get_kind` / `enrt_jumper_y_offsets` /
  `enrt_jumper_y_accelerations` / `enrt_jumper_start_speeds_hi` ->
  `enemy_boss_runtime.c` data tables.
- `z01_abs` / `z07_reset_obj_state` -> `enemy_walker_bridge.c`.

## Build verification

`python tools/debug/build_debug.py` — clean post step 6e wire. Active
scope `src/game/enemies/**`. No new `RoomRom/` files per WT-5.

## Step 6 progression summary

- 6a (`4dc8466a`): $22 FlyingGhini UPDATE wire.
- 6b (`96d722b9`): $1E Armos UPDATE wire.
- 6d:             $2B/$2C/$2D bubble + $30 gibdo UPDATE wires.
- 6e (this step): $0D/$0E tektite UPDATE + $0D/$0E/$2B/$2C/$2D INIT wires.
- 6c (deferred):  drain `c_change_tile_obj_tiles` natively + drain
                  `InitArmosOrFlyingGhini` fully + wire $1E + $22 INIT
                  rows. Audit-doc step 6 closes when 6c lands.

Steps 7..11 unchanged from step 1 audit doc sequencing.

Total dispatch coverage advance: 27 -> 29 wired UPDATE rows + 16 -> 21
wired INIT rows.
