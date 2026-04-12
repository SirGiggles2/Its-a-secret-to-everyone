#!/usr/bin/env python
"""compare_fs_screenshots.py

Compare NES Zelda vs Genesis port File Select screenshots pixel-by-pixel.

Inputs (current working dir or builds/reports/):
    fs1_nes.png  fs1_gen.png
    fs2_nes.png  fs2_gen.png

Strategy:
  - NES native resolution: 256x240
  - Genesis port resolution: typically 256x224 (H32) or 320x224 (H40)
  - Crop both to a common 256x224 core (drop NES top 8 + bottom 8
    rows, which are traditionally overscan-blanked by Zelda on NES)
  - Compare pixel-by-pixel. A pixel is "different" if the maximum
    per-channel RGB distance exceeds THRESHOLD (default 16).
  - Cluster differing pixels into 8x8 cells (sprite/tile aligned) and
    report cells with >= 4 differing pixels as "interesting".
  - Write an overlay PNG highlighting differences in red, for each
    screen.
  - Write a text report with per-cell summary.

Output:
    builds/reports/fs_compare_report.txt
    builds/reports/fs1_diff.png
    builds/reports/fs2_diff.png
"""
from __future__ import annotations
import os
import sys
from PIL import Image, ImageDraw

THRESHOLD = 24           # per-channel RGB distance; lower = stricter
CELL_SIZE = 8            # group diffs into 8x8 cells
CELL_DIFF_MIN = 2        # a cell is "interesting" if >= N pixels differ

ROOT = r"C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY\.claude\worktrees\nifty-chandrasekhar"
OUT_DIR = os.path.join(ROOT, "builds", "reports")
REPORT = os.path.join(OUT_DIR, "fs_compare_report.txt")

CANDIDATE_DIRS = [
    os.path.join(ROOT, "builds", "reports"),
    ROOT,
    os.path.join(ROOT, "tools"),
    r"C:\Users\Jake Diggity\Documents\GitHub\VDP rebirth tools and asms\BizHawk-2.11-win-x64",
    os.getcwd(),
]


def find_png(name):
    for d in CANDIDATE_DIRS:
        p = os.path.join(d, name)
        if os.path.exists(p):
            return p
    raise FileNotFoundError(f"could not locate {name} in: {CANDIDATE_DIRS}")


def load_core(path):
    """Load a PNG, crop to 256x224 centered."""
    img = Image.open(path).convert("RGB")
    w, h = img.size
    # Handle NES (256x240): drop top 8 + bottom 8 to get 256x224
    if (w, h) == (256, 240):
        img = img.crop((0, 8, 256, 232))
    elif (w, h) == (256, 224):
        pass  # already core
    elif (w, h) == (320, 224):
        # Gen H40: center-crop to 256x224
        img = img.crop((32, 0, 288, 224))
    elif (w, h) == (320, 240):
        img = img.crop((32, 8, 288, 232))
    else:
        # Generic: center-crop
        cx = (w - 256) // 2
        cy = (h - 224) // 2
        if cx < 0 or cy < 0:
            raise ValueError(f"{path} too small: {w}x{h}")
        img = img.crop((cx, cy, cx + 256, cy + 224))
    return img


def pixel_diff(a, b, threshold=THRESHOLD):
    """Return True if pixels differ beyond threshold (max channel distance)."""
    return (abs(a[0] - b[0]) > threshold
            or abs(a[1] - b[1]) > threshold
            or abs(a[2] - b[2]) > threshold)


def compare(nes_img, gen_img, tag, report_lines):
    nes = nes_img.load()
    gen = gen_img.load()
    W, H = 256, 224

    # Pixel-level diff mask
    diff_count = 0
    cell_diffs = {}  # (cx, cy) -> count of diff pixels
    cell_samples = {}  # (cx, cy) -> [(x, y, nes_rgb, gen_rgb), ...] up to 3

    diff_img = gen_img.copy()
    dd = diff_img.load()

    for y in range(H):
        for x in range(W):
            n = nes[x, y]
            g = gen[x, y]
            if pixel_diff(n, g):
                diff_count += 1
                cx, cy = x // CELL_SIZE, y // CELL_SIZE
                cell_diffs[(cx, cy)] = cell_diffs.get((cx, cy), 0) + 1
                lst = cell_samples.setdefault((cx, cy), [])
                if len(lst) < 3:
                    lst.append((x, y, n, g))
                # Highlight diff in red overlay
                dd[x, y] = (255, 0, 0)

    total_px = W * H
    pct = 100.0 * diff_count / total_px

    report_lines.append("")
    report_lines.append(f"===== {tag.upper()} =====")
    report_lines.append(f"  resolution:       {W}x{H} core")
    report_lines.append(f"  diff pixels:      {diff_count}/{total_px} ({pct:.2f}%)")
    report_lines.append(f"  threshold:        per-channel > {THRESHOLD}")
    report_lines.append(f"  interesting cells (>= {CELL_DIFF_MIN} pixels diff):")

    # Sort cells by diff count desc, then by row, col
    interesting = [(cnt, pos) for pos, cnt in cell_diffs.items() if cnt >= CELL_DIFF_MIN]
    interesting.sort(key=lambda x: (-x[0], x[1][1], x[1][0]))

    report_lines.append(f"  total interesting cells: {len(interesting)}")

    # Group by row first for a readable map
    cells_by_row = {}
    for cnt, (cx, cy) in interesting:
        cells_by_row.setdefault(cy, []).append((cx, cnt))
    for cy in sorted(cells_by_row.keys()):
        cells = cells_by_row[cy]
        cells.sort()
        screen_y = cy * CELL_SIZE
        row = f"    row {cy:02d} (screen_y={screen_y:3d}): "
        row += " ".join(f"col{cx:02d}(x={cx*CELL_SIZE:3d},n={cnt})"
                        for cx, cnt in cells[:8])
        if len(cells) > 8:
            row += f"  +{len(cells)-8} more"
        report_lines.append(row)

    # Top-20 cells with sample pixel values
    report_lines.append("")
    report_lines.append("  top-20 cells with sample diffs (x,y  NES_rgb  GEN_rgb):")
    for cnt, pos in interesting[:20]:
        cx, cy = pos
        samples = cell_samples[(cx, cy)]
        report_lines.append(
            f"    cell ({cx:2d},{cy:2d}) @ screen ({cx*CELL_SIZE:3d},{cy*CELL_SIZE:3d}) "
            f"diff={cnt}:")
        for x, y, n, g in samples:
            report_lines.append(
                f"        ({x:3d},{y:3d}) NES=#{n[0]:02X}{n[1]:02X}{n[2]:02X} "
                f"GEN=#{g[0]:02X}{g[1]:02X}{g[2]:02X}")

    # Save side-by-side diff image
    combined = Image.new("RGB", (W*3 + 6, H), (32, 32, 32))
    combined.paste(nes_img, (0, 0))
    combined.paste(gen_img, (W+3, 0))
    combined.paste(diff_img, (W*2+6, 0))
    out_path = os.path.join(OUT_DIR, f"{tag}_compare.png")
    combined.save(out_path)
    report_lines.append(f"  saved compare image: {out_path}")

    return diff_count, interesting


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    lines = []
    lines.append("=== FS Screenshot Compare Report ===")
    lines.append(f"threshold={THRESHOLD}  cell={CELL_SIZE}  cell_min={CELL_DIFF_MIN}")

    for tag in ("fs1", "fs2"):
        try:
            nes_path = find_png(f"{tag}_nes.png")
            gen_path = find_png(f"{tag}_gen.png")
        except FileNotFoundError as e:
            lines.append(f"ERROR: {e}")
            continue
        lines.append("")
        lines.append(f"NES source: {nes_path}")
        lines.append(f"GEN source: {gen_path}")
        nes = load_core(nes_path)
        gen = load_core(gen_path)
        compare(nes, gen, tag, lines)

    with open(REPORT, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"wrote {REPORT}")


if __name__ == "__main__":
    main()
