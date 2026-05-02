# RoomRom Z1 Full Sprite Atlas — Design Spec

**Status:** draft, pending user review
**Date:** 2026-05-01
**Owner:** RoomRom S-series sprite/atlas track
**Worktree:** `FINAL TRY-roomrom-s1` (branch `roomrom-s1`)

---

## 1. Goal

Stop the clobber. Every NES Zelda 1 (orig + Redux) graphic — sprite tiles AND BG tiles — gets a stable, NES-traceable, ROM-resident place in RoomRom *now*, even when the matching renderer doesn't exist yet.

Adding, removing, or fixing any sprite category must never shift the data offsets, VRAM tile indices, or rendering contracts of any other category. Renderers and atlas data are decoupled; either side can be edited without breaking the other.

The end state: future sprite work is *additive* (drop a renderer into a category that already has reserved bytes + reserved VRAM tiles + a documented dispatch class) rather than *combinatorial* (hand-edit a manifest, hope no other item shifts, build, find the regression in a different category).

## 2. Non-goals

- **Not** finishing every sprite renderer. Atlas data + VRAM contracts only. Renderers stay as-is in this spec; they migrate to the new contracts incrementally over later RoomRom S-phases.
- **Not** changing the Genesis-side scrolling, plane, or HUD layout architecture. Those are scoped by other RoomRom specs.
- **Not** Redux-only or orig-only. Both variants ship in the atlas, selected at runtime.
- **Not** runtime CHR bank-swapping (NES-style). Genesis uses flat VRAM with DMA scene-load instead — see §7.

## 3. Why this approach

We picked: disasm-driven, ROM-direct, fully-generated, category-split, scene-load-DMA architecture.

| Constraint | How this design satisfies it |
|---|---|
| Best long-term | Single source of truth (disasm + ROM bytes). No hand-authored manifests can drift from spec. Adding a sprite is mechanical (one parser config edit). |
| Maximally efficient | All build artifacts auto-generated. Validator gates lift bugs to compile time. No piecemeal manifest edits. |
| Match NES | Disasm IS the spec; parser walks every Anim_WriteItemSprites caller, every enemy AnimAttr table, every HUD digit reference. Dispatch class is read from disasm, not guessed. |
| Use Genesis strengths | DMA scene-load (~6.5KB/frame) replaces NES bank-swap. Flat 64KB VRAM holds active sprite categories with zero swap cost. CRAM bank-rotation handles palette-cycle effects (already proven on the sword beam). 16x8/8x16 native sprite sizes collapse NES Mirrored pairs into single Genesis sprites. |
| Suit Claude | Every step is a deterministic transformation. Disasm is structured ASM I parse reliably. Validator failures are compile-time errors with explicit citations. "Does this match NES" reduces to pixel-diff against captured BizHawk OAM, not visual judgment. |
| Best coding practice | Generated code is reproducible from source. Hand-written code (renderers) is the only ABI surface, and it's compile-time-validated against the generated registry. Clean ownership boundaries per category. |

## 4. Architecture

Five layers, top to bottom:

```
+----------------------------------------------------------+
| Layer 4 - Renderers (hand-written, validator-gated)       |
|   roomrom_sprites.c, roomrom_combat.c, roomrom_hud.c, ... |
+----------------------------------------------------------+
                           |
                           v
+----------------------------------------------------------+
| Layer 3 - Generated C surface                             |
|   - Per-category atlas blobs (.c/.h)                      |
|   - VRAM slot reservations header                         |
|   - Scene-load DMA upload functions                       |
|   - Renderer-side dispatch macros                         |
+----------------------------------------------------------+
                           |
                           v
+----------------------------------------------------------+
| Layer 2 - Master sprite registry (JSON, generated)        |
|   atlas_master.json - one entry per NES sprite,           |
|   joins disasm citations to ROM CHR bytes.                |
+----------------------------------------------------------+
                           |
                           v
+----------------------------------------------------------+
| Layer 1 - Source-of-truth tools                           |
|   tools/walk_z1_disasm.py - parses Z_*.asm tables         |
|   tools/extract_z1_chr.py - reads .nes CHR ROM banks      |
+----------------------------------------------------------+
                           |
                           v
+----------------------------------------------------------+
| Layer 0 - Inputs (read-only, version-pinned)              |
|   reference/aldonunez/Z_00..Z_07.asm                      |
|   Legend of Zelda, The (USA).nes  (orig CHR ROM)          |
|   Zelda Redux.nes                  (redux CHR ROM)        |
+----------------------------------------------------------+
```

Layers 0-3 are entirely deterministic. Same inputs, same generated bytes. CI can rebuild from scratch and byte-match.

Layer 4 is hand-written but constrained: every renderer cites a registry entry by name; a build-time validator checks SGDK `SPRITE_SIZE` matches the entry's NES dispatch class.

## 5. Layer 1 - source tools

### 5.1 `tools/walk_z1_disasm.py`

Reads `reference/aldonunez/Z_00..Z_07.asm`. Walks every sprite-emitting code path. Emits one canonical entry per NES sprite category to a JSON intermediate.

Entry includes:
- `name` — stable identifier (e.g. `boomerang`, `octorok_red_walk_0`, `hud_digit_3`)
- `category` — one of: `link`, `items`, `pickups`, `hud`, `enemies`, `bosses`, `npc`, `title`, `bg_overworld`, `bg_underworld`
- `nes_tile_ids` — list of NES tile IDs the sprite uses (per frame)
- `nes_chr_bank` — which CHR bank holds those bytes (e.g., `common_sprite`, `level1_sprite`, `level5_sprite`)
- `dispatch_class` — for items: `narrow` / `slim` / `mirrored` / `flippable`. For non-items: `direct_oam` plus the OAM write count + per-sprite size.
- `disasm_citation` — `{ "file": "Z_07.asm", "line": 4869, "label": "DrawBomb" }`
- `frame_count` — number of animation frames
- `palette_assumption` — which NES sprite sub-palette (0..3) the routine sets

Routines walked:
- `Anim_WriteItemSprites` callers (Z_07 + Z_05) → items, beams, projectiles, candle flame, fire, food
- `BombCloudOffsetsX1/Y1` consumers → explosion clusters
- `EnemyAnimAttr*` tables in Z_07 → every enemy
- `Boss*Draw` routines per boss in Z_07 → boss sprites
- HUD digit + icon writers in Z_05/Z_06 → status bar
- Title screen sprite tables in Z_02 → "ZELDA" letters, Triforce, cursor
- File select sprite writers in Z_05 → name letters, hand cursor, register box
- NPC draw routines (old man, fairy, etc) → NPC entries

The parser is a small Python tool, not a full ASM compiler. It only needs to recognize labels, byte-table directives (`.BYTE`), `LDA/STA` patterns that identify draw-sprite boundaries, and label cross-references. ~500 lines.

### 5.2 `tools/extract_z1_chr.py`

Reads `Legend of Zelda, The (USA).nes` and `Zelda Redux.nes` directly from disk. Skips the 16-byte iNES header. Splits CHR ROM into 8KB banks. Emits one binary file per (variant, bank) tuple to `RoomRom/out/chr_banks/<variant>/bank_<n>.bin`.

Also emits a JSON index mapping bank-name labels (`common_sprite`, `level1_sprite`, etc) to (variant, bank_idx) tuples. Bank-name labels come from disasm walking — Z1 disasm has explicit `LDA #<bank>` / `STA <bank_select_register>` calls that name each bank's purpose.

Hermetic. No emulator. Same NES file → same output bytes forever.

### 5.3 `tools/gen_atlas_master.py`

Joins the registry from §5.1 with the CHR bytes from §5.2. For each registry entry, looks up bytes in the named CHR bank and embeds them. Output: `RoomRom/data/atlas_master.json` — single-source manifest.

## 6. Layer 3 - generated C surface

### 6.1 Per-category atlas blobs

Single generator `tools/gen_atlas.py` reads `atlas_master.json` and emits, per category, a `.c` + `.h` pair under `RoomRom/src/atlas/`:

```
RoomRom/src/atlas/
  link_chr.{c,h}
  items_chr.{c,h}
  pickups_chr.{c,h}
  hud_chr.{c,h}
  enemies_chr.{c,h}
  bosses_chr.{c,h}
  npc_chr.{c,h}
  title_chr.{c,h}
  bg_overworld_chr.{c,h}
  bg_underworld_chr.{c,h}
```

Each header exposes `ROOMROM_ATLAS_<CAT>_<NAME>_OFFSET` constants — the byte offset of each named sprite block within the category's blob. Each `.c` exports a single `unsigned char roomrom_atlas_<cat>[ROOMROM_ATLAS_<CAT>_BYTES]` array (per-variant where applicable: `[VARIANT_COUNT][BYTES]`).

Adding a sprite within a category appends to that category's blob and adds a constant. Other categories untouched.

### 6.2 VRAM slot reservations

Generated header `RoomRom/src/atlas/roomrom_vram_slots.h`:

```c
/* Auto-generated by tools/gen_atlas.py - do not edit. */
#ifndef ROOMROM_VRAM_SLOTS_H
#define ROOMROM_VRAM_SLOTS_H

/* Tile indices in Genesis VRAM. Allocated by category. Total VRAM = 1024 tiles.
 * BG tile counts derived from atlas_master.json category sizes. Sprite
 * tile counts cap at the maximum simultaneously-resident set per scene.
 *
 * Stable across builds as long as the registry's category set is stable.
 * Adding sprites within a category extends its byte blob but keeps its
 * VRAM tile range the same (tiles in the blob beyond the budget are
 * scene-loaded, not all-resident). */

#define VRAM_BG_OW_BASE          16    /* OW BG tiles at boot     */
#define VRAM_BG_OW_COUNT        256
#define VRAM_BG_UW_BASE         272    /* UW BG tiles per scene   */
#define VRAM_BG_UW_COUNT        128
#define VRAM_HUD_BASE           400    /* HUD digits/icons        */
#define VRAM_HUD_COUNT           64
#define VRAM_LINK_BASE          464    /* Link poses + attack     */
#define VRAM_LINK_COUNT          64
#define VRAM_ITEMS_BASE         528    /* All B-item projectiles  */
#define VRAM_ITEMS_COUNT         48
#define VRAM_PICKUPS_BASE       576    /* Heart, fairy, rupee...  */
#define VRAM_PICKUPS_COUNT       32
#define VRAM_NPC_BASE           608    /* Old man, etc            */
#define VRAM_NPC_COUNT           32
#define VRAM_ENEMIES_BASE       640    /* Per-scene enemy bank    */
#define VRAM_ENEMIES_COUNT      256
#define VRAM_BOSSES_BASE        896    /* Per-dungeon boss bank   */
#define VRAM_BOSSES_COUNT       128

#endif
```

Counts are upper bounds based on the largest simultaneously-resident set per category. Generator computes these from the registry (e.g., sums max per-scene tile counts for `enemies` — one scene's enemies live in VRAM at a time).

### 6.3 Scene-load DMA upload functions

For each category, `roomrom_atlas_<cat>_upload(variant)` is generated. Each picks the variant's bytes from the blob and DMA-uploads to `VRAM_<CAT>_BASE * 32`. For scene-conditional categories (enemies, bosses, BG_UW), variants are scene-tagged — `roomrom_atlas_enemies_upload(variant, scene_id)` picks the active scene's enemy subset.

Generated file: `RoomRom/src/atlas/roomrom_atlas_upload.{c,h}`.

Renderers / scene-transition code calls these instead of hand-rolling tile-upload loops.

### 6.4 Renderer dispatch macros

Per-category `.h` exposes:

```c
/* atlas_dispatch_<NAME>(): expands to a struct literal of the NES dispatch
 * metadata. Used inside renderers to assert SGDK SPRITE_SIZE matches. */
#define ATLAS_BOOMERANG_DISPATCH       { .w = 1, .h = 1, .class = NES_NARROW }
#define ATLAS_SWORD_HORZ_DISPATCH      { .w = 2, .h = 1, .class = NES_FLIPPABLE }
...
```

A renderer-side macro `ATLAS_ASSERT_SIZE(name, w, h)` wraps `_Static_assert` on these structs so a renderer using `SPRITE_SIZE(2, 2)` for boomerang gets a compile error.

## 7. Scene-load DMA contract

Genesis DMA bandwidth: ~6.5KB / frame during VBLANK. Sprite atlas total: estimated 8-12KB (orig + redux variants). Splits naturally by scene type.

| Scene type | Categories resident in VRAM |
|---|---|
| Boot | link, items, pickups, hud |
| Title | link, hud, title |
| File Select | link, hud, title, npc |
| Overworld | link, items, pickups, hud, bg_overworld, npc, enemies(OW), bosses(none) |
| Underworld L1-L9 | link, items, pickups, hud, bg_underworld, enemies(L<n>), bosses(L<n>) |

Scene transition triggers the upload set for that scene. Categories already in VRAM are skipped (no redundant DMA). New categories DMA-upload during VBLANK.

`roomrom_scene_load(scene_id)` is the single entry point. It looks up the upload set, queues DMA, fires during VBLANK, returns when all queued tiles have arrived. Worst case: 2 frames of VBLANK to complete a full scene swap.

This is *better than NES*. NES Z1 swaps a single 8KB CHR bank per scene, no graceful transition — visible glitching during swap. Genesis DMA can land in one frame with the renderer paused.

## 8. Layer 4 - hand-written renderers (compile-time gated)

Existing renderers (`roomrom_sprites.c`, `roomrom_combat.c`, `roomrom_bomb.c`, etc) migrate to:

```c
#include "atlas/items_chr.h"            /* per-category constants */
#include "atlas/roomrom_vram_slots.h"   /* VRAM_ITEMS_BASE, etc */

ATLAS_ASSERT_SIZE(boomerang, 1, 1);     /* compile-fails if registry disagrees */

void roomrom_sprites_set_boomerang(short x, short y, unsigned char phase_idx) {
    unsigned short tile = VRAM_ITEMS_BASE
                        + (ROOMROM_ATLAS_ITEMS_BOOMERANG_OFFSET / 32u)
                        + frame_n * 2u;
    VDP_setSpriteFull(SLOT_BOOMERANG, x, y, SPRITE_SIZE(1, 1), ...);
}
```

Renderers no longer hand-allocate VRAM tile indices or hand-author dispatch sizes. Both come from the generated headers. New sprite categories don't shift existing renderer constants.

## 9. Validator gates

Three lines of defense:

**(a) Build-time validator (`tools/verify_atlas.py`).** Walks `atlas_master.json`, classifies every entry's NES tile through the disasm dispatch logic, fails build if registry's declared `dispatch_class` disagrees with the disasm reality. Also: every renderer source file is scanned for `ATLAS_ASSERT_SIZE(...)` macros + every `roomrom_sprites_set_*` function; every renderer's claimed item must exist in the registry.

**(b) Compile-time `_Static_assert`.** `ATLAS_ASSERT_SIZE(name, w, h)` expands to a static assert against the registry's dispatch struct. Wrong SGDK `SPRITE_SIZE` in a renderer = compile error with file/line.

**(c) Pixel-diff regression test.** Per category, a Lua probe captures NES OAM mid-action and a Genesis screenshot of the matching renderer. Diff > threshold = test fails. CI gate at PR time.

The current `verify_item_chr_manifest.py` becomes a thin wrapper around (a). Strict mode on by default.

## 10. Migration plan

Phased migration. Each phase is buildable, shippable, and committable independently.

### Phase 0 — pre-flight
- Locate + version-pin `Legend of Zelda, The (USA).nes` and `Zelda Redux.nes`. Copy SHA-256 hashes into `RoomRom/data/rom_inputs.lock`.
- Verify both ROMs in `tools/extract_z1_chr.py` smoke test against existing `nes_item_chr_pt0_orig.bin` (must byte-match the resident sprite CHR bytes already captured).

### Phase 1 — source tools (Layer 1)
- Implement `tools/extract_z1_chr.py` (smallest first, no disasm dependency).
- Implement `tools/walk_z1_disasm.py` for items only — re-derives the existing `gen_item_chr_manifest.py` ITEM_DEFS from disasm. Diff against current hand-authored values; reconcile any discrepancies.

### Phase 2 — registry expansion (Layer 2)
- Extend the disasm walker to enemies, bosses, HUD, NPC, title, BG. One category per commit. Each commit adds entries; never modifies existing.
- Generate `atlas_master.json`. Frozen as the single source of truth at end of phase.

### Phase 3 — atlas generators (Layer 3)
- Implement `tools/gen_atlas.py`. Emit per-category C/H pairs, VRAM slots header, upload functions.
- First emission: items + link only, validating the pipeline against current `roomrom_item_chr.{c,h}`. Byte-match expected.

### Phase 4 — renderer migration (Layer 4)
- One renderer at a time. Replace `BOMB_VRAM_TILE` etc with the generated `VRAM_ITEMS_BASE + ROOMROM_ATLAS_ITEMS_BOMB_OFFSET / 32` form. Add `ATLAS_ASSERT_SIZE` calls.
- Run validator + visual probe per renderer. Commit per renderer.
- Order: items → link → hud → pickups → npc → enemies → bosses → title.

### Phase 5 — scene-load wiring
- Replace hand-rolled `roomrom_sprites_upload_chr()` with `roomrom_scene_load(scene_id)`. Wire scene transitions.
- Test: title → OW → UW1 → UW9 → title cycle visually correct.

### Phase 6 — legacy cleanup
- Remove old `gen_item_chr_*.py` (superseded by atlas pipeline).
- Remove hand-authored constants in renderers (everything must reference generated headers).
- Validator strict mode becomes mandatory in `build.bat`.

Each phase is a separate spec → plan → implement loop. This document only writes the design for the *whole picture*; each phase will get its own implementation plan via writing-plans.

## 11. Test strategy

| Layer | Test |
|---|---|
| Source tools | Unit: parse known ASM snippets, expect specific registry entries. Golden files. |
| Registry | Schema validation. Cross-check: every disasm citation resolves to actual file:line. |
| Atlas C | Byte-match against captured BizHawk OAM bytes for known items. |
| VRAM slots | Sum of `<CAT>_COUNT` <= 1024. No overlap between bases. |
| Upload functions | Mocked DMA queue test: each scene's category set fits in DMA budget per VBLANK. |
| Renderers | `ATLAS_ASSERT_SIZE` compile gate. Visual regression: pixel-diff against NES reference per item action. |
| End-to-end | Full title→OW→UW1→...→UW9 walkthrough screenshot per room. Diffs against current build's screenshots = passing migration. |

## 12. Open questions / risks

1. **Disasm parser scope.** Walking every NES draw path means handling many ASM patterns. Risk: parser becomes a half-finished ASM compiler. Mitigation: scope-limit to the specific patterns used in sprite-emitting routines (`Anim_WriteItemSprites` family + direct OAM writes). Reject anything else loudly so we know to extend.

2. **CHR bank naming.** Z1 uses MMC1 / MMC3 mapper bank-switch. Naming each bank semantically (`common_sprite`, `level1_sprite`) requires walking the bank-select code paths. Risk: not every bank has a clear "purpose". Mitigation: fall back to numeric bank indices for unnamed banks, hand-annotate later.

3. **Redux variant divergence.** Redux changes some CHR bytes but the same disasm dispatches. Variants are byte-pair entries in the master registry; one disasm citation, two byte payloads.

4. **VRAM budget overflow.** Total category counts may exceed 1024 tiles. Mitigation: per-scene category gating (enemies / bosses are scene-conditional, not all-resident). If still over budget, drop tile-faithfulness of a low-priority category (e.g., merge similar enemy frames).

5. **NES enemies that share tiles via attribute flips.** Many NES enemies use 2 sprites with hflip for "two facings". Genesis can do same with a single sprite + attr flip — same as boomerang fix. Generator emits one Genesis tile, renderer toggles flip. Captured in dispatch class.

6. **Pixel-diff false positives.** Color flash effects (sword beam) are timing-sensitive. Mitigation: probe captures multi-frame; diff allows N out of M frames to match.

7. **Generator throughput.** ~300-400 registry entries, full pipeline rebuild on every commit. Mitigation: cache CHR extraction by ROM SHA, cache disasm parse by file mtime. Pipeline is deterministic so caching is safe.

## 13. Deliverables checklist

- [ ] `tools/extract_z1_chr.py` reads both ROMs, dumps CHR banks, writes index JSON.
- [ ] `tools/walk_z1_disasm.py` covers items + link + hud + npc + enemies + bosses + title + bg.
- [ ] `RoomRom/data/atlas_master.json` exists, validates, contains all enumerated categories.
- [ ] `tools/gen_atlas.py` emits 10 per-category C/H pairs, VRAM slots header, upload C, dispatch macros.
- [ ] `tools/verify_atlas.py` strict-mode passes with no warnings.
- [ ] All existing renderers reference generated constants; no hand-authored VRAM tile indices remain.
- [ ] `roomrom_scene_load(scene_id)` replaces `roomrom_sprites_upload_chr`. Title→OW→UW cycle visually identical to pre-migration.
- [ ] Per-category pixel-diff CI gate green.
- [ ] `build.bat` runs validator strict by default. Fail = build fail.

## 14. Spec review

Self-review pass complete:

- [x] No "TBD" / "TODO" in substance.
- [x] Architecture (§4) matches deliverables (§13) matches phases (§10).
- [x] Scope: too big for one plan; decomposes cleanly into 6 phases (§10), each gets its own implementation plan via writing-plans skill.
- [x] Ambiguity: every architectural decision has a single interpretation; trade-offs are stated, not hidden.

---

End of design.
