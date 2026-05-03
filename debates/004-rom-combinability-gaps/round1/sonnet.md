# SONNET Round 1 — ROM Combinability Gaps

Prime Directive lens: long-term > short-term, NES = spec, Genesis-native = impl, LLM-friendly = ONE answer per "where do I work?". Caveman precision mode.

## Answers to 10 asks

### 1. Per-gap fixes (compressed)
- **G1 Phase 8 Bosses**: RoomRom. Boss = gameplay scaffold. Add Worktree line.
- **G2 Phase 9 HUD/save**: SPLIT. See ask #6.
- **G3 Phase 10 Audio**: main. Audio driver lives in src/audio_driver.asm (shared substrate). RoomRom only consumes via SongRequest. Add Worktree: main.
- **G4 No active-pointer**: Solution = `tools/active_scope.py` reads `docs/master_plan.md` current phase + writes `.active_scope` file consumed by hook (warn on edit outside scope).
- **G5 Task 0.2 whatif alias**: See ask #9.
- **G6 State contract migration**: Add column `Owner Worktree` to state_contract.md table. Per-phase row says who migrates.
- **G7 Shared substrate edits**: Rule = substrate edits ALWAYS happen in main worktree, then RoomRom rebases. Enforced by ask #3 script.
- **G8 Phase 11 vs 2-7 ordering**: Parallel-eligible (different worktrees). See ask #7.
- **G9 Frontend boundary**: See ask #5.
- **G10 Merge readiness**: See ask #4.

### 2. Active worktree lines
- Phase 8 (Bosses): `Worktree: Active RoomRom implementation`
- Phase 9 (HUD/options/save): `Worktree: SPLIT — see Phase 9.A (RoomRom) / 9.B (main)`
- Phase 10 (Audio finalization): `Worktree: main (substrate); RoomRom consumes via SongRequest contract only`

### 3. Shared-substrate guard script
**Name**: `tools/substrate_guard.py`
**What**: detects edits under `src/sgdk_adapter/`, `src/abi/`, `src/state/`, `data/` in current diff. If hit, requires building BOTH ROMs (Title.elf + RoomRom.elf) and asserts both link clean + checksum recorded. Writes `builds/substrate_guard.json` with both ELF hashes.
**Where runs**: pre-commit hook + CI. Fails commit if either ROM doesn't build after substrate edit.

### 4. Merge readiness dashboard
**Name**: `tools/merge_readiness.py` -> `builds/merge_readiness.md`
**Reports**: per-RoomRom-module: (a) typed-state contract clean Y/N, (b) zero src/frontend includes Y/N, (c) zero RoomRom-only headers leaked Y/N, (d) symbol collision with src/game/* Y/N, (e) promotion-eligible Y/N. Plus rollup % eligible.
```
| Module           | Typed | NoFE | NoRR | NoCol | READY |
|------------------|-------|------|------|-------|-------|
| RoomRom/src/uw/  |   Y   |  Y   |  Y   |   Y   |  YES  |
| RoomRom/src/ow/  |   Y   |  N   |  Y   |   Y   |  NO   |
TOTAL: 14/22 eligible (63%)
```

### 5. Phase 12 frontend-boundary check
**Name**: `tools/frontend_boundary.py`. Greps src/game/**/*.{c,h} for `#include.*frontend/`. Any hit = FAIL. Wired into Phase 12 promotion gate + CI on main. Mechanical, zero-judgement.

### 6. Phase 9 split (per-task)
- **9.A RoomRom**: HUD rendering during gameplay, hearts/rupees/bombs/keys readouts, item-get overlay, pause-menu invocation from gameplay.
- **9.B main**: src/game/options/* file creation, save-slot serialization, options-menu screens (these are FS-adjacent frontend), save SRAM ABI in src/abi/.

### 7. Phase 11 vs Phase 2-7 interleave
**Parallel, gated at Phase 12.** Title.md frontend gap-fill (intro polish, FS slot art, options screens) edits only `src/frontend/*` and never touches RoomRom/. RoomRom phases 2-7 never touch src/frontend/. Zero overlap = safe parallel. Gate: substrate_guard.py runs on every shared-substrate edit either side makes.

### 8. Memory entry "active scope"
```
- [Active phase + worktree pointer](project_active_phase.md) — current
  master plan phase, owning worktree, allowed edit roots, blocked edit
  roots. Updated at every phase close. Body:
  PHASE: 2 (RoomRom S2 dungeon scaffold)
  WORKTREE: FINAL TRY-roomrom-s1
  ALLOW: RoomRom/src/, RoomRom/data/, RoomRom/tools/
  SUBSTRATE_OK: src/sgdk_adapter/, src/abi/, src/state/ (rebuild BOTH)
  BLOCK: src/frontend/, src/game/ (Phase 12 only)
```

### 9. Task 0.2 line 135 replacement
Old: `cp builds/Title.elf builds/whatif.elf  # alias`
New: `# whatif alias REMOVED per CLAUDE.md hard rule. Title.elf is canonical. Any tool referencing whatif.elf must be updated to Title.elf or fail loud.`

### 10. Final stance: **YELLOW**
Plan supports clean Phase 12 merge IF gaps 1-10 resolved. Untouched, RED. With substrate_guard + merge_readiness + active_scope pointer + frontend_boundary check + Phase 9 split + Phase 8/10 worktree lines: **GREEN**. Build the four tools first; they're force-multipliers Codex/Claude can run autonomously.

Stance: ship the tools BEFORE Phase 2 starts. Tools are cheap, drift is expensive.
