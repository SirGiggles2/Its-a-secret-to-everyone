# T-004 — Ganon chamber capture and Original room generator

- **NES source:** `reference/aldonunez/Z_05.asm:LayoutUWFloor` and `WriteSquareUW`; `Z_07.asm:GetUniqueRoomId`.
- **Drained C:** NONE for room-layout decoding; the linked consumer is `src/game/dungeon/uw_render.c` reading `RoomRom/src/uw_room_blob.c`.
- **Coverage:** FULL for the L9Q1 `$42` static room NT/attributes/palette and Original captured-room generator set; Ganon combat/progression and the complete builder remain separate tasks.
- **Stance:** REPLACE the stale forced-mode-4 room snapshot with natural mode-3 layout evidence; retain the ROM-table generator.

The previous L9Q1 `$42` blob entry came from the 2026-09-23 direct mode-4 Ganon probe. Focused NES probes reproduced that route and compared 2048 CIRAM bytes at Level 9 start `$76`, first play in `$42`, and Ganon combat phase 2. Mode 4 did **not** redraw the floor: the 704-byte play-area NT in `$42` stayed byte-identical to start room `$76`. The installed `LevelBlockAttrsD[$42]` was `$28`, but the old capture matched the start room, producing the reported 240-tile generator mismatch. It was a stale capture, not a floor-decoder defect.

Re-entering `$42` through NES mode 3 submode 2 executed the layout path. Its first-play and phase-2 NTs match `gen_uw_room_tiles.compose("UW2", 1, 0x42)` at **704/704 bytes**. Compared with the old blob, the proper NT changes 240 play-area tiles and 24 attribute bytes; PALRAM is unchanged. The correction was applied to the local per-level capture and aggregate, then the 649-entry blob was regenerated, including all 11 previously synthesized boss entries. A before/after inventory shows only index 165 (`orig`, Q1, L9, `$42`) changed in NT and attributes; all 649 palette entries and all other rooms remain byte-identical. `RoomRom/out` captures are ignored local data. `tools/builder/refresh_ganon_room_capture.py` records the repeatable development regeneration path without committing the user's ROM or raw capture.

`python tools/builder/gen_uw_room_tiles.py` now reports **Original 331/331 exact**. Across both maps it reports 551/649 exact; the remaining 98 are Redux door-state-only differences, with zero floor/frame mismatches. This is not a claim that the drag-and-drop builder is complete or capture-independent; T-080 owns that release gate.

Windows `Debug.bat` passes, including freshness 9/9 and VRAM budget. Final ROM SHA-256 is `e3f9a52653d411d48a5a41704f35bf50ab628b19d206891d36088850ff7d7234`. Focused Genesis debug-warp capture reached L9Q1 `$42` combat phase 2, and `python tools/builder/verify_ganon_room_render.py` found blob NT/attributes/palette equal to the live NES capture and **704/704** Plane A tile slots equal after the sparse CHR lookup. NES and Genesis screenshots are under `builds/reports/recovery/t004-ganon-nt-mode3/` and `t004-gen-ganon-nt/`. Raw reports and the user's NES ROM remain local. The build includes Claude's still-uncommitted T-013 `RoomRom/src/main.c` work; no such edit is part of this task.

The comparison establishes the room background at entry/combat phase 2. It does not verify a connected L9 route, Ganon attacks/reward, or every Redux door variant.
