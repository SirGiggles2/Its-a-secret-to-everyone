# OPUS ADVISOR — Round 2 (architecture-first cross-critique)

## Stance

Vindicated, refined. R1 was the lone B vote because A inverted source-of-truth. User clarification confirms: two ROMs permanent, shared source. This is **Path D = B's substrate discipline applied to a permanent two-target build**. My r1 plan survives with one structural change: drain becomes oracle (Sonnet got this right), not runtime.

## 1. Pick: **D3** (single header, `#ifdef ROOMROM_BUILD` drops A4)

Defense (dependency-graph lens):
- **D1 (fork header)** = two source-of-truth roots. Any RAM-layout change touches both, drift inevitable, breaks Rule D1's spirit.
- **D2 (drop A4 everywhere)** = correct *structurally* but pays Title.md perf cost forever for a frontend slated for native rewrite anyway. Penalizes the wrong target.
- **D3** = one header, one struct definition, one truth. Build flag selects ABI. Codegen differs; semantics identical. This is exactly how SGDK itself handles `__GNUC__` / target variants. Zero drift surface.

Codex/Gemini/Sonnet's A is dead per user. Among D, only D3 keeps the dependency graph acyclic with a single root.

## 2. Adjusted r1 plan

- **B0 → D0**: substrate adapter becomes `src/platform_abi.h` with `#ifdef ROOMROM_BUILD` branch. Lives in shared `src/`, not `RoomRom/src/compat/`.
- **B1 → D1**: cave port targets `src/game/cave/` (shared), built by both ROMs. Title links via A4 path, RoomRom via pointer path.
- **B2**: leaf-by-family proceeds in `src/game/`, both builds consume.
- **B3 retired**: Title.md is no longer scheduled for deletion — it's a permanent test target.

## 3. RoomRom boot-direct-to-gameplay preservation

`RoomRom/src/boot/roomrom_main.c` stays RoomRom-only (not in `src/game/`). It's the *entry point*, not gameplay. Shared code = `src/game/`. Per-ROM code = `RoomRom/src/boot/` + `src/frontend/intro/`. Boot-path divergence is feature, not debt.

## 4. Rule D1 + feedback_full_native_rewrite

Both satisfied. Drain stays oracle (`src/oracle/` per Sonnet). Native impl in `src/game/`. Rule D1 = "drain before native" — drain done, port proceeds. `feedback_full_native_rewrite` = "rewrite native from NES reference" — `src/game/` IS the native rewrite, oracle is the reference. Two ROMs don't change the rewrite axis.

## 5. Phase 12 deliverable (revised)

No longer "merge two ROMs." New gate: **`src/oracle/` is empty AND both ROMs pass parity oracle harness on shared `src/game/`.** Two ROMs ship forever; oracle retires when last leaf ports.

## 6. D1 vs D2 vs D3 maintainability

**D3 > D2 > D1.** D3: one header, build-time switch, zero drift. D2: one header, runtime cost, Title.md slower forever. D1: two headers, manual sync burden, drift guaranteed within 3 commits.

## 7. Most autonomously achievable

**D3.** One file edit (`platform_abi.h`), one build.bat flag, no file moves, no header forks. GREEN. D1 needs sync discipline AI will violate. D2 needs perf regression baseline.

## 8. New top risk: "two ROMs forever"

**Build-matrix CI gap.** Today only Title.md builds in `build.bat`. RoomRom build lives in worktree. Two permanent targets = `build.bat` MUST build both, every commit, or one rots. Mitigation: single `build_all.bat` invoking both targets; Phase 0 task before any D-port.

## 9. Convergence/divergence

- **Drain-as-oracle vs runtime**: Converged with Sonnet (oracle). My r1 said "reference" — same thing, Sonnet's name better.
- **Debug boot necessity**: Converged 4/4 — required. RoomRom IS the debug boot under D.
- **First commit**: Diverged. Codex/Gemini = debug-boot flag. Sonnet = oracle rename. Mine = `platform_abi.h` D3 switch + `build_all.bat`. Mine is prerequisite to all others.

## Final stance

D3 + oracle/ + build_all.bat. Two ROMs permanent, one source tree, one ABI header with build-time branch. Ship.
