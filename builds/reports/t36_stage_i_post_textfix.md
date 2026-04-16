# T36 Stage I — after text-render fix (Zelda27.161)

## Summary

`.INCLUDE dat/*.inc` flattening landed. Sword-cave text, BG, and lag all
fixed. Visual confirmed: textbox reads "DANGEROUS... TAKE THIS".

Parity still 6/9 — remaining failures are **timing drift inside cave**,
not data-layer bugs.

## Remaining gate evidence

### T36_CAVE_INTERIOR_MATCH — fails at t=288

- NES t=277..307: Link sits at (x=$40, y=$5D) idle in cave (30 frames).
- Gen t=277..285: Link sits at (x=$40, y=$5D) idle in cave (9 frames).
- Gen t=286: autowalk=$2E kicks in, Link teleports to cave-entry
  (x=$70, y=$DB) and walks up to (x=$70, y=$D5).
- NES t=307: same teleport to (x=$70, y=$DD), walks to (x=$70, y=$D5).

**Gen compresses the cave-idle-before-autowalk from 30 → 9 frames.**

Root cause candidate: cave-person textbox state machine. On Gen the
textbox completes (or skips) ~21 frames faster than NES. This is the
same bank-pin / state-machine region where P33b earlier forced bank 1.

### T36_CAVE_EXIT_TRIGGERED — fails by 22 frames

`nes_t=749 gen_t=727` — 22-frame gap, matches the interior compression
almost exactly (21 frames earlier entry to autowalk).

### T36_ROUND_TRIP_READY — y diff

`nes y=$61, gen y=$7E` — Gen ends capture with Link further south
(closer to cave mouth).  Consistent with Gen exiting cave earlier and
having more frames on the overworld side.

## Stair-phase red herring (investigated, not the real issue)

Earlier noted: mode-$10 stair descent fires y-step every 4 frames, gated
by `$0015 & 3 == 0`.  NES fires on t=217,221,...; Gen on t=215,219,....
The 2-frame offset is from $0015 phase at capture T=0:

- NES boot to T=0: 351 NMIs → $0015=$5F mod 256
- Gen boot to T=0: 621 NMIs → $0015=$6D mod 256
- Δ = +14 = +2 (mod 4)

This is **capture-alignment**, not a game bug.  Real hardware would
show the same drift depending on when you hit Start.  Only 2 of the
missing 9-2=7 interior frames come from this; the other 19 come from
the textbox/person-state compression documented above.

## Files touched this stage

- `tools/transpile_6502.py` — `_flatten_includes` for dat/*.inc
- `tools/bizhawk_t36_cave_nes_capture.lua` — $0350 BP added
  (quickerNES silent, BP infrastructure documented non-functional)
- `builds/reports/t36_stage_i_post_textfix.md` — this doc

## Status

- Build: Zelda27.161, Checksum $E41C
- Visual: PASS (cave text + BG + no lag)
- Parity: 6/9 (unchanged — text fix is data-layer; remaining are
  state-machine timing inside cave mode $0B)
- Next stage target: cave-person textbox state machine in
  `UpdatePersonState_Textbox` timing.  Characters advance every
  6 frames per-char on NES; check if Gen advances faster due to
  missed bank pin or different loop-count.
