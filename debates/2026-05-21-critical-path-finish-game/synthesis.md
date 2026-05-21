# Synthesis — Critical Path to Finish Zelda NES→Genesis Port

**Advisors:** Gemini, Codex, Sonnet, Copilot, Claude/Opus
**Style:** adversarial, 1 round (advisors saturated; sonnet evidence decisive)
**Date:** 2026-05-21

## Orderings on the table

| Advisor | Ordering | Cut |
|---|---|---|
| Opus    | a → f → b ∥ d ∥ c → e.6.10.6 | e.6.10.11 |
| Sonnet  | a → b ∥ d.T5.0.2/.3 ∥ f → c → e.6.10.6 | e.6.10.11 |
| Gemini  | f → b → a → c → e → d | d (T5.0.2/.3) |
| Copilot | d → a → b → c → f → e | e.6.10.11 |
| Codex   | d.T5.0.1 → a → b → c → d.T5.0.2 → d.T5.0.3 → e.6.10.6 → e.6.10.11 → f | d.T5.0.3 |

## Decisive evidence (Sonnet)

Grounded code reads. Wins ties:

- `mode_dispatch.c:55` → `case 0x0C: mode_stub()`. The park is a deliberate no-op. **T5.0.1 needs no investigation — it IS (a).** UpdateModeC body never ported.
- `audio_dispatch.c:131` → `gm = nes_ram[0x0012u]`. Dispatcher correct; waits on $0012. Audio is downstream symptom, not cause.
- `ow_render.c:602` → `roomrom_ow_room_render_publish_play_area_tiles()` exists; call-site may be missing from scene_load. (b) is a wiring task, not new infra.

## Convergence

- **Tier-0 unblock = (a)** — 4/5 explicit; Gemini outlier rejected (running (f) under $0C park = false-greens on tasks that never exercise).
- **(a) subsumes T5.0.1** — Sonnet's read collapses (d.T5.0.1) into (a).
- **(b) after (a)** — 4/5 (only Gemini puts b first; same false-green issue).
- **(c) Mode 5 Play** — after (a)+(b), all agree.
- **CUT consensus:**
  - **e.6.10.11 audio dispatch** — 3/5. MIDI-FS multi-month blocker, orthogonal to playability per `project_midi_fs_integration.md`.
  - **d.T5.0.3 m_song mirror** — Codex's cut. Premature mirror commitment until drained `_runtime.c` proves it required. Keep T5.0.2 (probe-only, no ABI touch).

## Worktree parallelism map

```
Main worktree (substrate writers, sequential):
  a        gamemode $0C unpark (drain UpdateModeC body, src/state + mode_dispatch.c)
  c        Mode 5 Play port (mode_dispatch.c case 0x05 body + sgdk_adapter wiring)
  e.6.10.6 StatusBarTransferBuf path

Parallel worktrees (post-(a), pre-(c)):
  WT-1  b           PlayAreaTiles call-site wiring (call-site only)
  WT-2  d.T5.0.2    dmc_last_idx Lua probe (read-only)
  WT-3  f           regression matrix re-run on 14 OOP REPLACE

Cut:
  e.6.10.11   blocked external (MIDI-FS rewrite v6)
  d.T5.0.3    premature; drain decides
```

## Worst-case-failure mitigations

- **(a) lands wrong transition target** → BizHawk probe on real NES OW: capture `nes_ram[$12]` over 300 frames + the writer that moves it off $0C. Drain only after probe. Rule Zero.
- **(b) call-site missing post-(a)** → highest hidden blast radius per Sonnet. Probe `collision_get_collidable_tile_still(0)` immediately after (a) merges; if still $00, fix (b) BEFORE running (c) probes.
- **(f) under $0C** → forbidden. (f) launches only after (a) merged.
- **(c) Mode 5 Play** → expected to expose 5-10 sub-bugs (collision dispatch, item-pickup, screen-scroll). Budget multi-session. Chuckle + /octo:debate per sub-bug.

## Final ordering

```
1. (a)+T5.0.1    main worktree, blocks all downstream
2. (b)           WT-1 || (d.T5.0.2) WT-2 || (f) WT-3 — launch immediately after (a) merges
3. (c) Mode 5 Play  main worktree
4. (e.6.10.6)    main worktree
5. Full-quest smoke L1-L9 × Q1/Q2 — acceptance gate
```

**Cuts:** e.6.10.11 (MIDI-FS external), d.T5.0.3 (premature).

## Next concrete action

Probe NES `nes_ram[$12]` over 300 frames on real Z1 OW room, capture writer that moves GameMode off $0C. Then drain the writer into mode_dispatch.c. Per Rule Zero: probe → diff → code.
