1. **Options Home: keep master plan placement.**  
Options state/runtime should stay in `src/game/options/` because the master plan explicitly names owned C files there, and because options are not just a frontend screen. They affect gameplay consumers, save/SRAM behavior, audio toggles, HUD/pause behavior, and eventually both ROM builds. The frontend can own the options *UI* under `src/frontend/fs/` or `src/frontend/options/`, but the authoritative options model/runtime belongs in `src/game/options/`. Moving all options into frontend creates exactly the Phase 12 risk we are trying to avoid: gameplay needing frontend-owned headers or duplicated option state.

2. **Substrate Edit Rule: main-only, RoomRom rebases.**  
Pick Codex/Sonnet/Opus. Shared substrate edits must land from main only: `src/sgdk_adapter/`, `src/abi/`, `src/state/`, `data/`, and likely `src/audio_driver.asm`. RoomRom consumes by rebase. Maintenance cost is the deciding factor: one writer means one source of ABI truth, fewer bidirectional cherry-picks, fewer “which worktree owns this struct?” disputes, and fewer hidden divergences. Gemini’s “either worktree may edit if dual check passes” catches breakage, but it still allows ownership ambiguity. The dual-ROM gate should verify substrate changes, not legitimize two substrate authorities.

3. **Canonical Tool Names.**  
Use `check_*.py` for hard gates, noun reports for dashboards, and avoid cute or vague names.

Canonical set:

- Substrate compile-both gate: `tools/gates/check_shared_substrate_dual_rom.py`
- Merge readiness: `tools/audit/merge_readiness.py`
- Frontend boundary: `tools/gates/check_frontend_boundary.py`
- Active scope pointer: `tools/active_scope.py`
- Whatif grep gate: `tools/gates/check_no_whatif.py`

Convention: `check_` means fail/pass gate; `merge_readiness.py` means report/dashboard; `active_scope.py` means state-management utility. This is more LLM-resilient than mixing `guard`, `dashboard`, `report`, `pointer`, and `phase` names inconsistently.

4. **Active Scope Mechanism: Sonnet’s generated `.active_scope`, with docs output.**  
Pick Sonnet’s mechanism: `tools/active_scope.py` reads the master plan and writes `.active_scope` consumed by hooks. This is hardest to drift because the hook reads machine state, not memory prose. Codex’s memory/doc pair is useful but manual. Gemini’s memory-only approach is weakest. Opus’s `docs/ACTIVE_PHASE.md` is good for humans, but a generated `.active_scope` file used by enforcement is stronger. Best version: `tools/active_scope.py` emits both `.active_scope` and `docs/ACTIVE_PHASE.md`.

Convergence confirmed:

- Phase 8 = RoomRom
- Phase 10 = main
- Phase 11 = parallel-gated
- `whatif` removed from Task 0.2 line 135
- `state_contract.md` gets `Owner Worktree` column

Final stance: **YELLOW**. The architecture is sound, but it becomes GREEN only after the ownership rules and gates are made mechanical.
