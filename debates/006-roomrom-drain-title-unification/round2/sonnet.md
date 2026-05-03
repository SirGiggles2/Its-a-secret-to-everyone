# SONNET ADVISOR — Round 2 (cross-critique, post-pivot)

## Pivot acknowledgment

My r1 picked A (delete RoomRom, fold into src/game/). User clarification
kills A: "I still want them to be separate roms... structurally combined
at the end." Codex + Gemini also picked A — all three of us misread the
testing-velocity constraint. Opus picked B (port drain INTO RoomRom) and
came closest to D, but B still assumed eventual single-tree.

## 1. Pick: **D3** (one platform_abi.h, `#ifdef ROOMROM_BUILD` drops A4)

Defend: D1 forks the header and guarantees drift (two ABI definitions =
two truths, violates `feedback_long_term_fix`). D2 sacrifices Title.md's
A4-relative perf which IS measurable on the transpiled hot paths (every
nes_ram access becomes a memory indirection, not a register-relative
EA). D3 keeps **one source of truth** for the ABI, lets the compiler
pick substrate per ROM, and matches how SGDK projects already gate
hardware variants. Opus's B-style adapter (`compat/nes_ram.{h,c}`) is
exactly D3 minus the unification — promote it from RoomRom-local to
shared header.

## 2. R1 plan adjustment

Drop "git mv RoomRom into src/game/." Keep oracle/ split. Add
`src/platform_abi.h` with `#ifdef ROOMROM_BUILD` guard. Both `Title.elf`
and `RoomRom.elf` link the same `src/game/` objects, compiled twice
with different `-DROOMROM_BUILD` flags. Build dir splits:
`builds/title/*.o` vs `builds/roomrom/*.o`.

## 3. RoomRom boot-direct value preserved

RoomRom keeps its own `genesis_shell.asm` entry pinned to gameplay
init. src/game/ code is substrate-agnostic via D3 macros. Title.md
boot path stays in `src/frontend/` — RoomRom doesn't link it. Sub-second
gameplay loop intact; Title's intro/title/story crash isolated to its
own ELF.

## 4. Rule D1 + full_native_rewrite

D1 (drain-first) survives: drain stays in `src/oracle/`, ported into
`src/game/` per family. `feedback_full_native_rewrite` survives:
src/game/ is the native rewrite destination, just compiled twice.
Neither rule mandated single-ROM output.

## 5. Phase 12 gate redefined

OLD: "delete oracle, single tree." NEW: "both ROMs boot to gameplay
parity from shared src/game/; combine deliverable = single distributable
that bundles both .bin files OR a launcher selecting between them at
M68K reset." Combine = packaging concern, not source concern.

## 6. Maintainability ranking

**D3 > D1 > D2.** D3 = one header, two compiles, zero drift surface.
D1 = two headers, guaranteed divergence over time (Codex's "behavior
drift" risk applies HERE). D2 = perf hit on Title's measured hot paths
(nes_ram indirection on transpiled inner loops); also forces re-verify
of every drained MATCH function.

## 7. Most autonomous

**D3.** Mechanical: add ifdef, duplicate build target, run both ELFs
through existing parity oracle harness (commit b476a2a5). Gemini's
GREEN rating transfers cleanly. D1 needs human judgment on which
header to update per change (drift triage). D2 needs perf re-baseline.

## 8. New top risk

**Build-matrix combinatorial explosion.** Two ROMs x growing subsystem
count = N x 2 build paths to keep green. Mitigation: CI gate that
builds BOTH targets per commit; fail-fast if either breaks. Opus's
worktree-discipline risk (`feedback_check_worktree_first`) compounds:
now BOTH ELFs must build in BOTH worktrees.

## 9. Final stance

D3 with oracle/ split. RoomRom permanent. Title.md permanent. Shared
src/game/ compiled twice via `#ifdef ROOMROM_BUILD`. Combine = Phase
12 packaging step.

## Convergence/divergence

- **Drain-as-oracle vs runtime**: CONVERGE with Opus + my r1 — oracle.
  Codex/Gemini implied runtime-then-replace; under D3 oracle wins
  cleanly because src/game/ isn't load-bearing for either ROM yet.
- **Debug boot mode**: CONVERGE all four — necessary. Title needs it
  to bypass story crash; RoomRom IS the debug boot.
- **First commit content**: DIVERGE. Codex/Gemini said "debug boot
  flag in Title." Opus said "substrate adapter in RoomRom." I now say
  **`src/platform_abi.h` with ROOMROM_BUILD ifdef + dual-target
  build.bat** — unblocks both directions in one commit.
