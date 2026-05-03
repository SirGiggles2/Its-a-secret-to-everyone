GEMINI Round 2 — Divergence Resolution & Final Stance

Me Gemini. Holes in cheese being filled. Round 1 convergence is strong, but four points remain "yellow." I resolve them to ensure **Maximally Efficient** execution.

### 1. OPTIONS HOME: `src/frontend/options/`
I override the Master Plan (Task 9.1). The user framing is clear: `Title.md` owns "Options-as-related-to-FS." Logic that draws menus, sliders, and toggles is **Frontend**, not **Gameplay**. 
*   **The Split**: `src/frontend/options/` owns UI/Menu logic. `src/state/` (substrate) owns the persistence struct. `src/game/` consumes these settings via the state contract but never knows how they were changed. This maintains the **Phase 12 Boundary** where gameplay guts stay pure.

### 2. SUBSTRATE EDIT RULE: Decentralized + Mechanical Check
I side with Gemini R1. Restricting substrate edits to the "Main" worktree (Codex/Sonnet/Opus) creates a human bottleneck and "rebase debt." 
*   **Decision**: Either worktree may edit `src/sgdk_adapter`, `src/abi`, `src/state`, or `data/` **IF AND ONLY IF** they run `check_dual_rom.py`. If the edit breaks the other ROM's build or link, the commit is blocked. Mechanical enforcement > central planning.

### 3. TOOL NAMES: Canonical Set
Consistency is safety. We use these names:
*   `check_dual_rom.py`: The Substrate compile-both gate.
*   `readiness_report.py`: The Phase 12 dashboard.
*   `check_frontend_boundary.py`: The `#include` grep-gate.
*   `active_scope.py`: The Phase/Worktree pointer.
*   `check_no_whatif.py`: The legacy alias grep-gate.

### 4. ACTIVE SCOPE MECHANISM: Scripted + Hooked
I side with Sonnet/Opus. `MEMORY.md` is too "soft" for LLMs. 
*   **Decision**: `tools/active_scope.py` reads `docs/master_plan.md` (canonical truth) and writes a `.active_scope` file. This file is consumed by a pre-commit hook to block edits in unauthorized directories. It is drift-proof and machine-verifiable.

---

### CONVERGENCE CONFIRMED
*   **Phase 8**: RoomRom owns Boss behaviors.
*   **Phase 10**: Main owns low-level Audio Driver; RoomRom owns high-level SFX triggers.
*   **Phase 11**: Parallel-eligible but gated by `readiness_report.py` at Phase 12.
*   **Task 0.2**: Line 135 replaced; `whatif` alias dead.
*   **State Contract**: `Owner Worktree` column added to `state_contract.md`.

### FINAL STANCE: **YELLOW**
The architecture is now **GREEN** on paper, but the repository is **YELLOW** until the five tools listed above are implemented. 
**Directive**: Build `check_dual_rom.py` and `active_scope.py` first. Without the **Dual ROM Smasher**, Phase 8 will drift. 

Ugh. Cheese fixed. Ready for implementation.
