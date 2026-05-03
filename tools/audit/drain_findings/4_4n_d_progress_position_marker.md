# Drain Finding — Phase 4 Task 4.4 (native port) — progress position marker

**Per Rule D1 Gate 1.** Drain MATCH proof + native port for the
overworld map position marker pair (Link's marker + per-level item
markers).

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/world/progress_dispatch.c` | `progress_update_position_marker`, `progress_update_player_position_marker`, `k_level_masks` baked-in table |
| Drain | `src/oracle/world/progress_runtime.c` | 67-102 |
| NES asm | `reference/aldonunez/Z_07.asm` | UpdatePositionMarker, UpdatePlayerPositionMarker, LevelMasks (line 747) |
| NES SRAM data | `nes_ram[$6000+$0BAC]` = base map-marker X offset |
| State accessors | `src/state/progress_state.h` | CUR_LEVEL, FRAME_COUNTER, MODE_VALUE, PLAYER_MARKER_DISABLE, MAP_MARKER_X/Y/TILE/ATTR |

## Drain MATCH proof — `update_position_marker`

| Drain (67-95) | NES UpdatePositionMarker | Verdict |
|---------------|--------------------------|---------|
| `row = (room_id & 0x70) >> 2; col = room_id & 0x0F` | NES same masks + shift | **MATCH** |
| `MAP_MARKER_Y(idx) = row + 0x17` | NES `STA MapMarkerY,X` | **MATCH** |
| `level == 0` -> `tile_val=17, col_shifted=col<<2`; else `tile_val=18, col_shifted=col<<3` | NES `LDA CurLevel / BNE :+ / LDA #17 / LDA col / ASL ASL / : LDA #18 / LDA col / ASL ASL ASL` | **MATCH** |
| `MAP_MARKER_TILE(idx) = 62` | NES `LDA #62 / STA MapMarkerTile,X` | **MATCH** |
| `MAP_MARKER_X(idx) = col_shifted + tile_val + nes_ram[$6BAC]` | NES adds SRAM base offset | **MATCH** |
| `if idx == 0: MAP_MARKER_ATTR(0) = 0; return` | NES `LDA #0 / STA MapMarkerAttr,X / RTS` for player marker | **MATCH** |
| else `attr = 3` | default full-bright | **MATCH** |
| `if level != 9 && (RAM($0671) & LevelMasks[level-1])` => keep `attr = 3` | NES `LDA $0671 / AND LevelMasks-1,Y / BNE skip_flash` | **MATCH** |
| else `flash = FRAME_COUNTER & $1F; if (flash < $10) attr = 2` | NES half-cycle flash | **MATCH** |
| `MAP_MARKER_ATTR(idx) = attr` | NES STA | **MATCH** |

## Drain MATCH proof — `update_player_position_marker`

| Drain (98-102) | NES UpdatePlayerPositionMarker | Verdict |
|----------------|--------------------------------|---------|
| `if MODE_VALUE == 9 return` | NES gate on game-over mode | **MATCH** |
| `if PLAYER_MARKER_DISABLE return` | NES gate on disable flag | **MATCH** |
| `progrt_update_position_marker(CUR_ROOM_ID, 0)` | NES delegate | **MATCH** |

## Native port

Mechanical translation. `k_level_masks[8]` baked inline (NES Z_07.asm:747:
`$01 $02 $04 $08 $10 $20 $40 $80`).

| Function | Drain | Native | Verdict |
|----------|-------|--------|---------|
| LevelMasks table | `extern const` | `static const` baked-in | **MATCH** |
| update_position_marker | drain | drop-in | **MATCH** |
| update_player_position_marker | drain (calls drain sub) | drop-in (calls native sub) | **MATCH** |

**Native verdict: FULL MATCH** for both. No deferred TODOs.

## Cutover gate

- 2 hand-written z01_* wrappers in src/gen/z_01.c share existing
  `NATIVE_PROGRESS` gate.
- Default OFF → oracle drain.
- Defined ON → native (drop-in FULL MATCH).

## Stance update

Phase 4 Task 4.4 (Stance: ADOPT) — fourth progress batch. 11/12 of
src/oracle/world/progress_runtime.c ported. Remaining 1:
`update_world_curtain_effect` (+ bank2 variant) — has z05_copy_column_to_tilebuf
transpile-shim dependency. Defers to z05 subsystem port. Plus
fetch_file_a_address_set is also unported (needs SaveFileAAddressSets
table extraction); recount: 10/12 if we count that. Remaining: 2
batches, 3 functions (curtain x2 + fetch_file_a).

## Provenance

- 2026-05-03. Author: Claude Opus.
- NES Z_07.asm:747 LevelMasks table cited.
