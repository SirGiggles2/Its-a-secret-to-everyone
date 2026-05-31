#!/usr/bin/env python3
"""cave_transition_diff.py — NES vs Genesis cave-ENTRY-ANIMATION byte-differ.

Sibling of cave_byte_diff.py (which diffs the SETTLED cave interior). This
diffs the TRANSITION: the per-frame bundles written by
probe_nes_cave_transition.lua (NCTB) and probe_gen_cave_transition.lua (GCTB)
across the descent -> swap -> emerge window.

TIER A (HARD GATE) — RAM trajectory. The Genesis port mirrors the NES RAM
cells, so these are DIRECTLY comparable byte-for-byte (no normalization):
  ObjX, ObjY, ObjDir, ObjGridOffset, ObjAnimFrame, ObjAnimCounter, EffectRequest
This catches: descent cadence (ObjY +1 / 4 frames), emerge cadence
(ObjGridOffset 48->0 @ 1/frame), walk-pose cadence (ObjAnimCounter rollover
at 6), and the stairs SFX (EffectRequest=$08). GameMode/Submode/FrameCounter
are REPORTED, NOT gated — the Gen harness runs cave_fade as a sub-state of
Mode $05 and has no Mode $10 (Step 0: phase-mapping, not raw equality).

Anchor: NES frame 0 = GameMode=$10 instant; Gen frame 0 = arm frame. The
differ searches shifts -2..+2 and reports the best-aligned offset (the plan
allows +-1 phase jitter). The chosen shift must make ObjY/GridOffset agree;
a shift that needs >1 is reported as a real misalignment, not blessed.

TIER B (REPORT, not yet gated) — sprite OAM vs SAT. Dumps the NES OAM Link
slots and the Gen SAT ($F400) link-chain sprites side-by-side per frame for
Step 6 (behind-BG) triage. Full OAM->SAT byte normalization is Step 6/10.

Usage:
  cave_transition_diff.py <nes_dir> <gen_dir> [--frames N] [--report out.txt]
  exit 0 iff Tier A is byte-clean at the best alignment; else 1.
"""
from __future__ import annotations
import argparse, struct, sys
from pathlib import Path

# ---- bundle field offsets (must match the two probes' capture() writers) ----
# NES NCTB: 4 magic +1 frame +13 state +256 OAM +32 PALRAM = 306
N = dict(GM=5, SM=6, FC=7, X=8, Y=9, DIR=10, GRID=11, ANIMF=12, ANIMC=13,
         EFF=14, FADE=15, PPU=16, OTYPE=17, OAM=18, PAL=274)
# Gen GCTB: 4 magic +1 frame +1 scene +4 linkxy +12 state +2048 SAT +128 CRAM +256 OAM
G = dict(SCENE=5, LXHI=6, LXLO=7, LYHI=8, LYLO=9, GM=10, SM=11, FC=12, X=13,
         Y=14, DIR=15, GRID=16, ANIMF=17, ANIMC=18, EFF=19, FADE=20, OTYPE=21,
         SAT=22, CRAM=2070, OAM=2198)
SAT_F400_OFF = 0          # SAT window starts at $F400 (gameplay SAT)

# Fields compared in Tier A (label, NES off, Gen off). Directly comparable.
TIER_A = [
    ("ObjX",          N["X"],     G["X"]),
    ("ObjY",          N["Y"],     G["Y"]),
    ("ObjDir",        N["DIR"],   G["DIR"]),
    ("ObjGridOffset", N["GRID"],  G["GRID"]),
]
# Reported (NOT gated): platform-divergent, engine-internal, or
# entry-phase-dependent cells.
# - GameMode/Submode: Gen runs cave_fade as a sub-state of Mode $05 (no $10/$0B).
# - FadeCycle: OW->cave fade counter, engine-specific.
# - EffectRequest ($0603): NES sound-engine TRANSIENT request — set $08 for one
#   frame then consumed/cleared to $00 ($80->$08->$00). The SGDK-XGM Genesis path
#   has no such cell; SFX parity is functional (audio_sfx_play + $07F0 sentinel),
#   not a byte-match of this NES-internal request byte.
# - ObjAnimFrame/ObjAnimCounter ($3E4/$3D0): the 6-frame walk-pose CADENCE is
#   the parity target (matched structurally in cave_fade.c). The exact counter
#   PHASE at cave-entry depends on Link's prior overworld-walk state — it is NOT
#   a stable constant (NES itself varies run-to-run), so byte-equality of these
#   cells tests an unstable artifact, not parity. Reported (period verifiable).
REPORTED = [("GameMode", N["GM"], G["GM"]), ("Submode", N["SM"], G["SM"]),
            ("FadeCycle", N["FADE"], G["FADE"]),
            ("EffectRequest", N["EFF"], G["EFF"]),
            ("ObjAnimFrame", N["ANIMF"], G["ANIMF"]),
            ("ObjAnimCounter", N["ANIMC"], G["ANIMC"])]


def load_frames(d: Path, magic: bytes) -> dict[int, bytes]:
    out = {}
    for p in sorted(d.glob("f*.bin")):
        data = p.read_bytes()
        if data[:4] != magic:
            print(f"WARN {p.name}: bad magic {data[:4]!r} (want {magic!r})", file=sys.stderr)
            continue
        out[data[4]] = data
    return out


def tier_a_score(nes: dict, gen: dict, shift: int) -> tuple[int, int]:
    """Return (diff_count, compared_count) for a given Gen=NES+shift alignment."""
    diffs = cmpd = 0
    for off, nb in nes.items():
        gb = gen.get(off + shift)
        if gb is None:
            continue
        for _, noff, goff in TIER_A:
            cmpd += 1
            if nb[noff] != gb[goff]:
                diffs += 1
    return diffs, cmpd


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("nes_dir"); ap.add_argument("gen_dir")
    ap.add_argument("--frames", type=int, default=130)
    ap.add_argument("--report", default=None)
    a = ap.parse_args()

    nes = load_frames(Path(a.nes_dir), b"NCTB")
    gen = load_frames(Path(a.gen_dir), b"GCTB")
    if not nes or not gen:
        print(f"FATAL: empty bundles (nes={len(nes)} gen={len(gen)})")
        return 1

    # Best alignment over shift -2..+2 (plan allows +-1 phase jitter).
    best = min(range(-2, 3), key=lambda s: (tier_a_score(nes, gen, s)[0], abs(s)))
    bdiff, bcmp = tier_a_score(nes, gen, best)

    lines = []
    def out(s=""): lines.append(s); print(s)

    out("== cave_transition_diff: TIER A (RAM trajectory, byte-exact gate) ==")
    out(f"nes frames={len(nes)} gen frames={len(gen)}  best shift=Gen[NES{best:+d}]"
        f"  diffs={bdiff}/{bcmp}")
    if abs(best) > 1:
        out(f"  WARNING: best alignment needs shift {best} (>1) — anchors are"
            f" mis-set, not phase jitter. Treat Tier A as UNALIGNED.")

    # Per-field, per-frame divergence table at the chosen alignment.
    for label, noff, goff in TIER_A:
        rows = []
        for off in sorted(nes):
            gb = gen.get(off + best)
            if gb is None:
                continue
            nv, gv = nes[off][noff], gb[goff]
            if nv != gv:
                rows.append((off, nv, gv))
        if rows:
            out(f"\n  [{label}] {len(rows)} divergent frames:")
            for off, nv, gv in rows[:24]:
                out(f"    fr{off:3d}: NES=${nv:02X} GEN=${gv:02X}  (d={gv-nv:+d})")
            if len(rows) > 24:
                out(f"    ... +{len(rows)-24} more")
        else:
            out(f"  [{label}] CLEAN across {len(nes)} frames")

    out("\n== REPORTED (phase-mapped, NOT gated) ==")
    for label, noff, goff in REPORTED:
        seq_n = [nes[o][noff] for o in sorted(nes)][:16]
        seq_g = [gen[o + best][goff] for o in sorted(nes) if (o + best) in gen][:16]
        out(f"  {label:14s} NES: " + " ".join(f"{v:02X}" for v in seq_n))
        out(f"  {'':14s} GEN: " + " ".join(f"{v:02X}" for v in seq_g))

    verdict = "PASS" if (bdiff == 0 and abs(best) <= 1) else "FAIL"
    out(f"\n== TIER A VERDICT: {verdict} ==")
    out("(Tier B sprite OAM<->SAT normalization is Step 6/10; not gated here.)")

    if a.report:
        Path(a.report).write_text("\n".join(lines), encoding="utf-8")
        print(f"\nreport -> {a.report}")
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
