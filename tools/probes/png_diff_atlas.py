"""png_diff_atlas.py — 3-mode visual diff toolkit for atlas captures.

Reads paired PNG screenshots from:
  C:/tmp/chr_cycle_nes/<state>.png   — NES test ROM
  C:/tmp/chr_cycle_gen/<state>.png   — Genesis Debug.md

Produces per-state outputs in docs/atlas/visual_diff/:
  1. pixel_diff/<state>.png       — RGB delta per pixel (saturate magnitude)
  2. tile_diff/<state>.json       — 8x8 cell aggregation, machine-readable
  3. mosaic/<state>.png           — NES | gap | Genesis with red diff boxes
  4. summary.md                   — top-level report

Both NES + Genesis screenshots are 256x224. Layout map per universal-
graphics scene (V1 + V2 alignment):
  view_page = 0 -> BG grid (NES tile_id $00..$FF in 16x16 cells)
  view_page = 1 -> SPR grid (NES SPR tile_id $00..$FF in 16x16 cells)
  view_page = 2 -> ITEM+Link grid (Genesis-only; NES blank, skip)
  view_page = 3 -> Misc/SCENE_OBJ (Genesis-only; NES blank, skip)

For pages 0 + 1, diff is meaningful cell-by-cell. Pages 2/3 are
informational (Genesis content rendered; NES blank).

NES screenshots are cropped 8 lines from top by BizHawk NTSC view (8 + 224
+ 8 = 240 PPU lines, 224 shown). Genesis screenshots show plane A from
line 0. So NES screenshot pixel (x, y) corresponds to nametable line
(x, y+8). To diff correctly: shift NES content DOWN 8 lines OR shift
Genesis content UP 8 lines.

For our layout, the grid starts at nametable row 0. NES screenshot crops
row 0 (pixel y=0..7); Genesis shows row 0 at pixel y=0..7. Mismatch.

Fix: pad NES screenshot top with 8 black rows OR crop Genesis top 8 rows.
Choose: crop Genesis 8 rows (preserves NES authentic crop). Both then
have grid row 0 at pixel y=0.

Wait — Genesis SCENE_DEBUG_TILEGRID writes Plane A starting at cell 0
(row 0 = lines 0-7). If Genesis screenshot shows plane A row 0 at
pixel 0, and NES screenshot shows nametable row 1 at pixel 0 (row 0
cropped), then to align: shift NES content DOWN 8 lines = drop top
row of NES nametable. But we WANT row 0 to compare too.

Resolution: shift Genesis DOWN 8 lines. Pad top of Genesis screenshot
with 8 black rows; compare against NES screenshot directly. NES row 0
is cropped; Genesis row 0 is below the visible NES area; no compare on
row 0. Subsequent rows (1+) align.

Better: just compare pixel-by-pixel at same (x, y) coordinates, accept
that NES row 0 (Genesis row 1) won't compare; report it as "out of
NES view". Genesis grid has 28 rows; NES grid has 28 rows (visible).
Both show rows 1..28 if Genesis offsets by 8 lines.

Cleanest: configure Genesis Plane A to render at line 8+ to match NES
crop. Or align in post-processing.

For V4 initial: PIL-shift Genesis screenshot UP by 8 rows when
comparing. Bottom 8 rows of Genesis get cropped (lose row 27);
top 8 rows of NES align with top 8 rows of Genesis.
"""
from __future__ import annotations

import json
import pathlib
import sys

try:
    from PIL import Image, ImageDraw, ImageChops
except ImportError:
    print("PIL/Pillow required: pip install Pillow")
    sys.exit(1)


REPO = pathlib.Path(__file__).resolve().parents[2]
NES_DIR = pathlib.Path("C:/tmp/chr_cycle_nes")
GEN_DIR = pathlib.Path("C:/tmp/chr_cycle_gen")
OUT_DIR = REPO / "docs" / "atlas" / "visual_diff"

CELL = 8
GRID_ROWS = 28          # visible rows (256x224 / 8)
GRID_COLS = 32

# Genesis screenshot needs to be shifted UP by NES_CROP_TOP rows to align
# with NES's 8-line top crop. Cell (r, c) at Genesis pixel ((r-1)*8, c*8)
# vs NES pixel ((r-1)*8, c*8) — both reference nametable row r (>= 1).
NES_CROP_TOP = 8


def align_genesis_to_nes(gen_img: Image.Image) -> Image.Image:
    """Shift Genesis screenshot up by NES_CROP_TOP rows; pad bottom with black."""
    w, h = gen_img.size
    out = Image.new("RGB", (w, h), (0, 0, 0))
    cropped = gen_img.crop((0, NES_CROP_TOP, w, h))
    out.paste(cropped, (0, 0))
    return out


def pixel_diff(nes_img: Image.Image, gen_img: Image.Image) -> tuple[Image.Image, int]:
    """Returns (diff_image, nonzero_pixel_count)."""
    diff = ImageChops.difference(nes_img, gen_img)
    # Saturate: any nonzero RGB delta becomes white in diff visualization
    bbox = diff.getbbox()
    if bbox is None:
        return diff, 0
    # Count nonzero pixels (RGB sum > 0)
    data = list(diff.getdata())
    count = sum(1 for r, g, b in data if r or g or b)
    return diff, count


def tile_diff(nes_img: Image.Image, gen_img: Image.Image) -> dict:
    """8x8 cell aggregation. Returns {cells: {(r,c): {diff_px, nes_mean_rgb, gen_mean_rgb}}}."""
    diff_cells = {}
    nes_px = nes_img.load()
    gen_px = gen_img.load()
    w, h = nes_img.size
    for r in range(min(GRID_ROWS, h // CELL)):
        for c in range(GRID_COLS):
            diff_count = 0
            for dy in range(CELL):
                for dx in range(CELL):
                    y = r * CELL + dy
                    x = c * CELL + dx
                    if x >= w or y >= h:
                        continue
                    if nes_px[x, y] != gen_px[x, y]:
                        diff_count += 1
            if diff_count > 0:
                diff_cells[f"{r},{c}"] = {"diff_px": diff_count}
    return diff_cells


def make_mosaic(nes_img: Image.Image, gen_img: Image.Image,
                diff_cells: dict) -> Image.Image:
    """NES | 16px gap | Genesis with red 1-px boxes around diff cells."""
    w, h = nes_img.size
    gap = 16
    mosaic = Image.new("RGB", (w * 2 + gap, h), (32, 32, 32))
    mosaic.paste(nes_img, (0, 0))
    mosaic.paste(gen_img, (w + gap, 0))

    draw = ImageDraw.Draw(mosaic)
    for cell_key in diff_cells:
        r, c = (int(x) for x in cell_key.split(","))
        # Box on both sides
        x0 = c * CELL
        y0 = r * CELL
        draw.rectangle([x0, y0, x0 + CELL - 1, y0 + CELL - 1],
                       outline=(255, 0, 0))
        x1 = w + gap + c * CELL
        draw.rectangle([x1, y0, x1 + CELL - 1, y0 + CELL - 1],
                       outline=(255, 0, 0))
    return mosaic


def state_labels():
    """Yield all state labels (8 banks × 4 sub_pals × 4 pages × 2 modes)."""
    for bank in range(8):
        for sub_pal in range(4):
            for page in range(4):
                for mode in range(2):
                    yield f"bank{bank}_sub{sub_pal}_page{page}_8x16{mode}"


def is_meaningful_diff_page(page: int) -> bool:
    """Pages 0 + 1 have NES mirrors; pages 2/3 are Genesis-only (skip)."""
    return page in (0, 1)


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "pixel_diff").mkdir(exist_ok=True)
    (OUT_DIR / "tile_diff").mkdir(exist_ok=True)
    (OUT_DIR / "mosaic").mkdir(exist_ok=True)

    summary = {
        "states_total": 0,
        "states_missing": 0,
        "states_skipped": 0,
        "states_clean": 0,
        "states_with_diff": 0,
        "diff_cells_by_state": {},
        "diff_cells_by_page": {0: 0, 1: 0},
    }

    for label in state_labels():
        summary["states_total"] += 1
        nes_path = NES_DIR / f"{label}.png"
        gen_path = GEN_DIR / f"{label}.png"
        if not nes_path.exists() or not gen_path.exists():
            summary["states_missing"] += 1
            continue
        page = int(label.split("page")[1].split("_")[0])
        if not is_meaningful_diff_page(page):
            summary["states_skipped"] += 1
            continue

        nes_img = Image.open(nes_path).convert("RGB")
        gen_img = Image.open(gen_path).convert("RGB")

        # Crop both to 256x224 if needed
        if nes_img.size != gen_img.size:
            w = min(nes_img.size[0], gen_img.size[0])
            h = min(nes_img.size[1], gen_img.size[1])
            nes_img = nes_img.crop((0, 0, w, h))
            gen_img = gen_img.crop((0, 0, w, h))

        # Align Genesis to NES crop (shift up 8 px)
        gen_aligned = align_genesis_to_nes(gen_img)

        # 1. Pixel diff
        diff_img, px_count = pixel_diff(nes_img, gen_aligned)
        diff_img.save(OUT_DIR / "pixel_diff" / f"{label}.png")

        # 2. Tile diff
        diff_cells = tile_diff(nes_img, gen_aligned)
        with (OUT_DIR / "tile_diff" / f"{label}.json").open("w") as f:
            json.dump({
                "state": label,
                "page": page,
                "px_diff_total": px_count,
                "diff_cell_count": len(diff_cells),
                "cells": diff_cells,
            }, f, indent=2)

        # 3. Mosaic
        mosaic = make_mosaic(nes_img, gen_aligned, diff_cells)
        mosaic.save(OUT_DIR / "mosaic" / f"{label}.png")

        if len(diff_cells) == 0:
            summary["states_clean"] += 1
        else:
            summary["states_with_diff"] += 1
            summary["diff_cells_by_state"][label] = len(diff_cells)
        summary["diff_cells_by_page"][page] = (
            summary["diff_cells_by_page"].get(page, 0) + len(diff_cells))

    # Top-level summary
    with (OUT_DIR / "summary.md").open("w") as f:
        f.write("# Visual Diff Summary\n\n")
        f.write(f"States total: {summary['states_total']}\n")
        f.write(f"  - Missing captures: {summary['states_missing']}\n")
        f.write(f"  - Skipped (Genesis-only pages 2/3): {summary['states_skipped']}\n")
        f.write(f"  - Clean (0 diff cells): {summary['states_clean']}\n")
        f.write(f"  - With diff: {summary['states_with_diff']}\n\n")
        f.write("## Diff cells per page\n\n")
        f.write("| Page | Diff cells |\n|---|---|\n")
        for page, n in sorted(summary["diff_cells_by_page"].items()):
            f.write(f"| {page} | {n} |\n")
        f.write("\n## States with diffs (top 20)\n\n")
        sorted_states = sorted(summary["diff_cells_by_state"].items(),
                               key=lambda kv: -kv[1])
        f.write("| State | Diff cells |\n|---|---|\n")
        for state, n in sorted_states[:20]:
            f.write(f"| {state} | {n} |\n")

    print(json.dumps(summary, indent=2, default=str))
    print(f"\nWrote outputs to {OUT_DIR}")


if __name__ == "__main__":
    sys.exit(main())
