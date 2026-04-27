#!/usr/bin/env python3
"""Read PNG sequence + compute mean brightness per frame to detect intro
phase transitions (fade-to-black, fade-from-black, content boundaries).

Output: phases.csv with frame, brightness, phase-classification.
"""
import sys
import re
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("pip install pillow", file=sys.stderr)
    sys.exit(2)

def main():
    if len(sys.argv) < 2:
        print("usage: analyze_phases.py <capture_dir>", file=sys.stderr)
        return 2
    d = Path(sys.argv[1])
    files = sorted(d.glob("*.png"))
    rows = []
    for f in files:
        m = re.search(r"f(\d+)\.png$", f.name)
        if not m:
            continue
        frame = int(m.group(1))
        img = Image.open(f).convert("L")
        # downsample for speed
        small = img.resize((32, 32))
        pixels = list(small.getdata())
        avg = sum(pixels) / len(pixels)
        rows.append((frame, avg))
    rows.sort()

    # Output CSV
    out = d.parent / (d.name + "_phases.csv")
    with open(out, "w") as fp:
        fp.write("frame,brightness\n")
        prev = None
        for f, b in rows:
            tag = ""
            if prev is not None:
                delta = b - prev
                if delta > 30: tag = "BRIGHTER"
                elif delta < -30: tag = "DARKER"
            fp.write(f"{f},{b:.1f},{tag}\n")
            prev = b
    print(f"wrote {out} ({len(rows)} frames)")

    # Also print summary: black runs, brightness peaks
    print("\n=== Transitions (delta > 20) ===")
    prev = None
    for f, b in rows:
        if prev is not None:
            d = b - prev
            if abs(d) > 20:
                print(f"  frame {f}: brightness {prev:.0f} -> {b:.0f} (delta {d:+.0f})")
        prev = b

    # Black-frame candidates (near solid black)
    print("\n=== Dark frames (b < 20) — fade-to-black or post-fade ===")
    in_dark = False
    dark_start = None
    for f, b in rows:
        if b < 20 and not in_dark:
            in_dark = True
            dark_start = f
        elif b >= 20 and in_dark:
            in_dark = False
            print(f"  dark range: {dark_start} - {f-5}")
    if in_dark:
        print(f"  dark range: {dark_start} - end")

if __name__ == "__main__":
    sys.exit(main() or 0)
