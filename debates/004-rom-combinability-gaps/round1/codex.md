Stance: **YELLOW as-is**. The plan’s architecture can support a clean Phase 12 merge, but only after mechanical ownership gates are added. Prime Directive says best long term, maximal efficiency, NES match, Genesis strengths, and CLI fit. That means fewer “remember this” rules, more scripts that fail fast.

Concrete fixes:

1. **Phase 8:** add: `Active worktree: RoomRom gameplay implementation; edit boss gameplay in RoomRom/src/*, promote only through Phase 12 gates.`
2. **Phase 9:** add: `Active worktree: split by task, not vibes.`  
   `9.1-9.2` main/shared: `src/game/options/`, SRAM ABI/map.  
   `9.3` main: `src/frontend/fs/` options UI.  
   `9.4` mixed: RoomRom for gameplay consumers, main for FS/audio consumers.  
   `9.5-9.6` RoomRom: HUD, pause, subscreen.  
   `9.7` mixed: save serialization/SRAM in main; death/continue gameplay in RoomRom; file-select return boundary in main.
3. **Phase 10:** add: `Active worktree: main owns audio driver/ABI/generated audio; RoomRom owns gameplay event callsites; shared audio ABI edits require dual-ROM gate.`
4. Add `docs/audit/active_scope.md` plus memory `project_active_scope`: current phase, active worktree, allowed paths, shared-substrate escape rule, last close gate. Update it at every phase close.
5. Replace Task 0.2 line 135 with: `Do not create or refresh any whatif.* compatibility aliases. build.bat emits only Title.md/Title.lst/Title.o/Title.elf; migrate active probes to Title.* before this task closes.`
6. In `state_contract.md`, add `Migration owner worktree` column. Rule: feature owner migrates state first; shared `src/state/` lands via main/shared substrate path, then RoomRom rebases/consumes.
7. Shared substrate rule: `src/sgdk_adapter`, `src/state`, `src/abi`, `data/` are main-owned substrate. RoomRom can request/use them, not fork them silently.
8. Phase 11 can run **parallel** with Phases 2-7 only for frontend-owned paths and frontend probes. It must close before Phase 12 flip. Shared substrate changes are gated.
9. Phase 12 frontend-boundary check: add `tools/audit/check_frontend_boundary.py`; scan includes in `src/game/**/*.c,h`; fail on `frontend/`, `../frontend/`, `src/frontend/`, or any basename matching headers under `src/frontend/`.
10. Add `tools/audit/merge_readiness_dashboard.py`.

Shared-substrate gate: `tools/gates/check_shared_substrate_dual_rom.py`, run from repo root after any substrate diff. It runs Title build, RoomRom build, state alias lint, macro-state lint, SGDK adapter boundary, frontend boundary.

Dashboard output sketch:

```text
ROOMROM MERGE READINESS
Title commit: abc123  build: GREEN
RoomRom commit: def456 build: GREEN

module        phase state probes globals frontend sgdk provenance ready
link          6     GREEN GREEN  GREEN   GREEN    GREEN GREEN      YES
hud           9     YELLOW GREEN GREEN   GREEN    GREEN MISSING    NO

promotion eligible: 18/24 = 75%
blockers: hud provenance, boss_state typed migration
```

Final stance: **YELLOW**, not RED. The design is right; the enforcement is incomplete. Add these gates and it turns **GREEN**.
best suit Codex + Claude + other CLIs strengths”; that requires explicit worktree ownership, mechanical gates, and dashboard visibility before more phases accumulate ambiguity.
