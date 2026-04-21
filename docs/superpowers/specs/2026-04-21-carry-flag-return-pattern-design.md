# Carry-Flag Return Pattern for C Porting

## Problem

361 `eori CCR` sites across all ASM banks represent functions that return a carry flag to callers. When `_stub_func()` replaces their body with `jmp c_<name>`, the carry normalization (`eori #$01,CCR`) is lost. Callers checking carry (`bcc`/`bcs`) after `jsr` get undefined CCR state from GCC's D0-clobbering ABI.

This is the single largest class of unportable functions, blocking ~95% of remaining code.

## Mechanism: Return Value Encoding

C functions that need to return carry use `unsigned int` return type:

- Bits 0-7: A register value (the normal return byte)
- Bit 8: carry flag (0x100 = carry set, 0x000 = carry clear)

```c
#define CARRY_SET 0x100

unsigned int z01_compare_example(unsigned int a, unsigned int b) {
    if ((unsigned char)a >= (unsigned char)b)
        return (unsigned char)a | CARRY_SET;
    return (unsigned char)a;
}
```

No global state. Self-contained per function. Self-documenting.

## Shim Template: Carry-Returning Export

After `jsr` to the C function, the shim extracts bit 8 into the M68K carry flag (X bit in CCR), then applies the `eori #$01,CCR` normalization that `_stub_func` removed from the original ASM body.

```asm
c_compare_example:
    andi.l  #$FF,D0
    move.l  D0,-(SP)
    ; ... push other args ...
    jsr     z01_compare_example
    addq.l  #4,SP          ; (or #8 for 2 args)
    btst    #8,D0
    beq.s   .no_carry
    ori     #$01,CCR
    bra.s   .apply_eori
.no_carry:
    andi    #$FE,CCR
.apply_eori:
    eori    #$01,CCR       ; 6502 carry normalization
    rts
```

Cost: 6 extra instructions per carry-returning shim vs. standard shim.

## Carry Semantics

The 6502 uses inverted carry for comparisons (`CMP` sets carry if A >= operand). The transpiler already emits `eori #$01,CCR` to normalize this. The C function models the *original 6502 carry sense* (set = true/success), and the shim re-applies the `eori` normalization so callers see correct CCR state.

## Implementation Order

### Phase 1: Infrastructure
- Add `#define CARRY_SET 0x100` to `src/nes_abi.h`
- Add carry-returning shim template to `src/c_shims.asm`
- Verify build with zero new functions (just infrastructure)

### Phase 2: z_01 Carry Utilities
Port ~20-30 carry-flag functions in z_01. Priority targets (called from multiple banks):
- Comparison/distance utilities (Abs variants, distance checks)
- Collision detection (DoObjectsCollide, threshold checks)
- Directional comparisons (GetOneDirectionAndDistance)

These are called from z_04/z_05/z_07, so porting them has maximum ripple effect.

### Phase 3: Cross-Bank Unlock
Re-scan all banks for functions now portable because z_01 carry utilities are in C. Port newly-unlocked functions in z_04 (hit detection), z_05 (door flags), z_07 (room flags).

### Phase 4: Propagate
Apply carry-flag pattern to remaining banks' own carry-returning functions. Target: all 361 carry sites eventually converted.

## Files Modified

| File | Change |
|------|--------|
| `src/nes_abi.h` | Add `CARRY_SET` macro |
| `src/c_shims.asm` | Add carry-returning shim variant, new shim bodies |
| `src/gen/z_01.c` | Port carry-flag utility functions |
| `tools/transpile_6502.py` | Add stubs in `_patch_z01()` for carry functions |

## Success Criteria

- Build boots clean after each phase
- Callers of carry-returning functions see correct `bcc`/`bcs` behavior
- Pattern documented and mechanical — no per-function design decisions needed
- Stub count increases by 20-30 in Phase 2, with further unlocks in Phase 3

## Risk

Low. Pattern is uniform and mechanical. Each function can be verified independently. If a carry sense is wrong, the symptom is a flipped branch — easy to diagnose by checking the original 6502 `CMP`/`SBC` semantics.
