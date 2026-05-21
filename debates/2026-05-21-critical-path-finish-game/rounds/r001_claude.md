# Claude (Opus) Analysis — Round 1

## Tier-0 unblock: (a) gamemode $0C park

The $0C park is not a music bug — it is a **gameplay-loop bug** with audio as the loudest symptom. From `T5.0` evidence (`docs/audit/t5_0_audio_probe_sweep.md`): "gamemode stuck at $0C, dispatcher never fires", "FS routing RED (gamemode never reaches $01)". NES GameMode `$0C` = `Mode_Continue_Question`. If we never leave it, we never enter Mode 5 Play, never reach Mode 12 EndLevel, never hit Mode 01 FileSelect. All three downstream blockers ((c)/(d)/(e) audio dispatch) collapse into this one.

The plan-v5a Tier-3 GameMode-`$05` restore is **conditional** on `s_in_gameplay` set in `RoomRom/src/main.c`. If `s_in_gameplay` never flips true, we deadlock at `$0C`. That is the single root cause to verify first.

## Ordering with worktree parallelism

```
Tier-0 (main worktree, blocks everything):
  a   gamemode $0C park root-cause + fix
       └─ pulls T5.0.1 with it; merges into (d)

Tier-1 (parallel worktrees, post-a):
  WT-1  d (T5.0.2/3 audio chain)              ─ substrate audio_driver.asm → main only
  WT-2  b (T0.4 PlayAreaTiles publish)        ─ src/state writers → main only
  WT-3  c (Mode 5 Play port)                  ─ depends on (a) unblock + (b) collision tile

Tier-2 (main worktree, post-Tier-1):
  f   regression matrix re-run on 14 OOP REPLACE
  e   ph6 deferrals (6.10.6 + 6.10.11) — drop 6.10.11 if MIDI-FS still blocked
```

## Highest hidden blast radius if landed last
**(f) regression matrix re-run.** 14 REPLACE deliveries with `regression_matrix_run=None` is a silent-debt landmine. If we ship Mode 5 Play + audio before running the matrix, any regression introduced in commits `c4be4dca..6091f23d` (8 enemy visual + 7 NMI sync) gets co-mingled with new bugs and bisect is hell. Run (f) IMMEDIATELY AFTER (a) to lock the post-fix baseline before adding more code.

## Adversarial: failure modes per ordering

- **a first, then parallel WTs**: risk = $0C fix touches `src/state/world_state.h` (substrate); WT-1/2/3 must rebase before running their probes. Mitigation = land (a) on main, force-push protected, broadcast rebase.
- **b before a**: PlayAreaTiles writer probes will all show $00 because cave-entry never triggers (gamemode $0C blocks scene-toggle). Wasted cycles.
- **c before a**: Mode 5 Play stub will never be entered — cannot probe-verify.
- **d before a**: T5.0.1 IS the $0C investigation; ordering (d) before (a) is incoherent.

## CUT
**CUT: (e) 6.10.11 audio dispatch.** Blocked on MIDI-FS integration per memory `project_midi_fs_integration.md`. Substrate rotting. Long-term unblock = native FS rewrite v6, which is not on this critical path. Mark as DEFERRED, ship game without it. 6.10.6 StatusBarTransferBuf stays — it's a HUD render gap, not architecture.

## MY ORDERING
**a → f → b ∥ d ∥ c → e(.6.10.6 only)**

(a first because all four downstream items decode from it; f second to lock baseline before parallelism; b/d/c in worktrees; e last with 6.10.11 cut)
