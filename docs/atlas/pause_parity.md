# Pause subscreen parity (Phase 7 v2 LITE + V2 extensions) — 2026-05-20

## Status

L0-L5 + L7 + V2.1 + V2.2 closed. L6 (full scroll port) DEFERRED.
V2.3 (atlas extension) DEFERRED.

## Latest diff (post-V2.1)

- Total grid cells: 896 (28 rows x 32 cols)
- Diff cells: 409 (45.6%)
- L1.5 gate: VISUAL-APPROX (debate consensus pixel-exact impossible)

Diff count INCREASED from 376 (L4) to 409 (V2.1) because Genesis now
renders more BG content (frames, triangle, labels) and any pixel mismatch
adds cells, but VISUAL fidelity is dramatically improved (B-item box,
item-grid box, filled triangle, all text in correct positions).

## What landed

| Task | Change | Visible result |
|---|---|---|
| L0 | enemy_render.c merge cleanup | MOOT — no markers (E0 5b6f2218 clean) |
| L1 | NES + Genesis capture pipeline + 3-mode classifier | Baseline 364 cells diff |
| L2 | NES SubmenuItemXs[16] + slot→item dispatch | Items at NES-correct rows ($36/$46/$1E/$76/$9E) |
| L3 | Cursor tile NES $1E + FrameCounter flash | Cursor uses SPR_TILE_BASE+$1E, PAL2/PAL3 toggle bit 3 |
| L4 | CRAM swap to NES subscreen PALRAM + alphabet sub-pal 1+3 force-include | Red INVENTORY/USE B BUTTON text, brown TRIFORCE label |
| L5 | SAT exit cleanup — all 80 slots zeroed | No ghost sprites on unpause |
| L7 | Divergence catalog | docs/atlas/pause_parity.md (this) |
| V2.1 | NES subscreen tilemap blob from CIRAM capture + force-include $69-$6E + $E7-$F1 + $F5 + row offset 8 (NES VScroll=$41) | B-item BOX outline, item-grid BOX, filled TRIFORCE triangle (color slightly off due to atlas sub_pal 3 bias inheriting gameplay PAL), correct vertical positions |
| V2.2 | HUD strip preserved via Genesis Window plane (no code change needed) | Gameplay HUD on Window stays visible during pause; NES bottom-HUD info parity-equivalent |

## Accepted divergences

| Divergence | Source | Reason |
|---|---|---|
| Sprite +128 offset | Gemini, Sonnet | Hardware fact: Genesis SAT requires +128 on X/Y vs NES OAM raw pixels. |
| CRAM 9-bit quantization | Codex, Opus | Genesis upper 3 bits per channel vs NES 6-bit master palette. pause_visual_diff.py 3-bit quantize before diff to remove this floor. |
| Scroll animation differs | Gemini math, Codex, Sonnet | Phase 6 row-by-row replacement is cosmetic; NES PPU VScroll deferred. PX7 BG_B priority swap architecturally dead. |
| HUD overlap boundary | Gemini, Opus | NES sprite-0-hit + HBlank scroll change to mask HUD over subscreen. Genesis Window plane behavior differs but functionally equivalent. |
| Triforce triangle color tint | V2.1 atlas | NES BG sub-pal 3 differs between gameplay and subscreen scenes. Atlas tile bias was extracted for gameplay sub-pal 3 = (green/yellow/blue). Subscreen NES sub-pal 3 = (brown/yellow/blue). Genesis CRAM at subscreen-enter loads subscreen sub-pal 3, but tile data bias was scene-specific. Resulting tint is close to NES intent. |
| LETTER / WAND / MAGIC_BOOMERANG items use placeholder tiles | Atlas | Not in items_chr_x4. Substituted BOOK_OF_MAGIC, SWORD_VERT, BOOMERANG. V2.3 deferred. |
| NES bottom HUD ($255, X16 B/A LIFE hearts) not in Plane A | Layout | Genesis Window plane carries equivalent HUD over Plane A. NES bottom-HUD strip (CIRAM page 0 rows 8-29) not ported to Plane A — Window plane provides parity-equivalent UI. |

## Artifacts

- `docs/atlas/visual_diff/pause/pixel_diff.png` — RGB delta saturate
- `docs/atlas/visual_diff/pause/tile_diff.json` — per-cell diff counts
- `docs/atlas/visual_diff/pause/mosaic.png` — NES | gap | Genesis side-by-side
- `docs/atlas/visual_diff/pause/palette_compare.json` — PALRAM vs CRAM raw bytes
- `build/probes/nes_subscreen_capture.lua` — NES baseline probe (CIRAM + PALRAM domains)
- `build/probes/gen_subscreen_capture.lua` — Genesis baseline probe
- `tools/probes/pause_visual_diff.py` — 3-mode classifier + L1.5 gate
- `src/game/inventory/inventory_palette.{c,h}` — NES PALRAM blob + CRAM swap
- `src/game/inventory/inventory_tilemap.{c,h}` — NES NT page 1 blob

## Debate context

- `debates/044-phase7-pause-subscreen/` — 4-AI adversarial Round 1 (Gemini + Codex + Sonnet + Opus)
- `~/.claude/plans/new-session-handoff-immutable-bear.md` Phase 7 v2 section — full LITE plan

## V2.3 deferred (atlas extension)

If user requests:
- Extract LETTER sprite from NES `CommonSpritePatterns.dat` -> add to item_chr_manifest.json -> regen items_chr_x4
- Extract MAGICAL_ROD sprite (NES $34/$36 sword-variant tiles)
- Extract MAGIC_BOOMERANG with sub_pal 1 variant
- Cost: 2-4 hr atlas regen + verify

## V2.4 deferred (sub_pal 3 atlas bias)

The triforce triangle renders with slight color tint because atlas tile bias was extracted from gameplay scene's sub_pal 3 (different colors than subscreen). True fix requires:
- Add subscreen-context atlas variant (4-PAL collapse cleanup)
- Or runtime CRAM swap of PAL0[12..15] specifically during subscreen render
- Cost: 1-2 hr if scene-context split path lands separately
