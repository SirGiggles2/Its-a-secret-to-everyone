#!/usr/bin/env python3
"""cave_transition_sprite_diff.py — Tier-B per-frame Link SPRITE byte-diff.

Companion to cave_transition_diff.py (Tier A = RAM trajectory). This decodes
the LINK sprite on both platforms each frame of the cave-entry transition and
compares it pixel-for-pixel in the port's own CRAM color space:
  NES  Link = OAM slots $10-$13 (8x16 via ppuctrl), CHR from chr_ref.bin,
             sub-pal from the per-frame PALRAM -> misc_palettes LUT -> CRAM word.
  Gen  Link = SAT (chain-walked from $F400), tile pixels from vram_ref.bin,
             color from the per-frame CRAM.
Both sides decode to 8x8 grids of CRAM words (flip baked in), so a grid match
proves tile + h/v-flip + pixels + palette all agree — i.e. the visible walk
cadence (R2) and behind-BG result. Position match proves {y,x}.

This reuses the decoders in cave_byte_diff.py:
  load_nes_to_cram_lut, nes_sprites_with_chr (slots=Link), gen_sprites_with_vram,
  detect_offset, cram_to_rgb, Cell.

Bundle layouts (must match probe_{nes,gen}_cave_transition.lua capture()):
  NCTB: magic(4) frame(1) 13 state + OAM 256 @18 + PALRAM 32 @274 ; ppuctrl @16.
  GCTB: magic(4) frame(1) scene(1) linkxy(4) 12 state + SAT 2048 @22
        + CRAM 128 @2070 + NES-OAM-mirror 256 @2198.
  chr_ref.bin: "NCHR"(4) + CHR 8192 + CIRAM 2048.
  vram_ref.bin: "GVRM"(4) + VRAM 65536.

Anchor: NES frame 0 = GameMode=$10; Gen frame 0 = arm. Pass --shift to align
(default 2, matching cave_transition_diff.py's reported best shift); the Gen
frame compared to NES frame N is N+shift.

Usage:
  cave_transition_sprite_diff.py <nes_dir> <gen_dir> [--shift N] [--report out.txt]
Exit 0 iff every compared frame's Link sprite matches (pos + pixels); else 1.
"""
from __future__ import annotations
import argparse, sys
from pathlib import Path

# Reuse the verified decoders.
from cave_byte_diff import (
    load_nes_to_cram_lut, nes_sprites_with_chr, gen_sprites_with_vram,
    detect_offset, PALETTES_C, Cell,
)

# Bundle field offsets (mirror cave_transition_diff.py / the probes).
N_PPU = 16
N_OAM = 18
N_PAL = 274
G_SAT = 22
G_CRAM = 2070
LINK_OAM_SLOTS = range(0x10, 0x14)   # NES Link = OAM $10..$13


def load_frames(d: Path, magic: bytes) -> dict[int, bytes]:
    out = {}
    for p in sorted(d.glob("f*.bin")):
        data = p.read_bytes()
        if data[:4] == magic:
            out[data[4]] = data
    return out


def grid_key(px):
    """Hashable signature of an 8x8 CRAM-word grid (None=transparent)."""
    return tuple(tuple(row) for row in px)


def link_cells_nes(nctb: bytes, chr_ref: bytes, lut):
    oam = nctb[N_OAM:N_OAM + 256]
    palram = nctb[N_PAL:N_PAL + 32]
    ppuctrl = nctb[N_PPU]
    chr_ = chr_ref[4:4 + 8192]
    return nes_sprites_with_chr(oam, chr_, palram, ppuctrl, lut,
                                slots=LINK_OAM_SLOTS)


def link_cells_gen(gctb: bytes, vram_ref: bytes):
    sat = gctb[G_SAT:G_SAT + 2048]
    cram = gctb[G_CRAM:G_CRAM + 128]
    vram = vram_ref[4:4 + 65536]
    return gen_sprites_with_vram(sat, vram, cram)


def match_link(nes_cells, gen_cells, dx, dy):
    """Match each NES Link cell to a Gen cell at (nx+dx, ny+dy). Return
    (matched, pos_only, missing, detail). A position may hold MULTIPLE gen
    cells (overlapping sprites) — keep all candidates (defaultdict(list)) and
    accept the match if ANY candidate's pixel grid equals the NES cell's
    (a plain dict would silently drop all but the last → false MISSING)."""
    from collections import defaultdict
    gen_by_pos = defaultdict(list)
    for c in gen_cells:
        gen_by_pos[(c.x, c.y)].append(c)
    matched = pos_only = missing = 0
    detail = []
    for nc in nes_cells:
        gx, gy = nc.x + dx, nc.y + dy
        cands = gen_by_pos.get((gx, gy), [])
        nk = grid_key(nc.px)
        if not cands:
            missing += 1
            detail.append((nc, None, "MISSING"))
        elif any(grid_key(gcc.px) == nk for gcc in cands):
            matched += 1
            detail.append((nc, cands[0], "OK"))
        else:
            pos_only += 1
            detail.append((nc, cands[0], "PX-DIFF"))
    return matched, pos_only, missing, detail


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("nes_dir"); ap.add_argument("gen_dir")
    ap.add_argument("--shift", type=int, default=2,
                    help="Gen frame compared to NES frame N is N+shift")
    ap.add_argument("--report", default=None)
    a = ap.parse_args()

    nes = load_frames(Path(a.nes_dir), b"NCTB")
    gen = load_frames(Path(a.gen_dir), b"GCTB")
    chr_ref = (Path(a.nes_dir) / "chr_ref.bin").read_bytes()
    vram_ref = (Path(a.gen_dir) / "vram_ref.bin").read_bytes()
    if not nes or not gen or chr_ref[:4] != b"NCHR" or vram_ref[:4] != b"GVRM":
        print(f"FATAL: bad inputs (nes={len(nes)} gen={len(gen)} "
              f"chr={chr_ref[:4]!r} vram={vram_ref[:4]!r})")
        return 1
    # Length guards (reviewers: truncated bundles → bare IndexError). Fail loud.
    if len(chr_ref) < 4 + 8192 or len(vram_ref) < 4 + 65536:
        print(f"FATAL: ref too short (chr={len(chr_ref)} vram={len(vram_ref)})")
        return 1
    for tag, frames, need in (("NCTB", nes, N_PAL + 32), ("GCTB", gen, G_CRAM + 128)):
        bad = [o for o, d in frames.items() if len(d) < need]
        if bad:
            print(f"FATAL: {len(bad)} {tag} bundles shorter than {need} "
                  f"(e.g. fr{bad[0]}={len(frames[bad[0]])})")
            return 1
    lut = load_nes_to_cram_lut(PALETTES_C)

    # Global NES->Gen sprite offset. detect_offset free-votes over
    # nes_Link x gen_ALL; in caves the 2 static bonfires + NPC produce many
    # spurious (dx,dy) pairs that can outvote the 8 Link-Link pairs and pick a
    # nonsense offset (observed: (-144,-248)). Sprites share screen coords with
    # BG, so the true offset is near the BG-proven (0,-8). Constrain the vote
    # to a sane screen window |dx|,|dy+8| <= WIN and accumulate per-delta votes
    # across all frames; fall back to (0,-8) if nothing lands in-window.
    from collections import Counter
    WIN = 24
    votes = Counter()
    for off, nctb in nes.items():
        gctb = gen.get(off + a.shift)
        if gctb is None:
            continue
        nc = link_cells_nes(nctb, chr_ref, lut)
        gc = link_cells_gen(gctb, vram_ref)
        if not (nc and gc):
            continue
        ngc = {(c.x, c.y) for c in gc}
        for n_ in nc:
            for gx, gy in ngc:
                ddx, ddy = gx - n_.x, gy - n_.y
                if abs(ddx) <= WIN and abs(ddy + 8) <= WIN:
                    votes[(ddx, ddy)] += 1
    dx, dy = votes.most_common(1)[0][0] if votes else (0, -8)

    lines = []
    def out(s=""): lines.append(s); print(s)
    out("== cave_transition_sprite_diff: TIER B (Link sprite, pixel-exact) ==")
    out(f"nes frames={len(nes)} gen frames={len(gen)} shift={a.shift} "
        f"offset=(dx={dx},dy={dy})")

    tot_n = tot_ok = tot_px = tot_miss = 0
    nes_offscreen = 0   # frames where NES Link OAM has 0 on-screen cells
    bad_frames = []
    for off in sorted(nes):
        gctb = gen.get(off + a.shift)
        if gctb is None:
            continue
        nc = link_cells_nes(nes[off], chr_ref, lut)
        gc = link_cells_gen(gctb, vram_ref)
        if not nc:
            # NES Link fully off-screen this frame (all of $10-$13 at Y>=$EF).
            # Reported for visibility (reviewers flagged a silent skip), but not
            # auto-failed: gc here is ALL gen sprites incl. static bonfires/NPC,
            # so it cannot cleanly isolate a Gen-Link-only render to gate on.
            nes_offscreen += 1
            continue
        m, p, miss, detail = match_link(nc, gc, dx, dy)
        tot_n += len(nc); tot_ok += m; tot_px += p; tot_miss += miss
        if p or miss:
            bad_frames.append((off, m, p, miss, detail))

    out(f"\nLink cells compared={tot_n}  OK={tot_ok}  PX-DIFF={tot_px}  "
        f"MISSING={tot_miss}  (NES-Link-offscreen frames={nes_offscreen})")
    if bad_frames:
        out(f"\n{len(bad_frames)} frames with Link sprite divergence:")
        for off, m, p, miss, detail in bad_frames[:24]:
            out(f"  fr{off:3d}: ok={m} px-diff={p} missing={miss}")
            for nc, gc, tag in detail:
                if tag != "OK":
                    g = f"GEN({gc.x},{gc.y}) {gc.src}" if gc else "GEN <none>"
                    out(f"      {tag}: NES({nc.x},{nc.y}) {nc.src}  vs  {g}")
        if len(bad_frames) > 24:
            out(f"    ... +{len(bad_frames)-24} more frames")

    verdict = "PASS" if (tot_px == 0 and tot_miss == 0 and tot_n > 0) else "FAIL"
    out(f"\n== TIER B VERDICT: {verdict} ==")
    if a.report:
        Path(a.report).write_text("\n".join(lines), encoding="utf-8")
        print(f"\nreport -> {a.report}")
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
