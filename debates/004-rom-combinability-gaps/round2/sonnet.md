# SONNET Round 2 — Cross-Critique

Prime Directive lens: long-term > short-term, mechanical > advisory, ONE LLM-resilient answer per ambiguous question.

## Divergence 1: OPTIONS HOME

**Concede to Opus partially, hold position overall.** Master plan Task 9.1 explicitly says `src/game/options/options_state.h`. Codex, Gemini, and I honored this. Opus moved to `src/frontend/options/`.

User framing ("Title.md = intro+title+FS+options-as-related-to-FS") implies options UI is FS-adjacent — but that conflates **state** with **UI**. State (volume, controller config, debug flags) is gameplay-consumed and belongs in `src/game/options/options_state.h` per master plan. UI screens (the options menu rendered in FS context) belong in `src/frontend/options/`. **Resolution**: split — `src/game/options/options_state.h` (state, owner: main substrate) + `src/frontend/options/options_menu.c` (UI, owner: main frontend). Keeps master plan honest, satisfies user framing. Opus was right about UI, master plan is right about state.

## Divergence 2: SUBSTRATE EDIT RULE

**Hold position; concede Gemini's tool, reject Gemini's rule.** Codex/Opus/I converged on "substrate edited only from main." Gemini said "either may edit + run check." Gemini's `check_dual_rom.py` is correct, but allowing dual-write substrate is a drift accelerator. **Pick: substrate edits only from main worktree.** RoomRom rebases. Mechanical, single-source-of-truth, prevents the exact rebase hell Phase 12 is supposed to eliminate. Run Gemini's tool as the gate.

## Divergence 3: TOOL NAMES

Convention: `tools/<verb>_<noun>.py`, no cute names (Gemini's "Dual ROM Smasher" fails LLM grep). Canonical set:
- Substrate compile-both gate: `tools/check_substrate_dual_rom.py` (Codex's name; clearest verb)
- Merge readiness dashboard: `tools/merge_readiness.py` (4-way agreement)
- Frontend boundary checker: `tools/check_frontend_boundary.py` (Codex/Opus)
- Active scope pointer: `tools/active_scope.py` (mine; emits `docs/audit/active_scope.md`)
- Whatif gate (Opus only): `tools/check_no_whatif.py` — **adopt**, Opus is right that grep-fail beats convention

## Divergence 4: ACTIVE SCOPE MECHANISM (LLM-resilience)

**Concede to Opus.** My round 1 proposal (`tools/active_scope.py` reads master plan + writes `.active_scope`) is mid-tier. Ranking by LLM-resilience:

1. **Opus**: phase-close commit hook emits `docs/ACTIVE_PHASE.md` — most resilient (mechanical, file-based, survives memory wipe, git-tracked)
2. **Mine**: `.active_scope` file from master plan — good, but `.active_scope` is dotfile (LLMs miss it)
3. **Codex**: docs/audit/ + memory — manual update fails when LLM forgets
4. **Gemini**: MEMORY.md only — fails on memory wipe / new session

**Pick Opus's**: `tools/phase_pointer.py` on phase-close commit hook → `docs/ACTIVE_PHASE.md`. Plain markdown, git-tracked, surfaces in any directory listing.

## Convergence Confirmed

Phase 8 = RoomRom, Phase 10 = main, Phase 11 parallel-gated at 12, whatif removed Task 0.2 line 135, state_contract Owner Worktree column. **All 4 advisors agree.**

## Final Stance: YELLOW → GREEN-on-tools-land

Plan supports clean Phase 12 IFF: substrate-main-only rule + 5 canonical tools + Opus's phase pointer + options state/UI split land before Phase 8 starts. Tools first, code second.
