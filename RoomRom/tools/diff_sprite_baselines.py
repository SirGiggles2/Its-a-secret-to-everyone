#!/usr/bin/env python3
"""Pre/post sprite-expansion baseline diff.

Reports per-file: SAME (no change), SHAPE_SAME_COLOR_DIFF (sprite
silhouette identical, color palette differs - expected for bomb /
explosion / sword-with-level), or DIFFERENT (pixel positions
diverge unexpectedly).

Run: python RoomRom/tools/diff_sprite_baselines.py

Exits 0 if all files are SAME or SHAPE_SAME_COLOR_DIFF, else 1.
"""
import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Pillow not available; falling back to byte-compare", file=sys.stderr)
    Image = None

ROOT = Path(__file__).resolve().parents[2]
PRE = ROOT / "RoomRom" / "out" / "baselines" / "pre_sprite_expansion"
POST = ROOT / "RoomRom" / "out" / "baselines" / "post_sprite_expansion"

# A pixel is "background" when its RGB is the dominant scene background
# (typically a teal UW dungeon wall or a dark backdrop). We approximate
# silhouette by treating any pixel matching the most-common pixel as bg.
def _pixels(im):
    """Return flat list of RGBA tuples, compatible across Pillow versions."""
    try:
        return list(im.get_flattened_data())  # Pillow 14+
    except AttributeError:
        return list(im.getdata())             # Pillow <14


def silhouette(im):
    """Return list-of-lists of bools: True where pixel != most-common."""
    from collections import Counter
    px = _pixels(im)
    bg = Counter(px).most_common(1)[0][0]
    w, h = im.width, im.height
    return [
        [px[y * w + x] != bg for x in range(w)]
        for y in range(h)
    ]


def diff_pair(pre_path, post_path):
    if Image is None:
        # byte-compare fallback
        a = pre_path.read_bytes()
        b = post_path.read_bytes()
        return "SAME" if a == b else "DIFFERENT"
    a = Image.open(pre_path).convert("RGBA")
    b = Image.open(post_path).convert("RGBA")
    if _pixels(a) == _pixels(b):
        return "SAME"
    if silhouette(a) == silhouette(b):
        return "SHAPE_SAME_COLOR_DIFF"
    return "DIFFERENT"


def main():
    fails = 0
    for pre in sorted(PRE.glob("*.png")):
        post = POST / pre.name
        if not post.exists():
            print(f"MISSING POST: {pre.name}")
            fails += 1
            continue
        verdict = diff_pair(pre, post)
        print(f"{verdict}: {pre.name}")
        if verdict == "DIFFERENT":
            fails += 1
    if fails:
        print(f"\n{fails} unexpected diff(s)", file=sys.stderr)
        return 1
    print("\nall pre/post pairs explained (SAME or SHAPE_SAME_COLOR_DIFF)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
