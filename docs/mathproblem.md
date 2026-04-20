# /mathproblem

**Definition.** A cheap 6502 op that the transpiler renders as a
verbose M68K sequence 10–20× slower than it should be. The transpiler
emulates 6502 semantics byte-by-byte — explicit carry flag manipulation,
zero-page pointer reconstruction, software-stack via `-(A5)` / `(A5)+` —
instead of using the native M68K equivalents which are one or two
instructions.

Net effect: Gen-side code that should beat NES throughput (we have 2×
raw MIPS and DMA) actually runs slower on hot paths. Discovered on
2026-04-18 while investigating room $73 music slowdown — Moblins firing
arrows at 4–8 active objects per frame pushed the 68K past 16.67 ms per
logical frame, dropping to ~44 fps (music at 73 % tempo).

## Patterns found

Counts are across `src/zelda_translated/z_00..z_07.asm` (excluding the
backup `.txt` copy). Cycle estimates include memory-op waits.

### 1. ZP-indirect-Y / ZP-indirect-X dereference (worst offender)

**Count:** 84 sites. Heavy in z_02 (39), z_05 (19).

Every `LDA ($nn),Y` turns into:

```
move.b  ($nn,A4),D1       ; 12
move.b  ($nn+1,A4),D4     ; 12
andi.w  #$00FF,D1         ;  8
lsl.w   #8,D4             ; 22
or.w    D1,D4             ;  4
ext.l   D4                ;  4
add.l   #NES_RAM,D4       ; 16
movea.l D4,A0             ;  4
move.b  (A0,D3.W),D0      ; 14
; total: ~96 cycles vs NES 5 cycles
```

A shadow 32-bit pre-converted Gen address maintained at write-time
(`STA ($nn)`) collapses the read path to `movea.l (shadow).l,A0 ;
move.b (A0,D3.W),D0` ≈ 30 cycles. Savings: ~66 cycles/fetch × 8
fetches/frame × 45 frames/sec ≈ 24000 cycles/sec recovered per hot
loop. A rough measurement on $73 says this alone could buy back
~3 fps.

### 2. 6502 stack via `-(A5)` / `(A5)+` (PHA/PLA emulation)

**Count:** 437 sites. Heavy in z_04 (135), z_05 (98).

Each 6502 `PHA` = 3 cycles becomes `move.b D0,-(A5)` ≈ 12 cycles; `PLA`
= 4 cycles becomes `move.b (A5)+,D0` ≈ 12 cycles. 4× slower on average.

Many PHA/PLA pairs exist only to preserve A across a single address
computation. The transpiler could emit `move.b D0,D6` / `move.b D6,D0`
(register-to-register, 4 cycles each) when it can prove no intervening
subroutine call clobbers D6 — a classic dead-stack optimization.

### 3. ADC/SBC with explicit CCR flip (flag-polarity workarounds)

**Count:** 535 `addx.b` / `subx.b` sites + 868 `andi/ori/eori #x,CCR`
manipulations. Heavy in z_04 (199 addx, 308 CCR), z_01 (99 addx, 183
CCR), z_05 (80 addx, 163 CCR).

Every `SBC` emits:

```
eori    #$10,CCR  ; flip X: 6502 SBC polarity   ; 20
subx.b  D1,D0                                   ;  4
eori    #$10,CCR  ; restore X = 6502 C          ; 20
; total: ~44 cycles vs NES 3 cycles
```

Every `CLC` → `andi #$EE,CCR` ≈ 20 cycles. Every `SEC` → `ori #$11,CCR`
≈ 20 cycles. The NES carry flag is rarely needed across statement
boundaries — most ADCs are followed immediately by a store with no
further ADC in between. A carry-tracking pass could elide the CCR ops
when the next carry-consuming op is itself an ADC/SBC (no intervening
code depends on the M68K X bit).

### 4. Sign-extension + NES→Gen relocation (`ext.l` + `add.l #NES_RAM`)

**Count:** 173 ext.l + 170 `andi.w #$00FF` zero-extends. Heavy in z_02
(77+77), z_05 (54+54).

Many sites build a 16-bit NES pointer in a word register, then
`ext.l` + `add.l #NES_RAM` to relocate it. Each relocate is ~20 cycles.
Because `NES_RAM = $FF0000`, a cheaper alternative when building from
scratch is to `move.l #NES_RAM,Dn` first and OR/add the low 16 bits —
avoids the sign-extend. For pointers repeatedly used, cache the Gen
address (same as Pattern 1's fix).

### 5. Inner-loop per-tile guard checks (already fixed 2026-04-18)

The P45 HUD guard inside `_transfer_tilebuf_fast` was running 3 memory
reads + 3 compares per NT tile. Hoisted out of the loop into a single
`tst.b D7` (computed once at function entry). Documented here as the
canonical template for the fix: **cache the invariant outside the
loop**.

## Phase 0 status (2026-04-19)

Shipped as commit `1504ecff` — P48. Native `MoveObject` replaces the
transpiled block in z_07.asm via `_patch_z07`'s `P48_WALKER` flag
(default on). Inlines q-speed fraction semantics so carry from each
`add.b`/`sub.b` is captured by `scc` immediately, then plain byte
arithmetic updates `ObjGridOffset` and `ObjX`/`ObjY`.

Parity: 180 logical ticks captured fresh-boot walk through
$77→$76→$75→$74 with P48=False vs P48=True. Byte-identical across
all 12 object slots × (type, x, y, dir, state, pos_frac, grid_ofs,
qspd_frac).

Global `AddQSpeedToPositionFraction` and `SubQSpeedFromPositionFraction`
labels in z_01.asm are untouched — other callers still use the
transpiled version.

Remaining: measure FPS improvement at $73 (blocked by a separate
TURBO_LINK-only freeze; see genesis_shell.asm TURBO_LINK equ line for
workaround). Once that's fixed, run walker_perf.lua at $73 with
P48=on vs P48=off and confirm the budgeted 44 → ≥48 fps gain.

## Stage 0 measurement (2026-04-19, P47 FIX cleared freeze)

Curated cycle profiler at `tools/cycle_probe.lua` measured 300 logical
ticks at $73 with 5 active objects (mode=$05 lvl=$00 room=$73). Savestate
at `C:\tmp\_gen_73_profile.State` (user-recorded). Artifacts:
`builds/reports/cycle_profile_73_p48off.csv`,
`builds/reports/cycle_profile_73_p48on.csv`.

| metric | P48 off | P48 on | Δ |
|---|---|---|---|
| logical FPS | 45.34 | **47.37** | +2.03 (+4.5%) |
| mean cyc/tick (proxy) | 169,176 | 161,931 | −7,245 |
| budget overrun vs 127,841 | 32.3% | 26.7% | −5.6pp |
| emu frames per logical tick | 1.323 | 1.267 | −0.056 |

Phase 0 budget was 44 → ≥48 fps. Measured 45.34 → 47.37 — missed ≥48 by
0.63 fps. Plan gate says "stop and revisit hotspot ranking" if Δ < 4 fps,
so Phase 1 (transpiler-wide shadow pointer + CFG carry elision) is NOT
justified on this evidence.

Top exclusive buckets (ESTIMATE: static_insts × 8 × calls/tick):

| bucket | calls/tick | est mean/tick | % of 169k tick |
|---|---|---|---|
| UpdateObject body | 6.83 | 8,090 | 4.8% |
| AddQSpeedToPositionFraction | 22.13 | 6,374 | 3.8% |
| Walker_Move body | 4.79 | 4,671 | 2.8% |
| AnimateAndDrawObjectWalking | 3.79 | 4,096 | 2.4% |
| UpdateArrowOrBoomerang body | 3.81 | 3,810 | 2.3% |
| GetCollidableTile | 2.65 | 2,865 | 1.7% |
| Walker_CheckTileCollision | 4.79 | 2,029 | 1.2% |
| UpdateMoblin body | 3.79 | 1,969 | 1.2% |
| MoveObject (transpiled) | 7.49 | 1,797 | 1.1% |

Sum of all instrumented buckets = 40,657 cyc/tick (24%). **76% of the
tick is in un-instrumented callees** — OAM fill, sprite draw, bank
window helpers, transpiled sub-functions invoked by the bucket bodies.
The /mathproblem patterns are most costly inside those callees, not
inside the hooked function bodies.

**Strategic implication.** Zeroing all top-5 hooked buckets saves
~27,000 cyc/tick = reaches ~53 fps, not 60. Hand-rewrite-only (Stage 1
in the plan at `C:\Users\Jake Diggity\.claude\plans\plan-it-with-this-peppy-peacock.md`)
has a ceiling below the target. The 60fps target requires the Stage 2
C-emission + freestanding m68k-elf-gcc backend to compound across all
un-instrumented callees.

**Measurement caveats.** BizHawk's Genesis Plus GX core does not
implement `TotalExecutedCycles()`. Per-bucket "cyc" values are
ESTIMATES = static_insts × 8 cyc/inst × calls. Static instr count is
EXCLUSIVE (body only, not callees). `tick_cyc` is DERIVED from
emu_frame-count × 127,841 (60Hz NTSC budget) — accurate to ±1 emu
frame per tick. Logical FPS is real (measured from FrameCounter
advance vs emu frames).

## Priority for fixes

| # | Pattern              | Sites | Cyc/site | Hot-loop impact |
|---|----------------------|-------|----------|-----------------|
| 1 | ZP-indirect-Y/X      |    84 |   ~66 saveable | High (walker AI) |
| 2 | PHA/PLA stack        |   437 |   ~8 saveable  | Medium (widespread) |
| 3 | ADC/SBC CCR flips    |   868 |   ~35 saveable | High (arithmetic-heavy) |
| 4 | ext.l / NES_RAM add  |   173 |   ~12 saveable | Medium |

Fix order should be 1 → 3 → 2 → 4. Pattern 1 is the highest-leverage
single change: a transpiler refactor to maintain shadow 32-bit addresses
for every NES zero-page pointer pair fixes 84 sites at once and has
the biggest impact on walker/arrow AI — the hot loop on $73 and every
edge-spawn room going forward.
