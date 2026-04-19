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
