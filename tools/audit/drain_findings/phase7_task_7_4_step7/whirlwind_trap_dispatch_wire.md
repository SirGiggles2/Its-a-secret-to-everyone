# Phase 7 Task 7.4 step 7 — whirlwind + trap UPDATE / INIT wires

## Task header (Drain Rule D1)

- **NES source**: `Z_07.asm:5295 UpdateObject_JumpTable`:
                  - row $2E Whirlwind -> `UpdateWhirlwind` @
                    `Z_07.asm:5698`. SwitchBank #$01 + JMP to
                    `UpdateWhirlwind_Full` @ `Z_01.asm:1765`.
                  - row $49 Trap     -> `UpdateTrap` @ `Z_07.asm:5718`.
                    SwitchBank #$01 + JMP to `UpdateTrap_Full` @
                    `Z_01.asm:2434`.
                  - row $4A Trap (alt) -> same `UpdateTrap`.
                  `Z_07.asm:5601 InitObject_JumpTable`:
                  - row $2E Whirlwind -> `DoNothing` (no init body).
                  - row $49 / $4A Trap -> `InitTrap` (SwitchBank #$01
                    + JMP `InitTrap_Full`).

- **Drained C**:  `src/oracle/world/trap_runtime.c`:
                  - `trprt_update_whirlwind_full` @ line 26.
                  - `trprt_update_trap_full` @ line 190.
                  - `trprt_init_trap_full` @ line 4.
                  Native rewrites (Phase 4 verified-by-use):
                  - `trap_update_whirlwind_full` @
                    `src/game/world/trap_dispatch.c:181`.
                  - `trap_update_trap_full` @
                    `src/game/world/trap_dispatch.c:250`.
                  - `trap_init_trap_full` @
                    `src/game/world/trap_dispatch.c:155`.

- **Coverage**:   FULL for $2E Whirlwind (no INIT row in NES jump
                  table; UPDATE wired here).
                  FULL for $49 / $4A Trap (UPDATE + INIT both wired).

- **Stance**:     ADOPT — drained native bodies + already-resolved
                  composed primitives. No new bridge edits needed.
                  `src/game/world/trap_dispatch.c` is in
                  `tools/debug/build_debug.py` ROOMROM_C_SOURCES
                  (line 94) since Phase 4. SwitchBank #$01 collapses
                  to no-op on Genesis (single linear address space).

## RAM cell map (NES Variables.inc -> state header macros)

| NES name              | NES addr | C macro                        |
|-----------------------|----------|--------------------------------|
| `ObjType`             | `$034F`  | `MON_TYPE` / `ENEMY_TYPE`      |
| `ObjState`            | `$00A0`  | `OBJ_STATE`                    |
| `ObjX`                | `$0070`  | `OBJ_X`                        |
| `ObjY`                | `$0050`  | `OBJ_Y`                        |
| `ObjMoveTimer`        | `$0028`  | `OBJ_MOVE_TIMER`               |
| `ObjStatusFlags`      | (per-slot)| `OBJ_STATUS_FLAGS`            |
| `LinkX`               | `$0070`  | `LINK_X`                       |
| `LinkY`               | `$0050`  | `LINK_Y`                       |
| `LinkDir`             | `$0098`  | `LINK_DIR`                     |
| `LinkActionTimer`     | `$006D`  | `LINK_ACTION_TIMER`            |
| `LinkCellarFlag`      | (RAM ext)| `LINK_CELLAR_FLAG`             |
| `TeleportActiveFlag`  | (RAM ext)| `TELEPORT_ACTIVE_FLAG`         |
| `TeleportLevelIndex`  | (RAM ext)| `TELEPORT_LEVEL_INDEX`         |
| `WhirlwindActiveFlag` | (RAM ext)| `WHIRLWIND_ACTIVE_FLAG`        |
| `WhirlwindPrevRoomId` | (RAM ext)| `WHIRLWIND_PREV_ROOM_ID`       |
| `FrameCounter`        | `$001A`  | `FRAME_COUNTER`                |
| `CombatCollided`      | (RAM ext)| `COMBAT_COLLIDED`              |
| `MonShoveDir`         | `$00C0`  | `MON_SHOVE_DIR`                |
| `MonShoveTimer`       | (per-slot)| `MON_SHOVE_TIMER`             |

## State machine summary

`trap_update_whirlwind_full(slot)` (Z_01.asm:1765):
1. `OBJ_X(slot) += 2` — drift right 2 px/frame.
2. If `LINK_ACTION_TIMER & 0x40` and `TELEPORT_ACTIVE_FLAG`:
   - drag Link's X with whirlwind.
   - if (tele != 1 && X==$80): finish teleport (clear ACTION_TIMER +
     ACTIVE_FLAG, kill obj, mark player position, draw, return).
   - else: skip Link collision check.
3. Else: `link_collision_check_link_collision(slot)`. On hit:
   - latch hit: LINK_DIR=1, MON_SHOVE_*=0, LINK_CELLAR_FLAG=0,
     LINK_ACTION_TIMER=$40, hide OAM 2/3.
   - record WHIRLWIND_PREV_ROOM_ID via WhirlwindPrevRoomIdList.
   - bump TELEPORT_ACTIVE_FLAG.
4. If `OBJ_X(slot) < 0xF0`: draw + return.
5. `core_destroy_whirlwind(slot)`. If TELEPORT_ACTIVE_FLAG:
   `room_go_to_next_mode_from_play()`. Draw + return.

`trap_update_trap_full(slot)` (Z_01.asm:2434):
- state == 0: bbox-test Link; on entry to range, set DIR + state to
  pursue along an axis (TrapAllowedDirs gate).
- state != 0: `object_move_object` + collision; reverse at edge of
  cluster bound. Falls through to person draw + collision check.

`trap_init_trap_full(slot)` (Z_07.asm + Z_01.asm chain):
- `count = (MON_TYPE(slot) == TRAP_OBJ_TYPE) ? 5 : 3`. Iterate
  count..0 spawning sub-objects at `TRAP_BASE_SLOT + count` from
  TrapXs/TrapYs tables. Each spawn: `core_init_one_simple_object`.

## Wired dispatch (delta from step 6c)

| Hex | NES type      | INIT row              | UPDATE row                  |
|-----|---------------|------------------------|-----------------------------|
| $2E | Whirlwind     | (none — DoNothing)     | `trap_update_whirlwind_full`|
| $49 | Trap          | `trap_init_trap_full`  | `trap_update_trap_full`     |
| $4A | Trap (alt)    | `trap_init_trap_full`  | `trap_update_trap_full`     |

## Native primitives composed (already linked)

| Primitive                                    | Native body                               |
|----------------------------------------------|-------------------------------------------|
| `core_set_up_whirlwind`                      | `core_dispatch.c`                         |
| `core_destroy_whirlwind`                     | `core_dispatch.c`                         |
| `core_init_one_simple_object`                | `core_dispatch.c:128`                     |
| `core_get_opposite_dir`                      | `core_dispatch.c`                         |
| `core_anim_set_sprite_desc_attrs(palette)`   | `core_dispatch.c:155`                     |
| `core_destroy_monster`                       | `core_dispatch.c`                         |
| `core_take_one_rupee`                        | `core_dispatch.c`                         |
| `core_abs`                                   | `core_dispatch.c`                         |
| `link_collision_check_link_collision`        | `link_collision_dispatch.c`               |
| `sprite_anim_advance_and_fetch`              | `sprite_dispatch.c:105`                   |
| `sprite_anim_set_obj_hflip`                  | `sprite_dispatch.c`                       |
| `sprite_anim_fetch_obj_pos`                  | `sprite_dispatch.c`                       |
| `draw_object_not_mirrored_with_frame`        | `draw_dispatch.c:426`                     |
| `draw_item_in_inventory`                     | `draw_dispatch.c`                         |
| `room_go_to_next_mode_from_play`             | `room_dispatch.c`                         |
| `uw_person_person_draw_and_check_collisions` | `uw_person_dispatch.c`                    |
| `progress_update_player_position_marker`     | `progress_dispatch.c`                     |
| `object_move_object`                         | `object_dispatch.c`                       |
| `enemy_find_empty_monster_slot`              | `enemy_dispatch.c`                        |

## Build verification

`python tools/debug/build_debug.py` — clean post step 7 wire. Active
scope `src/game/enemies/enemy_loop.c` (4 lines). No new files.

## Why a separate step

Step 6 family closed armos / flying-ghini / tektite / bubble / gibdo
($1E / $22 / $0D / $0E / $2B / $2C / $2D / $30) — eight rows.

Step 7 picks up two more *unblocked* drained-but-unwired rows that
already have native Phase 4 trap_dispatch.c bodies linked into
Debug.md. No bridge work, no new TUs, no data table promotion —
just dispatch row externs + table entries.

This advances Task 7.4 dispatch coverage:
  UPDATE: 29 → 32 wired rows (+3: $2E, $49, $4A).
  INIT:   23 → 25 wired rows (+2: $49, $4A; $2E has no NES INIT row).

Steps 8 / 9 / 10 / 11 unchanged from earlier sequencing:
  step 8  - $33 / $34 statue projectile shooters ($40 / $41 GuardFire
            / StandingFire — no oracle drain candidate, deferred).
  step 9  - shield handling.
  step 10 - multi-slot probe.
  step 11 - family close.
