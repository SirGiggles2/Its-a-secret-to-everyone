# OPUS ADVISOR — Round 1 (Architecture-First Lens)

**Frame:** Two ROMs are two *build targets* over one shared substrate. Combinability is a dependency-graph problem, not a merge problem. Treat `Title.md` and `RoomRom` as siblings consuming the same `src/abi/` + `src/sgdk_adapter/` + `data/` library, with disjoint app layers (`src/frontend/` vs `RoomRom/src/` -> `src/game/`). Phase 12 must be a *no-op rebuild* of Title against promoted gameplay, not a merge.

## 10 ASKS

**1. Per-gap fixes.**
- G1 Phase 8: add `Worktree: Active RoomRom` (boss AI is gameplay).
- G2 Phase 9: split — HUD/save state in RoomRom; options UI in main (frontend-adjacent).
- G3 Phase 10: `Worktree: main` — audio_driver.asm is shared substrate, edited from main, consumed by both ROMs.
- G4: emit `docs/ACTIVE_PHASE.md` from a `tools/phase_pointer.py` updated on phase-close commit hook.
- G5: edit Task 0.2 line 135 now (see ask 9).
- G6: state contract migration owned by **main** (substrate), consumed by RoomRom; gate with shared-substrate check (ask 3).
- G7: rule — `src/sgdk_adapter/`, `src/abi/`, `src/state/`, `data/` edits ONLY from main worktree; RoomRom rebases on main weekly.
- G8: Phase 11 runs **parallel** to 2-7 but **gated** at 12 (see ask 7).
- G9: add `tools/check_frontend_boundary.py` to Phase 12 gate.
- G10: `tools/merge_readiness.py` (ask 4).

**2. Phase 8/9/10 worktree lines.**
- Phase 8: `Worktree: Active RoomRom implementation`
- Phase 9: `Worktree: split — RoomRom (HUD/save), main (options UI in src/frontend/options/)`
- Phase 10: `Worktree: main (shared substrate: src/audio_driver.asm)`

**3. Shared-substrate compile-both check.** Name: `tools/compile_both.py`. Behavior: after any commit touching `src/sgdk_adapter/`, `src/abi/`, `src/state/`, `src/audio_driver.asm`, or `data/`, build BOTH `Title.elf` (main) and `RoomRom.elf` (worktree); diff symbol tables for ABI drift; fail if either fails or symbol shapes diverge. Runs: pre-push hook on main + nightly CI on roomrom-s1.

**4. Merge readiness dashboard.** `tools/merge_readiness.py` reports: (a) RoomRom commits ahead of main, (b) shared-substrate diffs (drift risk), (c) frontend-boundary violations, (d) ABI symbol delta, (e) NES parity oracle pass-rate, (f) determinism hash match. Output sketch:
```
MERGE READINESS — 2026-05-02
substrate drift:    0 files (GREEN)
abi symbols:        +3 -0  (YELLOW: review state.h)
frontend boundary:  0 viol (GREEN)
parity oracle:      94/97  (YELLOW)
overall:            YELLOW — fix oracle 3 before Phase 12
```

**5. Phase 12 frontend-boundary check.** `tools/check_frontend_boundary.py`: greps `RoomRom/src/**` and (post-promotion) `src/game/**` for any `#include "frontend/...`, any reference to symbols defined under `src/frontend/`, any `extern` of frontend globals. Hard-fail in CI. Mechanical, not advisory.

**6. Phase 9 split.** RoomRom: HUD overlay renderer, heart/rupee/key counters, save-slot RAM layout, item-get HUD interrupt. Main: file-select sub-screens, options menu, save-file picker UI, all under `src/frontend/options/`. Save *format* (state header) lives in `src/state/` (main, substrate).

**7. Phase 11 vs 2-7.** **Parallel, gated at 12.** Title.md frontend gap-fill (intro polish, file-select fidelity) blocks no gameplay phase and consumes only substrate. Gate at Phase 12: both ROMs must pass `compile_both` + `merge_readiness GREEN` before promotion flips Title's main-loop dispatch.

**8. Memory entry sketch.** `project_active_phase_pointer.md`: "Active phase = Phase N (see docs/ACTIVE_PHASE.md). Worktree for current edit: <main|roomrom-s1>. Auto-updated by tools/phase_pointer.py on phase-close. Check before any RoomRom or substrate edit."

**9. Task 0.2 line 135 replacement.** Replace `whatif alias retained for legacy refs` with: `whatif alias REMOVED — all references must use Title; tools/check_no_whatif.py greps repo and fails CI on any 'whatif' string outside builds/whatif.elf legacy artifact and debates/.`

**10. Stance: YELLOW.** Plan is structurally sound and Prime-Directive-aligned (long-term, NES-spec, Genesis-native, Codex/Claude friendly), but ships with 10 holes that compound at Phase 12. Fix all 10 before Phase 8 starts. GREEN after `compile_both`, `merge_readiness`, `check_frontend_boundary`, and ACTIVE_PHASE pointer land.

Architecture verdict: ROMs combine cleanly IFF substrate ownership is enforced mechanically, not by convention.
