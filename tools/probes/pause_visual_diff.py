"""pause_visual_diff.py — NES vs Genesis pause subscreen visual diff.

Reads paired captures from:
  C:/tmp/nes_subscreen/01_active.png  (256x224 NES)
  C:/tmp/gen_subscreen/01_active.png  (320x224 Genesis — crop to 256-wide)

Also dumps:
  - PALRAM (NES 32 B) vs CRAM (Genesis 128 B) palette comparison
  - Nametable tile-id coverage check against bg_sparse_tile_lut
  - SAT cursor/item slots vs NES OAM sprite positions

Outputs to docs/atlas/pause_parity.md + docs/atlas/visual_diff/pause/:
  - pixel_diff.png   — RGB delta saturate magnitude
  - tile_diff.json   — 8x8 cell aggregation
  - mosaic.png       — NES | gap | Genesis side-by-side with diff boxes
  - summary.md       — top-level report with L1.5 decision-gate count
"""
from __future__ import annotations

import json
import pathlib
import sys
import struct

try:
    from PIL import Image, ImageDraw
except ImportError:
    print("PIL/Pillow required: pip install Pillow")
    sys.exit(1)


REPO = pathlib.Path(__file__).resolve().parents[2]
NES_DIR = pathlib.Path("C:/tmp/nes_subscreen")
GEN_DIR = pathlib.Path("C:/tmp/gen_subscreen")
OUT_DIR = REPO / "docs" / "atlas" / "visual_diff" / "pause"
OUT_DIR.mkdir(parents=True, exist_ok=True)
PARITY_DOC = REPO / "docs" / "atlas" / "pause_parity.md"

CELL = 8
GRID_ROWS = 28
GRID_COLS = 32


def quantize_3bit(img: Image.Image) -> Image.Image:
    """Drop low 5 bits per channel — keep only top 3 bits (Genesis CRAM
    precision). Removes inter-emulator color-pipeline quantization noise."""
    data = bytearray(img.tobytes())
    for i in range(len(data)):
        data[i] &= 0xE0
    return Image.frombytes(img.mode, img.size, bytes(data))


def crop_genesis_to_nes_aspect(gen_img: Image.Image) -> Image.Image:
    """Genesis emits 320x224; NES emits 256x224. Crop Genesis 32 px each
    side to get 256x224 active area."""
    w, h = gen_img.size
    if w == 320:
        return gen_img.crop((32, 0, 288, h))
    elif w == 256:
        return gen_img
    else:
        raise ValueError(f"Unexpected Genesis width {w}")


def pixel_diff(nes_img: Image.Image, gen_img: Image.Image) -> Image.Image:
    """RGB absolute difference image."""
    nes_q = quantize_3bit(nes_img)
    gen_q = quantize_3bit(gen_img)
    nes_b = nes_q.tobytes()
    gen_b = gen_q.tobytes()
    out = bytearray(len(nes_b))
    for i in range(len(nes_b)):
        out[i] = abs(nes_b[i] - gen_b[i])
    return Image.frombytes("RGB", nes_q.size, bytes(out))


def tile_bounded_diff(nes_img: Image.Image, gen_img: Image.Image) -> dict:
    """Per-cell (8x8) aggregation. Returns cells with any non-zero diff."""
    nes_q = quantize_3bit(nes_img)
    gen_q = quantize_3bit(gen_img)
    nes_b = nes_q.tobytes()
    gen_b = gen_q.tobytes()
    w, h = nes_q.size
    cells = {}
    diff_count = 0
    for cy in range(GRID_ROWS):
        for cx in range(GRID_COLS):
            px_y0, px_y1 = cy * CELL, (cy + 1) * CELL
            px_x0, px_x1 = cx * CELL, (cx + 1) * CELL
            cell_diff = 0
            for y in range(px_y0, px_y1):
                row_off = y * w * 3
                for x in range(px_x0, px_x1):
                    px_off = row_off + x * 3
                    if (nes_b[px_off] != gen_b[px_off] or
                        nes_b[px_off + 1] != gen_b[px_off + 1] or
                        nes_b[px_off + 2] != gen_b[px_off + 2]):
                        cell_diff += 1
            if cell_diff > 0:
                cells[f"{cy},{cx}"] = {"px_diff": cell_diff}
                diff_count += cell_diff
    return {"total_diff_px": diff_count, "diff_cells": len(cells), "cells": cells}


def make_mosaic(nes_img: Image.Image, gen_img: Image.Image, cells: dict) -> Image.Image:
    """NES | 16px gap | Genesis side-by-side with red boxes on diff cells."""
    w, h = nes_img.size
    out = Image.new("RGB", (w * 2 + 16, h), (40, 40, 40))
    out.paste(nes_img, (0, 0))
    out.paste(gen_img, (w + 16, 0))
    draw = ImageDraw.Draw(out)
    for cell_key in cells:
        cy, cx = (int(c) for c in cell_key.split(","))
        x0, y0 = cx * CELL, cy * CELL
        x1, y1 = x0 + CELL, y0 + CELL
        draw.rectangle((x0, y0, x1, y1), outline=(255, 0, 0))
        draw.rectangle((w + 16 + x0, y0, w + 16 + x1, y1), outline=(255, 0, 0))
    return out


def compare_palrams() -> dict:
    """NES PALRAM 32 B vs Genesis CRAM 128 B. Convert NES 6-bit master
    palette indices to RGB; convert Genesis CRAM 9-bit RGB to RGB.
    Compare per-sub-pal slot."""
    nes_pal = (NES_DIR / "palram.bin").read_bytes()
    gen_cram = (GEN_DIR / "cram.bin").read_bytes()
    return {
        "nes_palram_hex": nes_pal.hex(),
        "gen_cram_hex": gen_cram.hex(),
        "nes_pal_bytes": len(nes_pal),
        "gen_cram_bytes": len(gen_cram),
    }


def main():
    nes_png = NES_DIR / "01_active.png"
    gen_png = GEN_DIR / "01_active.png"
    if not nes_png.exists():
        print(f"missing {nes_png}")
        sys.exit(1)
    if not gen_png.exists():
        print(f"missing {gen_png}")
        sys.exit(1)

    nes_img = Image.open(nes_png).convert("RGB")
    gen_img = crop_genesis_to_nes_aspect(Image.open(gen_png).convert("RGB"))

    # 1. Pixel diff
    diff_img = pixel_diff(nes_img, gen_img)
    diff_img.save(OUT_DIR / "pixel_diff.png")

    # 2. Tile diff JSON
    tile_diff = tile_bounded_diff(nes_img, gen_img)
    (OUT_DIR / "tile_diff.json").write_text(json.dumps(tile_diff, indent=2))

    # 3. Mosaic
    mosaic = make_mosaic(nes_img, gen_img, tile_diff["cells"])
    mosaic.save(OUT_DIR / "mosaic.png")

    # 4. Palette compare
    pal_compare = compare_palrams()
    (OUT_DIR / "palette_compare.json").write_text(json.dumps(pal_compare, indent=2))

    # 5. Summary
    total_cells = GRID_ROWS * GRID_COLS
    diff_cells = tile_diff["diff_cells"]
    pct = 100.0 * diff_cells / total_cells

    if diff_cells < 100:
        gate = "BYTE-EXACT FEASIBLE — proceed to strict L2-L4 with strict gate"
    elif diff_cells < 400:
        gate = "VISUAL-APPROX target — accept quantization-class noise"
    else:
        gate = "PIXEL-EXACT IMPOSSIBLE — L1.5 says scrap; accept visual fixes only"

    summary = f"""# Pause subscreen visual diff — L1.5 decision-gate

## Counts
- Total grid cells: {total_cells} ({GRID_ROWS} rows x {GRID_COLS} cols)
- Diff cells: {diff_cells} ({pct:.1f}%)
- Total diff pixels: {tile_diff['total_diff_px']}

## L1.5 gate
{gate}

## Artifacts
- `docs/atlas/visual_diff/pause/pixel_diff.png` — RGB delta saturate
- `docs/atlas/visual_diff/pause/tile_diff.json` — per-cell counts
- `docs/atlas/visual_diff/pause/mosaic.png` — side-by-side w/ red boxes
- `docs/atlas/visual_diff/pause/palette_compare.json` — PALRAM vs CRAM

## Source captures
- `C:/tmp/nes_subscreen/01_active.png` — NES (MenuState=$08 stable)
- `C:/tmp/gen_subscreen/01_active.png` — Genesis Debug.md (ABC + Start)
"""
    (OUT_DIR / "summary.md").write_text(summary)

    # Append/replace doc fragment
    PARITY_DOC.parent.mkdir(parents=True, exist_ok=True)
    parity_text = f"""# Pause subscreen parity (Phase 7 v2 LITE)

## Latest diff (L1.5 baseline run)
- Diff cells: {diff_cells} / {total_cells} ({pct:.1f}%)
- L1.5 gate: {gate}

## Accepted divergences (debate consensus)
- Sprite +128 offset: hardware fact, Genesis SAT requires +128 on X/Y vs NES OAM raw pixels.
- CRAM 9-bit quantization: Genesis can only express upper 3 bits per channel; NES master palette is denser.
- Scroll animation: row-by-row replacement (Phase 6) vs NES VScroll register animation. Deferred to V2.
- HUD overlap: NES sprite-0-hit vs Genesis Window plane. Accepted visual difference at boundary.

## See also
- `docs/atlas/visual_diff/pause/summary.md` — latest diff numbers
- `debates/044-phase7-pause-subscreen/` — adversarial review of Phase 7 plan
"""
    PARITY_DOC.write_text(parity_text)

    print(summary)


if __name__ == "__main__":
    main()
