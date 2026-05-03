Me Gemini. Plan have holes like bad cheese. Me fix. Drift is enemy of **Maximally Efficient** (Prime Directive). LLM need map.

### 1-10: Gap Projections
1.  **Phase 8**: Worktree: RoomRom. Boss logic is gameplay.
2.  **Phase 9**: RoomRom owns Gameplay HUD (`src/game/hud.c`). Main/Title owns Save Logic/FS UI (`src/frontend/save_menu.c`).
3.  **Phase 10**: Main owns `src/audio_driver.asm` (Low-level). RoomRom owns XGM2 triggers/sfx mapping (High-level).
4.  **Pointer**: `MEMORY.md` must store `CURRENT_CONTEXT: PHASE=X, WORKTREE=Y`.
5.  **Task 0.2**: Replace "Create whatif alias" with "Establish Title.md as primary frontend frame."
6.  **State Contract**: Worktree implementing the feature (e.g., RoomRom in P2) owns the migration step for that phase.
7.  **Substrate**: Both can edit `src/sgdk_adapter` or `src/state`. **Constraint**: Must run `tools/check_dual_rom.py`.
8.  **P11 Interleave**: Parallel. Main work on UI assets; RoomRom work on core gameplay logic.
9.  **Boundary**: Phase 12 verifier fails if `src/game/*.c` has `#include "frontend/..."`.
10. **Merge Readiness**: Tool `tools/readiness.py` scans modules.

### Active Worktrees (P8, P9, P10)
*   **Phase 8**: `Worktree: Active RoomRom implementation (Boss behaviors)`.
*   **Phase 9**: `Worktree: Hybrid (RoomRom for HUD; Main for Save/Options-FS)`.
*   **Phase 10**: `Worktree: Shared (Main for Driver/Driver-ABI; RoomRom for Game-SFX-Mapping)`.

### Integrity Tool: `tools/check_dual_rom.py`
Me call it **Dual ROM Smasher**. 
- **Action**: Runs `make -f RoomRom/makefile` AND `make -f Title/makefile` (or equivalent `build.bat`).
- **Trigger**: Run after every edit to `src/sgdk_adapter`, `src/state`, or `data/`.
- **Logic**: If one ROM breaks, commit blocked. **Maximally Efficient** choice—fail fast.

### Merge Readiness Dashboard
`tools/readiness_report.py` output:
```text
[PHASE 12 READINESS]
Module          | State Contract | Frontend-Clean | Ready?
----------------|----------------|----------------|-------
link_movement.c | 100%           | YES            | GREEN
hud_manager.c   | 80%            | NO             | RED
boss_aquamentus | 50%            | YES            | YELLOW
```

### Frontend Boundary Enforcement
Mechanical Check: `grep -r "src/frontend" src/game/`.
If result found, Phase 12 promotion gate stays **LOCKED**. Gameplay guts must not know about Title screen buttons.

### Phase 9 Split
*   **RoomRom Tasks**: HUD rendering, active game options (e.g., sound test during play).
*   **Main Tasks**: SRAM persistence, File Select screen, Options screen (Frontend).

### Memory.md Sketch
`[SESSION_TRACKER]`
`PHASE: 02`
`WORKTREE: RoomRom`
`LAST_CONTRACT_SYNC: link_state_v1`

### Task 0.2 Replacement (Line 135)
`135: Establish Title.md as primary frontend container. Remove legacy 'whatif' references.`

### Final Stance: YELLOW
Plan strong on vision, weak on mechanical guards. Without `tools/check_dual_rom.py` and boundary `grep`, Phase 12 will be spaghetti merge. Add tools now, then **GREEN**. **Match the NES** flow, but use **Genesis Strengths** (Dual ROM iteration). Ugh.
