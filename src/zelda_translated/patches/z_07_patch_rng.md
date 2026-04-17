# z_07 patch — RNG scramble loop carry preservation

**File:** `src/zelda_translated/z_07.asm`
**Routine:** `_L_z07_IsrNmi_LoopRandom` (transpiled from `@LoopRandom` in `reference/aldonunez/Z_07.asm:511`)
**Milestone:** T38 enemy AI

## What the transpiler emits

```asm
_L_z07_IsrNmi_LoopRandom:
    move.b  ($00,A4,D2.W),D1
    roxr.b  #1,D1   ; ROR $00,X
    move.b  D1,($00,A4,D2.W)
    addq.b  #1,D2
    subq.b  #1,D3
    bne  _L_z07_IsrNmi_LoopRandom
```

## Why this breaks

The 6502 loop rotates 13 consecutive bytes through the carry bit
(`Random` at `$18–$24`). Each `ROR $00,X` reads carry, rotates the memory
byte, and writes the new carry — the carry chain is what makes the
scrambled value flow between bytes.

On M68K, `roxr.b` uses the **X flag** as the carry. But `addq.b #1,D2`
and `subq.b #1,D3` both **modify X** as a side effect of their
arithmetic result. So after the first iteration X is reset (to 0, since
D3 doesn't underflow on the way down from 13), and every subsequent
`roxr` rotates a 0 bit in from the top. Each frame the NMI handler
therefore zeros bytes 1..7 of `Random`.

All enemy-AI code reads `Random, X` (X = object slot 1..8) and gets
`$00` every frame — so every enemy makes the same "random" decision,
which presented as all Octoroks in room `$76` moving in lockstep after
T38's transpiler fix for `.LOBYTES`/`.HIBYTES` corrected their spawn
positions.

## Patch

Preserve X across the index updates by capturing it to a scratch
register (`D6`) with `SCS`, then restoring before the loop branch:

```asm
_L_z07_IsrNmi_LoopRandom:
    move.b  ($00,A4,D2.W),D1
    roxr.b  #1,D1
    move.b  D1,($00,A4,D2.W)
    scs     D6              ; D6.b = $FF if X(C)=1, else $00
    addq.b  #1,D2
    subq.b  #1,D3           ; sets Z from D3 (not used -- BNE retests below)
    add.b   D6,D6            ; $FF -> X=1, $00 -> X=0; clobbers N/Z
    tst.b   D3              ; re-set Z for the loop branch
    bne  _L_z07_IsrNmi_LoopRandom
```

`scs` stores $FF or $00 based on the carry flag (which equals X after
`roxr`). After the `addq/subq` have run their course, `add.b D6,D6`
shifts the saved value back into X (byte add with $FF sets X, with $00
clears it). `tst.b D3` then restores Z for the loop branch.

## Re-apply recipe

1. Run the transpiler: `build.bat` (or `python tools/transpile_6502.py --all --no-stubs`).
2. Open `src/zelda_translated/z_07.asm`, locate label
   `_L_z07_IsrNmi_LoopRandom`.
3. Replace the three lines `addq.b  #1,D2` / `subq.b  #1,D3` /
   `bne  _L_z07_IsrNmi_LoopRandom` with the six-line sequence above
   (`scs D6` + `addq` + `subq` + `add.b D6,D6` + `tst.b D3` + `bne`).

## Long-term fix

Teach `transpile_6502.py` that any M68K instruction that clobbers X
must cache X across the clobber whenever the preceding `ROXR/ROXL` was
part of a memory-indexed rotate loop (6502 `ROR zp,X` / `ROL zp,X`
inside a `DEY/BNE` or `INX/CPX` loop). Simplest implementation: detect
the ROR/ROL memory-indexed mode and emit `scs D6` immediately after,
then whenever the next branch condition needs Z it emits `add.b D6,D6`
+ `tst.b` pair. Fall-through cost is tiny and always correct.
