# Opus R1 — Concrete plan: 0/56 visual → 56/56 byte-exact

## Current state (verified via probe + code read)

1. **DISPATCH is byte-perfect.** Phase A LBA_B routing 128/128 OW rooms. All 20 caves load correct `cave_id` into ObjType[1]. All 18 dungeons load correct level/quest/start_room. (Confirmed by 20/20 cave entry sweep + Phase F probe GREEN.)

2. **D1-D4 are ALREADY landed in code.**
   - `cave_dispatch.c:113-130` — bonfire slot 2/3 spawn + ENEMY_ALIVE_FLAG set
   - `cave_dispatch.c:685-700` — `cave_draw_person` publishes SAT via `sprite_anim_fetch_obj_pos + draw_object_mirrored/not_mirrored`
   - `cave_dispatch.c:285` — `cave_write_prices_transfer_buf` wired
   - `cave_dispatch.c:764-815` — char-streamer state 1 ported (states 3/6/7 still TODO)

3. **Why captures look wrong:** Not a dispatch bug. The sprite that renders for slot 1 (the NPC) depends on `ObjType[1] = cave_id` (= $6A..$7D). The Genesis sprite-anim table for ObjTypes $6A..$7D is **missing or wrong per cave_id**. cave_6A renders blue spheres (should be orange bonfires + Old Man); cave_77 renders 3 orange flames (NPC sprite = bonfire sprite, wrong).

4. **Probe-side cave/dungeon entry trick works but is HACKY.** Force-write `$24` into `nes_ram[$6530+col*$16+row]` only affects the collision drain reader; transition.c reads `s_raw_tiles` (BSS in `ow_render.c`) directly. Caves work because the cave-entry gate at `main.c:2089` uses the nes_ram path; dungeons go through transition.c which doesn't see our force.

## Plan — 4 phases

### Phase H1: NES baseline capture (4-6 hours)

**Files new:**
- `tools/parity/dungeon_visual_sweep/nes_probe.lua` — for each cave_id $6A..$7D: load standard NES save state, force `RoomId=<ow_room>`, walk to entrance, capture OAM (256 B) + PALRAM (32 B) + CIRAM (1024+64 B) + CHR pattern table (8 KB) + RAM cells (GameMode/RoomId/CurLevel/LinkX/Y/CavePersonState/CaveFlags/ObjType[0..15]/CaveItemIds/CavePrices) + PNG.
- `tools/parity/dungeon_visual_sweep/nes_baselines/` — 20 caves + 18 dungeon-entries + 18 dungeon-exits = 56 NES bundles.
- `tools/parity/dungeon_visual_sweep/run_nes_sweep.py` — orchestrator mirroring `run_sweep.py` for NES ROM at `C:\Users\Jake Diggity\Documents\GitHub\Legend of Zelda, The (USA).nes`.

NES has no MODE_TELEPORT. Use BizHawk `savestate.save("path")` to pre-position. Build the 20+18+18 savestates once via `nes_boot_to_scenario.lua` driven by joypad scripts (NES boot prefix: Start@f70, A@f200, Start@f260, then walk).

Effort: 4-6h. Risk: NES OW navigation for hidden caves (need bomb/burn) — must include the "fire candle" or "bomb wall" joypad sequence per scenario.

### Phase H2: Per-domain byte-diff verifier (3-5 hours)

**File new:** `tools/parity/dungeon_visual_sweep/diff_scenario.py` — for each scenario `<sid>`:
- Load NES bundle + Gen bundle.
- OAM (NES) → SAT (Gen) normalization. NES OAM = 4 bytes per sprite (Y, tile, attr, X). Gen SAT = 8 bytes (Y_w, size_link, attr_w, X_w). Tile_id translation via `data/chr/MANIFEST.json` (NES tile $XX → Gen VRAM tile $YY). EXACT after normalize.
- PALRAM → CRAM via canonical NES→Gen LUT in `src/game/world/render/cave_palette.c` k_cave_subpal_2_3_nes. EXACT.
- CIRAM nametable → Plane A tile_id normalized. EXACT.
- State cells (GameMode, RoomId, CurLevel, LinkX/Y, CavePersonState, CaveFlags, CavePrice[0..2], CaveItemIds[0..2], CAVE_TEXT_SELECTOR, ObjType[0..15]). EXACT.
- Char-stream from transfer buf $0302-$0316. EXACT bytes during text states.
- Pixel-diff PNG (quantize_3bit). Tolerance ≤ 0.5% cell mismatch (gen filtering noise).

Per scenario: emit `reports/<sid>/{summary.md, oam_diff.txt, pal_diff.txt, nt_diff.txt, ram_diff.txt, mosaic.png}`.

Aggregate: `sweep_report.md` 56-row table with per-domain pass/fail.

Effort: 3-5h. Risk: tile_id manifest gaps (cave-specific CHR tiles not in `data/chr/MANIFEST.json`) — falls back to sentinel + flags domain as `partial`.

### Phase H3: Fix per-cave_id sprite + nametable render (8-12 hours)

The actual content gap. Three sub-tasks:

**H3a — Per-cave_id NPC sprite descriptor table.** Find/extract NES table that maps ObjType $6A..$7D → sprite descriptor (tile_id, palette, mirrored). Likely lives at `reference/aldonunez/Z_01.asm:53-56 OverworldPersonTextSelectors` + sibling cave-person sprite table. Port to `src/game/cave/cave_person_sprites.c` as a 20-entry LUT. Wire into `cave_draw_person` so each cave_id picks correct sprite, not generic.

**H3b — Per-cave BG/nametable.** Each cave has unique BG layout (rocks/floor/walls + doorways for $7B). NES uses cave-specific heap + sprite-table render at cave entry. Extract per-cave nametable from NES via probe (32×30 BG tile_id array) → `data/cave_nametables/cave_$XX.bin` 20 files. At Genesis cave_init, load the right nametable into Plane A. Currently the cave BG is one stub template (`src/game/world/render/cave_fade.c` SWAP_ENTRY).

**H3c — Bonfire StandingFire sprite frame cadence.** SAT publish exists; verify the per-frame ANIM_FRAME mapping for ObjType=$40 matches NES (frame cycles every 8 frames, alternating tile_id between flame_frame_A and flame_frame_B). Probe `enrt_update_standing_fire` (in `src/game/enemies/`) — if missing or wrong, port from NES asm or drained C.

Effort: 8-12h. Risk H3a: Z1 sprite table may need DrawCavePerson disasm trace, not just static LUT. Risk H3b: BG extraction may need to run NES cave_init in a sandbox to capture decoded nametable post-init. Risk H3c: bonfire CHR tiles may not be in current `data/chr/MANIFEST.json` sprite atlas.

### Phase H4: Iteration loop — per-scenario retry (1 hour scaffold + N hours triage)

**Workflow:**
1. `python tools/parity/dungeon_visual_sweep/run_sweep.py --filter <sid>` — re-capture one Gen scenario
2. `python tools/parity/dungeon_visual_sweep/run_nes_sweep.py --filter <sid>` — re-capture NES baseline (if needed)
3. `python tools/parity/dungeon_visual_sweep/diff_scenario.py <sid>` — diff
4. Read `reports/<sid>/summary.md`, identify which domain failed (OAM vs CRAM vs NT vs RAM)
5. Per failed domain → grep src/ for the writer → port fix → rebuild Debug.md → goto 1
6. Loop until summary.md says PASS on all domains
7. Move to next scenario

**Per-scenario time budget:** 5-30 min depending on domain. OAM failures = sprite table miss; CRAM = palette LUT; NT = nametable extraction gap; RAM = state-cell write missing.

## Total effort

H1+H2+H3+H4 = 16-24 hours wall-clock for first 56/56 PASS. Most risk in H3a sprite tables + H3b nametable extraction.

## Files touched (summary)

**New:**
- `tools/parity/dungeon_visual_sweep/nes_probe.lua`
- `tools/parity/dungeon_visual_sweep/run_nes_sweep.py`
- `tools/parity/dungeon_visual_sweep/nes_baselines/*.bin` (56 files)
- `tools/parity/dungeon_visual_sweep/diff_scenario.py`
- `tools/parity/dungeon_visual_sweep/reports/<sid>/*` (56 folders)
- `src/game/cave/cave_person_sprites.c` + `.h`
- `data/cave_nametables/cave_$6A.bin` ... `cave_$7D.bin` (20 files)

**Edit:**
- `src/game/cave/cave_dispatch.c::cave_draw_person` — dispatch via new per-cave sprite LUT
- `src/game/world/render/cave_fade.c` SWAP_ENTRY — load per-cave nametable
- (possibly) `src/game/enemies/enemy_standingfire.c` — fix flame frame cadence

**No new RoomRom files** (WT-5 invariant).

## Verification sentinel

Final tag when 56/56 byte-exact: `caves-and-dungeons-pixel-perfect-2026-MM-DD`.

Per CLAUDE.md "fail loud": every FAIL gets per-domain report + the aggregate table reports which domain. No silent skips.
