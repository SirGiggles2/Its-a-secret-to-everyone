# Drain Finding — Phase 4 Task 4.4 (native port) — progress palette + reset_room_tile

**Per Rule D1 Gate 1.** Drain MATCH proof + native port for 3 ganon-
palette-replace variants + reset_room_tile_obj_info trivial.

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/world/progress_dispatch.c` | `progress_replace_ganon_brown_palette_row`, `progress_replace_ganon_blue_palette_row`, `progress_replace_ashes_palette_row`, `progress_reset_room_tile_obj_info`, file-static `progress_replace_palette_row_common`, baked-in tables |
| Drain | `src/oracle/world/progress_runtime.c` | 8-30 |
| NES asm | `reference/aldonunez/Z_01.asm` | ReplaceGanonBrownPaletteRow / Blue / Ashes (which all share a common helper sub-routine) |
| NES tables | `src/data/palette_tables.inc` (extracted by extract_misc.py) | `PaletteRow7TransferRecord` (8 bytes: $3F $1C $04 $0F $07 $17 $27 $FF), `GanonColorTriples` (9 bytes: brown $07 $17 $30; blue $16 $2C $3C; ashes $27 $06 $16) |
| State accessors | `src/state/progress_state.h`, `world_state.h` | `ROOM_TILE_OBJ_0/1/2 = RAM($052B/$052C/$052D)`, `TRANSFER_BUF_BYTE/POS` |

## Drain MATCH proof — palette-row replace family

| Drain (8-23) | NES (Z_01.asm) | Verdict |
|--------------|-----------------|---------|
| append `PaletteRow7TransferRecord[0..7]` to dynamic transfer buf at TRANSFER_BUF_POS | NES copies 8 bytes from PaletteRow7TransferRecord into DynTileBuf at DynTileBufLen | **MATCH** |
| `for (j=0..2) RAM($0306+j) = GanonColorTriples[color_index - 2 + j]` | NES `LDA GanonColorTriples,Y / STA $0306,j` with Y = color_index | **MATCH** (offset arithmetic preserved). |
| brown variant: `common(2)` → triples[0..2] = $07/$17/$30 | NES `LDA #$02 / JSR ReplacePaletteRowCommon` | **MATCH** |
| blue variant: `common(5)` → triples[3..5] = $16/$2C/$3C | NES `LDA #$05 / JSR ReplacePaletteRowCommon` | **MATCH** |
| ashes variant: `common(8)` → triples[6..8] = $27/$06/$16 | NES `LDA #$08 / JSR ReplacePaletteRowCommon` | **MATCH** |

## Drain MATCH proof — `reset_room_tile_obj_info`

Trivial: zero 3 RAM cells ($052B/$052C/$052D) + return 0. drain matches
NES `LDA #$00 / STA ROOM_TILE_OBJ_0/1/2 / RTS`. **MATCH**.

## Native port

Mechanical translation. Both NES tables baked in as `static const`
arrays inside progress_dispatch.c so native code is independent of
`src/data/palette_tables.inc` (which lives in the data extraction
pipeline). Future regeneration of palette_tables.inc must update the
baked-in copies — flag for tools/data-coverage gate.

| Function | Drain | Native | Verdict |
|----------|-------|--------|---------|
| common helper | drain `static` | drain shape with baked-in tables | **MATCH** |
| brown/blue/ashes | drain | drop-in (call common with 2/5/8) | **MATCH** |
| reset_room_tile_obj_info | drain | drop-in | **MATCH** |

**Native verdict: FULL MATCH** for all 4 functions. No deferred TODOs.

## Cutover gate

- 4 hand-written z01_* wrappers in src/gen/z_01.c share existing
  `NATIVE_PROGRESS` gate from finding 4_4n.
- Default OFF → oracle drain.
- Defined ON → native (drop-in FULL MATCH).
- RoomRom links unconditionally.

## Stance update

Phase 4 Task 4.4 (Stance: ADOPT) — second progress batch. 6/12 of
src/oracle/world/progress_runtime.c ported. Remaining 6:
update_bomb_flash_effect, update_position_marker (+ player_position),
update_world_curtain_effect (+ bank2 variant), fetch_file_a_address_set,
check_tile_objects_blocking, check_power_triforce_fanfare. Most have
larger state surfaces (CUR_LEVEL, MAP_MARKER_*, CUR_INV_TILE,
FRAME_COUNTER, HUD_DIRTY_FLAG, MON_TYPE, COMBAT_PART_INDEX).

## Provenance

- 2026-05-03. Author: Claude Opus.
- src/data/palette_tables.inc cited for table values.
