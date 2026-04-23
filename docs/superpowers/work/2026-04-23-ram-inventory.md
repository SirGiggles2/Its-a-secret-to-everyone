# Raw RAM offset inventory — 2026-04-23

Purpose: enumerate every magic offset currently surfaced in `src/gen/*.c` so
the state-header pass can name them before any drain runs. Grouped by owning
subsystem. Entries listed here MUST be covered by the state-header /
nes_abi.h additions in Tasks 3–5.

Grep artifacts: `2026-04-23-ram-grep.txt` (60 unique `RAM(0xNNN)` refs),
`2026-04-23-nesram-grep.txt` (30 `nes_ram[...]` direct indexings).

## Shared ABI / scratch (nes_abi.h)

| Offset | Proposed name             | Notes                                    |
|--------|---------------------------|------------------------------------------|
| 0x0000 | NES_TILE_XFER_PTR_LO      | scratch pointer low / multi-use          |
| 0x0001 | NES_TILE_XFER_PTR_HI      | scratch pointer high                     |
| 0x0002 | NES_SCRATCH_2             | multi-use scratch (pattern cnt hi etc.)  |
| 0x0003 | NES_SCRATCH_3             | multi-use scratch (pattern cnt lo etc.)  |
| 0x0004 | NES_SCRATCH_4             | multi-use scratch                        |
| 0x0005 | NES_SCRATCH_5             | multi-use scratch                        |
| 0x000E | NES_FRONTEND_ADD16_HI     | front-end add16 high (existing name)     |
| 0x000F | NES_FRONTEND_ADD16_LO     | front-end add16 low / moving-dir         |
| 0x0010 | NES_CUR_LEVEL             | current dungeon level / overworld flag   |
| 0x0011 | NES_GAME_MODE_PREV        | previous game-mode latch                 |
| 0x0012 | NES_GAME_MODE             | active top-level game mode               |
| 0x0013 | NES_SUB_MODE              | mode sub-state                           |
| 0x0014 | NES_ROOM_XFER_BUF_SELECT  | room transfer buffer selector            |
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
| 0x0302 | NES_TILE_XFER_BUF_BASE    | transfer records base (VRAM addr + data) |
| 0x0325 | NES_TILE_XFER_BUF_END     | transfer buffer sentinel tail            |
| 0x051A | NES_ROOM_LAYOUT_SCRATCH   | room layout scratch                      |
| 0x0526 | NES_ROOM_ID_ALT           | alternate room id latch                  |
| 0x0529 | NES_ROOM_HISTORY_IDX      | room history cursor                      |

## Object / enemy slot (object_state.h)

| Offset | Proposed name             | Notes                                    |
|--------|---------------------------|------------------------------------------|
| 0x0070 | NES_OBJ_TILE_X_BASE       | per-slot tile X (indexed by slot)        |
| 0x0084 | NES_OBJ_TILE_Y_BASE       | per-slot tile Y                          |
| 0x00AC | NES_OBJ_STATE_BASE        | per-slot state byte                      |
| 0x0394 | NES_OBJ_ALIGN_FLAG_BASE   | per-slot alignment flag                  |
| 0x03E4 | NES_OBJ_HFLIP_BASE        | per-slot horizontal flip                 |
| 0x049E | NES_OBJ_TILE_NEXT_BASE    | per-slot next tile                       |

## Link (link_state.h)

| Offset | Proposed name             | Notes                                    |
|--------|---------------------------|------------------------------------------|
| 0x0033 | NES_MODE11_DEATH_TIMER    | mode-11 death countdown                  |
| 0x0059 | NES_LINK_ROOM_SCRATCH     | room-scratch byte used by link logic     |
| 0x0602 | NES_DEATH_FRAME_COUNTER   | death animation frame                    |
| 0x066C | NES_LINK_HALT_FLAG        | player halt flag                         |

## Item / audio (item_state.h / audio)

| Offset | Proposed name             | Notes                                    |
|--------|---------------------------|------------------------------------------|
| 0x0600 | NES_SFX_PRIMARY           | primary SFX channel (existing alias)     |

## Collision / link collision (collision_state.h)

No new magic offsets observed in gen/ logic bodies; collision already runs
through `lcrt_` / `colrt_` forwarders. Header created as a declaration
boundary placeholder so future drains have a home.

## Weapon (weapon_state.h)

No new magic offsets observed. Header created as boundary placeholder.

## HUD (hud_state.h)

No new magic offsets observed. Header created as boundary placeholder.

## Sprite / OAM (sprite_state.h)

No raw `0x0200` OAM references in current gen/. Header created as boundary
placeholder for future sprite drains.

## Save / SRAM (save_state.h)

No raw SRAM references in current gen/ bodies (all SRAM access goes through
owned `savert_` / `progrt_` layer). Header created as boundary placeholder.

## Progress extension (progress_state.h)

`0x0010` (NES_CUR_LEVEL) and `0x0013` (NES_SUB_MODE) are shared enough they
live in nes_abi.h. `progress_state.h` will re-expose needed ones via symbolic
aliases where ownership is cleanly progress.

## Empty stubs / non-forwarders (kept as-is in gen/)

Scanner yielded these symbol counts per bank:

| Bank  | Forwarders captured | Non-forwarder fn defs remaining |
|-------|--------------------:|--------------------------------:|
| z_01  | 163                 | ~69 (statics + complex-body fns)|
| z_02  | 2                   | 17                              |
| z_03  | 0                   | 1                               |
| z_04  | 96                  | 0                               |
| z_05  | 84                  | 25 (real logic — drain target Plan B) |
| z_06  | 0                   | 3                               |
| z_07  | 0                   | 44 (real logic — drain target Plan C) |

Non-forwarders stay outside the Task 9 marker region and remain
hand-owned until a future drain promotes them into runtime modules.

## Exclusions / already-named

- Symbols already defined in current `src/room_state.h`, `src/combat_state.h`,
  `src/world_state.h`, `src/frontend_state.h`, `src/enemy_state.h`,
  `src/item_state.h`, `src/progress_state.h`, `src/cave_state.h`,
  `src/targeting_state.h`, `src/trap_state.h` — confirm in Task 3 that no
  Plan W additions collide.
