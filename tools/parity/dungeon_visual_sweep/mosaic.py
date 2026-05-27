"""Phase G6 — Aggregate visual mosaic.

Lays out all 56 captured PNGs into a single grid image so the user can
eyeball the entire sweep at once. Cave entries / dungeon entries /
dungeon exits each get their own section.

Usage: python mosaic.py [out.png]
"""
from __future__ import annotations

import json
import pathlib
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("PIL/Pillow required: pip install Pillow")
    sys.exit(2)


REPO = pathlib.Path(__file__).resolve().parents[3]
SCENARIOS = (
    REPO / "tools" / "parity" / "dungeon_visual_sweep" / "scenarios.json"
)
TMP = pathlib.Path(r"C:\tmp\g_sweep")
OUT_DEFAULT = (
    REPO / "tools" / "parity" / "dungeon_visual_sweep" / "mosaic.png"
)

TILE_W, TILE_H = 320, 224
GAP = 6
LABEL_H = 24
COLS = 6  # 6 per row → 10 rows max for 56 tiles


def load_png(sid: str) -> Image.Image:
    p = TMP / f"gen_{sid}.png"
    if not p.exists():
        # Look for status-suffixed
        for cand in TMP.glob(f"gen_{sid}*.png"):
            p = cand
            break
    if not p.exists():
        img = Image.new("RGB", (TILE_W, TILE_H), (40, 0, 0))
        d = ImageDraw.Draw(img)
        d.text((10, TILE_H // 2 - 6), "MISSING", fill=(255, 50, 50))
        return img
    img = Image.open(p).convert("RGB")
    if img.size != (TILE_W, TILE_H):
        img = img.resize((TILE_W, TILE_H))
    return img


def label_tile(img: Image.Image, label: str, status: str) -> Image.Image:
    out = Image.new("RGB", (TILE_W, TILE_H + LABEL_H), (20, 20, 20))
    out.paste(img, (0, LABEL_H))
    d = ImageDraw.Draw(out)
    color = (80, 255, 80) if status == "OK" else (255, 100, 100)
    d.text((4, 4), f"{label}  [{status}]", fill=color)
    return out


def make_mosaic(scs: list) -> Image.Image:
    rows = (len(scs) + COLS - 1) // COLS
    tile_with_label_h = TILE_H + LABEL_H
    canvas_w = COLS * TILE_W + (COLS + 1) * GAP
    canvas_h = rows * tile_with_label_h + (rows + 1) * GAP
    canvas = Image.new("RGB", (canvas_w, canvas_h), (8, 8, 12))

    for i, sc in enumerate(scs):
        r = i // COLS
        c = i % COLS
        sid = sc["id"]
        img = load_png(sid)
        # Determine status from filename suffix.
        status = "MISSING"
        if (TMP / f"gen_{sid}.bin").exists():
            status = "OK"
        else:
            for cand in TMP.glob(f"gen_{sid}_*.bin"):
                stem = cand.stem
                status = stem.split(sid + "_", 1)[1] if sid + "_" in stem else "?"
                break
        tile = label_tile(img, sid, status)
        x = GAP + c * (TILE_W + GAP)
        y = GAP + r * (tile_with_label_h + GAP)
        canvas.paste(tile, (x, y))

    return canvas


def main(argv):
    out_path = pathlib.Path(argv[1]) if len(argv) > 1 else OUT_DEFAULT
    scs = json.loads(SCENARIOS.read_text(encoding="utf-8"))["scenarios"]
    mosaic = make_mosaic(scs)
    mosaic.save(out_path)
    print(f"Mosaic: {out_path}  ({mosaic.size[0]}x{mosaic.size[1]})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
