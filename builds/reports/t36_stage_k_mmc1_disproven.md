# T36 Stage K — MMC1 Auto-Refresh DISPROVEN

## Hypothesis (plan `concurrent-watching-sky.md`)

Auto-refresh `$FF8000` bank window on every MMC1 PRG bank write so
cave-interior code that reads `$8xxx-$BFFF` pointers (text strings,
level-block data, spawn tables) returns correct bank data.

Predicted to close:

1. Textbox zeros (`"000000..."` instead of `"It's dangerous..."`)
2. Wrong BG tiles in cave
3. Cave lag
4. `$0350 = $6A` phantom cave-person spawn
5. `$00AC` halt / frozen Link

## Result: DISPROVEN twice

### Attempt 1 — `0eebfa74`
- Added `bsr _copy_bank_to_window` inside `_mmc1_common` after PRG
  register store.
- Result: boot stuck at mode $0F.
- Reverted as `477fd4da`.

### Attempt 2 — `354a1cdf` (safer register preservation)
- Added `movem.l D0/A0-A1,-(SP)` around the bsr + `moveq #0,D0`
  to zero upper bits.
- Boot succeeded visually but **T8 NMI cadence collapses 81.4% → 22.9%**.
- 3.5x real-time slowdown. Cave capture probe cannot reach mode 5
  within its frame budget.
- Reverted as `4a620a13`.

### Why auto-refresh is wrong even in principle

`_copy_bank_to_window` is a 16KB longword copy (≈ 50 k cycles each
time, ~40% of a 60 Hz frame on 7.67 MHz 68000). Zelda switches PRG
banks multiple times per frame for subroutine calls into other
banks. Eager copy on every bank write costs more frames than it saves.

The cache check at `_copy_bank_to_window:1627` (`cmp.b (_current_window_bank).l,D0`)
doesn't help here — the game does switch to a *different* bank each
time, satisfying the miss condition. Every cave-enter cycle the game
may legitimately rotate through banks 0-5.

## Actual observations from cave capture

### Gen (with MMC1 fix reverted — current state)

- `t=0 lvl_block=$77 sram_lvl=$42 cavetype=$00` (stabilize snapshot)
- `t=308 lvl_block=$77 sram_lvl=$42 cavetype=$6A sub=8`
- `$0350 = $6A` is the **mathematically correct** cave-dweller base
  type from the formula `((b & $FC) - $40) >> 2 + $6A` with b=$42.

### NES reference

- `t=0 lvl_block=$77 sram_0975=$42 cavetype=$00`
- `t=1 lvl_block=$00 sram_0975=$00 cavetype=$00`
- NES scenario start clears `$FF00EB` and `$FF6975` *between the
  stabilize snapshot and the first scenario frame.* Gen does not.

So the real divergence is **upstream** in the InitMode path —
something clears `$00EB` (level-block-attr index) and the attr table
on NES but not Gen. `AssignObjSpawnPositions_InCave` math is correct
on both; the inputs differ.

## Parity status

`builds/reports/bizhawk_t36_cave_parity_report.txt`:

```
T36_NES_CAPTURE_OK: PASS  len=840
T36_GEN_CAPTURE_OK: PASS  len=840
T36_NO_GEN_EXCEPTION: PASS  no exception
T36_BASELINE_PARITY: PASS  obj_x:OK; obj_y:OK; mode:OK; room:OK
T36_WALK_TO_STAIR: PASS  nes_t=213 gen_t=213
T36_CAVE_ENTER_TRIGGERED: PASS
T36_CAVE_INTERIOR_MATCH: FAIL  first diff t=307
                         nes=(m$0B,x$70,y$DD) gen=(m$0B,x$40,y$5D)
T36_CAVE_EXIT_TRIGGERED: PASS  nes_t=748 gen_t=748
T36_ROUND_TRIP_READY: PASS
```

**8/9 PASS.** Residual: 1-frame sub-state lag in cave-init — Gen
still at sub=7 when NES advanced to sub=8. Positions converge at
t=308 onward. Not a bank/memory/SRAM issue; a timing issue in the
sub-state progression.

Visual: HUD corruption on overworld post-cave-exit (top strip mis-rendered).
Separate class of issue (CHR / nametable restore) — not this stage.

## Next plan

Do not touch MMC1 auto-refresh again. Next attempt (different
session) should investigate:

1. The mode $0B sub=7 → sub=8 transition — what routine runs there
   on Gen that takes an extra frame?
2. Where does NES clear `$FF00EB` and `$FF6975` between stabilize
   and t=1? Trace that init path on Gen.
3. The post-exit HUD corruption — likely a separate PPU/CHR restore
   bug unrelated to cave-enter parity itself.

None of those fit the "single-point fix" pattern, so they deserve a
fresh plan with fresh evidence, not variants of the bank-refresh idea.
