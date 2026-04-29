# RoomRom Overworld Design

Goal: make RoomRom the fast, standalone proof target for Zelda 1 overworld room rendering across all 128 rooms, without booting or testing the main ROM in this pass.

RoomRom owns the test loop. It builds `RoomRom/out/RoomRom.md`, boots directly to room `0x77`, and navigates rooms with D-pad edge presses. The main ROM integration comes later, after RoomRom proves the renderer contract.

The renderer contract reserves VDP tile 0 as blank. Zelda raw BG tile IDs therefore map to VDP tile `raw + 1`. RoomRom must upload the combined NES BG tile address space in that order: common BG, overworld BG, then common misc, starting at VDP tile 1.

Palette loading uses the extracted `LevelInfoOW` palette bytes and `NesColorToGenesisCRAM` conversion table. Attribute selection is per 8x8 tile using the NES play-area attribute layout, not one palette per 16x16 square.

Verification is RoomRom-only:
- Build `RoomRom/out/RoomRom.md`.
- Boot only that ROM in BizHawk.
- Dump Plane A and CRAM for all 128 rooms by scripted D-pad navigation.
- Compare the dump against an extracted-data reference for every room.
- Capture a screenshot and check the HUD/borders remain black.
