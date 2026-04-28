<!-- docs/audit/abi_probe.md -->
# ABI Probe Results (locked at S0)

**Source:** `tools/probes/abi_probe.c`
**Listing:** `builds/abi_probe/abi_probe.s`
**Disasm:** `builds/abi_probe/abi_probe.disasm.txt`
**Compiler:** m68k-elf-gcc 13.2.0 (crosstool-NG, SGDK 2.x bundle)
**Compiler flags:** `-m68000 -ffixed-a4 -O1`

## Return registers

| Function | Return register | Notes |
|---|---|---|
| `u32 abi_ret_u32(void)` | `D0` | `move.l #0xDEADBEEF,%d0; rts` — 32-bit integer in D0 |
| `void *abi_ret_ptr(void)` | `D0` | `move.l #0xC0FFEE00,%d0; rts` — pointer also returned in D0, not A0 |

## Argument passing — `u32 abi_arg_mix(u16 a, u32 b, void *p)`

| Param | Type | Location on entry |
|---|---|---|
| `a` | u16 | Stack at sp+6 — `movew %sp@(6),%d0` after `moveq #0,%d0` (zero-extended to 32-bit) |
| `b` | u32 | Stack at sp+8 — `movel %sp@(8),%d1` |
| `p` | void * | Stack at sp+12 — `movel %sp@(12),%d1` |

All three arguments are passed on the stack (no register arguments). sp+4 is the return address (4-byte slot on m68k). Arguments begin at sp+6 because `a` (u16) is pushed as a 16-bit value aligned to sp+6, giving sp+4..5 = return address upper, sp+4 = full return addr longword, then u16 at sp+6.

Actually: sp+4 = return address (longword, 4 bytes), sp+6 = first arg `a` (u16, 2 bytes), sp+8 = second arg `b` (u32, 4 bytes), sp+12 = third arg `p` (pointer, 4 bytes).

## Callee-saved set (from MOVEM at function entry)

None observed — all three functions are leaf functions at -O1 that only use D0/D1. The contractual callee-saved set per System V m68k ABI is `D2-D7/A2-A6`; GCC emits MOVEM to preserve these only when a function actually uses them. The callee-saved contract is enforced by the ABI, not by the probe (which is too small to exercise it). See Section 4.5.

## Caller-saved set (proven by clobber)

`D0, D1` — both clobbered by `abi_arg_mix`. No address registers clobbered. Per System V m68k ABI the full caller-saved set is `D0, D1, A0, A1`; D0 and D1 are confirmed clobbered here.

## A4 register

Not touched in any of the three functions. `-ffixed-a4` keeps A4 reserved as the NES_RAM base pointer throughout; GCC does not allocate it as a scratch register.

## Struct return policy

Aggregates are forbidden in C↔asm signatures (spec rule). Probe does not
exercise struct returns; the rule stands by spec, not by probe.

## Pointer width

32-bit (m68k flat address space). Confirmed by load-immediate of
`0xC0FFEE00` into the pointer-return path.
