# Phase 7 Task 7.4 step 6c — armos + flying-ghini INIT wires (closes step 6)

## Task header (Drain Rule D1)

- **NES source**: `Z_07.asm:5601 InitObject_JumpTable`
                  rows $1E (Armos) and $22 (FlyingGhini) ->
                  `InitArmosOrFlyingGhini` (`Z_04.asm:3147`).
                  Body composes:
                  - `SecretArmosRoomIds` + `SecretArmosXs`
                    (`Z_04.asm:3144 / 3151` — 7-entry tables).
                  - `ChangeTileObjTiles`     (`Z_07.asm:1114`).
                  - `ChangePlayMapSquareOW`  (`Z_05.asm:6102`).
                  - `WriteSquareOW`          (`Z_05.asm:5942`).
                  - `PrimarySquaresOW`       (`Z_05.asm:5731`).
                  - `SecondarySquaresOW`     (`Z_05.asm:5740`).
                  - `PlaySecretFoundTune`    (`Z_04.asm:4088`).
                  - `GetRoomFlagUWItemState` (`Z_01.asm:4318`).
                  - `EndInitFlyer`           (`Z_07.asm:0`-region tail).
                  - `ResetObjMetastateAndTimer`.
                  - `DrawArmosAndCheckCollisions` (armos draw helper).
                  - `DrawGhiniAndCheckCollisions` (ghini fade helper).

- **Drained C**:  No oracle drain candidate for `InitArmosOrFlyingGhini`
                  in `src/oracle/enemies/`. Stance EXTEND with native
                  bodies in `src/game/`:
                  - **NEW** `src/game/world/dyn_tile_dispatch.c` carries
                    `dyn_tile_change_tile_obj_tiles`,
                    `dyn_tile_change_play_map_square_ow`,
                    `dyn_tile_write_square_ow` plus the
                    `k_play_area_column_addrs` (Z_07.asm:336),
                    `k_primary_squares_ow` (Z_05.asm:5731), and
                    `k_secondary_squares_ow` (Z_05.asm:5740) data
                    tables.
                  - **NEW** `enrt_init_armos_or_flying_ghini` body in
                    `src/game/enemies/enemy_walker_bridge.c:1047` plus
                    `k_secret_armos_room_ids[7]` /
                    `k_secret_armos_xs[7]` data tables (verbatim from
                    `Z_04.asm:3144 / 3151`).
                  Composed primitives all already drained:
                  - `core_map_screen_pos_to_ppu_addr` @
                    `src/game/core/core_dispatch.c:383`.
                  - `core_add_to_int16_at_0` @
                    `src/game/core/core_dispatch.c:319`.
                  - `core_reset_obj_metastate_and_timer` @
                    `src/game/core/core_dispatch.c`.
                  - `progress_get_room_flag_uw_item_state` @
                    `src/game/world/progress_dispatch.c:287`.
                  - `enemy_play_secret_found_tune` @
                    `src/game/enemies/enemy_dispatch.c:36`.
                  - `enrt_end_init_flyer` @
                    `src/oracle/enemies/enemy_flyer_runtime.c:112`.
                  - `armos_draw_and_check_collisions` @
                    `src/game/enemies/enemy_walker_bridge.c:946`.
                  - `enrt_draw_ghini_and_check_collisions` @
                    `src/oracle/enemies/enemy_walker_runtime.c:295`.

- **Coverage**:   FULL for $1E (UPDATE wired in step 6b + INIT wired here).
                  FULL for $22 (UPDATE wired in step 6a + INIT wired here).
                  Closes step 6 family ($1E / $22 / $0D / $0E / $2B / $2C /
                  $2D / $30 all wired across UPDATE + INIT where present
                  in the NES jump tables).

- **Stance**:     EXTEND (NES-asm-to-C native bodies, no oracle drain
                  candidate). Data tables ADOPT verbatim from NES.

## Why a native drain unblocks step 6c

`InitArmosOrFlyingGhini` reaches `ChangeTileObjTiles`, which calls a
SwitchBank pair around `ChangePlayMapSquareOW`. The legacy translated
build resolved `c_change_tile_obj_tiles` via `c_shims.asm:4669`, but
`tools/debug/build_debug.py` does not link `c_shims.asm`, so any
drain that called `c_change_tile_obj_tiles` produced an unresolved
symbol at link time. Step 6c picks the long-term fix (CLAUDE.md
"Decisions" rule): translate the three NES bodies to native C with
the data tables ADOPTed verbatim, then expose them via
`src/game/world/dyn_tile_dispatch.h`. SwitchBank #$04 / #$05 are
no-ops on the Genesis (single linear address space) so the bank
flips collapse to flag-clearing of `ReturnToBank4` ($00F7).

## RAM cell map (NES Variables.inc -> state/enemy_state.h + raw cells)

| NES name           | NES addr  | C macro / cell                  |
|--------------------|-----------|---------------------------------|
| `ObjType`          | `$034F`   | `ENEMY_TYPE`                    |
| `ObjTimer`         | `$0028`   | `ENEMY_MOVE_TIMER`              |
| `ObjUninitialized` | `$0492`   | `ENEMY_ALIVE_FLAG` (double-duty)|
| `ObjX`             | `$0070`   | `ENEMY_X`                       |
| `ObjY`             | `$0050`   | `ENEMY_Y`                       |
| `ObjState`         | `$00A0`   | `ENEMY_STATE_TIMER`             |
| `ObjDir`           | `$0098`   | `ENEMY_DIR`                     |
| `ObjInputDir`      | `$03F8`   | `ENEMY_PUSH_DIR_SCRATCH`        |
| `ObjGridOffset`    | `$0394`   | `OBJ(NES_OBJ_GRID_OFFSET)`      |
| `ObjQSpeedFrac`    | (per-slot)| `ENEMY_WALK_SPEED`              |
| `Random`           | `$0010`   | `ENEMY_RNG_A`                   |
| `RoomItemId`       | `$0098`   | `OBJ(NES_OBJ_FLAG_BASE,19)`     |
| `CurRoomId`        | `$00EB`   | `RAM(NES_CUR_ROOM_ID)`          |
| `ReturnToBank4`    | `$00F7`   | `RAM(0x00F7)`                   |
| `DynTileBuf`       | `$0302`   | `ROOM_TILE_XFER_BUF[*]`         |
| `DynTileBufLen`    | `$0301`   | `ROOM_TILE_XFER_BUF_IDX`        |

## State machine summary (`enrt_init_armos_or_flying_ghini`)

```
1. ENEMY_ALIVE_FLAG = ENEMY_MOVE_TIMER       (latch ObjUninitialized).
2. if MOVE_TIMER != 0       -> goto FinishInit (still fading in).
3. if TYPE == $22 FlyingGhini -> goto FinishInit (skip armos secret logic).
4. Armos secret-room scan (idx 6 down to 0):
     - For (room, x, y=$80) match:
         idx == 0 -> Bracelet path:
                     stage room item slot 19,
                     PlaySecretFoundTune unless RoomFlagUWItemState set,
                     chosen_tile = $26 (floor).
         idx >  0 -> stairs path: chosen_tile = $70 (default).
     - No match -> chosen_tile = $26 (floor).
5. if chosen_tile == $70 -> PlaySecretFoundTune.
6. INC ReturnToBank4; dyn_tile_change_tile_obj_tiles(chosen_tile, slot).
7. OBJ_GRID_OFFSET = 3.
8. ENEMY_WALK_SPEED = (RNG_A < $80) ? $20 : $60.

FinishInit:
9.  PUSH_DIR_SCRATCH = $04, DIR = $04 (face down).
10. if (MOVE_TIMER & 1)             -> return (skip-draw frame).
11. if TYPE == $22 FlyingGhini:
       enrt_draw_ghini_and_check_collisions(slot).
       if ALIVE_FLAG != 0          -> return (still fading).
       core_reset_obj_metastate_and_timer(slot).
       enrt_end_init_flyer(slot).
       return.
12. armos_draw_and_check_collisions(slot).
```

## Native primitives composed (dyn_tile_dispatch.c)

| Primitive                                 | Native body                          |
|-------------------------------------------|--------------------------------------|
| `dyn_tile_change_tile_obj_tiles`          | new — Z_07.asm:1114 EXTEND drain     |
| `dyn_tile_change_play_map_square_ow`      | new — Z_05.asm:6102 EXTEND drain     |
| `dyn_tile_write_square_ow`                | new — Z_05.asm:5942 EXTEND drain     |
| `core_map_screen_pos_to_ppu_addr`         | already drained (core_dispatch.c)    |
| `core_add_to_int16_at_0`                  | already drained (core_dispatch.c)    |

`SwitchBank #$04 / #$05` collapse to no-ops on Genesis. ReturnToBank4
($00F7) is still tracked for behavioural parity (some legacy paths
poll it) and is cleared at the tail of `dyn_tile_change_tile_obj_tiles`.

## Wired dispatch (delta from step 6e)

| Hex | NES type    | INIT row                              | UPDATE row                          |
|-----|-------------|---------------------------------------|-------------------------------------|
| $1E | Armos       | `enrt_init_armos_or_flying_ghini`     | `enrt_update_armos`     (step 6b)   |
| $22 | FlyingGhini | `enrt_init_armos_or_flying_ghini`     | `enrt_update_flying_ghini` (6a)     |

## Build verification

`python tools/debug/build_debug.py` — clean post step 6c wire. Active
scope `src/game/enemies/**` + `src/game/world/dyn_tile_dispatch.c`.
No new `RoomRom/` files per WT-5.

## Step 6 progression summary (final)

- 6a (`4dc8466a`): $22 FlyingGhini UPDATE wire.
- 6b (`96d722b9`): $1E Armos UPDATE wire.
- 6d:             $2B/$2C/$2D bubble + $30 gibdo UPDATE wires.
- 6e:             $0D/$0E tektite UPDATE + $0D/$0E/$2B/$2C/$2D INIT wires.
- 6c (this step): native ChangeTileObjTiles drain +
                  $1E/$22 INIT wires. **Closes step 6 family.**

Total dispatch coverage advance: 29 -> 29 wired UPDATE rows
(no UPDATE delta in 6c) and 21 -> 23 wired INIT rows.

Steps 7..11 unchanged from earlier sequencing:
  step 7  - $2E whirlwind family,
  step 8  - $33/$34 statue projectile,
  step 9  - shield handling,
  step 10 - multi-slot probe,
  step 11 - family close.
