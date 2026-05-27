# Round 001 — Pragmatic Implementer (Sonnet)

## Q1. OW per-room nametable byte-exact

Code path: `src/game/world/render/ow_render.c:383` `render_one_metatile_col`.

**Working correctly:** heap decode (OW_HEAP_BLOB_OFFSET + heap_offsets[]), col_dirs lookup, primary/secondary square expansion, repeat-bit FSM — all faithfully match Z_05.asm LayoutOWAndAdvanceSubmode.

**Known structural bug:** `outer_pal` and `inner_pal` are hard-wired to `2u` at line 402 based on a live NES probe showing OW PlayAreaAttrs is always $AA. That is correct for the *attribute byte* but sub-pal 2 is the wrong index. NES BG sub-pal attribute field 0..3 maps to sub-pal 0..3. Attribute $AA = sub-pal 2 uniform, so fixing this is just naming clarity — the value is already correct.

**Not a problem.** The Phase J sparse atlas `tile_word()` at line 293 maps `(raw_tile, pal & 0x03)` into the sparse LUT; slot=0xFFFF blank-tiles any unrepresented (tile,pal) pair. No diffing is possible without a live NES NT dump per room.

**Verification gap (effort: 2 days):** No NT byte-diff probe exists for the 128 OW rooms. Need a BizHawk Lua probe that reads NES PPU nametable at frame N post-warp and compares tile IDs against the Genesis raw-tile cache exported at `$FF7400` (probe base already in code at line 582). This is the byte-diff gate.

## Q2. OW palette per-room

`src/game/world/ow_bg_palram_table.c`: all 128 entries are **identical** — every row holds `{0x0F,0x30,0x00,0x12, 0x0F,0x16,0x27,0x36, 0x0F,0x1A,0x37,0x12, 0x0F,0x17,0x37,0x12}`.

**This is the biggest BG palette bug in the codebase.** The comment at line 2 says "Auto-captured live NES BG PALRAM per OW room" but the data is flat. Either the probe ran against one room and filled everything, or the generator populated defaults. NES BG sub-pal 2 colors vary per room (Lost Hills $0F,$17,$16,$26 vs Death Mountain $0F,$17,$27,$36 etc). Until this table has 128 distinct rows verified by `probe_nes_ow_bg_palram_full_scan.lua`, OW palette is NOT byte-exact for the majority of rooms.

`roomrom_ow_palette_patch_bg_per_room` at `ow_palette.c:65` looks correct in shape but feeds from the flat table, so it always writes the same 16 bytes. **Fix: re-run the scan probe against all 128 rooms and regenerate.**  Effort: 0.5 days.

`roomrom_ow_palette_patch_subpal3` at `ow_palette.c:55` is a confirmed no-op (disabled 2026-05-23). Sub-pal 3 enemies (Blue Moblin, Wizzrobe) get blue-ramp instead of Lost Hills colors. Acknowledged regression; pending CHR 4x expansion.

## Q3. Cave BG

`cave_palette.c:6` has two hardcoded sub-pal 2+3 NES bytes cited from `Z_06.asm:714`. Only sub-pals 2+3 of PAL0 are stamped; sub-pals 0+1 come from the OW PALRAM load that preceded cave entry — which carries the last OW room's palette. NES cave loads its own full PALRAM. Gap: sub-pals 0+1 may differ from NES. Effort to verify: 1 probe run against any cave room. Layout (2 col-dir tables) looks correct vs Z_05.asm RoomLayoutOWCave0/1.

## Q4. UW BG per-room palette

`uw_render.c:167` `load_palette_from_blob` uses `g_uw_room_palette[636][32]` captured live per room — this IS per-room NES PALRAM truth. Lookup is `g_uw_room_lookup[map][quest][level][room_id]` covering both quests × 9 levels. 636 captured rooms covers the populated subset of the possible 2304. Rooms without a blob fall through to `load_palette_from_levelinfo` which uses any captured room from the same level as a proxy — correct for level-constant palette, acceptable fallback.

**No palette bug here.** Coverage is empirical; gaps only in rooms not visited during capture sweep. Effort to fill: re-run sweep with exhaustive room list.

## Q5. BG priority (sprite-behind-BG)

OW: only `cave_fade_mark_arch_hi_prio` at `cave_fade.c:95` stamps the hi-prio bit (0x8000) on BG cells during the descend animation. **Missing:** tree-top priority — NES renders Link behind tree canopy on OW by setting behind-BG on Link's OAM entries when his Y places him under a tree. Genesis equivalent requires stamping 0x8000 on the tree-top tiles. No such logic exists outside the cave-fade path.

UW: `uw_render.c:254` `uw_is_door_tile` correctly classifies door-arch tiles ($78..$81, $88..$8B, $98..$AF) for priority stamping. That path is wired. No gap for UW doors.

OW tree-top priority = confirmed missing. Effort: 1 day (probe NES OAM for Link-behind-tree frame to get exact tile ranges, then stamp in OW render).

## Q6. Animated BG tiles

`palette_tick_runtime.c` provides the palette-toggle framework but the Phase 2 toggle table is **empty** (header says "Phase 5+ register entries"). Waterfall ($C8 tile family), lava, candle-fire-reveal wall — none are registered. `dyn_tile_dispatch.c` handles secret-reveal/burn-bush tile swaps (ChangeTileObjTiles path) but not frame-animated tiles. No animated-BG implementation exists. Effort: 2–3 days (probe NES CHR bank swap cadence per animated tile family, implement palette or tile-swap toggles).

## Q7. Verification

Existing: `$FF7400` raw-tile cache, `probe_nes_ow_bg_palram_full_scan.lua`. Missing: NT byte-diff per room, per-cave palette diff, UW NT diff. Need: `bg_golden/` bundle with `(scene, room_id) → {nt[32×22], attr[8×8], palram[32], priority_mask[32×22]}` captured from NES. Then Genesis-side probe reads live VRAM and diffs. No such bundle exists.

## Summary of confirmed bugs

1. `ow_bg_palram_table.c` all-128-rooms identical — OW BG palette wrong for most rooms. High severity.
2. OW tree-top BG priority missing — Link always renders in front of trees. Medium severity.
3. Animated BG tiles (waterfall, lava) not implemented — static display. Medium severity.
4. Cave sub-pals 0+1 not verified — may carry wrong OW colors. Low–medium severity.
5. UW BG: no NT byte-diff probe — correctness unverified below palette level.
