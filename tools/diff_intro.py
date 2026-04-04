#!/usr/bin/env python3
"""
diff_intro.py — Paired NES vs Genesis frame diff for the post-fade intro scroll.

Design choices (enforced by /codex:adversarial-review findings):

1. Y-crop is FIXED at [0,240). We do NOT auto-minimize Y offset — that would
   normalize away the +8 overscan defect we are trying to detect. Instead we
   report a second "shifted" comparison at Y[8,248) as a DIAGNOSTIC SIGNAL.
   If meanDelta_shifted << meanDelta_raw across most frames, that IS the
   +8 overscan signature (suspect #2).

2. Frame pairing is SEMANTIC, not absolute. Story scroll is driven by
   AnimateDemoPhase1Subphase0 which increments CurVScroll only on alternating
   frames and wraps at $F0. A single-frame timing skew would look identical
   to a growing scroll-cadence bug. We match on the tuple
   (gameMode, phase, subphase, CurVScroll, SwitchReq) and compute the best
   small constant offset. A growing offset is itself the #6 signature.

Inputs:  builds/reports/intro_nes/  and  builds/reports/intro_gen/
Outputs: builds/reports/intro_diff.txt
         builds/reports/intro_diff_summary.md
         builds/reports/intro_diff_strip.png
"""

import os
import sys
import re
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("ERROR: Pillow not installed. Run: pip install Pillow", file=sys.stderr)
    sys.exit(1)

REPO = Path(r"C:\Users\Jake Diggity\Documents\GitHub\FINAL TRY")
REPORTS = REPO / "builds" / "reports"
NES_DIR = REPORTS / "intro_nes"
GEN_DIR = REPORTS / "intro_gen"
OUT_DIFF = REPORTS / "intro_diff.txt"
OUT_SUMMARY = REPORTS / "intro_diff_summary.md"
OUT_STRIP = REPORTS / "intro_diff_strip.png"

# NES active: 256x240. Genesis active: 320x224 (plus 8px top overscan room).
NES_W, NES_H = 256, 240
GEN_X_CROP = (32, 32 + NES_W)  # center 256 of 320
Y_RAW = (0, NES_H)
Y_SHIFTED = (8, 8 + NES_H)  # diagnostic for +8 overscan signature

# ------------------------------------------------------------
# Trace loading
# ------------------------------------------------------------
TRACE_COLS = [
    "frame", "gameMode", "phase", "subphase", "curVScroll",
    "curHScroll", "ppuCtrl", "switchReq", "vsram0", "ppuScrlX", "ppuScrlY",
]


def load_trace(trace_path: Path):
    """Return dict frame_number -> dict of decoded fields."""
    out = {}
    if not trace_path.exists():
        print(f"WARN: trace missing: {trace_path}", file=sys.stderr)
        return out
    with trace_path.open() as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split(",")
            if len(parts) < len(TRACE_COLS):
                continue
            rec = {}
            try:
                rec["frame"] = int(parts[0])
                for i, col in enumerate(TRACE_COLS[1:9], start=1):
                    rec[col] = int(parts[i], 16)
                rec["vsram0"] = int(parts[8], 16)
                rec["ppuScrlX"] = int(parts[9], 16)
                rec["ppuScrlY"] = int(parts[10], 16)
            except ValueError:
                continue
            out[rec["frame"]] = rec
    return out


# ------------------------------------------------------------
# Screenshot loading & cropping
# ------------------------------------------------------------
FRAME_RE = re.compile(r"_f(\d+)\.png$", re.IGNORECASE)


def index_screens(directory: Path, label: str):
    """Return dict frame_number -> Path."""
    out = {}
    if not directory.exists():
        return out
    for p in directory.iterdir():
        if not p.name.lower().startswith(label + "_f"):
            continue
        m = FRAME_RE.search(p.name)
        if m:
            out[int(m.group(1))] = p
    return out


def load_nes(path: Path) -> Image.Image:
    img = Image.open(path).convert("L")
    # BizHawk NES screenshots are 256x240 by default.
    if img.size != (NES_W, NES_H):
        img = img.resize((NES_W, NES_H))
    return img


def load_gen_raw(path: Path) -> Image.Image:
    """Crop Genesis 320x224 (or similar) to NES active area Y[0,240)."""
    img = Image.open(path).convert("L")
    w, h = img.size
    # Genesis BizHawk default is 320x224. We want to compare the center 256
    # columns against NES 256x240. For Y, we need 240 rows; Genesis is 224,
    # so we pad by repeating the last row if needed (or just resize).
    left = GEN_X_CROP[0]
    right = min(GEN_X_CROP[1], w)
    if right - left != NES_W:
        # Unusual frame size — resize horizontally first.
        img = img.resize((320, h))
        left, right = 32, 32 + NES_W
    top = 0
    bot = min(h, NES_H)
    crop = img.crop((left, top, right, bot))
    if crop.size[1] != NES_H:
        # Pad bottom by resizing vertically (Genesis 224 -> NES 240).
        crop = crop.resize((NES_W, NES_H))
    return crop


def load_gen_shifted(path: Path) -> Image.Image:
    """Same horizontal crop, but shifted down by 8 rows (diagnostic for +8)."""
    img = Image.open(path).convert("L")
    w, h = img.size
    left = GEN_X_CROP[0]
    right = min(GEN_X_CROP[1], w)
    if right - left != NES_W:
        img = img.resize((320, h))
        left, right = 32, 32 + NES_W
    top = min(8, h)
    bot = min(h, top + NES_H)
    crop = img.crop((left, top, right, bot))
    if crop.size[1] != NES_H:
        crop = crop.resize((NES_W, NES_H))
    return crop


# ------------------------------------------------------------
# Delta computation
# ------------------------------------------------------------
def mean_abs_delta(a: Image.Image, b: Image.Image) -> float:
    pa = a.tobytes()
    pb = b.tobytes()
    # Both are L mode same size — byte arrays compare directly.
    total = 0
    n = len(pa)
    for i in range(n):
        total += abs(pa[i] - pb[i])
    return total / n


def row_band_maxes(a: Image.Image, b: Image.Image):
    """Return (top_band_max, mid_band_max, bot_band_max) of per-row mean delta."""
    import array
    pa = a.tobytes()
    pb = b.tobytes()
    w = a.size[0]
    h = a.size[1]
    rows = array.array("f", [0.0] * h)
    for y in range(h):
        off = y * w
        s = 0
        for x in range(w):
            s += abs(pa[off + x] - pb[off + x])
        rows[y] = s / w
    # Top band = rows [0,80), mid = [80,160), bot = [160,240).
    def band_max(lo, hi):
        m = 0.0
        for y in range(lo, hi):
            if rows[y] > m:
                m = rows[y]
        return m
    return band_max(0, 80), band_max(80, 160), band_max(160, 240)


# ------------------------------------------------------------
# Semantic alignment
# ------------------------------------------------------------
def semantic_state(rec):
    return (
        rec.get("gameMode", -1),
        rec.get("phase", -1),
        rec.get("subphase", -1),
        rec.get("curVScroll", -1),
        rec.get("switchReq", -1),
    )


def find_best_offset(nes_trace, gen_trace, search=5):
    """
    Find constant integer offset k such that for most frames f,
    semantic_state(gen_trace[f+k]) == semantic_state(nes_trace[f]).
    Returns (best_k, match_ratio, growing_drift_flag).
    """
    common = sorted(set(nes_trace) & set(gen_trace))
    if not common:
        return 0, 0.0, False

    best_k = 0
    best_matches = -1
    for k in range(-search, search + 1):
        matches = 0
        total = 0
        for f in common:
            if (f + k) not in gen_trace:
                continue
            total += 1
            if semantic_state(nes_trace[f]) == semantic_state(gen_trace[f + k]):
                matches += 1
        if matches > best_matches:
            best_matches = matches
            best_k = k
    best_ratio = best_matches / max(1, len(common))

    # Detect growing drift: does alignment quality depend on frame position?
    # Split the window in half and recompute best-k per half; if they differ,
    # the offset is not constant → scroll cadence drift.
    half = len(common) // 2
    if half >= 8:
        first = common[:half]
        second = common[half:]
        def best_for(frames):
            bk, bm = 0, -1
            for k in range(-search, search + 1):
                m = sum(
                    1 for f in frames
                    if (f + k) in gen_trace
                    and semantic_state(nes_trace[f]) == semantic_state(gen_trace[f + k])
                )
                if m > bm:
                    bm = m
                    bk = k
            return bk
        bk1 = best_for(first)
        bk2 = best_for(second)
        growing = bk1 != bk2
    else:
        growing = False

    return best_k, best_ratio, growing


# ------------------------------------------------------------
# Main
# ------------------------------------------------------------
def main():
    if not NES_DIR.exists() or not GEN_DIR.exists():
        print(f"ERROR: missing capture dirs.\n  {NES_DIR}\n  {GEN_DIR}", file=sys.stderr)
        sys.exit(2)

    nes_trace = load_trace(NES_DIR / "nes_trace.txt")
    gen_trace = load_trace(GEN_DIR / "gen_trace.txt")
    nes_imgs = index_screens(NES_DIR, "nes")
    gen_imgs = index_screens(GEN_DIR, "gen")

    print(f"NES frames: {len(nes_imgs)} screens, {len(nes_trace)} trace rows")
    print(f"GEN frames: {len(gen_imgs)} screens, {len(gen_trace)} trace rows")

    # Semantic alignment
    best_k, ratio, growing = find_best_offset(nes_trace, gen_trace)
    print(f"Semantic alignment: best_k={best_k}  match_ratio={ratio:.3f}  growing_drift={growing}")

    # Pair frames
    per_frame = []
    for f in sorted(nes_imgs):
        g = f + best_k
        if g not in gen_imgs:
            continue
        nes_img = load_nes(nes_imgs[f])
        gen_raw = load_gen_raw(gen_imgs[g])
        gen_shifted = load_gen_shifted(gen_imgs[g])

        mean_raw = mean_abs_delta(nes_img, gen_raw)
        mean_shifted = mean_abs_delta(nes_img, gen_shifted)
        top, mid, bot = row_band_maxes(nes_img, gen_raw)

        grec = gen_trace.get(g, {})
        nrec = nes_trace.get(f, {})
        per_frame.append({
            "nes_f": f, "gen_f": g,
            "mean_raw": mean_raw,
            "mean_shifted": mean_shifted,
            "top": top, "mid": mid, "bot": bot,
            "vsram0": grec.get("vsram0", -1),
            "gen_curV": grec.get("curVScroll", -1),
            "nes_scrl_x": nrec.get("ppuScrlX", nrec.get("curHScroll", -1)),
            "nes_scrl_y": nrec.get("ppuScrlY", nrec.get("curVScroll", -1)),
        })

    if not per_frame:
        print("ERROR: no paired frames produced.", file=sys.stderr)
        sys.exit(3)

    # Write intro_diff.txt
    with OUT_DIFF.open("w") as f:
        f.write(f"# semantic alignment: best_k={best_k} ratio={ratio:.3f} growing_drift={growing}\n")
        f.write("nes_f,gen_f,meanRaw,meanShifted,topBandMax,midBandMax,botBandMax,vsram0,gen_curV,nes_scrl_x,nes_scrl_y\n")
        for r in per_frame:
            f.write("{nes_f},{gen_f},{mean_raw:.2f},{mean_shifted:.2f},{top:.2f},{mid:.2f},{bot:.2f},{vsram0:04X},{gen_curV:02X},{nes_scrl_x:02X},{nes_scrl_y:02X}\n".format(**r))

    # Summary
    means_raw = [r["mean_raw"] for r in per_frame]
    means_shifted = [r["mean_shifted"] for r in per_frame]
    median = sorted(means_raw)[len(means_raw) // 2]
    spikes = [r for r in per_frame if r["mean_raw"] > 3 * median and median > 0]

    # Heuristics for suspect categorization
    avg_raw = sum(means_raw) / len(means_raw)
    avg_shifted = sum(means_shifted) / len(means_shifted)
    shift_helps = avg_shifted < avg_raw * 0.7

    top_heavy_spikes = [r for r in spikes if r["top"] > 2 * max(r["mid"], r["bot"])]
    wrap_window_spikes = [r for r in spikes if 1440 <= r["nes_f"] <= 1460]

    with OUT_SUMMARY.open("w") as f:
        f.write("# Intro Scroll Diff — Triage Summary\n\n")
        f.write(f"- Paired frames: {len(per_frame)}\n")
        f.write(f"- Semantic alignment: best_k={best_k}, ratio={ratio:.3f}, growing_drift={growing}\n")
        f.write(f"- meanDelta (raw Y0): avg={avg_raw:.2f}  median={median:.2f}\n")
        f.write(f"- meanDelta (Y+8 shifted): avg={avg_shifted:.2f}\n")
        f.write(f"- Spikes (>3× median): {len(spikes)}\n\n")

        f.write("## Suspect signatures detected\n\n")
        if growing:
            f.write("- **#6 Scroll cadence drift** — semantic alignment changes across the window; gen/nes scroll speeds diverge.\n")
        if shift_helps:
            f.write(f"- **#2 +8 overscan offset** — Y+8 comparison improves avg delta by {(1 - avg_shifted / avg_raw) * 100:.0f}%. `src/nes_io.asm:304`.\n")
        if wrap_window_spikes:
            f.write(f"- **#1 H-int dead-zone skip timing** — {len(wrap_window_spikes)} spikes in F1440–1460 wrap window. `src/nes_io.asm:330-345`.\n")
        if top_heavy_spikes and not wrap_window_spikes:
            f.write(f"- **#1 (top-band spikes)** — {len(top_heavy_spikes)} top-band-dominant spikes outside wrap window.\n")
        if not (growing or shift_helps or wrap_window_spikes or top_heavy_spikes):
            f.write("- No strong signature match; inspect `intro_diff_strip.png` manually.\n")

        f.write("\n## Worst 12 frames (by meanRaw)\n\n")
        worst = sorted(per_frame, key=lambda r: -r["mean_raw"])[:12]
        f.write("| nes_f | gen_f | meanRaw | meanShifted | top | mid | bot | vsram0 |\n")
        f.write("|---|---|---|---|---|---|---|---|\n")
        for r in worst:
            f.write("| {nes_f} | {gen_f} | {mean_raw:.1f} | {mean_shifted:.1f} | {top:.1f} | {mid:.1f} | {bot:.1f} | {vsram0:04X} |\n".format(**r))

    # Strip image: worst 12 frames NES | GEN side by side
    worst = sorted(per_frame, key=lambda r: -r["mean_raw"])[:12]
    strip_w = NES_W * 2 + 4
    strip_h = NES_H * len(worst)
    strip = Image.new("L", (strip_w, strip_h), 0)
    for i, r in enumerate(worst):
        nes_img = load_nes(nes_imgs[r["nes_f"]])
        gen_img = load_gen_raw(gen_imgs[r["gen_f"]])
        strip.paste(nes_img, (0, i * NES_H))
        strip.paste(gen_img, (NES_W + 4, i * NES_H))
    strip.save(OUT_STRIP)

    print(f"\nWrote: {OUT_DIFF}")
    print(f"Wrote: {OUT_SUMMARY}")
    print(f"Wrote: {OUT_STRIP}")


if __name__ == "__main__":
    main()
