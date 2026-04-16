# T36 Stage H — MMC1 PRG Bank-Window Auto-Refresh (FAILED)

**Status**: Reverted. Does not work as a universal fix.
**Build tested**: Zelda27.180 (unguarded), Zelda27.183 (mode-gated).

## Hypothesis from plan `concurrent-watching-sky`

Add `bsr _ensure_bank_window` inside `_mmc1_common` (src/nes_io.asm
~line 2270) after the 5th-bit write commits to `MMC1_PRG`. Intent: whenever
the NES game switches PRG banks, update `$FF8000-$FFBFFF` to mirror the
new bank so every NES-pointer read (`NES_RAM + ptr = $FF8xxx`) returns
real data instead of stale bytes from whatever bank was live at the last
explicit pin.

Plan promised to fix:

1. Sword-cave textbox showing `"000000000000..."`
2. Wrong BG tiles inside the cave
3. Cave lag
4. Phantom cave-person spawn ($0350 = $6A)
5. Frozen Link

## What actually happened

### Iteration 1 — unconditional (Zelda27.180)

Game boot hung at mode `$0F` sub `$04` (title screen display) forever.
T36 gen capture `reached_mode5 = false`, `trace_length = 0`. The title
sequence never transitioned to file-select / overworld.

### Iteration 2 — gated on `GameMode >= $05` (Zelda27.183)

Boot succeeded (`reached_mode5 = true`, `T0_FRAME = 636`). Game entered
overworld. But Link could no longer walk. 840-frame trace:

```
FINAL t=839 x=$70.30 y=$8E.87 dir=$00 room=$77 mode=$05
```

Link starts at `x=$70`, the `walk_left` phase holds Left from t=60 to
t=101 expecting to reach `x=$40` — he never moved west.

T36 parity dropped from 8/9 (baseline) to 3/9:

```
T36_BASELINE_PARITY: PASS
T36_WALK_TO_STAIR:      FAIL  gen_t=None
T36_CAVE_ENTER_TRIGGERED: FAIL  gen mode never reached $10
T36_CAVE_INTERIOR_MATCH:  FAIL
T36_CAVE_EXIT_TRIGGERED:  FAIL
T36_ROUND_TRIP_READY:     FAIL
```

## Root cause of the failure

The codebase already contains **~18 manual `P33b`/`P33c` pin sites** that
call `_copy_bank_to_window` directly at translated-code points that need
a specific bank in the window:

```
src/zelda_translated/z_01.asm:786   bank 1 (textbox)
src/zelda_translated/z_03.asm:141,162,185,202   bank 3
src/zelda_translated/z_05.asm:4270,6779,7374,7398,7405,7783,7811,7860  bank 5
src/zelda_translated/z_06.asm:240   bank 6
```

These pins **intentionally disagree with `MMC1_PRG`**. The NES game
leaves `MMC1_PRG` at its last bank-switch value (often 5 or 7), but
the translated code needs bank 1 (or 3, or 6) loaded for a specific
pointer-through-ROM read.

A universal auto-refresh on `MMC1_PRG` commit undoes every pin the
moment the NES code does its next bank write. Mid-frame this is
catastrophic — the bank window flips out from under an active read.

In mode `$05` the overworld update loop writes `MMC1_PRG` multiple times
per frame. Every write now resets the window to whatever NES-bank was
last selected, overwriting the carefully-staged bank 5 (or whatever)
that the manual pins installed. Link's movement state machine reads
pointer tables in the wrong bank → no dispatch happens → Link freezes.

## Why the earlier P33 scheme exists

When the Genesis port reads an NES pointer in the $8xxx range, it maps
`NES_RAM + ptr = $FF8xxx`, i.e. the bank window. For this to return
valid data, the right 16 KB bank image must have been copied into
`$FF8000-$FFBFFF` before the read.

The port's approach is to **manually pin** at every code site that
reads a pointer into a specific bank: `moveq #N,D0 / jsr
_copy_bank_to_window` just before the read. This decouples the
"which bank is in the window for pointer reads" question from the
"which bank did the NES game select via MMC1" question — they're
allowed to disagree, because translated code only reads through the
window at pinned sites.

## Conclusion

Universal auto-refresh on MMC1 PRG write is **fundamentally incompatible**
with the P33 pin scheme. To fix cave-interior stale reads (textbox
zeros, wrong BG tiles, phantom spawn) the correct approach is to:

1. Identify each cave-interior pointer-through-ROM read in translated
   code that currently reads stale data.
2. Add a P33b-style `moveq #N,D0 / jsr _copy_bank_to_window` pin at
   that site, with N = the bank containing the pointer target.

The plan's claim of "one bsr addition with maximal blast radius" was
wrong: the blast radius includes collateral damage to every existing
pin. Follow-up work should treat each cave symptom as its own pin-
insertion task, matching the P33b pattern.

## Artifacts

- `src/nes_io.asm:2270-2285` — reverted to baseline; comment block
  documents the failed experiment.
- Build baseline restored: T36 gen capture reaches mode $05 at frame
  636, Link walks to x=$40 (walk_left), enters cave, exits, returns
  to overworld. Parity back at 8/9.
