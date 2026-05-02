# RoomRom Full Graphics Registry / Atlas — North-Star Design

**Status:** north-star design — approved at north-star level (NOT yet implementation-scheduled). Stays north-star until the active CHR / palette expansion (Phase −1) lands.
**Date:** 2026-05-01 (rev 4 after Codex P3 cleanups)
**Owner:** RoomRom S-series sprite/atlas track
**Worktree:** `FINAL TRY-roomrom-s1` (branch `roomrom-s1`)
**Depends on:** [2026-05-01-roomrom-bg-palette-chr-expansion-design.md](2026-05-01-roomrom-bg-palette-chr-expansion-design.md) (active), [roomrom_vram_map.h](../../../RoomRom/src/roomrom_vram_map.h) (existing slot-map authority)

---

## 0. Why this is a north-star, not an implementation spec

Codex review (2026-05-01) flagged three blocking issues that prevent this from being scheduled directly:

1. **Source-truth error.** Earlier rev claimed Z1 has CHR ROM banks. iNES headers say byte 5 = 0 for both vanilla (`Legend of Zelda, The (USA).nes`) and Redux (`Zelda Redux.nes`) → **CHR RAM, not CHR ROM**. Pattern data lives in PRG ROM as `.INCBIN`-style blocks that get copied/transferred into CHR RAM (CPU/PPU transfer, not Genesis-style DMA) at runtime by Z1 boot/scene code. Source extraction must walk PRG pattern labels in disasm + verify against live BizHawk CHR RAM, never split a non-existent CHR ROM bank.
2. **VRAM authority duplication.** [roomrom_vram_map.h](../../../RoomRom/src/roomrom_vram_map.h) is already the single source of truth for VRAM tile bases (`ROOMROM_BG_TILE_BASE`, `ROOMROM_SPR_TILE_BASE`, sub-pal stride math). Earlier rev proposed a parallel `roomrom_vram_slots.h` — would split the authority and re-introduce the clobber it claims to fix. **Atlas work must consume / extend `roomrom_vram_map.h`, not replace it.**
3. **Global VRAM residency overreach.** Genesis VRAM (1024 tiles) cannot keep every BG + HUD + item + enemy + boss + title + FS tile resident simultaneously. Stable ROM atlas offsets — yes. Stable per-scene VRAM contracts — yes. Stable global VRAM tile indices for every category — not realistic.

Two more sharpenings:

4. **Disasm alone is not enough source truth.** Earlier rev said "Disasm IS the spec." Better: **disasm locates pattern labels and dispatch paths; live NES CHR / OAM / PALRAM verifies the result.** Both required. We already got burned by a wrong capture once (memory: `feedback_check_dont_guess`); live emulator verification stays mandatory.
5. **Scope overlap.** This atlas plan does NOT supersede the active BG palette / item atlas / CHR expansion work. It positions as a **later unification layer** on top of that foundation.

This document is now the long-term direction. Phase 0–1 of the migration (§10) gets a proper implementation spec only **after** the BG palette + CHR expansion work lands and the source-pipeline corrections below have been prototyped.

## 1. Goal

Stop the clobber. Every NES Zelda 1 (orig + Redux) graphic that *is* used by the Genesis port — sprite tiles AND BG tiles — gets a stable, NES-traceable place in:
- the ROM-resident atlas data (always-on, byte offsets fixed),
- a *per-scene* VRAM contract (which categories occupy which `roomrom_vram_map.h` regions when scene S is active).

Adding, removing, or fixing any sprite category must never shift the ROM byte offsets, the per-scene VRAM contract, or the dispatch-class metadata of any other category. Renderers and atlas data are decoupled; either side can be edited without breaking the other.

The end state: future sprite work is *additive* — drop a renderer into a category that already has reserved bytes + a documented VRAM region (when its scene is active) + a known dispatch class — rather than *combinatorial* hand-edits that ripple-break neighbouring items.

## 2. Non-goals

- **Not** finishing every sprite renderer. Atlas data + per-scene VRAM contracts only. Renderers stay as-is in this spec; they migrate incrementally over later RoomRom S-phases.
- **Not** changing the Genesis-side scrolling, plane, or HUD-on-window architecture. Other RoomRom specs own those.
- **Not** Redux-only or orig-only. Both variants ship in the atlas, runtime-selected.
- **Not** runtime CHR bank-swapping (NES-style). Genesis flat VRAM + CPU/DMA scene-load instead — see §7.
- **Not** superseding [2026-05-01-roomrom-bg-palette-chr-expansion-design.md](2026-05-01-roomrom-bg-palette-chr-expansion-design.md). That spec ships first; this one builds on top.

## 3. Why this approach

Disasm-located, PRG-extracted, live-verified, fully-generated, category-split, **per-scene-resident** atlas. Aligns with five constraints:

| Constraint | How this design satisfies it |
|---|---|
| Best long-term | Single source of truth (disasm pattern labels + PRG bytes + live capture). No hand-authored manifests. Adding a sprite is mechanical (parser config + rebuild). |
| Maximally efficient | Build artifacts auto-generated. Validator gates lift bugs to compile time. Per-scene category gating keeps VRAM budget realistic. |
| Match NES | Disasm gives the canonical tile IDs + dispatch class; live BizHawk CHR / OAM / PALRAM capture confirms bytes + frame timing. Both required (disasm alone insufficient — pattern labels can drift relative to runtime CHR RAM contents). |
| Use Genesis strengths | Per-scene CPU-upload (current path) replaces NES bank-swap; DMA-queued upload is a future optimization once the queue is implemented. CRAM bank-rotation handles palette-cycle effects (proven on the sword beam). 16x8 / 8x16 native sprite sizes collapse NES Mirrored pairs into one Genesis sprite. |
| Suit Claude | Every step is a deterministic transformation. Disasm tables + PRG `.INCBIN` blocks parse reliably. Validator failures are compile-time errors with explicit citations. "Does it match NES" reduces to pixel-diff against captured BizHawk OAM / CHR-RAM, not visual judgment. |
| Best coding practice | Generated code reproducible from sources. Hand-written code (renderers) is the only ABI surface, validated against the registry. Clear ownership boundaries per category. Extends — never duplicates — `roomrom_vram_map.h`. |

## 4. Architecture

Five layers, top to bottom:

```
+----------------------------------------------------------+
| Layer 4 - Renderers (hand-written, validator-gated)       |
|   roomrom_sprites.c, roomrom_combat.c, roomrom_hud.c, ... |
|   Cite atlas entries by name; SGDK SPRITE_SIZE             |
|   compile-checked vs registry dispatch class.             |
+----------------------------------------------------------+
                           |
                           v
+----------------------------------------------------------+
| Layer 3 - Generated C surface                             |
|   - Per-category atlas blobs (.c/.h)                      |
|   - Per-scene VRAM contract tables (extend roomrom_vram_  |
|     map.h; do NOT replace it)                             |
|   - Scene-load upload functions (CPU now, DMA later)      |
|   - Renderer-side dispatch macros / static asserts        |
+----------------------------------------------------------+
                           |
                           v
+----------------------------------------------------------+
| Layer 2 - Master sprite registry (JSON, generated)        |
|   atlas_master.json - one entry per Z1 sprite, joins      |
|   disasm citations to PRG-extracted bytes to live-capture |
|   verification hashes.                                    |
+----------------------------------------------------------+
                           |
                           v
+----------------------------------------------------------+
| Layer 1 - Source-of-truth tools                           |
|   tools/walk_z1_disasm.py                                 |
|     - locates pattern labels (.INCBIN, table .BYTE blocks)|
|     - walks Anim_WriteItemSprites callers + enemy        |
|       AnimAttr + HUD + title + boss draw routines         |
|   tools/extract_z1_prg_chr.py                             |
|     - reads PRG ROM, extracts pattern blocks at the       |
|       labels walker located, NOT a non-existent CHR ROM   |
|     - outputs verified-NES-tile bytes per (variant, label)|
|   tools/verify_chr_live.py                                |
|     - drives BizHawk to scene-load each block             |
|     - captures CHR RAM + OAM + PALRAM mid-action          |
|     - byte-matches PRG-extracted block vs live capture    |
+----------------------------------------------------------+
                           |
                           v
+----------------------------------------------------------+
| Layer 0 - Inputs (read-only, version-pinned)              |
|   reference/aldonunez/Z_00..Z_07.asm                      |
|   Legend of Zelda, The (USA).nes  (PRG holds patterns;    |
|                                   CHR RAM = 0 banks)      |
|   Zelda Redux.nes                  (same iNES shape)      |
+----------------------------------------------------------+
```

Layers 0–3 are deterministic given pinned inputs. CI rebuilds from scratch and byte-matches.
Layer 4 is hand-written but compile-time-bound to the registry.

## 5. Layer 1 — source tools (corrected)

### 5.1 `tools/walk_z1_disasm.py`

Reads `reference/aldonunez/Z_00..Z_07.asm`. Walks every sprite-emitting code path AND every pattern-data block. Emits a JSON intermediate.

For each **sprite category entry**:
- `name`, `category`, `nes_tile_ids` (list per frame), `dispatch_class`, `disasm_citation` (file/line/label), `frame_count`, `palette_assumption`.

For each **pattern-data block** (the actual bytes that the NES CPU writes into CHR RAM via PPUDATA at runtime — Z1 is CHR RAM, no Genesis-style DMA on NES side):
- `label` (e.g., `CommonSpritePatterns`, `OwBgPatterns`, `Level1SprPatterns`)
- `disasm_file_line`, `byte_count`, `target_chr_ram_address` (where the boot/scene code copies it to)
- `referenced_by` — list of disasm code paths that copy/transfer this block into CHR RAM (NES side: CPU writes through PPUDATA; the runtime transfer may transform bytes — bit-flip, mask, or pack — before they land in CHR RAM, but the canonical PRG bytes themselves are read-only).

Routines walked (sprite categories):
- `Anim_WriteItemSprites` callers (Z_07 + Z_05)
- `BombCloudOffsetsX1/Y1` consumers
- `EnemyAnimAttr*` tables
- Boss-specific draw routines (per boss in Z_07)
- HUD digit + icon writers (Z_05/Z_06 status bar)
- Title screen sprite tables (Z_02)
- File select sprite writers (Z_05)
- NPC draw routines

Pattern blocks walked: `.INCBIN` directives in `Z_*.asm` plus inline `.BYTE` pattern tables.

Parser scope-limited to the patterns Z1 actually uses; rejects unknown ASM forms loudly so we know to extend, not silently misparse.

### 5.2 `tools/extract_z1_prg_chr.py` (replaces the wrong "split CHR ROM banks" tool)

Reads `Legend of Zelda, The (USA).nes` and `Zelda Redux.nes`. **Skips the 16-byte iNES header. Reads PRG ROM (no CHR ROM exists per byte 5 = 0).** For each pattern-block label from §5.1, locates the byte range inside PRG ROM and extracts it as that block's canonical bytes.

Output: `RoomRom/out/prg_blocks/<variant>/<label>.bin` + `RoomRom/out/prg_blocks/<variant>_index.json` mapping label → (offset, length, sha256).

Hermetic. No emulator. Same .nes file → same output bytes forever.

### 5.3 `tools/verify_chr_live.py` (mandatory live-verify gate)

Drives BizHawk to a known scene state per pattern block (e.g., enter Level 1 to load `Level1SprPatterns`, kill all enemies + load File Select to load title patterns, etc). For each scene, captures **CHR RAM** (the live tile bytes the PPU is rendering from), OAM (so we know which sprite indices are active mid-action), and PALRAM. Byte-matches captured CHR RAM against the PRG-extracted block from §5.2.

Mismatch → fail. Possible causes: the disasm-located label is wrong; the PRG offset extraction is wrong; or Z1's runtime transfer routine transforms the bytes (bit-flip, mask, etc.) on the way into CHR RAM. The third case is not a PRG mutation — PRG ROM is read-only — but a transfer-time transform that the registry must record so generators can replay it. All three are bugs / gaps we want caught up front.

This is the live-verify-mandatory step Codex called out. It runs on CI when ROM changes (rare), not on every renderer commit.

### 5.4 `tools/gen_atlas_master.py`

Joins (registry from §5.1) × (PRG bytes from §5.2) × (live-verify status from §5.3). Writes `RoomRom/data/atlas_master.json` — single source manifest. Each entry carries: dispatch class, pattern block ID, byte slice within block, variant overrides, last verified-live timestamp + capture hash.

## 6. Layer 3 — generated C surface (corrected)

### 6.1 Per-category atlas blobs

Single generator `tools/gen_atlas.py` reads `atlas_master.json`. Emits per-category C/H pairs under `RoomRom/src/atlas/`:

```
link_chr        items_chr         pickups_chr      hud_chr
enemies_chr     bosses_chr        npc_chr          title_chr
bg_overworld    bg_underworld
```

Per category: one `unsigned char roomrom_atlas_<cat>[VARIANT_COUNT][BYTES]` blob, plus `ROOMROM_ATLAS_<CAT>_<NAME>_OFFSET` constants for named entries inside the blob. Byte offsets stable within a category as long as the registry's entry order is stable. Adding a sprite within a category appends; doesn't shift other categories.

**Bytes stored: NES 2bpp source.** `atlas_master.json` and the per-category blobs store the canonical NES 2bpp pattern bytes (16 bytes per 8x8 tile, plane-0 then plane-1, exactly as they appear in PRG ROM). The pixel-biased NES → Genesis 4bpp expansion (sub-palette tile copies) stays owned by the active [CHR expansion pipeline](2026-05-01-roomrom-bg-palette-chr-expansion-design.md). Atlas → renderer flow: 2bpp bytes from the atlas → CHR-expansion conversion at upload time → 4bpp tiles in VRAM at the address the per-scene contract specifies. The atlas does NOT bake 4bpp; doing so would couple atlas data to whichever palette layout the expansion pipeline picks today, re-introducing the clobber.

**No-compaction rule.** Once a named entry is added to a category blob, its byte offset is permanent. Removing a sprite tombstones the entry: the bytes stay, the constant gets a `_DEPRECATED` suffix, and a registry-level `removed: true` marker lets the validator skip dispatch checks on it. Generators never compact existing category blobs across builds. Compaction is allowed only via an explicit `atlas_version` bump that all renderers and per-scene contracts re-check against. This is what guarantees stable offsets — without it, "remove a sprite" silently becomes "shift every later renderer's tile reference".

### 6.2 Per-scene VRAM contracts (extend `roomrom_vram_map.h`)

`roomrom_vram_map.h` stays the single VRAM authority. Generator emits a NEW header alongside it — `roomrom_scene_vram_contracts.h` — that maps `(scene_id, category) → tile-range within the existing map regions`.

Example (illustrative, not final allocation):

```c
/* Auto-generated by tools/gen_atlas.py - do not edit. */
#ifndef ROOMROM_SCENE_VRAM_CONTRACTS_H
#define ROOMROM_SCENE_VRAM_CONTRACTS_H
#include "roomrom_vram_map.h"

/* Each contract: at scene S the named category occupies the listed
 * tile range, expressed relative to one of the regions defined in
 * roomrom_vram_map.h. NO new VRAM bases declared here. */

typedef struct {
    unsigned short tile_base;   /* absolute Genesis VRAM tile index */
    unsigned short tile_count;
    unsigned short blob_offset; /* byte offset into the category blob */
    unsigned short blob_bytes;
} roomrom_vram_contract_t;

extern const roomrom_vram_contract_t roomrom_vram_contract_OW_link;
extern const roomrom_vram_contract_t roomrom_vram_contract_OW_items;
extern const roomrom_vram_contract_t roomrom_vram_contract_OW_enemies;
/* ... per-scene contracts only; no globally stable category bases. */

#endif
```

Per-scene contracts are stable as long as the scene's category set is stable. Scene definitions live in disasm-walked metadata, so adding a new scene (e.g., a Redux-only dungeon level) requires a registry entry, not a VRAM map edit.

### 6.3 Scene-load upload functions

For each (scene, category) pair, `roomrom_atlas_load_<scene>_<cat>(variant)` is generated. Implementation calls into the existing `render_chr_upload()` (CPU-mode `VDP_loadTileData`) — **CPU upload is the current model** per `RoomRom/src/render_adapter_sgdk.c`. DMA queueing is a future optimization with its own spec; this design does not depend on it.

A coordinator `roomrom_scene_load(scene_id, variant)` calls each category's per-scene loader in order. VBLANK scheduling is left to the existing render loop; if upload exceeds one frame, the scene-load explicitly disables sprite rendering for the duration (existing behaviour).

### 6.4 Renderer dispatch macros

Per-category `.h` exposes:

```c
#define ATLAS_BOOMERANG_DISPATCH    { .w = 1, .h = 1, .class = NES_NARROW }
#define ATLAS_SWORD_HORZ_DISPATCH   { .w = 2, .h = 1, .class = NES_FLIPPABLE }
```

`ATLAS_ASSERT_SIZE(name, w, h)` triggers a compile error if the renderer's claimed size disagrees with the registry entry.

**Implementation depends on compiler capability.** SGDK's m68k toolchain (`gcc-m68k` shipped under `sgdk/bin/`) is not guaranteed to default to a C11-supporting standard. Phase 0 verifies in a smoke test:

```c
/* phase0_static_assert_probe.c */
_Static_assert(sizeof(int) >= 4, "C11 _Static_assert available");
```

If the smoke test passes (likely on modern SGDK gcc with `-std=gnu11` or higher), `ATLAS_ASSERT_SIZE` expands to a `_Static_assert`. If the smoke test fails, `ATLAS_ASSERT_SIZE` falls back to a portable typedef-based assertion macro:

```c
/* Portable C89-compatible static assert. Generates a typedef of an
 * array; size is positive when the predicate holds, -1 (illegal)
 * when it fails. Compile error fires at the typedef. */
#define ATLAS_STATIC_ASSERT_C89(predicate, name) \
    typedef char atlas_static_assert_##name[(predicate) ? 1 : -1]
```

The macro contract is unchanged — wrong SGDK `SPRITE_SIZE` is still a compile error with file/line. Only the underlying mechanism switches per Phase 0 result. Phase 0 commits the chosen fallback path into `RoomRom/src/atlas/atlas_static_assert.h` so the registry contract is not compiler-version brittle.

## 7. Scene-load contract (CPU-based, corrected)

Current path: `render_chr_upload()` in `render_adapter_sgdk.c` calls `VDP_loadTileData(buf, tile, count, CPU)` — synchronous CPU upload, 1 tile per call. Bandwidth ~2-3 KB / frame during VBLANK depending on contention.

Sprite atlas total estimate: 8–12 KB per variant (orig + redux). Splits across scenes:

| Scene type | Categories resident |
|---|---|
| Boot | link, items, pickups, hud |
| Title | link, hud, title |
| File Select | link, hud, title, npc |
| Overworld | link, items, pickups, hud, bg_overworld, npc, enemies(OW), bosses(none) |
| Underworld L1-L9 | link, items, pickups, hud, bg_underworld, enemies(L<n>), bosses(L<n>) |

Scene transition: target ≤ 2 frames blocked for the per-scene loader. **This is a measurement gate, not a promise.** Phase 1 emits per-scene upload-byte counts; the implementation spec measures actual elapsed VBLANK time across representative scenes (Title→OW, OW→UW1, UW1→UW9 boss). If a scene exceeds the 2-frame budget, two explicit fallbacks apply, in this order:

1. **Forced display-off multi-frame load.** Blank the screen via `VDP_setEnable(FALSE)` for the duration of the upload. No VBLANK contention; CPU upload runs at full speed across N frames. Visible glitch is now an explicit black-frame transition (still matches NES behavior).
2. **Split scene-load.** Move category uploads that aren't immediately needed (e.g. boss tiles when entering a non-boss room of a dungeon) to deferred uploads inside subsequent VBLANKs while gameplay continues with placeholder tiles in those slots.

Visible-glitch behaviour during transitions is acceptable as long as it's deterministic and one of the documented fallbacks. Renderers must not assume scene-load completes in any specific frame count; they only assume the per-scene VRAM contract is in place by the time `roomrom_scene_load` returns.

DMA-queued upload is a separate future spec. When implemented, scene-load timing improves to 1 VBLANK / scene; the renderer ABI does not change.

## 8. Layer 4 — renderer migration sketch

```c
#include "atlas/items_chr.h"                 /* per-category constants */
#include "roomrom_vram_map.h"                /* unchanged authority */
#include "atlas/roomrom_scene_vram_contracts.h"

ATLAS_ASSERT_SIZE(boomerang, 1, 1);          /* compile gate */

void roomrom_sprites_set_boomerang(short x, short y, unsigned char phase_idx) {
    const roomrom_vram_contract_t *c = &roomrom_vram_contract_OW_items;
    unsigned short tile = c->tile_base
                        + (ROOMROM_ATLAS_ITEMS_BOOMERANG_OFFSET / 32u)
                        + frame_n * 2u;
    VDP_setSpriteFull(SLOT_BOOMERANG, x, y, SPRITE_SIZE(1, 1), ...);
}
```

Renderers reference `roomrom_vram_map.h` regions via the per-scene contract struct, plus the category atlas's named offsets. No hand-allocated VRAM tile indices, no hand-authored dispatch sizes.

## 9. Validator gates

Three lines of defense:

(a) **Build-time validator (`tools/verify_atlas.py`).** Walks `atlas_master.json`. For every entry, classifies the NES tile through the disasm dispatch logic; fails build if `dispatch_class` disagrees with disasm. Cross-checks: every renderer source file is scanned for `ATLAS_ASSERT_SIZE(...)` macros + every `roomrom_sprites_set_*` function — every claimed name must exist in the registry. Strict by default in `RoomRom/build.bat`.

(b) **Compile-time assert** via `ATLAS_ASSERT_SIZE` (C11 `_Static_assert` if SGDK toolchain supports it; otherwise the C89-compatible typedef-array fallback — see §6.4).

(c) **Pixel-diff regression test.** Per category, a Lua probe captures NES OAM mid-action and a Genesis screenshot of the matching renderer. Diff > threshold → fail. CI gate at PR time. Tolerates timing-sensitive effects (color flash) by allowing N-of-M-frame matches.

The current `verify_item_chr_manifest.py` becomes a thin wrapper around (a). Strict mode goes on once Phases 1–3 land.

## 10. Migration plan (now phased on top of existing work)

### Phase −1 — finish dependencies (LANDED 2026-05-02)
- BG palette / item atlas / CHR expansion ([2026-05-01-roomrom-bg-palette-chr-expansion-design.md](2026-05-01-roomrom-bg-palette-chr-expansion-design.md)) lands first.
- All renderers stable on the corrected slot map + populated PAL0/PAL1 + `roomrom_vram_map.h` post-Phase-3 layout.
- Only after Phase −1 does Phase 0 below get its own writing-plans pass.

### Phase 0 — pre-flight
- Pin both `Legend of Zelda, The (USA).nes` and `Zelda Redux.nes` SHA-256 into `RoomRom/data/rom_inputs.lock`.
- PRG extraction smoke test: `tools/extract_z1_prg_chr.py` extracts the `CommonSpritePatterns` block from PRG. Verifier launches BizHawk, scene-loads the overworld, captures the live CHR RAM slice at `CommonSpritePatterns`'s known target address (per disasm), byte-matches that slice — NOT the whole `nes_item_chr_pt0_orig.bin` dump — against the PRG-extracted bytes. Per-block target-address comparison is the only valid check; whole-pattern-table dumps mix multiple blocks at different addresses and would mask offset bugs.
- Compiler capability smoke test: compile `phase0_static_assert_probe.c` against the SGDK m68k gcc. If `_Static_assert` builds, commit `ATLAS_ASSERT_SIZE` to expand to it. If not, commit the C89 typedef-array fallback. Either way, write the chosen path into `RoomRom/src/atlas/atlas_static_assert.h` so subsequent phases inherit a stable assertion mechanism.

### Phase 1 — source tools (Layer 1)
- Implement `tools/extract_z1_prg_chr.py` first (no disasm dependency beyond pattern labels).
- Implement `tools/walk_z1_disasm.py` items-only — re-derive existing `gen_item_chr_manifest.py` ITEM_DEFS from disasm. Diff against current hand-authored values; reconcile.
- Implement `tools/verify_chr_live.py` items-only.

### Phase 2 — registry expansion
- Disasm walker extends to enemies, bosses, HUD, NPC, title, BG. One category per commit. Append-only.
- Generate `atlas_master.json`. Frozen as single source of truth.

### Phase 3 — atlas generators (Layer 3)
- Implement `tools/gen_atlas.py`. Emit per-category C/H, **scene VRAM contract header (NOT a new VRAM authority)**, scene-load upload functions, dispatch macros.
- First emission: items + link only, byte-matching current generated `roomrom_item_chr.{c,h}`.

### Phase 4 — renderer migration
- One renderer at a time. Replace `BOMB_VRAM_TILE` etc with the generated contract + offset form. Add `ATLAS_ASSERT_SIZE`.
- Per-renderer probe + visual diff. Commit per renderer.
- Order: items → link → hud → pickups → npc → enemies → bosses → title.

### Phase 5 — scene-load wiring
- Replace hand-rolled `roomrom_sprites_upload_chr()` with `roomrom_scene_load(scene_id, variant)`. Wire transitions.
- Cycle test: title → OW → UW1 → UW9 → title visually unchanged.

### Phase 6 — legacy cleanup
- Remove `gen_item_chr_*.py` (superseded by atlas pipeline).
- All renderers reference generated headers only.
- Validator strict mode mandatory in `build.bat`.

Each phase is its own spec → plan → implement loop. This document is the design for the *whole*; phases get implementation specs after Phase −1 lands.

## 11. Test strategy

| Layer | Test |
|---|---|
| Source tools | Unit: parse known ASM snippets; expect specific registry entries. Golden files. |
| Registry | Schema validation. Cross-check: every disasm citation resolves to actual file:line. |
| PRG extraction | Byte-match extracted blocks vs live BizHawk CHR-RAM captures (mandatory). |
| Atlas C | Byte-match against captured BizHawk OAM / PALRAM bytes for known items. |
| VRAM contracts | Sum of per-scene tile counts ≤ regions in `roomrom_vram_map.h`. No overlap within a scene. |
| Upload functions | Per-scene CPU-upload time MEASURED at Phase 1; ≤ 2 frames is the target gate. Over-budget scenes invoke a documented fallback (display-off multi-frame OR split deferred load). Renderer ABI does not assume a specific frame count. |
| Renderers | `ATLAS_ASSERT_SIZE` compile gate. Pixel-diff vs NES reference per item action. |
| End-to-end | Title → OW → UW1 → … → UW9 walkthrough screenshot per room. Diffs against current build = passing migration. |

## 12. Open questions / risks

1. **PRG pattern-label coverage.** Z1 may copy bytes into CHR RAM from non-labelled PRG offsets in some scenes (CPU/PPUDATA writes from a PRG region the disasm walker did not catch). Mitigation: Phase 1 tool reports any CHR-RAM bytes that don't match a labelled block; we either label them or document them as known divergences.
2. **Pattern-block aliasing.** Z1 sometimes copies subsets of one block into multiple CHR RAM regions per scene. The registry tracks `target_chr_ram_address` per (block, scene) so aliases are explicit, not hidden.
3. **Redux variant divergence.** Redux modifies some pattern blocks but keeps disasm dispatch. Variants are byte-pair entries in the master registry; one disasm citation, two byte payloads.
4. **VRAM budget overflow per scene.** Mitigation: scene-conditional categories (enemies / bosses). If still over budget after gating, drop frames of low-priority categories rather than expanding `roomrom_vram_map.h` regions.
5. **Pixel-diff false positives on color-flash effects.** Probe captures multi-frame; diff allows N-of-M-frame match.
6. **Generator throughput.** ~300–400 registry entries. Cache PRG extraction by ROM SHA + disasm walk by file mtime. Pipeline deterministic → caching safe.
7. **Live-verify drift.** BizHawk version changes may shift capture timing. Pin BizHawk version in `RoomRom/data/biz_hawk.lock`.

## 13. Deliverables checklist

- [ ] `tools/extract_z1_prg_chr.py` reads PRG ROM (NOT a non-existent CHR ROM), extracts pattern blocks at disasm-located labels, writes index JSON.
- [ ] `tools/walk_z1_disasm.py` covers items + link + hud + npc + enemies + bosses + title + bg pattern blocks.
- [ ] `tools/verify_chr_live.py` byte-matches every PRG block against live BizHawk CHR-RAM. Mandatory CI gate.
- [ ] `RoomRom/data/atlas_master.json` exists, validates, contains all enumerated categories.
- [ ] `tools/gen_atlas.py` emits 10 per-category C/H pairs, scene VRAM contracts header (extending `roomrom_vram_map.h`), upload C, dispatch macros.
- [ ] `tools/verify_atlas.py` strict-mode passes with no warnings.
- [ ] All renderers reference generated constants + per-scene contracts; no hand-authored VRAM tile indices remain.
- [ ] `roomrom_scene_load(scene_id, variant)` replaces `roomrom_sprites_upload_chr`. Cycle visually identical.
- [ ] Per-category pixel-diff CI gate green.
- [ ] `build.bat` runs validator strict by default. Fail = build fail.
- [x] **Phase −1 dependency** ([2026-05-01-roomrom-bg-palette-chr-expansion-design.md](2026-05-01-roomrom-bg-palette-chr-expansion-design.md)) shipped before this spec graduates to implementation.

## 14. Spec review

Self-review pass (rev 3 after Codex review of rev 2):

- [x] Source-truth correction applied: PRG block extraction + live verify, NOT a non-existent CHR ROM split.
- [x] VRAM authority: extends `roomrom_vram_map.h`. NO competing slot map.
- [x] Per-scene VRAM contracts only; no claim of stable global VRAM indices for every category.
- [x] Disasm + live capture both required for source truth.
- [x] Positioned as a north-star with explicit `Phase −1` dependency on the active CHR / palette expansion spec.
- [x] CPU-upload acknowledged as current path; DMA queue noted as future-only.
- [x] Rev 3: NES-side wording fixed — "DMA into CHR RAM" → CPU/PPU-bus PPUDATA writes (no Genesis-style DMA on NES).
- [x] Rev 3: no-compaction rule added — tombstone removed entries, never compact without explicit `atlas_version` migration.
- [x] Rev 3: PRG smoke test scoped to per-block target-address slice, not whole `nes_item_chr_pt0_orig.bin`.
- [x] Rev 3: atlas stores NES 2bpp source bytes; pixel-biased 4bpp expansion stays owned by the CHR-expansion pipeline.
- [x] Rev 4: remnant DMA wording cleaned up. Pattern-block transfers consistently described as CPU/PPUDATA copy/transfer/load. Runtime byte transformation (bit-flip / mask) explicitly noted as transfer-time, not PRG mutation.
- [x] Rev 4: scene-load 2-frame timing reframed as a measurement gate (Phase 1 measures, fallbacks documented: forced display-off multi-frame OR split deferred load). Renderer ABI does not assume frame count.
- [x] Rev 4: `_Static_assert` portability handled. Phase 0 compiler-capability smoke test picks `_Static_assert` (C11) or C89 typedef-array fallback. `ATLAS_ASSERT_SIZE` macro contract unchanged either way.
- [x] All sections internally consistent; no "TBD" / "TODO" in substance.

---

End of design (rev 4).
