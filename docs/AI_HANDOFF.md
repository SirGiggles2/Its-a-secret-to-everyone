# WHAT IF AI Handoff

## Project goal

`WHAT IF` is an exact, faithful port of The Legend of Zelda (NES, 1986) to the Sega Genesis / Mega Drive. The target is real-game behavior on native 68000 / VDP / YM2612 hardware, with BizHawk as the main development emulator.

## Project root

`C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\WHAT IF`

## Architecture

Two workstreams:

1. Data extraction (Python) - reads the NES ROM and Aldonunez disassembly, outputs Genesis-ready `.inc` files with `dc.b` / `dc.w` tables.
2. Genesis engine (68000 ASM, vasm) - consumes the extracted data through the platform, renderer, and room systems.

## Current status

Phase 1 is complete.

Phase 2 is complete.

Phase 3 is in progress.

Current baseline on `P3.46`:

- the ROM boots into overworld room `$77`
- the visible playfield is now a recognizable Zelda 1 opening screen
- the offline reference, RAM room buffer, Plane A VRAM, and CRAM all match for that room
- placeholder HUD and placeholder Link are still present, but the scenery tiles are now corrected, Link's bank/order/colors are much closer to the NES start-screen capture, Link now renders slightly lower on the playfield, and placeholder movement plus smooth room transitions in all four directions are back

The current scene is still intentionally frozen for fidelity:

- placeholder Link sprite still present
- placeholder HUD/top strip still present
- smooth scroll-transition animation now exists for overworld moves in all four directions
- no cave-entry behavior yet

The room baseline itself is no longer frozen: the placeholder Link can move and crossing any room edge now scrolls into the adjacent overworld room. The scene is only "frozen" in the sense that cave behavior is still disabled so the current probes stay deterministic.

## Most important recent fixes

### 1. Startup / exception bring-up fixed

Recent shell fixes in `src/main.asm` and `src/platform.asm`:

- `STACK_TOP` now points to `$00FFFFFE` instead of colliding with the low-RAM variable block at `$00FF0000`
- `DefaultException` now executes `stop #$2700` and loops instead of `rte`
- `Input_Poll` now updates `INPUT_PREVIOUS` before computing pressed edges

### 2. Common-pattern extraction bug fixed

The first major graphics root cause was in `tools/extract_chr.py`.

Cause:

- bank 2 common patterns were being found with an ISR-relative heuristic
- `CommonBackgroundPatterns` was effectively being extracted from the post-data `$FF` padding area

Fix:

- bank 2 is now anchored on the explicit `161`-byte `$FF` padding run that follows `CommonMiscPatterns` in `Z_02.asm`

Result:

- shared BG art is now correct and the screen is no longer garbage

### 3. Bank-3 overworld pattern seam fixed

The last big scenery bug was still in `tools/extract_chr.py`.

Cause:

- the bank-3 extractor assumed the pattern blocks sat immediately before `BANK_03_ISR`
- live NES CHR-RAM capture proved the real overworld BG block for room `$77` comes from bank 3 offset `$093B`
- the old heuristic was extracting `PatternBlockOWBG` from `$1CB0`, which produced the "close but wrong" tree and wall tiles seen through `P3.37`

Fix:

- bank 3 now uses the verified pattern-data seam at `$011B`
- block layout is now:
  - `PatternBlockUWBG` at `$011B`
  - `PatternBlockOWBG` at `$093B`
  - `PatternBlockOWSP` at `$115B`
  - remaining sprite and boss blocks follow contiguously from there

Result:

- `P3.38` removes the blue-speckled tree block and renders the opening screen with the corrected scenery tiles

### 4. Overworld layout extraction seam fixed

The bigger room-logic blocker was in `tools/extract_rooms.py`.

Cause:

- `RoomLayoutsOW` was treated as `0x400` bytes
- the real seam is `0x390` bytes
- that made the extractor start the blob `0x70` bytes too early and shifted the unique-room layout table

Fix:

- `ROOM_LAYOUT_OW_SIZE` is now `0x0390`
- room `$77` now resolves to the correct 16-byte layout block

Result:

- `tools/compare_nes_start_room.py` now reports `Mismatch count: 0`

### 5. Room-reference and NES-reference tooling added

Current ground-truth tools:

- `tools/render_overworld_reference.py`
- `builds/reports/overworld_start_room_reference.png`
- `builds/reports/overworld_start_room_reference.json`
- `tools/bizhawk_nes_start_capture.lua`
- `builds/reports/nes_start_capture.png`
- `builds/reports/nes_start_tilemap.json`
- `tools/compare_nes_start_room.py`

These are now the authoritative comparison path for room `$77`.

### 6. NES CHR-RAM dump tooling corrected

The older NES graphics dumps were misleading because they read the wrong BizHawk domains.

Fixes:

- `tools/dump_nes_start_bg.lua` now uses:
  - `CHR` for pattern memory
  - `CIRAM (nametables)` for nametable and attribute memory
  - `PALRAM` for palette memory
- it now respects `PPUCTRL` bit 4 and dumps the active BG pattern table half (`$1000-$1FFF` for room `$77`)

Result:

- the live NES CHR-RAM dump is now trustworthy enough to prove extractor bugs directly

### 7. Palette-layout bug fixed

Important findings in `Room_ConvertOverworldPalette`:

- `LevelInfoOW+3` is the correct start of the NES BG palette bytes
- Genesis CRAM is `4` palette lines of `16` colors each

Fix:

- build a 64-word CRAM image
- place the NES sub-palettes into Genesis palette-line slots:
  - line 0 colors 0-3
  - line 1 colors 0-3
  - line 2 colors 0-3
  - line 3 colors 0-3
- queue the full 64-word CRAM upload

### 8. Live square-writer bug fixed

The last runtime mismatch was in `Room_WriteSquareOW` inside `src/rooms.asm`.

Cause:

- the live 68000 type-1 square path was still using the wrong tile-index increments for the non-top-left tiles

Fix:

- corrected the live type-1 square increments to match the NES layout semantics

Result:

- `tools/check_room_fidelity.py` now passes against `P3.32`

### 9. Placeholder Link sprite path corrected

The remaining visible sprite problem after `P3.32` was not background fidelity anymore; it was the frozen scene's placeholder Link.

Fixes made:

- `src/scenes/zelda_data_smoke.asm` now uploads `TilesCommonSprites` before `TilesOverworldSP`, so shared sprite tile numbers line up with Zelda's original common-sprite bank
- `src/renderer.asm` now gives `Renderer_AddLinkMetaSprite2x2` NES-accurate `8x16` tile ordering:
  - top row: base tile, base tile `+2`
  - bottom row: base tile `+1`, base tile `+3`
- `tools/extract_misc.py` now emits a tuned `LinkColorsGenesis` triplet matched against the real NES start-screen capture, replacing the old blue-heavy direct conversion

Result:

- `P3.39` keeps the room-fidelity pass intact while making the placeholder Link much closer to the NES capture
- the green base stays essentially unchanged, while the warm shades are now tuned so the larger shaded region reads dark brown and the smaller highlight reads orange

### 10. Placeholder movement and room changes restored

`src/scenes/zelda_data_smoke.asm` now restores the first real bit of Phase 3 interaction on top of the corrected room baseline.

Current behavior:

- D-pad moves the placeholder Link around the live overworld room
- crossing the left/right room edge scrolls into the adjacent overworld room, while top/bottom still swap directly
- the scene reapplies the Link sprite palette after each room load so the room's CRAM upload does not wipe out the placeholder sprite colors

Verified path:

- room `$77` transitions right into room `$78`

### 11. Smooth horizontal transitions landed

The previously unfinished `P3.42` transition path is now fixed in `P3.45`.

Root causes that were fixed:

- transition staging was mutating `CURRENT_ROOM_ID` during target-room builds
- Link X/Y were being clobbered when the transition-start helper reused caller registers
- transition completion was losing the direction flag before deciding the landing edge
- `Room_QueueOverworldTilemapAt` only staged the first target row correctly because the row loop kept its base row and staging column in `D4/D5`, which the queue helper reuses internally

Fixes:

- added `ROOM_BUILD_ROOM_ID` so transition staging builds use a separate decode room id
- preserved caller movement registers around `Scene_ZeldaDataSmoke_StartHorizontalTransition`
- preserved the direction word across the final room-load call
- fixed `Room_QueueOverworldTilemapAt` to preserve `D4-D6` across each queued row submission

Current verified behavior:

- walking right from `$77` scrolls smoothly into `$78`
- walking left from `$77` scrolls smoothly into `$76`
- the mid-transition BizHawk capture now shows both rooms sharing Plane A instead of a black half-plane

### 12. Vertical transitions landed

`P3.46` extends the same transition system to up/down overworld movement.

Key fixes:

- wrapped Plane A row submission in `Room_QueueOverworldTilemapAt` so target rooms can stage above or below the visible room on the 32-row plane map
- added vertical transition directions and VScroll-driven settle logic in `src/scenes/zelda_data_smoke.asm`
- shifted the placeholder Link sprite downward in the scene draw path so it sits closer to the NES reference during normal play and transitions

Current verified behavior:

- walking up from `$77` scrolls smoothly into `$67`
- walking down from `$67` scrolls smoothly back into `$77`
- room-fidelity checks for the baseline `$77` room still pass after the transition work

## Files that matter now

| File | Role |
|------|------|
| `src/main.asm` | ROM vectors, frame loop, VBlank |
| `src/platform.asm` | Genesis hardware init and VDP setup |
| `src/renderer.asm` | VRAM/CRAM/VSRAM primitives, transfer queue, sprite manager |
| `src/rooms.asm` | Overworld room decode, palette conversion, room submission |
| `src/scenes/zelda_data_smoke.asm` | Current frozen Phase 3 fidelity scene |
| `tools/extract_rooms.py` | Room/layout extraction |
| `tools/render_overworld_reference.py` | Offline room ground truth |
| `tools/bizhawk_nes_start_capture.lua` | NES-side capture of the opening-screen reference |
| `tools/compare_nes_start_room.py` | NES-vs-reference raw tile compare |
| `tools/bizhawk_phase3_room_fidelity_probe.lua` | Runtime probe for CRAM/room/VRAM |
| `tools/check_room_fidelity.py` | Probe/reference comparer |

## Build/test workflow

Build:

- `build.bat`

Archived phase build:

- `tools/run_phase_build.bat 3`

Latest archived build:

- `builds/archive/P3.46.md`
- checksum `$3782`

Useful probes:

- `tools/run_bizhawk_boot_probe.bat`
- `tools/run_bizhawk_phase3_room_probe.bat`
- `tools/run_bizhawk_phase3_room_fidelity_probe.bat`
- `tools/run_bizhawk_phase3_navigation_probe.bat`
- `tools/run_bizhawk_phase3_left_navigation_probe.bat`
- `tools/run_bizhawk_phase3_up_navigation_probe.bat`
- `tools/run_bizhawk_phase3_down_navigation_probe.bat`
- `tools/dump_nes_start_bg.lua`
- `tools/bizhawk_list_domains.lua`
- `tools/bizhawk_capture_frame.lua`
- `tools/bizhawk_vdp_probe.lua`

## Next recommended work

Phase 3 next steps should be on top of the now-correct opening-screen baseline:

1. Add cave-entry / cave-exit behavior.
2. Add cave-entry coverage to the probe suite and keep the four-direction transition probes in place.
3. Replace more scene-specific placeholder logic with real overworld/player ownership as Phase 4 starts.
4. After that, split room handling into clearer overworld/dungeon modules.

## Hardware note to preserve

VDP register 0 must remain `$8004`, not `$8000`.

`src/platform.asm` already does this. Do not regress it.
