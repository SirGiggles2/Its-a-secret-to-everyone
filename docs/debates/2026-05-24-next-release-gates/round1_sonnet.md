# Round 1 — Sonnet

The tracker is lying. 14 REPLACE tasks with no `regression_matrix_run`,
uncommitted cave/audio WIP, and a stale "next action" pointer mean the
real Phase 17 blocker isn't packaging — it's **trust in the artifact**.
Ship gates that prove the bytes, not gates that decorate them.

## Top 3 (ranked)

### 1. Land Phase 10 audio + flush the 14 REPLACE backlog through one regression sweep
- **Closes:** `task_10_3_audio_link_into_debug_md` + `task_10_5_audio_probes_runtime`; converts the 14 orphan REPLACE entries from "claimed" to "verified".
- **Blast radius if skipped:** v1.0 ships a ROM whose cave-entry chain, NMI sync, enemy visuals, Triforce transition, and `ow_theme_vgm.c` audio swap have **never been gated together**. Any single regression here = post-release patch, which kills "Public Builder" credibility.
- **Effort:** 2–3 days. Link the audio TUs (`src/sgdk_adapter/audio_adapter.c` already dirty), commit the cave WIP, run one matrix pass covering all 14 deltas.

### 2. Phase 11 live-capture pass — convert the 8 placeholder baselines to GREEN
- **Closes:** `phase11_live_capture_pass`; transitively unblocks `phase17_from_scratch_build_gate` (you can't byte-diff a fresh build against placeholder baselines).
- **Blast radius if skipped:** `from_scratch_gate.py` is decorative — no oracle = no determinism claim = Phase 17.4 stays DEFERRED forever.
- **Effort:** 1 day. BizHawk capture run via `/bizhawkScript`, drop into `tools/builder/from_scratch_gate.py` baseline dir.

### 3. Cross-emulator matrix as hardware-smoke proxy
- **Closes:** `phase16_cross_emulator_matrix`; legitimately substitutes for `hardware_smoke` per brief constraint.
- **Blast radius if skipped:** BizHawk-only validation = unknown behavior on BlastEm/Gens-KMod/Exodus = field bug reports from day-1 users on non-default emulators.
- **Effort:** 1.5 days. Three headless runs + diff harness in `tools/builder/`.

**Skip:** Phase 9.4 unwired options (cosmetic), Phase 14 dungeon harness expansion (nice-to-have post-1.0), end-user docs polish (1.0.1).

Total critical path: **~5 days wall-clock**. Everything else is theater.

— Sonnet — Round 1 opening
