# Opus R1 — Byte-exact cave sprite parity plan

## Current code state (verified)

- `cave_init` (cave_dispatch.c:113-130): slot 1 NPC at ($78,$80), slots 2/3 bonfire (ObjType=$40) at ($48,$80)/($A8,$80), ENEMY_ALIVE+2/3=1.
- `cave_draw_person` (cave_dispatch.c:685-700): calls `draw_object_mirrored` for cave_id<$7B, `draw_object_not_mirrored` for ≥$7B.
- `enrt_update_standing_fire` (enemy_walker_runtime.c:146-154): dir=$08, attrs=2, calls `z07_animate_object_walking` (advances frame), `c_draw_object_not_mirrored_with_frame(0, slot)`.
- `k_obj_animations[127]` (draw_dispatch.c:73-90): verbatim Z_01.asm:1958 ObjAnimations.
- `k_obj_anim_frame_heap[228]` (draw_dispatch.c:93+): verbatim Z_01.asm:1977.
- `k_cave_ware_xs[3]` (cave_dispatch.c:218): NES Z_01.asm:385 CaveWareXs ware positions.
- `cave_palette.c:6` k_cave_subpal_2_3_nes 8 bytes — ALL caves identical.

## 7-point execution

### 1. CHR atlas coverage (effort: 3h)
- Generate `tools/parity/cave_sprite_inventory.py`: walks `k_obj_animations[i]` for i in [$6B..$7E] (cave NPCs), `k_obj_anim_frame_heap` slices, ItemId range $00..$3F, ObjType $40 (bonfire), $C0-$DA (cursor/effects). Resolves to NES tile_id set ~50 tiles for cave scene.
- Cross-check `data/chr/MANIFEST.json` covers all. Emit `tools/parity/cave_chr_gap_report.md` listing missing NES tile→Gen VRAM slot.
- CI: `make verify-cave-chr` fails on any gap.

### 2. OAM byte-exact (effort: 4h)
Extend probe_one_gen.lua + probe_nes_one.lua to dump per-frame OAM/SAT at frames {0, 8, 16, 24, 32, 60, 120, 240} (covers bonfire 2-frame loop + person blink + steady state).

Per-record schema: `{slot, x, y, tile_id_normalized, palette, flip_h, flip_v, priority, visible}`. Byte-diff after sort by slot. NES Y=$F0 means "hidden" — normalize both platforms to omit.

### 3. Palette (effort: 2h)
Dump NES PALRAM $3F10-$3F1F at same frames per cave_id. Compare vs k_cave_subpal_2_3_nes after mirror normalization. Suspected divergence: hit-flash on item touch, fire flicker (might be sub-pal NOT palette mutation).

### 4. Animation cadence (effort: 4h)
Seed FrameCounter $0015 = 0 at scene entry on BOTH platforms (force write). Capture frames 0..32 in 1-frame increments. Diff bonfire tile_id sequence (should toggle every 4 frames per NES); diff person blink (Z_03.asm:328 FrameCounter gate). Genesis must match cycle exactly.

### 5. State machine (effort: 5h)
Per cave_id ($6A..$7D × 20), drive `CavePersonState` 0→8 via probe-only state writer at $FF00AD. For each state, 60 frames capture. State 0 (idle): NPC visible. State 1 (textbox open): NPC + textbox glyphs in transfer buf. State 6 (purchase confirm): item icon + cursor. Each state's OAM trace = oracle.

### 6. Genesis improvements (effort: 8h, OPT-IN OVERLAY)
Per Codex: strict parity = default. Add `CAVE_VISUAL_MODE` env: `parity` (default) or `enhanced`. Enhanced mode:
- 16-color sprite sub-pal (NES 4-color → Gen 16-color) for richer NPC shading
- Anti-flicker: spread sprites across multiple SAT slots if scanline overflow
- Smoother bonfire (4-frame loop interpolated)
- Item shine particles
Strict mode renders byte-identical to NES. Enhanced mode renders prettier. CI gates on STRICT MODE only.

### 7. Verification infra (effort: 6h — LONG-TERM)
`tools/parity/cave_golden/<cave_id>/<frame_phase>/{oam.json, palram.bin, chr_hashes.txt, anim_phase.json, state_trace.json}` per cave_id × per state.

CI workflow:
1. `python tools/parity/dungeon_visual_sweep/run_sweep.py --filter cave_*`
2. `python tools/parity/dungeon_visual_sweep/run_nes_sweep.py --filter cave_*` (if NES baseline missing, regenerate)
3. `python tools/parity/cave_byte_diff.py` — strict per-domain compare, exit 1 on any diff

`docs/parity/cave_strict.md` documents the contract. Regression gate hardcoded in CI.

## Total effort

3+4+2+4+5+6 = 24h core + 8h opt-in = ~32h. Includes existing H4 differ extension. Splittable across 3-4 wall-days.

## Risks

- Genesis 4bpp normalization vs NES 2bpp: tile art hash must compare LOGICAL pixel pattern, not raw bytes
- FrameCounter seed: NES boot vs Gen boot have different frame offsets; need deterministic reset via Lua probe write
- Hit-flash/item-flash palette cycles may not be in current cave_palette_apply — likely missing, need port
