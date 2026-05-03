# Palette Toggle Inventory (Phase 2.6.5)

> Per master plan Task 2.6.5: every NES frame-cadence palette toggle that the Phase 2.6 renderer cutover would otherwise strip must be preserved by the typed `palette_toggle_t` system in `src/state/palette_state.h` + the `palette_tick(frame)` runtime that lives in RoomRom (promoted at Phase 12).

## Format per row

- **Toggle id**: stable string for logging + parity-oracle diff
- **NES source**: file:line in disassembly + RAM/PALRAM target
- **Kind**: `BG_SUBPAL`, `SPR_SUBPAL`, or `CRAM_SLOT`
- **Target index**: which sub-pal (0..3) or CRAM slot
- **Cadence**: `FrameCounter & bit_N`
- **State A / State B**: the two flip values
- **Probe**: parity probe id that asserts the cadence

## Toggles to preserve

| # | Toggle id | NES source | Kind | Target | Cadence | A | B | Probe |
|---|-----------|------------|------|--------|---------|---|---|-------|
| 1 | `intro_item_flash_8f` | `Z_07.asm:878 DrawItemBySlot @Flash` (slots $16, $19, $1A, $1B) | SPR_SUBPAL | per-item slot | `bit 3` (8-frame) | sprite pal 1 (blue `$00 $02 $22 $30`) | sprite pal 2 (red `$00 $16 $27 $30`) | `intro_item_flash_8frame_cycle` |
| 2 | `low_health_hearts_flash` | TODO: locate in Z_05/Z_06 status-bar render | BG_SUBPAL | hearts row sub-pal | `bit 3` (8-frame) | normal red | bright red | `low_health_flash` |
| 3 | `boss_aquamentus_palette_flash` | TODO: locate in Z_04 boss render | SPR_SUBPAL | boss sprite sub-pal | TBD | base palette | flash palette | `boss_aquamentus_palette_flash` |
| 4 | `link_hit_invuln_flash` | TODO: locate in Z_07 Link draw with HIT_REACTION | SPR_SUBPAL | Link sprite sub-pal | `bit 0` (2-frame) when invuln | normal | invuln (cycling) | `link_hit_invuln_flash` |
| 5 | `heart_container_pickup_blink` | TODO: heart-container pickup sequence | SPR_SUBPAL | container sprite | TBD | base | blink | `heart_container_pickup_blink` |
| 6 | `triforce_dungeon_clear_flash` | TODO: triforce-spawn on dungeon clear | SPR_SUBPAL | triforce sprite | TBD | base | flash | `triforce_dungeon_clear_flash` |

## Owner runtime

Default: typed `palette_toggle_t` in `src/state/palette_state.h` (substrate, main worktree). Implementation `palette_tick_init/register_toggle/palette_tick` lives in RoomRom (gameplay-side). Promoted to `src/game/palette_runtime.c` at Phase 12.

## Implementation order

1. **Substrate first** (this commit): `palette_toggle_t` + `palette_tick_state_t` + API declarations in `palette_state.h`. Inventory doc (this file).
2. RoomRom runtime: `RoomRom/src/roomrom_palette_tick.c` implements `palette_tick_init`, `palette_register_toggle`, `palette_tick`. Pure C, no SGDK API calls — reads/writes `PaletteState.nes_palram` and bumps `generation`.
3. Per-toggle implementation + probe: start with `intro_item_flash_8f` (best-documented; memory `project_intro_item_flash` has the full NES trace). Add probe `intro_item_flash_8frame_cycle` per Phase 1.5 capture pipeline.
4. Continue per toggle: low_health_hearts_flash, boss_aquamentus_palette_flash, link_hit_invuln_flash, heart_container_pickup_blink, triforce_dungeon_clear_flash.
5. Phase 2.6.5 close-gate: all 6 toggles implemented + probes pass + diff against `build/generated/nes_reference/` captures (where Phase 1.5 captures exist).

## Why this matters

Phase 2.6 cutover replaces the old `pal & 0x03 << 13` per-tile-attr palette routing with a tile-index sub-palette selection (each tile lives in exactly one sub-pal slot). That cutover STRIPS the per-frame palette-index toggle that NES Zelda relied on for item flash, low-health, boss flash, etc.

Without Phase 2.6.5: visually-identical Genesis renderer that loses every palette animation. With Phase 2.6.5: NES parity preserved through the new tile-index world.

## Related memory

- `project_intro_item_flash` — heart/container flash mechanism (NES Z_07:878)
- `project_chr_expansion` — 14-stage CHR rollout that interacts with palette layout
- `project_intro_loop` — intro phase machine that consumes intro item flash
