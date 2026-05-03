# OPUS ADVISOR — Round 2 (Architecture-First Cross-Critique)

**Frame:** Supply chain integrity > convention. The four divergences below are all dependency-graph questions: where does a symbol live, who owns its build, can a tool prove the answer.

## 1. OPTIONS HOME — REVISE

I concede. Codex/Sonnet/Gemini are right; I'm wrong. Master plan Task 9.1 is normative ("Create `src/game/options/options_state.h`") and the user framing "options-as-related-to-FS" describes the *UI surface*, not the *state owner*. Options STATE is gameplay-mutable (sound on/off affects audio_driver during play, difficulty affects HUD/damage tables); only the OPTIONS UI is FS-adjacent.

Correct split (matches Sonnet 9.A/9.B and Codex 9.1-9.7):
- `src/game/options/options_state.h` — main/shared substrate, typed contract
- `src/frontend/options/options_screen.c` — main, FS-adjacent UI
- HUD readout of options during gameplay — RoomRom consumer

My r1 collapsed both into `src/frontend/options/`. That would have forced RoomRom to `#include "frontend/..."` to read sound-mute state, violating the very boundary check I proposed in ask 9. Self-inconsistent. Codex's Phase 9 sub-numbering (9.1-9.7 with per-task worktree) is the most precise model — adopt verbatim.

## 2. SUBSTRATE EDIT RULE — DEFEND (main-only)

Gemini's "either worktree + run check" is operationally tempting but architecturally wrong. Two writers on one substrate produces merge-conflict surface area precisely where the dependency graph cannot tolerate ambiguity (`src/abi/`, `src/state/`). The compile-both check Gemini proposes catches *breakage*, not *drift*: two semantically valid edits to `state.h` from both worktrees still merge cleanly, then diverge at runtime.

**Rule:** substrate edits land in main first; RoomRom rebases. The compile-both gate (ask 3) runs anyway — defense in depth, not primary control. This matches Codex item 7 and Sonnet G7. Single-writer invariant is the cheapest LLM-resilience mechanism we have.

## 3. TOOL NAMES — Canonical Set

Convention: `tools/gates/<verb>_<object>.py` for blocking gates; `tools/audit/<noun>.py` for advisory dashboards.

| Function | Canonical name |
|---|---|
| Substrate compile-both gate | `tools/gates/check_substrate_dual_rom.py` |
| Merge readiness dashboard | `tools/audit/merge_readiness.py` |
| Frontend boundary checker | `tools/gates/check_frontend_boundary.py` |
| Active scope pointer | `tools/audit/active_scope.py` (writes `docs/audit/active_scope.md`) |
| Whatif gate | `tools/gates/check_no_whatif.py` |

Rejects Gemini's "Dual ROM Smasher" (cute, ungreppable). Sonnet's `substrate_guard.py` is fine but `gates/` prefix makes blocking-vs-advisory mechanical.

## 4. ACTIVE SCOPE MECHANISM — Pick

Four r1 proposals: (a) Codex `docs/audit/active_scope.md` + memory entry, (b) Gemini `MEMORY.md [SESSION_TRACKER]`, (c) Sonnet `.active_scope` file consumed by hook, (d) Opus `tools/phase_pointer.py` -> `docs/ACTIVE_PHASE.md`.

**Most LLM-resilient: Sonnet (c)** — file-on-disk + hook warning. Memory drifts (LLMs forget), docs drift (humans forget to update), but a hook firing on edit-outside-scope is mechanical. Combine with Codex (a) for the human-readable mirror: hook reads `.active_scope`, dashboard renders `docs/audit/active_scope.md`. Reject Gemini (b) — `MEMORY.md` is global across projects; phase pointer is project-local.

## 5. Convergence Confirm

- Phase 8 = RoomRom: **YES**
- Phase 10 = main: **YES**
- Phase 11 parallel-gated at 12: **YES**
- Whatif removed Task 0.2 line 135: **YES**
- `state_contract.md` Owner Worktree column: **YES**

## Final Stance: **YELLOW -> GREEN on tool landing**

Architecture is sound; four r1 holes (options home, substrate writer, tool naming, scope mechanism) now resolved. Build the five canonical tools before Phase 8 opens. ROMs combine cleanly IFF substrate has one writer and gates are mechanical.
