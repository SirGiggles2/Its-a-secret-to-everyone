# C-First Promotion Pipeline for m68k-elf-gcc Porting

## Problem

Current C conversion proves `m68k-elf-gcc` can build and link into the ROM, but project still lacks a stable long-term ownership model. Right now logic is split across:

- generated bank-shaped C in `src/gen/z_01.c` ... `z_07.c`
- a very large asm shim surface in `src/c_shims.asm`
- original transpiled asm / hardware glue still treated as structural center

That works for incremental porting, but it is not best long term for optimization. Giant generated C is hard to reason about, hard to profile cleanly, and tends to preserve bank-era structure instead of game-system structure. If project keeps treating generated bank files as final architecture, the C port will remain mechanically translated rather than becoming code that is easy to optimize, maintain, and test.

## Decision

Adopt a **C-first promotion pipeline**:

- `src/gen/z_*.c` remains **staging/reference code**, not final architecture
- long-term owned logic moves into **hand-maintained subsystem C modules**
- asm remains only where it is the right tool:
  - startup / vectors / ISR entry
  - raw hardware access
  - ABI bridges
  - rare cycle- or register-sensitive helpers

This keeps the translator valuable, but demotes it from "project architecture" to "migration and verification tool."

## Mechanism

### Source-of-truth rule

For any subsystem under active optimization, the source of truth becomes promoted hand-owned C, not generated bank C.

Generated C may still exist for:
- unfinished subsystems
- comparison/reference
- fallback during migration

But once a subsystem is promoted, new behavioral fixes and optimizations happen in owned C modules.

### Promotion path

Each subsystem follows the same path:

1. Existing translated asm/C continues to build and run.
2. A subsystem boundary is selected.
3. Its logic is moved into a hand-owned C module with an explicit header/API.
4. Callers are redirected through stable shim/helper interfaces.
5. Probes/regression coverage are attached to that subsystem.
6. Generated bank code for that subsystem becomes reference-only or is reduced to thin forwarding glue.

This avoids random per-function drift and keeps every move testable.

### File ownership rule

- `src/gen/z_*.c`
  - machine-oriented staging
  - no long-term architectural ownership
  - minimal hand edits only when needed to unblock migration

- new promoted modules
  - subsystem-oriented ownership
  - readable names
  - explicit headers
  - preferred location for optimization/refactor work

- `src/c_shims.asm`
  - temporary interop layer
  - should shrink over time
  - new shim additions allowed only when they help promotion, not as permanent architecture

### Architecture rule

Human architecture should follow **game systems**, not original bank layout.

Good long-term module shapes:
- frontend / mode flow
- room load / room state
- object runtime
- player / combat
- enemies
- save / SRAM
- transfer buffer / PPU compatibility helpers

Bank files can remain build artifacts or references, but not the mental model for owned code.

### Testing rule

Use **milestone parity**, not strict per-function lockstep and not open-ended breakage.

Best long-term testable workflow:
- allow temporary subsystem-local churn
- require buildable state and focused verification at subsystem boundaries
- preserve regression probes for already-stable behavior
- add targeted probes for promoted subsystems when old probes are too bank-specific

This balances architecture progress with safety.

## Implementation Order

### Phase 1: Stabilize C/ASM contract

Define and document:
- ABI rules between asm and GCC C
- register preservation rules
- carry/flag return conventions
- NES RAM access conventions
- when helper logic belongs in C vs asm

Goal: make interop predictable before larger promotion.

### Phase 2: Establish first promoted subsystem

Choose one subsystem already partly converted and valuable for optimization. Promote it out of `src/gen/z_*.c` into owned C files with clear headers and call boundaries.

Goal: prove the bank-to-subsystem promotion model works in the repo, not just in theory.

### Phase 3: Reduce shim sprawl

As promoted modules gain direct C-callable helpers, replace one-off asm trampolines with smaller, more regular interfaces. Keep asm shims only where truly needed.

Goal: stop `src/c_shims.asm` from becoming a permanent complexity sink.

### Phase 4: Repeat by subsystem

Migrate additional gameplay areas one subsystem at a time, preserving test coverage and using generated code as a reference oracle.

Goal: steadily shift the project center of gravity from translated bank code to owned subsystem C.

## Files Modified

| File | Change |
|------|--------|
| `src/c_runtime.h` | Expand core ABI/runtime declarations |
| `src/c_runtime.c` | Add shared runtime helpers / conventions |
| `src/c_shims.asm` | Normalize or shrink interop surface over time |
| `src/gen/z_01.c` ... `z_07.c` | Keep as staging/reference; reduce ownership burden |
| `tools/transpile_6502.py` | Support forwarding stubs / promotion boundaries where needed |
| `build.bat` | Keep promoted modules in build alongside generated units |
| `src/<new subsystem files>` | Long-term owned C implementation |
| `docs/superpowers/specs/...` | Record promotion policy and subsystem plan |

## Success Criteria

- ROM still builds through the current `m68k-elf-gcc` / `ld` / `objcopy` pipeline
- promoted subsystems have explicit owned C modules and headers
- optimization work happens in owned C, not giant generated bank files
- asm surface is smaller and better justified over time
- generated code remains useful as a migration/reference layer, but no longer defines long-term architecture
- each subsystem move remains testable with focused probes or parity checks

## Risk

Medium.

Main risk is split ownership: generated bank C and promoted subsystem C can diverge unless rules are explicit. If the project keeps mixing permanent fixes into both places, architecture becomes harder, not cleaner.

Mitigation:
- once promoted, owned subsystem C becomes authoritative
- generated bank code becomes staging/reference only
- shim additions must serve migration, not become default design
- promotion happens by subsystem boundary, not random isolated functions
