# Claude (Opus) Round 1 Analysis

I have read both planning documents in full and have edited project context (CLAUDE.md, memory rules, prior sessions). I write independently of the other three advisors; cross-critique happens in round 2.

## 1. Top 3 highest-impact gaps

### G1. No NES golden-master capture pipeline
Plan says "compare against NES capture" in Phases 3, 4, 5, 6, 7, 8 yet never defines a single deterministic capture harness. Each subsystem will reinvent BizHawk Lua probes, frame counts, RNG seeds, and screenshot storage. Without one canonical captor, "matches NES" decays into "matches whatever Claude captured that day." Fix: add **Phase 1.5 — NES Reference Capture Harness** producing `tools/nes_capture/` that drives BizHawk on the validated user ROM, runs canonical scenarios from a manifest (`captures.json`), writes frame-aligned screenshots + PPU/OAM/PALRAM/CIRAM dumps + RAM snapshots into `build/generated/nes_reference/<rom_hash>/`, with seeded RNG injection. Every later phase consumes the same captures.

### G2. State struct migration is implicit, not staged
Phases 4–13 all assume `src/state/*_state.h` exists with typed fields, but no phase explicitly migrates RoomRom globals into `src/state/`. Workstream C lists targets but no schedule. The implementer hits "replace RoomRom globals with src/state structs" in Task 12.3 with hundreds of call sites and no incremental gate. Fix: insert state-conversion subtask at the top of every phase that touches a new subsystem (cave, dungeon, link, enemy, boss) — convert that subsystem's globals before adding behavior. Promotion gate then becomes trivially satisfiable.

### G3. No regression matrix between phases
Phase close gate is per-phase, but Phase N can silently break Phase M's probe. Every phase report archives, no phase rebuilds prior reports. Fix: add `tools/run_regression_matrix.py` that runs all archived probes against current ROM, diffs state schema and key dump bytes, and is required green before any phase-close commit.

## 2. Top 3 shipping/parity risks

### R1. Audio driver lock-in vs FS song bug (memory `project_midi_substrate_works`, `project_fs_no_song_change`)
Phase 10.1 keeps current driver but the FS song change is gated on game mode hook, not driver. Phase 10 wires music events without first specifying the FS-vs-title boundary. Risk: title song bleeds through every FS scene at release.

### R2. CHR expansion vs sprite-pal toggles (memory `project_intro_item_flash`, `project_chr_expansion`)
Phase 2 cuts to tile-index subpalette selection, but intro item flash uses Z_07 sprite-pal toggle every 8 frames. Phase 2.6 strips that path. Without explicit "preserve frame-cadence palette toggles where NES uses them," intro flash dies.

### R3. Promotion gate vs RoomRom worktree drift
Promotion in Phase 12 reads from main worktree headers, but RoomRom development lives in `FINAL TRY-roomrom-s1`. Plan never specifies the merge protocol from worktree → main → src/game. Risk: silently promoting stale main-branch RoomRom code instead of the actual S2+ worktree state.

## 3. Five concrete additions

1. **New Phase 1.5 — NES Reference Capture Harness** between current Phase 1 and Phase 2. Tasks: define `captures.json` schema, build canonical movie set (title, FS, OW rooms 0x00/0x77, UW L1, every cave type, every boss room), capture under deterministic seed, write to `build/generated/nes_reference/`, hash and manifest. Every subsequent "compare against NES" task references this harness by capture id.
2. **Task 0.6 — Worktree merge protocol.** Document command sequence for merging `roomrom-s1` work into main before any Phase 12 promotion. Include "branch must rebase clean, RoomRom build must pass in main worktree before promotion."
3. **Task 2.6.5 — Preserve NES frame-cadence palette toggles.** Add explicit list (intro item flash, low-health flash, boss palette flash, hit invuln flash) and the runtime that owns them post-CHR-expansion. Add probe `intro_item_flash_8frame_cycle`.
4. **Task 9.0 — FS audio routing decision.** Before wiring music events in 10.3, define explicit hook: "FS music keyed off `gamemode == 0x01` not bitmap." Add probe `fs_silent_or_explicit_song`.
5. **Workstream F — Regression Matrix.** New cross-cutting workstream: `tools/run_regression_matrix.py` runs every archived probe; required green before any phase-close commit. Add Task 16.5.5 "remove flaky probes from matrix or fix them."

## 4. Plan part that maps poorly to Codex+Claude strengths

**Phase 14 — Full Quest Completion.** Currently a single sequential checklist of "play through First Quest, Second Quest." This is the worst possible Codex shape: long-running stateful playthrough with no deterministic checkpoint. Probes time out, RNG drifts, save state corrupts.

Better task shape: **per-dungeon canonical movie**. Each dungeon (1–9, both quests) becomes a deterministic recorded BizHawk movie file that an agent runs unattended. Each agent owns one dungeon. Output: pass/fail + frame log + final RAM state. Parallelize 18 dungeon-completion agents.

## 5. Final stance

**YELLOW.** Plan is structurally sound and the recent edits closed the worst gaps (subagent strategy, promotion gate, probe contract, reproducibility). Remaining risks are concrete and fixable: capture harness, regression matrix, state migration cadence, audio routing pre-decision. Without those, "match NES" cannot be enforced mechanically and the plan drifts to "match what Claude remembered to capture."
