# RoomRom BG Palette + Item Atlas + CHR Expansion — Design

**Date:** 2026-05-01
**Worktree:** `FINAL TRY-roomrom-s1` (branch `roomrom-s1`)
**Scope:** RoomRom only. Not whatif/transpiled path.

## Problem

NES Zelda 1 uses 4 BG sub-palettes + 4 sprite sub-palettes (32 colors total). Genesis VDP has 4 palette slots × 16 entries (64 colors). RoomRom currently maps NES sub-pal index directly into Gen palette-slot index via `(pal & 0x03) << 13` in plane-A tile words and via the SAT palette-bit field for sprites. This collides:

- BG load was cut from `slot < 4` to `slot < 3` (commit `b932f4b5`, Apr 30) to free PAL3 for sprites.
- NES rooms still encode pal=3 in AT bytes and OW AttrsA/AttrsB bytes (verified L1 R0: BG-pal-3 = `0F 12 1C 2C`).
- BG tiles tagged pal=3 select Gen PAL3 = sprite palette → render with sword/Link colors.
- Drift looked "slow" because sprite work (S3 Link, S7 sword/items) progressively populated PAL3 with non-zero colors over commits, surfacing the bug.

Two more existing problems live in the same render pipeline:

- Item sprite tiles use guessed `common_chr` literals (`$82..$89`). Visible art wrong (horizontal sword, beam, arrow).
- Palette source data comes from `LEVEL_INFO_PALETTE_OFFSET` heuristic for OW; not byte-for-byte NES PALRAM truth.

Solving the slot collision properly requires CHR expansion (pixel-biased tile copies). The item atlas problem is independent and can ship first. PALRAM truth is shared infrastructure.

## Architecture (final state)

### Slot map

| Gen slot | Owner | NES source |
|----------|-------|------------|
| PAL0 | Packed NES BG PALRAM `[0..15]` (4 sub-pals × 4 colors) | per-room PALRAM dump |
| PAL1 | Packed NES SPR PALRAM `[16..31]` (4 sub-pals × 4 colors) | per-room PALRAM dump |
| PAL2 | Reserved / preserved (fade, redux secrets, HUD overlays) | — |
| PAL3 | Reserved / preserved | — |

Layout within PAL0: BG sub-pal `s` color `c` lives at PAL0 entry `s*4 + c`. Same for PAL1. Index 0 of each Gen palette stays the universal NES backdrop (transparent for sprites).

### Tile pixel bias

NES tile pixel `v ∈ {0..3}` (2bpp). Genesis 4bpp tile copy for sub-pal `s` emits:

```
biased_pixel = (v == 0) ? 0 : (s * 4 + v);
```

Pixel 0 stays 0 always (transparent / NES universal backdrop). Only nonzero pixels carry the sub-pal bias. This avoids solid-box artifacts for sprites and respects NES universal-backdrop semantics for BG.

VRAM holds 4 copies per NES tile, one per sub-pal. NES tile `t` sub-pal `s` lives at Gen VRAM tile `base + s * tile_count + t`.

### Renderer rule

Sub-pal selector goes into the **tile index**, not into the Gen palette-slot field:

```c
nt_word = base + sub_pal * tile_count + nes_tile_id;
```

The Gen palette-slot field in the nametable word is fixed at `0` for BG and `1` for sprites. The pattern `(pal & 0x03) << 13` is forbidden in renderers post-cutover.

NES attribute-byte decode (`s_pal_to_attr`, `attr_palette_for`) is unchanged — it still emulates NES AT semantics correctly. Only the consumer of its 2-bit output changes (tile-index math instead of Gen pal-slot bits).

### Palette load

`roomrom_bg_palette_load_palram_full(palram32)` writes:

- Gen PAL0 = `nes_to_cram(palram32[i])` for `i ∈ [0..15]`
- Gen PAL1 = `nes_to_cram(palram32[i])` for `i ∈ [16..31]`

PAL2 and PAL3 are not touched by the BG/SPR loader. They stay preserved across room loads for fades, redux secret overlays, etc.

## Phases

### Phase 1 — Item atlas wiring

Independent of palette work. Replaces guessed `$82..$89` literals with live NES CHR. Items ship correct ART; correct COLOR follows in Phase 4.

1. Confirm or regenerate live item CHR dumps:
   - `RoomRom/out/nes_item_chr_pt0_orig.bin`
   - `RoomRom/out/nes_item_chr_pt0_redux.bin`
2. Generate `RoomRom/src/roomrom_item_chr.{c,h}` from `RoomRom/tools/gen_item_chr_blob.py`.
3. Add `roomrom_sprites_set_redux(unsigned char redux)` API; same for `roomrom_combat_set_redux`.
4. `RoomRom/src/roomrom_sprites.c`:
   - Replace item VRAM macros with atlas-derived offsets.
   - Drop all `common_chr`-sourced item uploads.
   - Add `COMMON_SPRITE_PATTERN_TILE_COUNT 112u` guard; out-of-block tile ids upload a blank 32-byte tile instead of reading past the common block.
   - Re-enable horizontal arrow from atlas.
5. `RoomRom/src/main.c`: drive `roomrom_sprites_set_redux(current_redux_flag())` + same for combat module after boot upload and on every scene/map toggle.
6. `RoomRom/build.bat`: link `roomrom_item_chr.c`.
7. Verifier: `RoomRom/tools/verify_item_chr_manifest.py` rejects:
   - Any `guessed_common_chr: true` flag in manifest
   - Any `$82..$89` literal in `roomrom_sprites.c`
   - Tile-count mismatch between manifest and generated atlas
8. Build + emu smoke: orig + redux, sword (vertical/horizontal), beam, boomerang, arrow, bomb, explosion render with NES-correct art.

Phase 1 keeps the existing `slot < 3` BG load and PAL3-sprite slot map. Items still pick up sprite palette from PAL3. ART correct; COLOR remains as today (sub-pal-0 only).

### Phase 2 — Live PALRAM capture + central converter

Data + infrastructure. No renderer changes.

1. `RoomRom/probe_nes_bg_palette_manifest.lua`:
   - Boot vanilla NES Z1 + Redux Z1.
   - For each of 128 OW rooms, drive teleport, settle 12 frames with rendering on, dump PALRAM domain (not PPU Bus) `$3F00..$3F1F` → 32 bytes.
   - Output `RoomRom/out/nes_bg_palette_manifest_orig.json`, `RoomRom/out/nes_bg_palette_manifest_redux.json`. Each entry stores room id, map id (`orig|redux`), full PALRAM 32 bytes, PPU mask, settle frame count.
   - UW: reuse existing `RoomRom/out/nes_uw_aggregate.json` PALRAM entries; do not re-probe.
2. `RoomRom/tools/gen_bg_palette_blob.py`:
   - Inputs: OW manifest JSONs + UW aggregate JSON.
   - Output: `RoomRom/src/roomrom_ow_palette.{c,h}` exposing
     ```c
     extern const unsigned char g_roomrom_ow_palram[2][128][32];
     ```
     Map index 0 = original, 1 = redux. Stored as raw NES PALRAM bytes (full 32 bytes, BG + SPR), not Gen CRAM words.
3. `RoomRom/src/roomrom_bg_palette.{c,h}`:
   - Public API:
     ```c
     unsigned short roomrom_bg_palette_nes_to_cram(unsigned char nes_color);
     void roomrom_bg_palette_load_palram_full(const unsigned char *palram32);
     void roomrom_bg_palette_load_bg_only(const unsigned char *palram16);
     ```
   - `load_palram_full` writes Gen PAL0 (16 colors from `palram32[0..15]`) and Gen PAL1 (16 colors from `palram32[16..31]`). Does NOT touch PAL2/PAL3.
   - `load_bg_only` writes Gen PAL0 only — fallback for callers that have BG bytes only.
   - Centralizes `nes_to_cram` so OW + UW + sprite paths share one converter.
4. Build links `roomrom_bg_palette.c` and `roomrom_ow_palette.c`. No renderer wiring yet.

### Phase 3 — CHR expansion (BG + sprite)

Pixel-biased 4x tile copies. Solves slot collision.

1. `RoomRom/tools/expand_bg_chr.py`:
   - Inputs: existing BG CHR bins (`overworld_bg_chr.bin`, `underworld_bg_chr.bin`, `redux_overworld_bg_chr.bin`, `redux_uw_bg_chr.bin`, BG section of common CHR).
   - For each NES tile, emit 4 4bpp Genesis tiles. Tile copy `s ∈ {0..3}` per-pixel rule: `out_pixel = (in_pixel == 0) ? 0 : (s * 4 + in_pixel)`.
   - Output to `RoomRom/data/expanded/`. Do not modify shared `data/common_chr.bin` or other global assets — keep RoomRom CHR expansion outputs isolated under RoomRom paths.
2. `RoomRom/tools/expand_sprite_chr.py`:
   - Same rule, applied to RoomRom item atlas CHR + Link/sword/beam/boomerang/arrow/bomb/explosion CHR.
   - Output to `RoomRom/data/expanded/`.
3. New tile-base macros — one base per sub-pal:
   ```c
   #define UW_VDP_TILE_BASE_PAL(s) (UW_VDP_TILE_BASE + (s) * UW_BG_PACKED_TILE_COUNT)
   #define LINK_VRAM_TILE_PAL(s)   (LINK_VRAM_TILE_BASE + (s) * SPRITE_ATLAS_TILE_COUNT)
   ```
   Sprite stride uses the actual atlas tile count, not `0x100`.
4. CHR uploader writes 4 banks per scene. VRAM layout pinned in code constants (one source of truth).
5. New `tile_word`:
   ```c
   static unsigned short tile_word(unsigned char raw_tile, unsigned char sub_pal) {
       return (unsigned short)(UW_VDP_TILE_BASE_PAL(sub_pal & 0x03) + raw_tile);
   }
   ```
   No `(pal & 0x03) << 13`. Gen pal-slot bits stay 0.
6. Sprite SAT writes use `TILE_ATTR_FULL(PAL1, ...)` and tile pointer:
   ```c
   tile = base + sub_pal * SPRITE_ATLAS_TILE_COUNT + local_tile;
   ```
7. NES attr decode (`s_pal_to_attr`, `attr_palette_for`) preserved. Only the consumer (tile-word builder) changes.

### Phase 4 — Renderer wiring + slot-map cutover

Activates Phase 2 data + Phase 3 infrastructure.

1. `roomrom_ow_room_render_load_palette(room_id)`:
   ```c
   const unsigned char *p = g_roomrom_ow_palram[s_roomrom_map_id][room_id & 0x7F];
   roomrom_bg_palette_load_palram_full(p);
   ```
   Drops `LEVEL_INFO_PALETTE_OFFSET` path.
2. `load_palette_from_blob` (UW):
   ```c
   roomrom_bg_palette_load_palram_full(g_uw_room_palette[idx]);
   ```
3. `load_palette_from_levelinfo` (UW): build a 16-byte BG buffer from level info, call `roomrom_bg_palette_load_bg_only(buf)`. Sprite half stays as last-loaded value (acceptable: levelinfo fallback only fires when no blob match).
4. OW `tile_word` + UW `write_tile_raw` switched to Phase 3.5 form.
5. Sprite module + combat module use `LINK_VRAM_TILE_PAL(sub_pal)` form. Phase 1 set sub_pal = 0 implicitly; Phase 4 makes it explicit and supports {1,2,3} for items/enemies that need them.
6. Sprite palette: PAL1 loaded from Phase 2 PALRAM data. Old `roomrom_sprites_load_palette` writing PAL3 deleted.

### Phase 5 — Verifiers + build + acceptance

1. `RoomRom/tools/verify_bg_palette_manifest.py`:
   - 128 entries × 2 ROMs.
   - Each entry has 32 PALRAM bytes.
   - `palram[0] == 0x0F` (NES universal backdrop expected).
   - No all-zero PALRAM entries.
   - `roomrom_ow_palette.h` shape is `[2][128][32]`.
2. `RoomRom/tools/verify_item_chr_manifest.py` (Phase 1).
3. `RoomRom/tools/verify_slot_map.py`:
   - Greps `RoomRom/src/{ow,uw}_room_render_roomrom.c` for `(pal & 0x03) << 13` → must be absent.
   - Greps for `slot < 3` BG palette loaders → must be absent.
   - Greps for `s_pal_to_attr[`-based Gen-pal-slot writes (must be tile-index path only).
4. `RoomRom/tools/verify_vram_budget.py`:
   - Computes per-scene tile residency (BG copies + sprite copies + HUD + automap + redux extras).
   - Confirms tile range does not overlap VDP plane-A nametable, plane-B, window, SAT, or H-scroll table regions in the linker / SGDK config.
   - Not just `≤ 2048 tiles`; actual address-range non-overlap check.
5. NES side-by-side acceptance gate:
   - For 6 sample rooms (L1 R0, L1 R73, OW screen 0x77, OW screen 0x00, redux UW R0, redux OW screen 0x77):
     - Captured NES PALRAM bytes match generated `g_roomrom_ow_palram` / `g_uw_room_palette` source data.
     - Gen CRAM word at slot N entry M equals `nes_to_cram(palram[…])` for each loaded color.
6. Emu smoke: orig + redux, OW + UW, scene/map/level/quest toggles do not leave stale CHR or stale palettes.

## Components

### New files

- `RoomRom/probe_nes_bg_palette_manifest.lua`
- `RoomRom/tools/gen_bg_palette_blob.py`
- `RoomRom/tools/expand_bg_chr.py`
- `RoomRom/tools/expand_sprite_chr.py`
- `RoomRom/tools/verify_bg_palette_manifest.py`
- `RoomRom/tools/verify_slot_map.py`
- `RoomRom/tools/verify_vram_budget.py`
- `RoomRom/src/roomrom_bg_palette.{c,h}`
- `RoomRom/src/roomrom_ow_palette.{c,h}` (generated)
- `RoomRom/src/roomrom_item_chr.{c,h}` (generated, Phase 1)

### Modified

- `RoomRom/src/ow_room_render_roomrom.c` — palette loader + `tile_word` + tile-base macros
- `RoomRom/src/uw_room_render_roomrom.c` — palette loader + `write_tile_raw` + tile-base macros
- `RoomRom/src/roomrom_sprites.{c,h}` — atlas offsets, PAL1, sub-pal-in-tile, redux toggle
- `RoomRom/src/roomrom_combat.c` — redux variant, sub-pal-in-tile
- `RoomRom/src/roomrom_arrow.c`, `roomrom_bomb.c`, `roomrom_boomerang.c` — same
- `RoomRom/src/main.c` — set_redux on toggles
- `RoomRom/build.bat` — link new modules

### Regenerated assets (under RoomRom paths only)

- `RoomRom/data/expanded/*_bg_chr.bin` (4x copies)
- `RoomRom/data/expanded/*_sprite_chr.bin` (4x copies)
- `RoomRom/src/roomrom_ow_palette.c` (PALRAM blob)

Shared `data/common_chr.bin` is NOT regenerated. RoomRom CHR expansion stays scoped to RoomRom.

## Edge / Error Handling

- Pixel value 0 stays 0 across all 4 sub-pal copies → preserves NES universal-backdrop semantics.
- VRAM budget hit: per-scene tile residency (load only sub-pal copies actually referenced by current room). Start with full 4x load; downgrade if budget exceeded.
- Sprite tiles that never appear with sub-pal != 0 (e.g. Link uses sub-pal 0 only) still get 4 copies in extractor for uniformity. Renderer just doesn't reference the unused copies. Trade VRAM for code simplicity. Revisit if budget tight.
- `load_palette_from_levelinfo` fallback writes BG only, leaves sprite palette untouched. Acceptable: fires only when blob lookup misses, sprites already loaded from prior room.
- Boot palette state: first scene init must call `roomrom_bg_palette_load_palram_full` before any plane render to avoid one-frame stale-palette flash.

## Acceptance Criteria

- All visible item sprites sourced from live NES item atlas. No `guessed_common_chr` flags. No `$82..$89` literals in `roomrom_sprites.c`.
- Horizontal sword, beam, arrow render correct NES art.
- Renderer source has no `(pal & 0x03) << 13` pattern, no `slot < 3` BG palette loaders.
- Captured NES PALRAM bytes (from probe) match generated source data for sampled rooms.
- Gen CRAM = `nes_to_cram(PALRAM byte)` for each loaded color in PAL0 + PAL1, sampled across L1 R0, L1 R73, OW 0x77, OW 0x00, redux UW R0, redux OW 0x77.
- VRAM budget verifier confirms per-scene tile ranges do not overlap VDP plane / window / SAT / H-scroll regions.
- Verifiers green: `verify_item_chr_manifest`, `verify_bg_palette_manifest`, `verify_slot_map`, `verify_vram_budget`.
- Emu smoke: orig + redux, OW + UW, all toggles, no stale CHR / stale palettes.

## Out of Scope

- Enemy sprite atlas (separate work; use same expansion machinery once ready)
- Candle / rod items (blocked on CHR extraction; revisit after Phase 1)
- Dynamic mid-frame palette swap (S/H, H-int)
- Title screen / FS / intro palette (not RoomRom)
- whatif/transpiled path (separate `src/` rewrite)

## Assumptions

- RoomRom CHR expansion is RoomRom-local; no global asset regeneration.
- BG palette truth = live NES PALRAM bytes captured per room, not Gen CRAM words.
- All RoomRom OAM sprites currently use NES sprite sub-pal 0; sub-pals 1..3 enabled by Phase 3 infra but consumer code lit up incrementally per item.
- NES attribute-byte decode (`s_pal_to_attr`, `attr_palette_for`) is correct as-is. Only the Gen-side consumer changes.
- Phase 1 ships independently; visible item ART fix lands before COLOR fix.
- Sprite tile copies for unused sub-pals are tolerated (VRAM cost) until per-scene residency optimizer lands.
