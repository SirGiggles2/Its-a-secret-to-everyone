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
   constant offset within a wider search window. A growing offset is itself
   the #6 signature.

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

# Modern BizHawk captures for this project are already 256x224 active-area PNGs
# for both NES and Genesis. Keep compatibility with older 256x240 NES and
# 320x224 Genesis captures so historical reports still re-run cleanly.
ACTIVE_W, ACTIVE_H = 256, 224
LEGACY_NES_H = 240

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
    cols = TRACE_COLS
    if not trace_path.exists():
        print(f"WARN: trace missing: {trace_path}", file=sys.stderr)
        return out
    with trace_path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith("# frame,"):
                cols = [part.strip() for part in line[2:].split(",")]
                continue
            if line.startswith("#"):
                continue
            parts = line.split(",")
            if len(parts) < len(cols):
                continue
            rec = {}
            try:
                rec["frame"] = int(parts[0])
                for i, col in enumerate(cols[1:], start=1):
                    rec[col] = int(parts[i], 16)
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


CMP_H = ACTIVE_H


def _blank_image(mode):
    color = 0 if mode == "L" else (0, 0, 0)
    return Image.new(mode, (ACTIVE_W, ACTIVE_H), color)


def _ensure_active_size(img: Image.Image) -> Image.Image:
    """Normalize a capture to 256x224 without stretching pixels."""
    w, h = img.size

    if w > ACTIVE_W:
        left = (w - ACTIVE_W) // 2
        img = img.crop((left, 0, left + ACTIVE_W, h))
    elif w < ACTIVE_W:
        padded = _blank_image(img.mode)
        left = (ACTIVE_W - w) // 2
        padded.paste(img, (left, 0))
        img = padded

    if img.size[1] > ACTIVE_H:
        img = img.crop((0, 0, ACTIVE_W, ACTIVE_H))
    elif img.size[1] < ACTIVE_H:
        padded = _blank_image(img.mode)
        padded.paste(img, (0, 0))
        img = padded

    return img


def load_nes(path: Path, shifted: bool, mode="L") -> Image.Image:
    """
    Load NES capture into the 256x224 comparison window.
    - New captures: already 256x224 active area -> use as-is.
    - Legacy captures: 256x240 -> raw uses rows 0..223, shifted uses 8..231.
    """
    img = Image.open(path).convert(mode)
    w, h = img.size
    if w != ACTIVE_W:
        img = img.resize((ACTIVE_W, h))
        h = img.size[1]

    if h >= ACTIVE_H + 8:
        top = 8 if shifted else 0
        return img.crop((0, top, ACTIVE_W, top + ACTIVE_H))

    return _ensure_active_size(img)


def load_gen(path: Path, mode="L") -> Image.Image:
    """
    Load Genesis capture into the 256x224 comparison window.
    - New captures: already 256x224 active area -> use as-is.
    - Legacy captures: 320x224 -> center-crop to 256x224.
    """
    img = Image.open(path).convert(mode)
    return _ensure_active_size(img)


def load_nes_raw(path: Path) -> Image.Image:
    return load_nes(path, shifted=False, mode="L")


def load_nes_shifted(path: Path) -> Image.Image:
    return load_nes(path, shifted=True, mode="L")


def load_gen_raw(path: Path) -> Image.Image:
    return load_gen(path, mode="L")


def load_gen_shifted(path: Path) -> Image.Image:
    return load_gen(path, mode="L")


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


def ink_mismatch(a: Image.Image, b: Image.Image) -> float:
    """
    Return fraction of pixels whose on/off occupancy differs.
    This filters out palette quantization and highlights real geometry or
    placement mismatches in glyphs, borders, and scroll position.
    """
    pa = a.tobytes()
    pb = b.tobytes()
    mismatches = 0
    n = len(pa)
    for i in range(n):
        if (pa[i] != 0) != (pb[i] != 0):
            mismatches += 1
    return mismatches / n


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
    # Top/mid/bot thirds of comparison window (224 rows → 74/75/75).
    third = h // 3
    def band_max(lo, hi):
        m = 0.0
        for y in range(lo, hi):
            if rows[y] > m:
                m = rows[y]
        return m
    return band_max(0, third), band_max(third, 2 * third), band_max(2 * third, h)


# ------------------------------------------------------------
# Semantic alignment
# ------------------------------------------------------------
def semantic_state(rec):
    key_fields = (
        "gameMode",
        "phase",
        "subphase",
        "curVScroll",
        "switchReq",
        "demoLineTextIndex",
        "demoNTWraps",
        "lineCounter",
        "lineAttrIndex",
        "lineDstLo",
        "lineDstHi",
        "attrDstLo",
        "attrDstHi",
        "phase0Cycle",
        "phase0Timer",
        "transferBufSel",
        "demoBusy",
    )
    return tuple(rec.get(name, -1) for name in key_fields)


def find_best_offset(nes_trace, gen_trace, search=120):
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
    best_total = 0
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
            best_total = total
    best_ratio = best_matches / max(1, best_total)

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
    sample_nes_size = Image.open(nes_imgs[min(nes_imgs)]).size
    sample_gen_size = Image.open(gen_imgs[min(gen_imgs)]).size

    print(f"NES frames: {len(nes_imgs)} screens, {len(nes_trace)} trace rows")
    print(f"GEN frames: {len(gen_imgs)} screens, {len(gen_trace)} trace rows")
    print(f"Capture sizes: NES={sample_nes_size} GEN={sample_gen_size}")

    # Semantic alignment
    best_k, ratio, growing = find_best_offset(nes_trace, gen_trace)
    print(f"Semantic alignment: best_k={best_k}  match_ratio={ratio:.3f}  growing_drift={growing}")

    # Pair frames
    per_frame = []
    for f in sorted(nes_imgs):
        g = f + best_k
        if g not in gen_imgs:
            continue
        nes_img = load_nes_raw(nes_imgs[f])
        nes_shifted = load_nes_shifted(nes_imgs[f])
        gen_raw = load_gen_raw(gen_imgs[g])
        gen_shifted = load_gen_shifted(gen_imgs[g])

        mean_raw = mean_abs_delta(nes_img, gen_raw)
        mean_shifted = mean_abs_delta(nes_shifted, gen_shifted)
        mask_raw = ink_mismatch(nes_img, gen_raw)
        mask_shifted = ink_mismatch(nes_shifted, gen_shifted)
        top, mid, bot = row_band_maxes(nes_img, gen_raw)

        grec = gen_trace.get(g, {})
        nrec = nes_trace.get(f, {})
        per_frame.append({
            "nes_f": f, "gen_f": g,
            "mean_raw": mean_raw,
            "mean_shifted": mean_shifted,
            "mask_raw": mask_raw,
            "mask_shifted": mask_shifted,
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
        f.write("nes_f,gen_f,meanRaw,meanShifted,maskRaw,maskShifted,topBandMax,midBandMax,botBandMax,vsram0,gen_curV,nes_scrl_x,nes_scrl_y\n")
        for r in per_frame:
            f.write("{nes_f},{gen_f},{mean_raw:.2f},{mean_shifted:.2f},{mask_raw:.5f},{mask_shifted:.5f},{top:.2f},{mid:.2f},{bot:.2f},{vsram0:04X},{gen_curV:02X},{nes_scrl_x:02X},{nes_scrl_y:02X}\n".format(**r))

    # Summary
    means_raw = [r["mean_raw"] for r in per_frame]
    means_shifted = [r["mean_shifted"] for r in per_frame]
    masks_raw = [r["mask_raw"] for r in per_frame]
    masks_shifted = [r["mask_shifted"] for r in per_frame]
    median = sorted(means_raw)[len(means_raw) // 2]
    median_mask = sorted(masks_raw)[len(masks_raw) // 2]
    spikes = [r for r in per_frame if r["mask_raw"] > max(0.005, 3 * median_mask)]

    # Heuristics for suspect categorization
    avg_raw = sum(means_raw) / len(means_raw)
    avg_shifted = sum(means_shifted) / len(means_shifted)
    avg_mask_raw = sum(masks_raw) / len(masks_raw)
    avg_mask_shifted = sum(masks_shifted) / len(masks_shifted)
    shift_helps = avg_mask_shifted < avg_mask_raw * 0.7 if avg_mask_raw > 0 else avg_shifted < avg_raw * 0.7

    top_heavy_spikes = [r for r in spikes if r["top"] > 2 * max(r["mid"], r["bot"])]
    wrap_window_spikes = [r for r in spikes if 1440 <= r["nes_f"] <= 1460]

    with OUT_SUMMARY.open("w") as f:
        f.write("# Intro Scroll Diff — Triage Summary\n\n")
        f.write(f"- Paired frames: {len(per_frame)}\n")
        f.write(f"- Semantic alignment: best_k={best_k}, ratio={ratio:.3f}, growing_drift={growing}\n")
        f.write(f"- Capture sizes: NES={sample_nes_size}, GEN={sample_gen_size}\n")
        f.write(f"- meanDelta (raw Y0): avg={avg_raw:.2f}  median={median:.2f}\n")
        f.write(f"- meanDelta (Y+8 shifted): avg={avg_shifted:.2f}\n")
        f.write(f"- inkMismatch (raw Y0): avg={avg_mask_raw:.4f}  median={median_mask:.4f}\n")
        f.write(f"- inkMismatch (Y+8 shifted): avg={avg_mask_shifted:.4f}\n")
        f.write(f"- Spikes (>3× median): {len(spikes)}\n\n")

        f.write("## Suspect signatures detected\n\n")
        if growing:
            f.write("- **#6 Scroll cadence drift** — semantic alignment changes across the window; gen/nes scroll speeds diverge.\n")
        if shift_helps:
            base = avg_mask_raw if avg_mask_raw > 0 else avg_raw
            improved = avg_mask_shifted if avg_mask_raw > 0 else avg_shifted
            f.write(f"- **#2 +8 overscan offset** — Y+8 comparison improves avg mismatch by {(1 - improved / base) * 100:.0f}%. `src/nes_io.asm:304`.\n")
        if wrap_window_spikes:
            f.write(f"- **#1 H-int dead-zone skip timing** — {len(wrap_window_spikes)} spikes in F1440–1460 wrap window. `src/nes_io.asm:330-345`.\n")
        if top_heavy_spikes and not wrap_window_spikes:
            f.write(f"- **#1 (top-band spikes)** — {len(top_heavy_spikes)} top-band-dominant spikes outside wrap window.\n")
        if not (growing or shift_helps or wrap_window_spikes or top_heavy_spikes):
            f.write("- No strong signature match; inspect `intro_diff_strip.png` manually.\n")

        f.write("\n## Worst 12 Frames (By inkMismatch)\n\n")
        worst = sorted(per_frame, key=lambda r: (-r["mask_raw"], -r["mean_raw"]))[:12]
        f.write("| nes_f | gen_f | maskRaw | maskShifted | meanRaw | top | mid | bot | vsram0 |\n")
        f.write("|---|---|---|---|---|---|---|---|---|\n")
        for r in worst:
            f.write("| {nes_f} | {gen_f} | {mask_raw:.4f} | {mask_shifted:.4f} | {mean_raw:.1f} | {top:.1f} | {mid:.1f} | {bot:.1f} | {vsram0:04X} |\n".format(**r))

    # Strip image: worst 12 frames NES | GEN side by side
    worst = sorted(per_frame, key=lambda r: (-r["mask_raw"], -r["mean_raw"]))[:12]
    strip_w = ACTIVE_W * 2 + 4
    strip_h = CMP_H * len(worst)
    strip = Image.new("L", (strip_w, strip_h), 0)
    for i, r in enumerate(worst):
        nes_img = load_nes_raw(nes_imgs[r["nes_f"]])
        gen_img = load_gen_raw(gen_imgs[r["gen_f"]])
        strip.paste(nes_img, (0, i * CMP_H))
        strip.paste(gen_img, (ACTIVE_W + 4, i * CMP_H))
    strip.save(OUT_STRIP)

    print(f"\nWrote: {OUT_DIFF}")
    print(f"Wrote: {OUT_SUMMARY}")
    print(f"Wrote: {OUT_STRIP}")


if __name__ == "__main__":
    main()
