# Drain Finding — Phase 4 Task 4.4 (native port) — progress misc batch

**Per Rule D1 Gate 1.** Drain MATCH proof + native port for 3 progress
functions: bomb-flash effect, tile-object blocking scan, Power
Triforce fanfare driver.

## Targets

| Side | Path | Lines |
|------|------|-------|
| Native (new) | `src/game/world/progress_dispatch.c` | `progress_update_bomb_flash_effect`, `progress_check_tile_objects_blocking`, `progress_check_power_triforce_fanfare` |
| Drain | `src/oracle/world/progress_runtime.c` | 50-65, 134-152, 154-168 |
| NES asm | `reference/aldonunez/Z_01.asm` | UpdateBombFlashEffect, CheckTileObjectsBlocking, CheckPowerTriforceFanfare |
| NES vars | various per function (CUR_INV_TILE $00FE, OBJ_STATE $00AC, OBJ_MOVE_TIMER $0028, MON_TYPE $034F, COMBAT_PART_INDEX $0F-ish, LINK_X $0061, LINK_Y $0062, ITEM_SFX_SECONDARY $0600, HUD_DIRTY_FLAG $0672, LINK_ACTION_TIMER $00AC, ROOM_TRANSFER_BUF_SELECT $0014, POWER_TRIFORCE_FANFARE_FLAG $0509, CURTAIN_TIMER $0028) |

## Drain MATCH proof — `update_bomb_flash_effect`

| Drain (50-65) | NES UpdateBombFlashEffect | Verdict |
|---------------|---------------------------|---------|
| `if (OBJ_STATE != $13) return` | `LDA ObjState,X / CMP #$13 / BNE @Exit` | **MATCH** |
| `mask = CUR_INV_TILE; mask >>= 1` | NES shifts CurInvTile right | **MATCH** |
| timer == $16 \|\| timer == $11 → `mask = (mask << 1) \| 1` | NES specific timer-arm | **MATCH** |
| timer == $12 \|\| timer == $0D → `mask = mask << 1` | NES specific timer-arm | **MATCH** |
| else return (no commit) | NES skip-store | **MATCH** |
| `CUR_INV_TILE = mask` | NES STA CurInvTile | **MATCH** |

## Drain MATCH proof — `check_tile_objects_blocking`

| Drain (134-152) | NES CheckTileObjectsBlocking | Verdict |
|-----------------|------------------------------|---------|
| `for (slot = 12; slot >= 1; slot--)` | NES `LDX #$0C / @loop / DEX / BPL` | **MATCH** |
| filter monster types $68/$62/$65/$66 | NES same set | **MATCH** |
| filter OBJ_STATE == 1 | NES same | **MATCH** |
| `dx = abs(LINK_X - OBJ_X); if dx >= $10 continue` | NES same range check | **MATCH** |
| `dy = abs((LINK_Y + 3) - OBJ_Y); if dy >= $10 continue` | NES adds 3 to LinkY before subtract | **MATCH** |
| `COMBAT_PART_INDEX = 0` | NES `LDA #0 / STA CombatPartIndex` | **MATCH** |

## Drain MATCH proof — `check_power_triforce_fanfare`

| Drain (154-168) | NES CheckPowerTriforceFanfare | Verdict |
|-----------------|-------------------------------|---------|
| `if (!POWER_TRIFORCE_FANFARE_FLAG) return` | NES `LDA / BEQ @Exit` | **MATCH** |
| `if (!CURTAIN_TIMER): replace_ashes_palette + ITEM_SFX_SECONDARY=32 + HUD_DIRTY_FLAG=1 + LINK_ACTION_TIMER=0 + flag=0; return` | NES same sequence | **MATCH** |
| else: `phase = CURTAIN_TIMER & 7; ROOM_TRANSFER_BUF_SELECT = (phase < 4) ? 120 : 24` | NES `AND #7 / CMP #4 / BCC :+ / LDA #24 / JMP : / LDA #120 :+ / STA $0014` | **MATCH** |

**Drain verdict: 3 functions FULL MATCH** vs NES.

## Native port

Mechanical translation. `progress_check_power_triforce_fanfare` calls
the previously-ported `progress_replace_ashes_palette_row` natively.

| Function | Drain | Native | Verdict |
|----------|-------|--------|---------|
| update_bomb_flash_effect | drain | drop-in | **MATCH** |
| check_tile_objects_blocking | drain | drop-in (signed-char abs) | **MATCH** |
| check_power_triforce_fanfare | drain (calls drain palette) | drop-in (calls native palette) | **MATCH** |

**Native verdict: FULL MATCH** for all 3 functions. No deferred TODOs.

## Cutover gate

- 3 hand-written z01_* wrappers in src/gen/z_01.c share existing
  `NATIVE_PROGRESS` gate.
- Default OFF → oracle drain.
- Defined ON → native (drop-in FULL MATCH).

## Stance update

Phase 4 Task 4.4 (Stance: ADOPT) — third progress batch. 9/12 of
src/oracle/world/progress_runtime.c ported. Remaining 3:
update_position_marker (+ player_position_marker variant) — needs
LevelMasks table + CUR_LEVEL + MAP_MARKER_* + FRAME_COUNTER state;
update_world_curtain_effect (+ bank2 variant) — has z05_ transpile
shim dependency; fetch_file_a_address_set — needs SaveFileAAddressSets
table extraction.

## Provenance

- 2026-05-03. Author: Claude Opus.
