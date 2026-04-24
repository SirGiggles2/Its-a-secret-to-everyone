# Raw RAM offset inventory — 2026-04-23

Purpose: enumerate every magic offset currently surfaced in `src/gen/*.c` so
the state-header pass can name them before any drain runs. Grouped by owning
subsystem. Entries listed here MUST be covered by the state-header / nes_abi.h
additions in Tasks 3–5.

## Shared ABI / scratch (nes_abi.h)

| Offset | Proposed name             | Notes                                    |
|--------|---------------------------|------------------------------------------|
| 0x0000 | NES_TILE_XFER_PTR_LO      | scratch pointer low / multi-use          |
| 0x0001 | NES_TILE_XFER_PTR_HI      | scratch pointer high                     |
| 0x0002 | NES_SCRATCH_2             | multi-use scratch                        |
| 0x0003 | NES_SCRATCH_3             | multi-use scratch                        |
| 0x0004 | NES_SCRATCH_4             | multi-use scratch                        |
| 0x0005 | NES_SCRATCH_5             | multi-use scratch                        |
| 0x0010 | NES_CUR_LEVEL             | current dungeon level / overworld flag   |
| 0x0011 | NES_GAME_MODE_PREV        | previous game-mode latch                 |
| 0x0012 | NES_GAME_MODE             | active top-level game mode               |
| 0x0013 | NES_SUB_MODE              | mode sub-state                           |
| 0x0015 | NES_FRAME_TICK            | frame tick bit field                     |
| 0x0016 | NES_SAVE_SLOT             | selected save slot 0..2                  |

## Room subsystem (room_state.h)

| Offset | Proposed name             | Notes                                    |
|--------|---------------------------|------------------------------------------|
| 0x00E8 | NES_TILE_XFER_COL         | target column + 1                        |
| 0x00E9 | NES_TILE_XFER_ROW         | target row                               |
| 0x00EB | NES_CUR_ROOM_ID           | currently loaded room id                 |
| 0x00FE | NES_PPU_MASK_SHADOW       | PPU mask written pre-vblank              |
| 0x0301 | NES_TILE_XFER_BUF_IDX     | next free byte in transfer buffer        |
| 0x0302 | NES_TILE_XFER_BUF_BASE    | transfer records base                    |
| 0x0526 | NES_ROOM_ID_ALT           | alternate room id latch                  |
| 0x0529 | NES_ROOM_HISTORY_IDX      | room history cursor                      |
| 0x0621 | NES_ROOM_HISTORY_BASE     | room history 6-entry table base          |
| 0x0657 | NES_ITEMS_BY_LEVEL_BASE   | per-level item bitmap table base         |
| 0x6530 | NES_PLAY_AREA_BASE        | 22x32 play-area tile storage             |
| 0x0016 | (shares NES_TILE_COL_STRIDE 0x16) | stride constant, not RAM          |

## Object / enemy slot (object_state.h)

| Offset | Proposed name             | Notes                                    |
|--------|---------------------------|------------------------------------------|
| 0x0070 | NES_OBJ_TILE_X_BASE       | per-slot tile X (indexed by slot)        |
| 0x0084 | NES_OBJ_TILE_Y_BASE       | per-slot tile Y                          |
| 0x0098 | NES_OBJ_FLAG_BASE         | per-slot flag byte                       |
| 0x00AC | NES_OBJ_STATE_BASE        | per-slot state byte                      |
| 0x00C0 | NES_OBJ_SHOVE_DIR_BASE    | per-slot shove direction                 |
| 0x00D3 | NES_OBJ_SHOVE_DIST_BASE   | per-slot shove distance                  |
| 0x034F | NES_OBJ_TYPE_BASE         | per-slot object type                     |
| 0x0394 | NES_OBJ_ALIGN_FLAG_BASE   | per-slot alignment flag                  |
| 0x03D0 | NES_OBJ_ANIM_CNTR_BASE    | per-slot anim counter                    |
| 0x03E4 | NES_OBJ_HFLIP_BASE        | per-slot horizontal flip                 |
| 0x0405 | NES_OBJ_METASTATE_BASE    | per-slot meta state                      |
| 0x049E | NES_OBJ_TILE_NEXT_BASE    | per-slot next tile                       |
| 0x04F0 | NES_OBJ_INV_TIMER_BASE    | per-slot invincibility timer             |

## Sprite / OAM (sprite_state.h)

| Offset | Proposed name             | Notes                                    |
|--------|---------------------------|------------------------------------------|
| 0x0200 | NES_OAM_BASE              | OAM shadow, 64 sprites * 4 bytes         |

## Link (link_state.h)

| Offset | Proposed name             | Notes                                    |
|--------|---------------------------|------------------------------------------|
| 0x000F | NES_LINK_MOVING_DIR       | moving direction bits                    |
| 0x0033 | NES_MODE11_DEATH_TIMER    | mode-11 death countdown                  |
| 0x0059 | NES_LINK_ROOM_SCRATCH     | room-scratch byte used by link logic     |
| 0x0602 | NES_DEATH_FRAME_COUNTER   | death animation frame                    |
| 0x066C | NES_LINK_HALT_FLAG        | player halt flag                         |

## Save / SRAM (save_state.h)

| Offset         | Proposed name                 | Notes                        |
|----------------|-------------------------------|------------------------------|
| 0x6000 + 0x09FE| NES_SRAM_ROOM_UNIQUE_ID_BASE  | per-room unique id table     |
| 0x6000 + 0x0BAF| NES_SRAM_ROOM_FLAGS_PTR_LO    | room-flags pointer low       |
| 0x6000 + 0x0BB0| NES_SRAM_ROOM_FLAGS_PTR_HI    | room-flags pointer high      |
| 0x0630         | NES_CONTINUE_COUNT_BASE       | per-slot continue counter    |

## Collision / link collision (collision_state.h)

No new magic offsets observed in gen/ logic bodies; collision already runs
through `lcrt_` / `colrt_` forwarders. Header created as a declaration
boundary placeholder so future drains have a home.

## Weapon (weapon_state.h)

No new magic offsets observed. Header created as boundary placeholder.

## HUD (hud_state.h)

No new magic offsets observed. Header created as boundary placeholder.

## Progress / item (progress_state.h extension)

`0x0010` (NES_CUR_LEVEL) lives in nes_abi.h. `0x0657` is an item-bitmap
table; declare `NES_ITEMS_BY_LEVEL_BASE` in `progress_state.h` pointing
at the nes_abi.h constant to keep ownership clear.

## Exclusions / already-named

- `NES_OBJ_DIR_STATE (0x000F)` — already named in `nes_abi.h`; confirm in Task 3.
- `NES_CUR_SLOT (0x0016)` — already named; confirm in Task 3.
- Per-slot offsets already named by earlier phases — confirm in Task 3 grep.
