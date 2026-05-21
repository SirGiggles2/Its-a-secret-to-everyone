# Debate: Critical-path order to finish Zelda NES→Genesis port

**Started:** 2026-05-21
**Style:** adversarial, 2 rounds
**Advisors:** Codex, Gemini, Sonnet (Agent), Opus (moderator), Copilot

## Project state (verified 2026-05-21)
- Phase 17 packaging shipped; 11/11 close-gate green, 24 evidence entries, 0 blockers
- Debug.bat builds clean → builds/Debug.md 2.0 MB
- 14 out-of-phase REPLACE tasks recorded with `regression_matrix_run=None`
- All 18 phases marked complete in tracker

## Known live-broken (carry-fwd)
- **(a)** GameMode parked at `$0C` — blocks music dispatch + FS routing + Mode 5 Play port
- **(b)** T0.4 OW `PlayAreaTiles[$06A0+]` not populated → blocks T0.1 cave-entry verify (`collision_get_collidable_tile_still(0)` returns `$00`)
- **(c)** Mode 5 Play not ported. Prereqs: collision engine, T1.1 controller bridge (T1.1 shipped per v5a)
- **(d)** T5.0.1 investigate `$0C` park, T5.0.2 find `dmc_last_idx` address, T5.0.3 decide `m_song` mirror → `nes_ram[$88]`
- **(e)** Phase 6 deferrals: `6.10.6` StatusBarTransferBuf, `6.10.11` audio dispatch (blocked on MIDI-FS per memory `project_midi_fs_integration.md`)
- **(f)** Re-run `tools/run_regression_matrix.py` on the 14 out-of-phase REPLACE deliveries

## Question
What ordering of (a)..(f) minimizes total wall-clock to a playable end-to-end full quest (L1-L9 × Q1/Q2)?
- Which can run in parallel via separate git worktrees?
- Which has the highest hidden blast radius if landed last?
- Identify the single Tier-0 unblock without which everything else stalls.
- Adversarial pushback expected: each advisor must propose at least one worst-case-failure-mode per ordering and one item they'd cut entirely.

## Hard constraints
- Substrate writer rule WT-1: `src/sgdk_adapter`, `src/abi`, `src/state`, `data/`, `src/audio_driver.asm` are main-worktree only
- Drain rule D1: drained `_runtime.c` is PRIMARY evidence, NES asm secondary tiebreak
- No GREENFIELD where `tools/audit/drain_coverage.json` shows a candidate
- Per-commit 3-gate verification: per-fn diff → per-RAM-cell trace → per-scenario oracle
