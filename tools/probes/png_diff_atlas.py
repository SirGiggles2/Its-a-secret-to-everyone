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


def quantize_3bit(img: Image.Image) -> Image.Image:
    """Drop low 5 bits per channel — keep only top 3 bits (Genesis CRAM
    precision). NES 6-bit master palette gets crushed to same precision so
    diff isn't dominated by quantization-noise. Both screenshots quantized
    the same way; remaining diff = real routing/atlas divergence."""
    w, h = img.size
    out = Image.new("RGB", (w, h))
    src = img.load()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b = src[x, y][:3]
            dst[x, y] = (r & 0xE0, g & 0xE0, b & 0xE0)
    return out


# Canonical 2C02 NES master palette — used to reverse-lookup NES screenshot
# pixel back to NES color index. Same table as scene_walk_diff.py.
NES_MASTER = [
    (0x62,0x62,0x62),(0x00,0x1F,0xB2),(0x24,0x04,0xC8),(0x52,0x00,0xB2),
    (0x73,0x00,0x76),(0x80,0x00,0x24),(0x73,0x0B,0x00),(0x52,0x28,0x00),
    (0x24,0x44,0x00),(0x00,0x57,0x00),(0x00,0x5C,0x00),(0x00,0x53,0x24),
    (0x00,0x3C,0x76),(0x00,0x00,0x00),(0x00,0x00,0x00),(0x00,0x00,0x00),
    (0xAB,0xAB,0xAB),(0x0D,0x57,0xFF),(0x4B,0x30,0xFF),(0x8A,0x13,0xFF),
    (0xBC,0x08,0xD6),(0xD2,0x12,0x69),(0xC7,0x2E,0x00),(0x9D,0x54,0x00),
    (0x60,0x7B,0x00),(0x20,0x98,0x00),(0x00,0xA3,0x00),(0x00,0x99,0x42),
    (0x00,0x7D,0xB4),(0x00,0x00,0x00),(0x00,0x00,0x00),(0x00,0x00,0x00),
    (0xFF,0xFF,0xFF),(0x53,0xAE,0xFF),(0x90,0x85,0xFF),(0xD3,0x65,0xFF),
    (0xFF,0x57,0xFF),(0xFF,0x5D,0xCF),(0xFF,0x77,0x57),(0xFA,0x9E,0x00),
    (0xBD,0xC7,0x00),(0x7A,0xE7,0x00),(0x43,0xF6,0x11),(0x26,0xEF,0x7E),
    (0x2C,0xD5,0xF6),(0x4E,0x4E,0x4E),(0x00,0x00,0x00),(0x00,0x00,0x00),
    (0xFF,0xFF,0xFF),(0xB6,0xE1,0xFF),(0xCE,0xD1,0xFF),(0xE9,0xC3,0xFF),
    (0xFF,0xBC,0xFF),(0xFF,0xBD,0xF4),(0xFF,0xC6,0xC3),(0xFF,0xD5,0x9A),
    (0xE9,0xE6,0x81),(0xCE,0xF4,0x81),(0xB6,0xFB,0x9A),(0xA9,0xFA,0xC3),
    (0xA9,0xF0,0xF4),(0xB8,0xB8,0xB8),(0x00,0x00,0x00),(0x00,0x00,0x00),
]


def _load_misc_palettes_lut() -> list[tuple[int, int, int]]:
    """Load port's misc_palettes table -> Genesis-quantized RGB per NES index.
    Returns list[64] of (R, G, B) 8-bit values as BizHawk Genesis would render."""
    pal_path = REPO / "data" / "misc" / "palettes.c"
    import re
    text = pal_path.read_text(encoding="utf-8", errors="ignore")
    m = re.search(
        r"const\s+unsigned\s+char\s+misc_palettes\[\s*[A-Za-z0-9_]+\s*\]\s*"
        r"(?:[^=]*?)=\s*\{(.*?)\}\s*;",
        text, re.DOTALL)
    raw = bytes(int(t.group(1), 16) for t in re.finditer(r"0x([0-9A-Fa-f]{1,2})", m.group(1)))
    lut = []
    for i in range(64):
        # LE word in C array: low byte first
        word = raw[i * 2] | (raw[i * 2 + 1] << 8)
        # Genesis CRAM 9-bit format: 0BBB GGGR RR0 ; per channel even nibble
        b3 = (word >> 9) & 0x7
        g3 = (word >> 5) & 0x7
        r3 = (word >> 1) & 0x7
        # BizHawk Genesis renders by replicating top bits — same as my 3-bit
        # scale to 8-bit: val_8 = (val_3 << 5) | (val_3 << 2) | (val_3 >> 1)
        def expand(v3):
            return (v3 << 5) | (v3 << 2) | (v3 >> 1)
        lut.append((expand(r3), expand(g3), expand(b3)))
    return lut


def _nes_to_idx(px: tuple[int, int, int]) -> int:
    """Find closest NES master palette index for a pixel."""
    pr, pg, pb = px
    best_i = 0
    best_d = 1 << 30
    for i, (r, g, b) in enumerate(NES_MASTER):
        d = (pr - r) ** 2 + (pg - g) ** 2 + (pb - b) ** 2
        if d < best_d:
            best_d = d
            best_i = i
    return best_i


def _gen_to_idx(px: tuple[int, int, int], misc_lut) -> int:
    """Find closest NES master index that the port's misc_palettes maps to
    a color near px. I.e. reverse the misc_palettes lookup."""
    pr, pg, pb = px
    best_i = 0
    best_d = 1 << 30
    for i, (r, g, b) in enumerate(misc_lut):
        d = (pr - r) ** 2 + (pg - g) ** 2 + (pb - b) ** 2
        if d < best_d:
            best_d = d
            best_i = i
    return best_i


def logical_color_diff(nes_img: Image.Image, gen_img: Image.Image,
                       misc_lut) -> tuple[Image.Image, dict]:
    """Diff that reverse-quantizes each pixel back to NES master palette
    index and compares INDICES, not RGB. NES side via NES master directly;
    Genesis side via reverse-lookup in port's misc_palettes table.

    Same logical color (e.g. NES master $00) renders as different RGB on
    NES (0x62 0x62 0x62) vs Genesis (0x88 0x88 0x88), but both map back
    to index $00 — so logical diff = 0.

    Real diff (palette routing, atlas drift): logical indices differ.

    Returns (visualization image, totals dict)."""
    w, h = nes_img.size
    out = Image.new("RGB", (w, h), (0, 0, 0))
    out_px = out.load()
    nes_px = nes_img.load()
    gen_px = gen_img.load()
    diff_total = 0
    by_cell = {}

    for r in range(min(GRID_ROWS, h // CELL)):
        for c in range(GRID_COLS):
            cell_diff = 0
            cell_nes_nz = 0
            cell_gen_nz = 0
            for dy in range(CELL):
                for dx in range(CELL):
                    y = r * CELL + dy
                    x = c * CELL + dx
                    if x >= w or y >= h:
                        continue
                    npx = nes_px[x, y]
                    gpx = gen_px[x, y]
                    nidx = _nes_to_idx(npx)
                    gidx = _gen_to_idx(gpx, misc_lut)
                    # Treat indices as logically-equivalent if BOTH map to
                    # NES master (0,0,0) — there are 12 black entries
                    # (0D/0E/0F/1D/1E/1F/...). Same logical color.
                    n_black = (NES_MASTER[nidx] == (0, 0, 0))
                    g_black = (misc_lut[gidx] == (0, 0, 0))
                    if (nidx != gidx) and not (n_black and g_black):
                        cell_diff += 1
                        out_px[x, y] = (255, 0, 0)
                    if not n_black:
                        cell_nes_nz += 1
                    if not g_black:
                        cell_gen_nz += 1
            if cell_diff > 0:
                # Classify same as RGB tile_diff but with logical-color
                # nz semantics (treat NES "black master indices" as nz=0).
                if cell_gen_nz == 0 and cell_nes_nz > 0:
                    cat = "SPARSE_BLANK"
                elif cell_nes_nz == 0 and cell_gen_nz > 0:
                    cat = "COVERAGE_GAP"
                else:
                    cat = "REAL_DIFF"
                by_cell[f"{r},{c}"] = {"diff_px": cell_diff, "category": cat}
                diff_total += cell_diff

    totals = {"REAL_DIFF": 0, "SPARSE_BLANK": 0, "COVERAGE_GAP": 0}
    for v in by_cell.values():
        totals[v["category"]] += 1
    return out, {"cells": by_cell, "totals": totals, "px_diff_total": diff_total}


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
    """8x8 cell aggregation with classification.

    Per cell, count:
      - diff_px: total pixels where nes != gen
      - nes_nz_px: pixels where NES is non-black
      - gen_nz_px: pixels where Genesis is non-black

    Categorize:
      - CLEAN        : both render same pixels (diff_px == 0)
      - SPARSE_BLANK : Genesis renders blank (gen_nz_px == 0) but NES has
                       content — sparse atlas LUT excludes unused tile_id
                       by design. Not a bug.
      - COVERAGE_GAP : NES blank but Genesis has content — anomaly to
                       investigate (Genesis shows tile NES doesn't have).
      - REAL_DIFF    : both have content but pixels differ — real bug or
                       palette routing mismatch.

    Returns {cells: {"r,c": {diff_px, nes_nz, gen_nz, category}}, totals}."""
    nes_px = nes_img.load()
    gen_px = gen_img.load()
    w, h = nes_img.size

    cells = {}
    totals = {"CLEAN": 0, "SPARSE_BLANK": 0, "COVERAGE_GAP": 0, "REAL_DIFF": 0}

    for r in range(min(GRID_ROWS, h // CELL)):
        for c in range(GRID_COLS):
            diff_count = 0
            nes_nz = 0
            gen_nz = 0
            for dy in range(CELL):
                for dx in range(CELL):
                    y = r * CELL + dy
                    x = c * CELL + dx
                    if x >= w or y >= h:
                        continue
                    npx = nes_px[x, y]
                    gpx = gen_px[x, y]
                    if npx != gpx:
                        diff_count += 1
                    if npx != (0, 0, 0):
                        nes_nz += 1
                    if gpx != (0, 0, 0):
                        gen_nz += 1

            if diff_count == 0:
                category = "CLEAN"
            elif gen_nz == 0 and nes_nz > 0:
                category = "SPARSE_BLANK"
            elif nes_nz == 0 and gen_nz > 0:
                category = "COVERAGE_GAP"
            else:
                category = "REAL_DIFF"

            totals[category] += 1
            if category != "CLEAN":
                cells[f"{r},{c}"] = {
                    "diff_px": diff_count,
                    "nes_nz": nes_nz,
                    "gen_nz": gen_nz,
                    "category": category,
                }
    return {"cells": cells, "totals": totals}


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
    (OUT_DIR / "logical_diff").mkdir(exist_ok=True)

    misc_lut = _load_misc_palettes_lut()

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

        # Quantize both to 3-bit channels (Genesis CRAM precision) so the
        # diff filters out NES 6-bit → Genesis 3-bit master palette noise.
        nes_q = quantize_3bit(nes_img)
        gen_q = quantize_3bit(gen_aligned)

        # 1. Pixel diff (quantized)
        diff_img, px_count = pixel_diff(nes_q, gen_q)
        diff_img.save(OUT_DIR / "pixel_diff" / f"{label}.png")

        # 2. Tile diff with classification (quantized)
        td = tile_diff(nes_q, gen_q)
        diff_cells = td["cells"]
        totals = td["totals"]
        with (OUT_DIR / "tile_diff" / f"{label}.json").open("w") as f:
            json.dump({
                "state": label,
                "page": page,
                "px_diff_total": px_count,
                "totals": totals,
                "cells": diff_cells,
            }, f, indent=2)

        # 3. Mosaic — highlight REAL_DIFF cells only (not sparse-blank noise)
        real_diff_cells = {k: v for k, v in diff_cells.items()
                           if v["category"] == "REAL_DIFF"}
        mosaic = make_mosaic(nes_img, gen_aligned, real_diff_cells)
        mosaic.save(OUT_DIR / "mosaic" / f"{label}.png")

        # 4. LOGICAL-color diff (reverse-quantize to NES master index;
        #    catches palette routing without quant noise)
        logical_img, logical_data = logical_color_diff(nes_img, gen_aligned, misc_lut)
        logical_img.save(OUT_DIR / "logical_diff" / f"{label}.png")
        for cat, n in logical_data["totals"].items():
            key = "logical_totals_" + cat
            summary[key] = summary.get(key, 0) + n

        real_diff_count = logical_data["totals"]["REAL_DIFF"]
        if real_diff_count == 0:
            summary["states_clean"] += 1
        else:
            summary["states_with_diff"] += 1
            summary["diff_cells_by_state"][label] = real_diff_count
        summary["diff_cells_by_page"][page] = (
            summary["diff_cells_by_page"].get(page, 0) + real_diff_count)
        for cat, n in totals.items():
            key = "totals_" + cat
            summary[key] = summary.get(key, 0) + n

    # Top-level summary
    with (OUT_DIR / "summary.md").open("w") as f:
        f.write("# Visual Diff Summary\n\n")
        f.write(f"States total: {summary['states_total']}\n")
        f.write(f"  - Missing captures: {summary['states_missing']}\n")
        f.write(f"  - Skipped (Genesis-only pages 2/3): {summary['states_skipped']}\n")
        f.write(f"  - Clean (0 REAL_DIFF cells): {summary['states_clean']}\n")
        f.write(f"  - With REAL_DIFF: {summary['states_with_diff']}\n\n")
        f.write("## Cell category totals (across all audited states)\n\n")
        f.write("| Category | Cells |\n|---|---|\n")
        for cat in ("CLEAN", "REAL_DIFF", "SPARSE_BLANK", "COVERAGE_GAP"):
            f.write(f"| {cat} | {summary.get('totals_' + cat, 0)} |\n")
        f.write("\nCategory meanings:\n")
        f.write("- CLEAN: NES + Genesis identical (after 3-bit quantize + alignment).\n")
        f.write("- REAL_DIFF: both render content but pixels differ. Likely "
                "palette routing, atlas drift, or alignment slip — investigate.\n")
        f.write("- SPARSE_BLANK: Genesis renders blank; NES has content. "
                "Expected: bg_sparse_tile_lut deliberately excludes "
                "unused tile_ids (VRAM headroom design).\n")
        f.write("- COVERAGE_GAP: NES blank; Genesis has content. Anomalous "
                "— Genesis shows tile NES doesn't.\n\n")
        f.write("## REAL_DIFF cells per page\n\n")
        f.write("| Page | REAL_DIFF cells |\n|---|---|\n")
        for page, n in sorted(summary["diff_cells_by_page"].items()):
            f.write(f"| {page} | {n} |\n")
        f.write("\n## States with REAL_DIFF (top 20)\n\n")
        sorted_states = sorted(summary["diff_cells_by_state"].items(),
                               key=lambda kv: -kv[1])
        f.write("| State | REAL_DIFF cells |\n|---|---|\n")
        for state, n in sorted_states[:20]:
            f.write(f"| {state} | {n} |\n")

    print(json.dumps(summary, indent=2, default=str))
    print(f"\nWrote outputs to {OUT_DIR}")


if __name__ == "__main__":
    sys.exit(main())
