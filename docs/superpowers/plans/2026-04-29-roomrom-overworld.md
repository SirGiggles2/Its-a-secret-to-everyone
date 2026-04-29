# RoomRom Overworld Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make RoomRom render all 128 Zelda 1 overworld rooms with the correct tile index space, palettes, and HUD offset.

**Architecture:** Keep RoomRom as the only emulator target. Fix the shared `ow_room_render` contract so it can later move into the main ROM cleanly, but verify this pass only through `RoomRom/out/RoomRom.md`.

**Tech Stack:** SGDK, BizHawk Lua, Python reference verifier, extracted C data arrays.

---

### Task 1: RoomRom Reference Verification

**Files:**
- Create: `RoomRom/probe_roomrom_all.lua`
- Create: `RoomRom/verify_roomrom_all.py`

- [x] Add a Lua probe that boots RoomRom, navigates from room `0x77` to each target room using held D-pad taps, and dumps Plane A cells `(cols 0..31, rows 2..23)` plus CRAM.
- [x] Add a Python verifier that reconstructs expected Plane A words from `data/rooms/overworld.c`, `data/chr/overworld_bg.c`, `data/chr/common.c`, and `data/misc/palettes.c`.
- [x] Run the verifier against the current ROM and confirm it fails before renderer changes.

### Task 2: Renderer Contract Fix

**Files:**
- Modify: `src/game/room/ow_room_render.c`
- Modify: `RoomRom/build.bat`

- [x] Change CHR upload to reserve tile 0 and upload common BG, overworld BG, and common misc into VDP tile IDs `1..256`.
- [x] Change tile writes so raw tile `N` emits VDP tile `N + 1`.
- [x] Replace square-level palette selection with per-tile NES play-area attribute selection.
- [x] Load CRAM palettes from extracted `LevelInfoOW` plus `NesColorToGenesisCRAM`.
- [x] Include `common.c` and `misc/palettes.c` in RoomRom build inputs.

### Task 3: RoomRom Verification

**Files:**
- Modify as needed: `RoomRom/check_roomrom_screen.ps1`

- [x] Build RoomRom using `RoomRom/build.bat`.
- [x] Boot only `RoomRom/out/RoomRom.md` with `RoomRom/probe_roomrom_all.lua`.
- [x] Run `python RoomRom/verify_roomrom_all.py --dump RoomRom/out/roomrom_all_dump.json` and require zero tile/palette/CRAM mismatches across all 128 rooms.
- [x] Capture `RoomRom/out/roomrom_screen.png` and require black HUD/top/right/bottom zones.
- [x] Commit the RoomRom-ready changes.
