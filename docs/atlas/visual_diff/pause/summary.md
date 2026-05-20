# Pause subscreen visual diff — L1.5 decision-gate

## Counts
- Total grid cells: 896 (28 rows x 32 cols)
- Diff cells: 376 (42.0%)
- Total diff pixels: 9344

## L1.5 gate
VISUAL-APPROX target — accept quantization-class noise

## Artifacts
- `docs/atlas/visual_diff/pause/pixel_diff.png` — RGB delta saturate
- `docs/atlas/visual_diff/pause/tile_diff.json` — per-cell counts
- `docs/atlas/visual_diff/pause/mosaic.png` — side-by-side w/ red boxes
- `docs/atlas/visual_diff/pause/palette_compare.json` — PALRAM vs CRAM

## Source captures
- `C:/tmp/nes_subscreen/01_active.png` — NES (MenuState=$08 stable)
- `C:/tmp/gen_subscreen/01_active.png` — Genesis Debug.md (ABC + Start)
