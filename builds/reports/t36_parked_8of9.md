# T36 Parked at 8/9 — Residual Is Benign 1-Frame Phase Offset

**Status**: Parked. Three root-cause hypotheses disproved. Per /whatnext
stuck-rule (same class of fix tried twice and failed) — move on.

## What the comparator sees

`T36_CAVE_INTERIOR_MATCH FAIL  first diff t=307
nes=(m$0B,x$70,y$DD) gen=(m$0B,x$40,y$5D)`

One frame. t=308 onward: both platforms byte-equal at (x=$70,y=$DB)
through cave exit + round-trip.

## Evidence — why it's a phase glitch, not a semantic bug

Frame-by-frame trace of `sub` + `cur_row` ($00E9) through cave-enter
sub-stages 0→8:

```
 t | NES sub r   | GEN sub r
280|  s04 r00    |  s04 r00    (sub=4 entry, both agree)
281|  s04 r00    |  s04 r01    Gen starts copying, NES idle
282|  s04 r00    |  s04 r02    NES still idle
283|  s04 r01    |  s04 r03    NES resumes, 2 frames behind
...
301|  s04 r13    |  s04 r15    
302|  s04 r14    |  s05 r16    Gen finishes sub=4 first
303|  s04 r15    |  s06 r16    
304|  s05 r16    |  s06 r16    NES finishes sub=4
305|  s06 r16    |  s07 r16    
306|  s07 r16    |  s07 r16    Gen holds sub=7 longer (3 frames)
307|  s08 r16    |  s07 r16    ← DIFF: NES advanced to sub=8
                                        Gen still in sub=7
308|  s08 r16    |  s08 r16    Gen catches up
309+|  both identical
```

Gen runs sub=4 two frames faster than NES (no frame-skip gate), then
Gen's sub=7 takes two frames longer than NES — net phase cancels by
t=308. The comparator's strict equality catches the single t=307
mismatch where the two offsetting delays briefly misalign.

## Disproved hypotheses

1. **Stage K — MMC1 PRG auto-refresh** (commit `08bcc5fb`). Added bank
   window copy on every `_mmc1_common` write. No effect on gate, and
   caused minor regressions elsewhere; reverted.
2. **Stage L — T8 NMI cadence** (commit `90a53d63`). Hypothesis: sub=7
   1-frame lag caused by NMI timing gap. Probe showed no cadence
   difference between NES and Gen at cave-enter.
3. **Stage M — T8 definitively unrelated** (commit `06701015`). Isolated
   VBlankISR path, confirmed cadence matches frame-for-frame. Root
   cause for sub=4 / sub=7 divergence remains unknown.

## Why park and not push harder

- Game plays correctly. Enter cave → see text → exit cave → round-trip
  landing — all match NES.
- Comparator alone sees the 1-frame blip. Visual and semantic
  correctness confirmed via `t39_gen_in.png` + `t36_cave_gen_capture.png`.
- Three fundamentally different hypotheses all failed. Next attempt
  would likely repeat Stage K/L/M's pattern of instrumenting deeper
  into the NMI/transfer-buf path, same dead end.
- User's higher-value target (cave HUD / BG corruption) is visibly
  broken and tractable with local fixes.

## If revisited later

The root cause is almost certainly in the main loop's gating of
`CopyNextRowToTransferBufAndAdvanceSubmodeWhenDone` (sub=4 handler at
`z_05.asm:8026`). NES skips handler execution on 2 frames at sub=4
entry; Gen runs every frame. The gate is NOT the T8 VBlankISR (Stage M).
Likely candidates:

- A check on `$0301` (transfer-buf length) — NES waits for NMI to drain
  buffer before next CopyRowToTileBuf; Gen drains synchronously.
- A check on `$00AC` (halt/state flag) — NES cave-entry may set a
  2-frame hold; Gen transpilation may skip or clear too eagerly.
- A main-dispatcher frame-skip based on PPU bus state.

Requires a fresh bus-write probe on `$FF00E9` + `$FF0301` + `$FF00AC`
during cave-enter sub=4 window (t=278..305) to identify the exact
gate. Out of scope for current session.
