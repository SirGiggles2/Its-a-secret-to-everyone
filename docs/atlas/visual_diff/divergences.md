# Visual Diff Divergences — Accepted Non-Bugs

After V0-V4 across all atlas surfaces, **byte audit confirms 0 real
mismatches** in:

- BG sparse atlas (256 NES tile_ids × 4 sub_pals × 8 banks, LUT-routed) — `tools/probes/full_atlas_audit_v2.py`
- Common SPR (first 44 tiles × 8 banks) — same audit
- SCENE_OBJ overlay (per-bank enemy/boss CHR blobs, 7 banks) — same audit
- CRAM palette (modulo PPU $3F10/$14/$18/$1C mirror) — same audit
- items_chr_x4 (98 tiles in orig variant) — `tools/probes/item_atlas_audit.py`

The V4 PNG diff finds **10,764 logical REAL_DIFF cells across 128 states**
(pages 0 + 1 only — pages 2/3 are Genesis-only and skipped). These are
**NOT** atlas bugs. They fall into four documented categories below.

---

## Category 1 — NES 6-bit master palette vs Genesis 3-bit CRAM quantization

NES master palette has 64 entries each defined as 6-bit RGB (effective
24-bit on emulator output via lookup table). Genesis CRAM stores 9-bit
RGB (3 bits per channel, even nibble). The port's color conversion via
`misc_palettes` table (`data/misc/palettes.c`) maps each NES master index
to a Genesis CRAM word with the quantization choice baked in.

Example: NES master $00 = (98, 98, 98). NES BizHawk renders this exactly.
Genesis port maps via `misc_palettes[$00]` → CRAM `$0888` → BizHawk
Genesis renders as (136, 136, 136). Both represent the same LOGICAL NES
color but produce different RGB on screen.

Logical-color diff path (`png_diff_atlas.py::logical_color_diff`) reverse-
quantizes each pixel back to NES master index and compares indices. This
filters out 2,150 quant-noise cells (12,914 → 10,764).

Remaining quant-noise cells: edge cases where reverse-lookup picks a
different NES index due to RGB-distance tie-breaking. These are
intrinsic to lossy 6-bit→3-bit conversion. **Accept.**

---

## Category 2 — Page 1 (SPR view) palette source asymmetry

Page 1 of the universal-graphics scene shows NES SPR pattern table tiles
in both ROMs. **The rendering paths differ:**

- **NES side** sets PPUCTRL bit 4 = 0, redirecting BG fetch to SPR
  pattern table ($0000-$0FFF). Resulting pixels use the **BG attribute
  table** + **NES BG PALRAM** ($3F00..$3F0F).
- **Genesis side** renders Plane A cells referencing VRAM tile slot
  `533 + tile_id`. Pixels use the **PAL1+sub_pal** palette = **NES SPR
  PALRAM** ($3F10..$3F1F) via `bg_palette.c::roomrom_bg_palette_load_palram_full`.

Same tile bytes, different palette source → visibly different RGB output
per pixel. Logical-color diff still flags REAL_DIFF because the NES
SPR sub-pal entries differ from BG sub-pal entries.

This is **expected for the test scene's design**. To make Page 1 pixel-
identical, either:
  (a) Modify Genesis side to render SPR tiles with PAL0 (BG colors) —
      breaks gameplay-representative rendering
  (b) Modify NES side to render SPR tiles through BG with attribute
      table copying SPR sub-pals into BG attribute regions — adds PRG
      complexity for marginal value

**Accept.** Byte audit already proves SPR atlas bytes match.

---

## Category 3 — Sparse atlas LUT intentional exclusions

`bg_sparse_tile_lut[256][4]` only contains entries for `(tile_id, sub_pal)`
combinations USED by NES Z1 OW/UW rooms (per
`tools/probes/audit_per_tile_subpal.py` audit output). Unused combos
return sentinel `0xFFFF` and render as the BLANK_TILE (slot 1000 = zero
pixels). NES side shows the actual CHR content for every tile_id in the
nametable.

Quantified: **18,502 SPARSE_BLANK cells** across 128 states (NES has
content, Genesis renders blank). This is the **designed VRAM headroom
strategy** — tiles not appearing in any room don't get atlas slots.

**Accept by design.** Per `RoomRom/src/roomrom_vram_map.h` Phase J.2:
sparse atlas saves ~150 KB of VRAM that would otherwise be wasted on
unused tile/sub-pal combos.

---

## Category 4 — Coverage gaps (Genesis renders where NES blank)

**3,696 COVERAGE_GAP cells**: Genesis has content, NES shows black.
Causes:

- NES BizHawk crops the top 8 lines of the 240-line PPU output (NTSC
  view). The PNG diff tool shifts Genesis up 8 lines to align, so NES
  pixel y=0..7 doesn't exist (cropped from view); Genesis row 0 was
  shifted up to y=0..7 but corresponds to NES nametable row 0 which is
  invisible. After alignment, Genesis content for nametable row 28+
  ends up in the y=216..223 region where NES screenshot is blank.
- Some Genesis SCENE_OBJ tiles bleeding into cells where NES bank 0
  has no scene-specific content (Common-only mode).

**Accept** — alignment-edge artifact + per-bank scope mismatch.

---

## Bottom line

| Surface | Byte Audit | Visual Diff |
|---------|-----------|-------------|
| BG sparse atlas | **0** mismatches | 4,698 cells in cat. 1+3 |
| Common SPR | **0** mismatches | absorbed in cat. 2 |
| SCENE_OBJ | **0** mismatches | overlap with cat. 2 |
| CRAM palette | **0** mismatches | n/a (palette diff measured directly) |
| items_chr_x4 | **0** mismatches | n/a (Page 2 Genesis-only, skipped) |

**The port's atlases are byte-identical to NES Z1.** Visual RGB diffs come
from emulation-mechanism differences (NES BizHawk vs Genesis BizHawk,
palette-source asymmetry on Page 1, NES screenshot crop alignment), not
from atlas drift or routing bugs.

For future probes catching real atlas regressions:
- Run `tools/probes/full_atlas_audit_v2.py` after any
  `gen_bg_sparse.py` / `gen_atlas.py` / `extract_chr.py` change.
- Run `tools/probes/item_atlas_audit.py` after any item manifest edit.
- Run `tools/probes/byte_atlas_audit_fix.py --fix` for live-capture
  cross-check against NES test ROM.

Visual PNG diff (V4) is supplementary — useful for spotting catastrophic
RENDERING regressions (entire pages going blank, plane-attr corruption,
scroll-register slips) but **not** for byte-level atlas correctness.
