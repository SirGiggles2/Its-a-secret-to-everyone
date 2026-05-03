# Debate 004 — ROM Combinability Gaps + Phase 12 Merge Design: Synthesis

**Date:** 2026-05-02
**Participants:** Codex (CLI), Gemini (CLI), Sonnet (Agent), Opus (architecture lens)
**Mode:** thorough cross-critique, 2 rounds, ~400 words/advisor
**Caveman mode:** active

---

## TL;DR

**Final stance: YELLOW → GREEN-on-tool-land** (4-0).

Master plan architecture is sound and Prime-Directive-aligned. Ten gaps are mechanical, not structural. Build five canonical tools + edit four doc sections before Phase 8 opens, and Phase 12 merge becomes a no-op rebuild.

---

## Resolved divergences (round 2)

### 1. Options home — **SPLIT** (3-1, Gemini outvoted)
- `src/game/options/options_state.h` — state contract (master plan Task 9.1 honored; main/shared substrate)
- `src/frontend/options/options_menu.c` — UI screens (main, FS-adjacent)
- HUD readout of options during gameplay — RoomRom consumer

Sonnet's framing: state vs UI is the right cleavage. Opus conceded r1 (his collapse-into-frontend would have forced RoomRom to `#include "frontend/..."`, violating the very boundary he proposed).

### 2. Substrate edit rule — **MAIN-ONLY, RoomRom rebases** (3-1, Gemini outvoted)
Substrate (`src/sgdk_adapter/`, `src/abi/`, `src/state/`, `data/`, `src/audio_driver.asm`) edited from main worktree only. RoomRom consumes by rebase. Compile-both gate runs as defense-in-depth, not primary control.

Opus's argument: two writers on one substrate produces semantically valid edits that diverge at runtime. Compile-both catches *breakage*, not *drift*. Single-writer invariant is the cheapest LLM-resilience mechanism we have.

### 3. Canonical tool names — **`tools/gates/` for blocking, `tools/audit/` for advisory** (4-0)

| Function | Canonical name |
|----------|---------------|
| Substrate compile-both gate | `tools/gates/check_substrate_dual_rom.py` |
| Frontend-boundary checker | `tools/gates/check_frontend_boundary.py` |
| Whatif legacy-alias gate | `tools/gates/check_no_whatif.py` |
| Merge readiness dashboard | `tools/audit/merge_readiness.py` |
| Active scope pointer | `tools/audit/active_scope.py` (writes `docs/audit/active_scope.md`) |

Convention: `check_*.py` = pass/fail gate. Noun-named scripts under `audit/` = advisory reports. Rejects Gemini's "Dual ROM Smasher" (ungreppable, cute).

### 4. Active scope mechanism — **Sonnet's file-on-disk + hook + human-readable mirror** (4-0)
`tools/audit/active_scope.py` reads master plan current phase, writes `.active_scope` (machine, hook-consumed) + `docs/audit/active_scope.md` (human, git-tracked). Pre-commit hook reads `.active_scope` and warns when an edit lands outside the allowed paths for the current phase. Updated automatically on phase-close commit.

Most LLM-resilient because:
- Memory drifts (LLMs forget)
- Docs drift (humans forget to update)
- Hook firing on out-of-scope edit is mechanical and visible

---

## Convergence (no dispute, 4-0)

| Item | Resolution |
|------|-----------|
| Phase 8 (Bosses) worktree | RoomRom |
| Phase 10 (Audio) worktree | main (substrate) — RoomRom consumes via SongRequest contract only |
| Phase 11 vs Phase 2-7 | Parallel-eligible (different worktrees), gated at Phase 12 |
| Task 0.2 line 135 (whatif alias) | REMOVE per user hard rule |
| State contract migration order | Add `Owner Worktree` column |
| Phase 12 frontend boundary check | Mechanical grep gate (`check_frontend_boundary.py`) |
| Substrate gate trigger | Any commit touching `src/sgdk_adapter/`, `src/abi/`, `src/state/`, `data/`, `src/audio_driver.asm` |

---

## Per-gap concrete fixes (final, panel-merged)

### Gap 1 — Phase 8 Worktree
Add to master plan Phase 8 header:
> **Worktree:** Active RoomRom implementation (boss AI is gameplay scaffold).

### Gap 2 — Phase 9 split (per-task)
Add to master plan Phase 9 header:
> **Worktree:** SPLIT per task — see sub-numbering below.

Task split (per Codex/Sonnet refinement):
- **9.1, 9.2** — main: `src/game/options/options_state.h`, `src/game/options/options_runtime.c/h`, SRAM ABI/map (substrate)
- **9.3** — main: `src/frontend/options/options_menu.c` (FS-adjacent UI)
- **9.4** — RoomRom: HUD options readout during gameplay (sound flag, difficulty)
- **9.5, 9.6** — RoomRom: HUD rendering, pause-menu invocation, item-get overlay
- **9.7** — split: save serialization in main (substrate); death/continue gameplay in RoomRom; file-select return boundary in main

### Gap 3 — Phase 10 Worktree
Add to master plan Phase 10 header:
> **Worktree:** main owns audio driver / driver-ABI / generated audio (`src/audio_driver.asm`, `data/audio/`); RoomRom owns gameplay event callsites only. Shared audio-ABI edits trigger `tools/gates/check_substrate_dual_rom.py`.

### Gap 4 — Active scope pointer
Build `tools/audit/active_scope.py`:
- Reads current phase from master plan "Current Next Action" section
- Writes `.active_scope` (key=value: `PHASE=N`, `WORKTREE=<main|roomrom-s1>`, `ALLOW=<paths>`, `BLOCK=<paths>`, `SUBSTRATE_OK=<paths>`)
- Writes `docs/audit/active_scope.md` (human-readable mirror, git-tracked)
- Phase-close commit hook re-runs the script

Pre-commit hook (separate, lightweight): reads `.active_scope`, compares staged paths against ALLOW/BLOCK, emits WARNING (not block) if out-of-scope.

### Gap 5 — Task 0.2 line 135 replacement
Old (per master plan):
> After `Title.md` is created, copy it to `whatif.md`.

New (panel consensus):
> Do NOT create or refresh any `whatif.*` compatibility aliases. `build.bat` emits only `Title.md` / `Title.lst` / `Title.o` / `Title.elf`. Migrate any active probe or launcher still referencing `whatif.*` to `Title.*` before this task closes. Enforced by `tools/gates/check_no_whatif.py` in CI.

### Gap 6 — State contract Owner Worktree column
Edit `docs/audit/state_contract.md` migration table to add column:

| Phase | Subsystem | State header | Owner Worktree |
|-------|-----------|--------------|----------------|
| 2 | Graphics registry | `vram_map_state.h` (new), `palette_state.h` | main (substrate) |
| 3 | Caves | `cave_state.h` (new) | main (substrate); RoomRom consumes |
| 4 | Overworld | `world_state.h` | main (substrate); RoomRom consumes |
| 5 | Dungeon | `room_state.h`, `collision_state.h` | main (substrate); RoomRom consumes |
| 6 | Link/items/combat | `link_state.h`, `item_state.h` | main (substrate); RoomRom consumes |
| 7 | Enemies | `enemy_state.h` | main (substrate); RoomRom consumes |
| 8 | Bosses | `boss_state.h` (new) | main (substrate); RoomRom consumes |
| 9 | HUD/options/save | `save_state.h`, `options_state.h` | main (substrate) |
| 13 | Multiplayer | `link_state.h` → `player_state.h` | main (substrate) |

Rule: substrate state headers (`src/state/*.h`) live in main. RoomRom rebases.

### Gap 7 — Substrate edit rule
Add to master plan Execution Rules:
> Shared substrate (`src/sgdk_adapter/`, `src/abi/`, `src/state/`, `data/`, `src/audio_driver.asm`) is edited from `main` worktree only. RoomRom worktrees rebase to consume substrate changes. The `tools/gates/check_substrate_dual_rom.py` gate runs on any commit touching substrate paths and must build BOTH `Title.elf` and `RoomRom.elf` clean.

### Gap 8 — Phase 11 vs 2-7 ordering
Add to master plan Phase 11 header:
> **Worktree:** main (Title.md frontend gap-fill). **Ordering:** PARALLEL-ELIGIBLE with Phases 2-8 because frontend touches only `src/frontend/*` (no overlap with RoomRom gameplay paths). GATED at Phase 12 — both ROMs must pass `check_substrate_dual_rom.py` + `merge_readiness.py` GREEN before Phase 12 promotion flips Title's main-loop dispatch.

### Gap 9 — Phase 12 frontend boundary check
Build `tools/gates/check_frontend_boundary.py`:
- Greps `RoomRom/src/**/*.{c,h}` and `src/game/**/*.{c,h}` for `#include "frontend/`, `#include "../frontend/`, `#include "src/frontend/`, OR any header basename matching files under `src/frontend/`
- Also greps for `extern` declarations of symbols defined under `src/frontend/`
- Hard-fail in CI on any hit
- Wire into Phase 12 promotion gate as MUST-PASS

### Gap 10 — Merge readiness dashboard
Build `tools/audit/merge_readiness.py` → `builds/merge_readiness.md`:

```
MERGE READINESS — <date>
==================================
Title.md commit:    <sha> build: GREEN
RoomRom.md commit:  <sha> build: GREEN
Substrate drift:    <N> files (ahead of last common ancestor)
ABI symbol delta:   +N -N (review state.h if any)
Frontend-boundary:  <N> violations
Parity oracle:      <N>/<TOTAL>
Determinism hash:   match | mismatch

Per-RoomRom-module promotion eligibility:
| Module           | Typed | NoFE | NoCol | Provenance | READY |
|------------------|-------|------|-------|-----------|-------|
| RoomRom/src/uw/  |   Y   |  Y   |   Y   |   Y       |  YES  |
| RoomRom/src/ow/  |   Y   |  N   |   Y   |   Y       |  NO   |

Eligible: 14/22 (63%)
Blockers: ow includes frontend/, hud_state typed migration pending
Overall: <GREEN | YELLOW | RED>
```

---

## Tool build order (priority)

1. `tools/gates/check_no_whatif.py` — closes user hard rule, smallest scope
2. `tools/gates/check_frontend_boundary.py` — Phase 12 prerequisite, doc-aligned
3. `tools/gates/check_substrate_dual_rom.py` — wire into pre-commit + CI
4. `tools/audit/active_scope.py` + `.active_scope` + `docs/audit/active_scope.md` — kills drift
5. `tools/audit/merge_readiness.py` — Phase 12 dashboard

All five before Phase 8 starts. Tools are cheap; drift is expensive (Sonnet r2).

---

## Memory entries to add/update

1. **`project_active_scope_pointer.md`** (new) — explains `tools/audit/active_scope.py` mechanism + says future sessions consult `docs/audit/active_scope.md` and `.active_scope` BEFORE editing
2. **`feedback_substrate_main_only.md`** (new) — substrate edits land in main; RoomRom rebases; rule enforced by `check_substrate_dual_rom.py`
3. **`feedback_no_whatif_emit.md`** (new) — user hard rule: `build.bat` MUST NEVER emit `whatif.*`; alias dead; verifier `check_no_whatif.py` enforces

---

## CLAUDE.md additions

Add to "Decisions" / "Worktree rule" section:
> **Active scope pointer.** Before any edit, consult `docs/audit/active_scope.md` (or `.active_scope`) for the current phase's allowed paths. The pointer is auto-generated by `tools/audit/active_scope.py` on phase-close. Edits outside the active scope trigger pre-commit warnings.
>
> **Substrate ownership.** `src/sgdk_adapter/`, `src/abi/`, `src/state/`, `data/`, `src/audio_driver.asm` are main-worktree only. RoomRom rebases to consume substrate changes. `tools/gates/check_substrate_dual_rom.py` builds both ROMs after any substrate-touching commit.
>
> **No whatif emission.** `build.bat` emits only `Title.*`. The legacy `whatif.*` alias is removed permanently. `tools/gates/check_no_whatif.py` greps for the string in active code paths and fails CI on any hit (allowlists: `debates/`, `docs/archive/`).

---

## Final stance: YELLOW → GREEN on tool land

| Vote | Stance |
|------|--------|
| Codex | YELLOW → GREEN on tools |
| Gemini | YELLOW → GREEN on tools |
| Sonnet | YELLOW → GREEN-on-tools-land |
| Opus | YELLOW → GREEN on tool landing |

Architecture is sound. Phase 12 merge is a no-op rebuild IFF substrate has one writer + gates are mechanical. Five tools + four doc edits + three memory entries = GREEN.

---

## Cost / artifacts

- 4 advisors × 2 rounds = 8 advisor outputs (~26KB)
- Round files: `debates/004-rom-combinability-gaps/round{1,2}/{codex,gemini,sonnet,opus}.md`
- Synthesis: this file
