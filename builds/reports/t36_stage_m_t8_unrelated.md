# T36 Stage M — T8 NMI Cadence NOT the Cause of Cave 1-Frame Lag

## Context

Stage L (`builds/reports/t36_stage_l_sub7_lag.md`) hypothesized that
the cave sub=7 1-frame lag at T36 was a symptom of the pre-existing
T8 NMI cadence regression (81.4% vs prior 97.8%).  The "fix" was to
restore cadence to 95%+ and expect T36 to auto-close.

Stage M sets out to confirm the mechanism, builds a controlled
experiment, and **disproves the linkage**.

## Experiment 1 — Boot probe fix

`tools/bizhawk_boot_probe.lua` had ROOT hard-coded to the main tree,
so from a worktree it silently read `main/builds/whatif.lst` instead
of the worktree's own listing.  All landmark addresses (IsrReset,
RunGame, LoopForever, IsrNmi) resolved wrong, and the 300-frame soak
never observed any of them.  This was independent noise that would
have blocked any further Stage L progress.

Fix: honor `CODEX_BIZHAWK_ROOT` env var (same pattern as the cave
capture harness), fall back to main tree only if unset.  Committed
as `ea3eb939`.

Fresh boot probe now captures cleanly:

```
first_nmi=f20  eligible=280  with_nmi=228  multi_nmi=0  rate=81.4%
14 PASS / 1 FAIL (T8_NMI_CADENCE only)
```

Reproducing the Stage L baseline exactly.

## Experiment 2 — VBlankISR isolation

Hypothesis: the added work in `VBlankISR`
(`_ags_prearm`, `_mode_transition_check`, `music_tick`, `_ags_flush`)
was pushing runtime past one frame, causing NMI to pile up.

Test: temporarily comment out **all four** `bsr` calls in VBlankISR,
rebuild, re-run boot probe.

Result:

```
first_nmi=f20  eligible=280  with_nmi=228  multi_nmi=0  rate=81.4%
```

**Identical to 4 decimals.**  With zero auxiliary work in VBlankISR,
cadence is unchanged.  Therefore VBlankISR runtime is **not** the
cause of missed NMIs.

## Experiment 3 — PPUCTRL.7 trace

Instrumented the probe to sample `PPU_CTRL` shadow (`$FF0804`) every
frame and emit the list of frames where bit 7 (NMI-enable) is clear.

Result:

```
PPUCTRL.7=0 at frames: 1-18,21-70,73-80
```

- f1-f18: boot reset (expected — NMI off until RunGame writes $A0)
- f20: first NMI entry
- f21-f70: 50 consecutive frames NMI is disabled **by game code**
- f73-f80: another 8 frames disabled
- f81+: NMI on continuously through end of probe

The "52 missed NMIs" of T8 are **not missed NMIs at all**.  The
VBlankISR `btst #7,(PPU_CTRL)` gate is behaving correctly — the game
explicitly cleared PPUCTRL.7 during boot init.  IsrNmi wasn't meant
to run those frames.

## Why the 97.8% → 81.4% apparent regression

- 6c25a3c7 probe: `first_nmi=f22  eligible=278  with_nmi=272` →
  only 6 frames in the post-LoopForever window had NMI off.
- Current:       `first_nmi=f20  eligible=280  with_nmi=228` →
  52 frames have NMI off.

Absolute NMI count dropped 272 → 228 = 44 fewer fires, but this is
**not caused by the VBlankISR path.**  It is caused by the game
staying in its "NMI-disabled boot init" phase for 44 more frames than
before.  That extension is driven by main-thread code — transpiled
Zelda + any new NES I/O helpers (MMC1 bank copies, transfer
interpreter, palette cache).

The `btst` gate is correct.  The probe metric is correct.  But the
**metric is boot-phase specific**, not a measure of gameplay lag.

## Implication for T36

Cave capture runs long after boot.  By frame 80+ NMI is on
continuously.  The cave scenario executes at frame ~307 in capture
time, well into the NMI-on window.  **T8 cadence has no bearing on
cave sub=7 timing.**

The Stage L hypothesis — "restore T8 cadence and T36 auto-closes" —
is therefore disproven.  T36 residual 1-frame lag is independent of
boot-phase NMI suppression.

## Next-action triage

1. T36 cave 1-frame lag: still unexplained.  Sub=7 handler has no
   frame-split loop (Stage L confirmed).  A fresh hypothesis is
   needed — probably inspect what NES did during frame 306-307 that
   Gen did during 307-308 in more detail.  Park at 8/9 until then.

2. T8 boot-phase apparent regression: real (44 extra NMI-off frames)
   but cosmetic — doesn't affect gameplay.  Fixing it would require
   finding what makes boot init 44 frames slower on Gen than on the
   prior-cadence-fix build (e.g. MMC1 bank-copy cost via
   `_copy_bank_to_window`, or slower transfer buffer processing).
   Not urgent.

3. User-reported cave BG / sprite visual corruption: separate class.
   This is the next `/whatnext` target since T36 parity is parked
   and T8 is cosmetic.

## Evidence artifacts

- `builds/reports/bizhawk_boot_probe.txt` (current build,
  Zelda27.167) — 14/15 PASS, T8 FAIL at 81.4% with PPUCTRL trace
- `tools/bizhawk_boot_probe.lua` — now ROOT-aware, PPUCTRL frame
  trace instrumented
- Test rebuilds 165-167: confirmed VBlankISR body is timing-neutral
  against the T8 metric

## Parked

T36 cave parity: 8/9 PASS, residual is sub=7 1-frame lag, root
cause unknown.  Stage L and Stage M hypotheses both disproven.
