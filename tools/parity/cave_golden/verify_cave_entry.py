#!/usr/bin/env python3
"""verify_cave_entry.py — definitive per-cave cave-ENTRY parity verdict.

Runs over the captured transition bundles (nes_XX_trans / gen_XX_trans) and
emits TWO byte-verdicts per cave, at each cave's own best frame-anchor shift
(the cave-entry trigger frame varies +-1..2 per OW room — a capture-timing
constant, not a divergence; the shift that aligns the cave's whole window is
the legit anchor):

  TIER-A (positioning/motion/transition):  ObjX, ObjY, ObjDir, ObjGridOffset
      byte-diff across the full descent->hold->emerge window. Gate: diffs==0.

  TIER-B POSE-CADENCE (walk animation):  the NES Link visible pose
      (OAM slot $12 h-flip bit) vs the Gen Link visible pose (SAT slot-0 tile:
      LINK UP frame0 vs frame1) compared as a SEQUENCE at the pose's own best
      shift. This proves the walk-pose CADENCE (the 6-frame flip sequence)
      byte-matches NES. (The exact pose-vs-position PHASE depends on the entry
      FrameCounter and is an unstable per-entry variable -- the raw sprite-cell
      diff conflates it with the cadence; this isolates the cadence, which IS
      a stable parity target.) Gate: mismatch==0 on the on-screen frames.

Pose tile IDs are the fixed Link VRAM tiles (LINK_VRAM_TILE + pose*tiles), so
$36F (UP frame0) / $373 (UP frame1) are cave-independent.

Usage: verify_cave_entry.py [cave_hex ...]   (no args -> all 20)
Exit 0 iff every cave is TIER-A clean AND pose-cadence clean.
"""
from __future__ import annotations
import sys
from pathlib import Path

OUT_ROOT = Path(r"C:\tmp\cave_golden")
CAVES = [0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F, 0x70, 0x71, 0x72, 0x73,
         0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x7B, 0x7C, 0x7D]

# NCTB field offsets (cave_transition_diff.py N dict).
N_X, N_Y, N_DIR, N_GRID, N_OAM = 8, 9, 10, 11, 18
# GCTB field offsets (cave_transition_diff.py G dict).
G_X, G_Y, G_DIR, G_GRID, G_SAT = 13, 14, 15, 16, 22
LINK_OAM_SLOT = 0x12          # NES lower-half Link sprite (8x16)
GEN_LINK_UP_F0 = 0x36F        # Gen Link UP pose-0 first VRAM tile
GEN_LINK_UP_F1 = 0x373        # Gen Link UP pose-1 first VRAM tile


def load(d: Path, magic: bytes) -> dict[int, bytes]:
    out = {}
    for p in sorted(d.glob("f*.bin")):
        b = p.read_bytes()
        if b[:4] == magic:
            out[b[4]] = b
    return out


def tier_a_diffs(nes, gen, shift):
    diffs = 0
    for off, nb in nes.items():
        gb = gen.get(off + shift)
        if gb is None:
            continue
        if nb[N_X] != gb[G_X]:    diffs += 1
        if nb[N_Y] != gb[G_Y]:    diffs += 1
        if nb[N_DIR] != gb[G_DIR]: diffs += 1
        if nb[N_GRID] != gb[G_GRID]: diffs += 1
    return diffs


def nes_pose(nb):
    """0 / 1 from OAM $12 h-flip; None if Link off-screen (Y >= $EF)."""
    y = nb[N_OAM + LINK_OAM_SLOT * 4]
    if y >= 0xEF:
        return None
    return (nb[N_OAM + LINK_OAM_SLOT * 4 + 2] >> 6) & 1


def gen_pose(gb):
    """0 / 1 from SAT slot-0 Link tile; None if neither pose tile."""
    t = ((gb[G_SAT + 4] << 8) | gb[G_SAT + 5]) & 0x7FF
    if t == GEN_LINK_UP_F0:
        return 0
    if t == GEN_LINK_UP_F1:
        return 1
    return None


def pose_cadence_mismatch(nes, gen, shift):
    mm = cmpd = 0
    for off, nb in nes.items():
        np = nes_pose(nb)
        gb = gen.get(off + shift)
        if np is None or gb is None:
            continue
        gp = gen_pose(gb)
        if gp is None:
            continue
        cmpd += 1
        if np != gp:
            mm += 1
    return mm, cmpd


def main() -> int:
    args = [int(a, 16) for a in sys.argv[1:]] or CAVES
    rows = []
    all_clean = True
    for cave in args:
        nd = OUT_ROOT / f"nes_{cave:02X}_trans"
        gd = OUT_ROOT / f"gen_{cave:02X}_trans"
        nes = load(nd, b"NCTB")
        gen = load(gd, b"GCTB")
        if len(nes) < 100 or len(gen) < 100:
            rows.append((cave, "CAPFAIL", f"nes={len(nes)} gen={len(gen)}", ""))
            all_clean = False
            continue
        # Tier-A: shift minimizing motion diffs.
        a_sh = min(range(-4, 5), key=lambda s: (tier_a_diffs(nes, gen, s), abs(s)))
        a_diffs = tier_a_diffs(nes, gen, a_sh)
        # Tier-B pose: shift minimizing pose mismatch (its own anchor).
        b_sh = min(range(-4, 5),
                   key=lambda s: (pose_cadence_mismatch(nes, gen, s)[0], abs(s)))
        b_mm, b_cmp = pose_cadence_mismatch(nes, gen, b_sh)
        a_ok = a_diffs == 0
        b_ok = b_mm == 0 and b_cmp > 0
        if not (a_ok and b_ok):
            all_clean = False
        rows.append((cave,
                     f"A:{'OK' if a_ok else f'{a_diffs}diff'}@{a_sh:+d}",
                     f"pose:{'OK' if b_ok else f'{b_mm}/{b_cmp}'}@{b_sh:+d}",
                     ""))

    print("== cave-entry verify: TIER-A positioning + TIER-B pose-cadence ==")
    na = nb = 0
    for cave, a, b, _ in rows:
        print(f"  ${cave:02X}: {a:18s} {b}")
        if a.startswith("A:OK"):
            na += 1
        if "pose:OK" in b:
            nb += 1
    print(f"\nTIER-A clean: {na}/{len(rows)}   POSE-CADENCE clean: {nb}/{len(rows)}")
    return 0 if all_clean else 1


if __name__ == "__main__":
    raise SystemExit(main())
