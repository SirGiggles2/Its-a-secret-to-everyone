"""Compare NES vs Genesis item scroll captures frame-by-frame.

Matches frames by game state (curV, textIndex, itemRow) and reports
per-item mismatch statistics plus side-by-side screenshots of worst frames.
"""
from __future__ import annotations
import csv, sys
from pathlib import Path
from PIL import Image
import numpy as np

ROOT = Path(r"C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY")
NES_DIR = ROOT / "builds" / "reports" / "items_seq_nes_fresh"
GEN_DIR = ROOT / "builds" / "reports" / "items_seq_gen_fresh"
OUT_DIR = ROOT / "builds" / "reports" / "item_scroll_cmp"
OUT_DIR.mkdir(parents=True, exist_ok=True)

# Item names indexed by itemRow (0-based)
ITEM_NAMES = [
    "heart+clock",           # row 0: left=$22(heart) right=$1A(clock)  -- but row0 is pre-scroll
    "heart+clock",           # row 1
    "heart+clock",           # row 2: left=$22 right=$1A
    "containerHeart+fairy",  # row 3: left=$23 right=$21
    "clock+food",            # row 4: left=$18 right=$0F
    "rupy+5rupies",          # row 5: left=$1F right=$20
    "lifePotion+2ndPotion",  # row 6: left=$15 right=$04
    "letter+food",           # row 7: left=$01 right=$02
    "sword+whiteSword",      # row 8: left=$03 right=$1C
    "magicSword+magicShield",# row 9: left=$1D right=$1E
    "boomerang+magicBoom",   # row 10: left=$00 right=$0A
    "bomb+bow",              # row 11: left=$08 right=$09
    "arrow+silverArrow",     # row 12: left=$06 right=$07
    "blueCandle+redCandle",  # row 13: left=$12 right=$13
    "blueRing+redRing",      # row 14: left=$14 right=$05
    "powerBracelet+recorder",# row 15: left=$0C right=$0D
    "raft+stepladder",       # row 16: left=$10 right=$11
    "magicRod+bookOfMagic",  # row 17: left=$19 right=$0B
    "key+magicKey",          # row 18: left=$17 right=$16
    "triforce",              # row 19: left=$1B right=$1B (centered)
    "link_sprite_0",         # row 20: $30
    "link_sprite_1",         # row 21: $31
    "link_sprite_2",         # row 22: $32
    "link_sprite_3",         # row 23: $33
]

# Parse trace CSV
def parse_trace(path):
    lines = path.read_text().splitlines()
    header = lines[1][2:].split(",")
    rows = []
    for raw in csv.DictReader(lines[2:], fieldnames=header):
        rows.append(raw)
    return rows

def frame_path(d, label, frame):
    return d / f"{label}_f{int(frame):05d}.png"

def mismatch_pct(a, b, threshold=20):
    diff = np.abs(a.astype(np.int16) - b.astype(np.int16))
    return float((diff > threshold).mean()) * 100

def load_gray(p):
    return np.array(Image.open(p).convert("L"), dtype=np.uint8)

def make_diff_image(nes_img, gen_img):
    diff = np.abs(nes_img.astype(np.int16) - gen_img.astype(np.int16))
    diff_boosted = np.clip(diff * 4, 0, 255).astype(np.uint8)
    return diff_boosted

# Parse both traces
nes_rows = parse_trace(NES_DIR / "nes_fresh_trace.txt")
gen_rows = parse_trace(GEN_DIR / "gen_fresh_trace.txt")

# Filter to item scroll (phase=01, subphase=02)
nes_scroll = [r for r in nes_rows if r["phase"] == "01" and r["subphase"] == "02"]
gen_scroll = [r for r in gen_rows if r["phase"] == "01" and r["subphase"] == "02"]

# Build lookup by (textIndex, itemRow) for matching
# These are game-state variables that progress identically on both platforms
# lineCounter is off by 1 between NES/GEN due to startup frame offset
def make_key(r):
    return (r["textIndex"], r["itemRow"])

nes_by_key = {}
for r in nes_scroll:
    k = make_key(r)
    if k not in nes_by_key:
        nes_by_key[k] = r

gen_by_key = {}
for r in gen_scroll:
    k = make_key(r)
    if k not in gen_by_key:
        gen_by_key[k] = r

shared_keys = sorted(set(nes_by_key) & set(gen_by_key))

# Compare matched frames
results = []
per_item = {}  # itemRow -> list of mismatch pcts

for key in shared_keys:
    nr = nes_by_key[key]
    gr = gen_by_key[key]
    nf = int(nr["frame"])
    gf = int(gr["frame"])

    np_nes = frame_path(NES_DIR, "nes_fresh", nf)
    np_gen = frame_path(GEN_DIR, "gen_fresh", gf)

    if not np_nes.exists() or not np_gen.exists():
        continue

    nes_img = load_gray(np_nes)
    gen_img = load_gray(np_gen)

    pct = mismatch_pct(nes_img, gen_img)
    irow = int(nr["itemRow"], 16)
    tidx = int(nr["textIndex"], 16)
    curv = int(nr["curVScroll"], 16)

    results.append({
        "nesFrame": nf,
        "genFrame": gf,
        "curV": curv,
        "textIndex": tidx,
        "itemRow": irow,
        "mismatch_pct": pct,
        "nesSprites": nr["spriteVisible"],
        "genSprites": gr["spriteVisible"],
    })

    per_item.setdefault(irow, []).append(pct)

# Write summary
with open(OUT_DIR / "item_scroll_comparison.txt", "w") as f:
    f.write("# Item Scroll NES vs Genesis Comparison\n\n")
    f.write(f"Total matched frames: {len(results)}\n")
    if results:
        avg = sum(r["mismatch_pct"] for r in results) / len(results)
        f.write(f"Average mismatch: {avg:.2f}%\n")
        perfect = sum(1 for r in results if r["mismatch_pct"] < 0.1)
        f.write(f"Near-perfect frames (<0.1%): {perfect}/{len(results)}\n\n")

    f.write("## Per-Item Mismatch Summary\n\n")
    f.write(f"{'Row':>4} {'Item Name':<28} {'Avg%':>6} {'Max%':>6} {'Count':>5}\n")
    f.write("-" * 55 + "\n")
    for irow in sorted(per_item.keys()):
        vals = per_item[irow]
        name = ITEM_NAMES[irow] if irow < len(ITEM_NAMES) else f"row_{irow}"
        avg_v = sum(vals) / len(vals)
        max_v = max(vals)
        f.write(f"{irow:4d} {name:<28} {avg_v:6.2f} {max_v:6.2f} {len(vals):5d}\n")

    f.write("\n## Worst Frames (top 20)\n\n")
    f.write(f"{'NES':>6} {'GEN':>6} {'curV':>5} {'text':>5} {'iRow':>5} {'mis%':>7} {'nSpr':>5} {'gSpr':>5}\n")
    f.write("-" * 55 + "\n")
    worst = sorted(results, key=lambda r: -r["mismatch_pct"])[:20]
    for r in worst:
        f.write(f"{r['nesFrame']:6d} {r['genFrame']:6d} {r['curV']:5d} {r['textIndex']:5d} "
                f"{r['itemRow']:5d} {r['mismatch_pct']:7.2f} {r['nesSprites']:>5} {r['genSprites']:>5}\n")

# Save diff images for worst 10
worst10 = sorted(results, key=lambda r: -r["mismatch_pct"])[:10]
for r in worst10:
    nf = r["nesFrame"]
    gf = r["genFrame"]
    nes_img = load_gray(frame_path(NES_DIR, "nes_fresh", nf))
    gen_img = load_gray(frame_path(GEN_DIR, "gen_fresh", gf))
    diff = make_diff_image(nes_img, gen_img)

    # Side by side: NES | GEN | DIFF
    h, w = nes_img.shape
    combined = np.zeros((h, w * 3), dtype=np.uint8)
    combined[:, :w] = nes_img
    combined[:, w:2*w] = gen_img
    combined[:, 2*w:] = diff

    Image.fromarray(combined).save(
        OUT_DIR / f"diff_n{nf}_g{gf}_ir{r['itemRow']:02d}.png"
    )

# Also save representative frames for each item row
for irow in sorted(per_item.keys()):
    item_results = [r for r in results if r["itemRow"] == irow]
    if not item_results:
        continue
    # Pick the frame with worst mismatch for this item
    worst_r = max(item_results, key=lambda r: r["mismatch_pct"])
    nf = worst_r["nesFrame"]
    gf = worst_r["genFrame"]
    nes_img = load_gray(frame_path(NES_DIR, "nes_fresh", nf))
    gen_img = load_gray(frame_path(GEN_DIR, "gen_fresh", gf))
    diff = make_diff_image(nes_img, gen_img)
    h, w = nes_img.shape
    combined = np.zeros((h, w * 3), dtype=np.uint8)
    combined[:, :w] = nes_img
    combined[:, w:2*w] = gen_img
    combined[:, 2*w:] = diff
    name = ITEM_NAMES[irow] if irow < len(ITEM_NAMES) else f"row_{irow}"
    Image.fromarray(combined).save(
        OUT_DIR / f"item_{irow:02d}_{name}_{worst_r['mismatch_pct']:.1f}pct.png"
    )

print(f"Comparison complete. {len(results)} matched frames analyzed.")
print(f"Results in: {OUT_DIR}")
print(open(OUT_DIR / "item_scroll_comparison.txt").read())
