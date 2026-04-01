# WHAT IF Progress

Last updated: 2026-03-30

## Current Position

- Phase 1 is complete.
- Phase 2 is complete.
- Phase 3 is in progress, and the graphics-recovery milestone is now complete.
- `P3.50` keeps the corrected opening-screen baseline, all four overworld room transitions, and now supports basic cave enter/exit behavior in the Phase 3 smoke scene.

## Phase Status

| Phase | Status | Notes |
|------|--------|-------|
| 1 | Complete | Extraction pipeline is integrated into `build.bat` and emits the plan-facing graphics outputs plus the broader data set. |
| 2 | Complete | The renderer now has split HUD/playfield layout, ownership-aware sprite handling, queued VBlank transfers, RAM-backed DMA for sprite/scroll uploads, and horizontal/vertical streaming foundations. |
| 3 | In progress | `P3.50` carries the corrected room baseline forward, keeps smooth four-direction overworld transitions, and now includes initial cave enter/exit flow in the smoke scene. |
| 4 | Not started | Player movement/combat not started. |
| 5 | Not started | Object slot framework and enemy behavior not started. |
| 6 | Not started | Mode manager not started. |
| 7 | Not started | Real frontend/menu logic not started. |
| 8 | Not started | Audio driver not started. |
| 9 | Not started | Polish and second quest verification not started. |

## Phase 3 Progress

Completed so far:

- Added `src/rooms.asm` as the first real room-system module.
- Ported the original overworld room decode path from the NES column/square format:
  - start-room selection from `LevelInfo_StartRoomId`
  - room layout lookup by unique room id
  - column-directory lookup by descriptor high nibble
  - compressed column scan by descriptor low nibble
  - square decode through `PrimarySquaresOW` / `SecondarySquaresOW`
  - tile-object primary replacement for the visible overworld room image
- Added a Genesis-side `FillPlayAreaAttrs` equivalent and a dedicated playfield-attribute buffer.
- Added an offline ground-truth path:
  - `tools/render_overworld_reference.py`
  - `builds/reports/overworld_start_room_reference.png`
  - `builds/reports/overworld_start_room_reference.json`
- Added a direct NES-side ground-truth capture/comparison loop:
  - `tools/bizhawk_nes_start_capture.lua`
  - `builds/reports/nes_start_capture.png`
  - `builds/reports/nes_start_tilemap.json`
  - `tools/compare_nes_start_room.py`
- Added a room-fidelity verification path:
  - `tools/bizhawk_phase3_room_fidelity_probe.lua`
  - `tools/check_room_fidelity.py`
  - `tools/run_bizhawk_phase3_room_fidelity_probe.bat`
- Fixed two real bring-up / stability issues in the Genesis shell:
  - `STACK_TOP` now points to `$00FFFFFE` instead of colliding with the low-RAM variable block
  - `DefaultException` now stops and loops instead of `rte`-ing back into undefined behavior
- Fixed a major extractor bug in `tools/extract_chr.py`:
  - bank-2 common pattern data was being found with an invalid ISR-based heuristic
  - `CommonBackgroundPatterns` was effectively coming out of the post-data `$FF` padding block
  - the extractor now anchors bank 2 on the explicit `161`-byte `$FF` padding run after `CommonMiscPatterns`, matching `Z_02.asm`
  - this corrected the common BG tile atlas used by every overworld room
- Fixed the real bank-3 overworld pattern seam in `tools/extract_chr.py`:
  - the old bank-3 heuristic assumed the pattern blocks ended right before `BANK_03_ISR`
  - live NES CHR-RAM capture proved the actual overworld BG block for room `$77` comes from bank 3 offset `$093B`, not the old extracted seam at `$1CB0`
  - the verified bank-3 pattern-data seam is now anchored at `$011B`
  - this corrected the overworld BG atlas and removed the blue-speckled, wrong-tree scenery that was still visible in `P3.37`
- Fixed the NES-side CHR dump tooling so graphics debugging uses real CHR-RAM data:
  - `tools/dump_nes_start_bg.lua` now reads BizHawk's `CHR`, `CIRAM (nametables)`, and `PALRAM` domains instead of the invalid `PPU Bus` path
  - it now respects `PPUCTRL` bit 4 and dumps the active BG pattern table half (`$1000-$1FFF` for room `$77`)
  - this made the bank-3 seam bug directly provable from the live NES start screen
- Fixed the real overworld layout extraction seam in `tools/extract_rooms.py`:
  - `RoomLayoutsOW` is `0x390` bytes, not `0x400`
  - the old extractor started the blob `0x70` bytes too early
  - that shifted the unique-room layout table and made room `$77` read the wrong 16-byte layout block
  - after correcting the seam, the offline decode of room `$77` matches the NES tilemap exactly
- Fixed multiple real Phase 3 bugs found by BizHawk probes:
  - queued and direct fill helpers reused clobbered `DBRA` registers
  - transfer-queue processing could re-read the same entry instead of advancing
  - room row submission reused a clobbered loop counter and truncated uploads
  - type-1 2x2 squares wrote the wrong bottom-left tile
  - type-1 2x2 squares were still using the wrong tile-index increments in the live 68000 path
  - secondary-square writes re-read tile bytes from a clobbered pointer after palette lookup
- Fixed the placeholder Link sprite path in the frozen Phase 3 scene:
  - common sprite tiles now upload before overworld-specific sprite tiles, matching Zelda's original shared-sprite numbering
  - `Renderer_AddLinkMetaSprite2x2` now uses NES-accurate `8x16` tile ordering (`0C/0E` on the top row, `0D/0F` on the bottom row)
  - `LinkColorsGenesis` is now manually tuned from the NES start-screen reference so the placeholder Link renders with green, brown, and orange instead of the previous blue-heavy palette
- Tuned the placeholder Link palette again in `tools/extract_misc.py`:
  - kept the green base color essentially unchanged
  - swapped the warm-color emphasis so the larger shaded region now lands on dark brown and the smaller highlight lands on orange, matching the NES start-screen sprite more closely
  - current tuned triplet is `$00C8,$028E,$004A`
- Reintroduced Phase 3 room navigation in `src/scenes/zelda_data_smoke.asm`:
  - D-pad now moves the placeholder Link sprite around the live room
  - crossing the left/right room edges now scrolls into the adjacent overworld room, while top/bottom still swap directly
  - room transitions preserve the placeholder sprite palette by reapplying the Link palette after each room load
  - current validated path is room `$77` walking right into room `$78`
- Replaced the unfinished instant-swap transition path with smooth horizontal overworld scrolling:
  - added `ROOM_BUILD_ROOM_ID` so transition staging can build a target room without mutating `CURRENT_ROOM_ID`
  - fixed transition register clobbers in `Scene_ZeldaDataSmoke_StartHorizontalTransition` and `Scene_ZeldaDataSmoke_UpdateTransition`
  - fixed `Room_QueueOverworldTilemapAt` so all `22` staged rows preserve their base row and staging column instead of only the first row landing correctly
  - `tools/bizhawk_phase3_navigation_probe.lua` now validates smooth rightward settle from `$77 -> $78`
  - `tools/bizhawk_phase3_left_navigation_probe.lua` now validates smooth leftward settle from `$77 -> $76`
  - `tools/bizhawk_phase3_transition_capture.lua` now shows both rooms sharing Plane A mid-scroll instead of a black half-plane
- Extended the same transition system to vertical overworld movement:
  - added smooth up/down staging using wrapped Plane A row submission
  - `Room_QueueOverworldTilemapAt` now wraps row writes across the 32-row plane map so target rooms can stage above or below the visible room
  - `tools/bizhawk_phase3_up_navigation_probe.lua` validates `$77 -> $67` with smooth settle
  - `tools/bizhawk_phase3_down_navigation_probe.lua` validates downward return from `$67 -> $77` with smooth settle
- Shifted the placeholder Link sprite downward in the scene draw path so the live sprite sits closer to the NES reference on the playfield
- Added initial Phase 3 cave flow in `src/scenes/zelda_data_smoke.asm` and `src/rooms.asm`:
  - cave mode now uses a dedicated context flag so cave movement does not trigger overworld room-edge transitions
  - pressing up at the cave entrance in room `$77` now loads an overworld cave layout via `Room_LoadOverworldCave`
  - pressing down at the cave doorway exits back to the saved overworld room and return position
  - cave layout selection now comes from the extracted overworld cave index (`RoomAttrsOW_B` high nibble) through `Room_GetOverworldCaveLayoutPtr`
- Added cave probe tooling:
  - `tools/bizhawk_phase3_cave_probe.lua`
  - `tools/run_bizhawk_phase3_cave_probe.bat`
  - probe verifies cave mode enter/exit and return to room `$77`
- Fixed the palette-layout bug in `Room_ConvertOverworldPalette`:
  - `LevelInfoOW+3` is the correct start of the NES BG palette bytes
  - Genesis CRAM is `4` palette lines of `16` colors each
  - the loader now spreads the NES sub-palettes into color slots `0-3` of Genesis palette lines `0-3`
  - the full 64-word CRAM image is queued so palette-selected room tiles render correctly
- The active Phase 3 smoke scene is still intentionally constrained for fidelity work:
  - uploads the full overworld background set
  - uploads overworld sprite tiles for a Link placeholder
  - boots directly into room `$77`
  - now allows placeholder movement, smooth room transitions in all four directions, and basic cave enter/exit behavior

Current estimated completion:

- Phase 3: 99%

## Latest Verification

Latest successful build:

- `build.bat`
- ROM output: `builds/whatif.md`
- Listing output: `builds/whatif.lst`
- Header checksum after latest successful build: `$8BF1`
- Integrity check: pass
- Latest archived Phase 3 build: `builds/archive/P3.50.*`
- BizHawk boot probe: pass
- BizHawk room probe: pass
- BizHawk room-fidelity probe: pass
- NES-vs-reference start-room compare: pass (`Mismatch count: 0`)
- BizHawk navigation probe: pass (`$77 -> $78`, smooth settle)
- BizHawk left navigation probe: pass (`$77 -> $76`, smooth settle)
- BizHawk up navigation probe: pass (`$77 -> $67`, smooth settle)
- BizHawk down navigation probe: pass (`$67 -> $77`, smooth settle)
- BizHawk cave probe: pass (entered cave mode from `$77`, exited back to `$77`)

Notes:

- The latest captured frame now shows the corrected overworld scenery tiles for the Zelda 1 opening screen, with the blue-speckled tree block gone.
- The room-fidelity checker confirms that CRAM, the room buffer, and Plane A VRAM match the offline reference for room `$77`.
- The placeholder Link sprite colors are now closer to the NES start-screen capture: the larger shadow region is dark brown again and the smaller highlight reads as orange instead of brown.
- Placeholder movement is back, and the full four-direction probe set confirms stable smooth settle around room `$77`.
- I could not reproduce a persistent bottom black bar in the automated `P3.46` captures, so the room framing itself was left unchanged.
- The remaining visible mismatch is now mostly cave interaction polish and placeholder HUD work beyond the corrected room/tile baseline.

## Next Up

Immediate next targets inside Phase 3:

1. Polish cave interaction details (trigger bounds, spawn/exit placement, and cave-specific constraints) now that basic enter/exit flow is online.
2. Keep the cave probe plus the four-direction room-transition probes in the regular verification loop.
3. Replace more scene-specific placeholder logic with real overworld/player ownership as Phase 4 starts.
4. After overworld and cave transitions are stable, split room handling into clearer `src/overworld.asm` / `src/dungeon.asm` modules.
