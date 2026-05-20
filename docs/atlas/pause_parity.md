# Pause subscreen parity (Phase 7 v2 LITE) — 2026-05-20

## Status

L0-L5 + L7 closed. L6 (scroll port) DEFERRED per debate consensus (PX7
architecturally dead — BG_B aliased to Plane A nametable per
`RoomRom/src/main.c:487`).

## Latest diff (post-L4 baseline)

- Total grid cells: 896 (28 rows x 32 cols)
- Diff cells: 376 (42.0%)
- Total diff pixels: 9344
- L1.5 gate: **VISUAL-APPROX** — accept quantization-class noise

## What landed

| Task | Change | Visible result |
|---|---|---|
| L0 | enemy_render.c merge cleanup | MOOT — no markers in file (E0 fix 5b6f2218 already clean) |
| L1 | NES + Genesis capture pipeline + pause_visual_diff.py | Baseline 364 cells diff established |
| L2 | NES SubmenuItemXs[16] table + slot→item dispatch | Items now in NES-correct rows (Y=$36 row 1, Y=$46 row 2, Y=$1E top, Y=$76/$9E for map/compass) |
| L3 | Cursor tile NES $1E + FrameCounter flash | Cursor sprite uses ROOMROM_SPR_TILE_BASE+$1E, PAL2/PAL3 toggle per bit 3 |
| L4 | CRAM swap to NES subscreen palram + alphabet force-include sub-pal 1+3 | Text renders red ("INVENTORY", "USE B BUTTON FOR THIS") + brown ("TRIFORCE"); items render in NES SPR sub-pal 0 colors |
| L5 | SAT exit cleanup — all 80 slots zeroed | No ghost item sprites on unpause |
| L7 | This doc | Divergence catalog |

## Accepted divergences (debate consensus)

| Divergence | Source | Reason |
|---|---|---|
| Sprite +128 offset | Gemini, Sonnet | Hardware fact: Genesis SAT requires +128 on X/Y vs NES OAM raw pixels. Already applied in `draw_item_icon`. Sprite-position byte-diff IS impossible. |
| CRAM 9-bit quantization | Codex, Opus | Genesis can only express upper 3 bits per channel; NES 6-bit master palette denser. `pause_visual_diff.py` applies 3-bit quantize before diff to remove this floor. |
| Scroll animation differs | Gemini math, Codex, Sonnet | Phase 6 row-by-row replacement is cosmetic; NES PPU VScroll register animation deferred. PX7 BG_B priority swap is architecturally dead (Plane B aliased to Plane A). |
| HUD overlap | Gemini, Opus | NES uses sprite-0-hit + HBlank scroll change to mask HUD over subscreen. Genesis Window plane behavior differs. Accepted boundary divergence. |
| B-item box frame missing | Layout work | BG tilemap decoration (NES draws blue box around B-item slot); deferred to V2 with BG-frame port. |
| Item-grid box missing | Layout work | NES draws frame around top-right item grid (4x3 cells); deferred V2. |
| Filled triforce triangle | Layout work | NES uses BG tilemap fill for triangle interior; current Genesis shows label only. Deferred V2. |
| Bottom HUD strip not preserved | Layout work | NES subscreen leaves bottom-rows for gameplay HUD via VScroll-clip; Genesis Window plane carries HUD already. Out of scope for L2-L5. |
| Letter / Wand items use placeholder tiles | Atlas | `ROOMROM_ITEM_TILE_LETTER` and `ROOMROM_ITEM_TILE_MAGICAL_ROD` not extracted; substitute BOOK_OF_MAGIC and SWORD_VERT until atlas extension. |
| Magic boomerang shares wood tile | Atlas | No separate magic-boomerang sprite in items_chr_x4 atlas. Future task. |

## Artifacts

- `docs/atlas/visual_diff/pause/pixel_diff.png` — RGB delta saturate
- `docs/atlas/visual_diff/pause/tile_diff.json` — per-cell diff counts
- `docs/atlas/visual_diff/pause/mosaic.png` — NES | gap | Genesis side-by-side
- `docs/atlas/visual_diff/pause/palette_compare.json` — PALRAM vs CRAM raw bytes
- `build/probes/nes_subscreen_capture.lua` — NES baseline probe (savestate-free, scripted nav + RAM-poke for items)
- `build/probes/gen_subscreen_capture.lua` — Genesis baseline probe
- `tools/probes/pause_visual_diff.py` — 3-mode classifier + L1.5 gate
- `src/game/inventory/inventory_palette.{c,h}` — NES PALRAM blob + CRAM swap

## Debate context

- `debates/044-phase7-pause-subscreen/` — 4-AI adversarial review of original Phase 7 PX0-PX9 plan (Gemini + Codex + Sonnet + Opus)
- `~/.claude/plans/new-session-handoff-immutable-bear.md` Phase 7 v2 section — full LITE plan with cost breakdown

## Next (V2 candidates)

If user wants further parity:
1. BG-frame port: B-item box outline + item-grid frame + triforce triangle (~3-5 hr atlas force-include + tilemap write)
2. HUD strip preservation: keep bottom 4 rows showing gameplay HUD during subscreen (1-2 hr — extend write_inventory_row to skip rows 24-27)
3. Item atlas extension: extract LETTER + MAGICAL_ROD + MAGIC_BOOMERANG sprites from NES CHR (1-2 hr atlas regen)
4. Sub-pal 3 cycle on triforce pieces (cosmetic, 30 min)
