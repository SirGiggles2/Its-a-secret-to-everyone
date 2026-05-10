# FPS findings — armed-probe vs default A+B+C

**Date:** 2026-05-10
**ROM:** `builds/Debug.md` at commit `229a690c` (post-SAT-DMA-fix +
post-probe-arm-gating).
**Method:** four Lua probes under `src/debug/probes/`. Each measures
600 emu frames after a 60-frame settle and reads `s_frame_counter` at
$FF7202..$FF7203 to compute the game-frame ratio.

## Result table

| Probe | Arm bytes | Enemies alive | Game frames / 600 emu | FPS  |
|-------|-----------|----------------|------------------------|------|
| `fps_profile.lua` (cold start)   | 00 00 | 0  | 394 | 39.40 |
| `fps_profile.lua` (warm)         | 00 00 | 0  | 600 | 60.00 |
| `fps_uw_vs_ow.lua` UW            | 00 00 | 0  | 600 | 60.00 |
| `fps_uw_vs_ow.lua` OW            | 00 00 | 0  | 600 | 60.00 |
| `fps_armed_stress.lua`           | 45 50 | 11 | 277 | 27.70 |
| `fps_armed_no_enemies.lua`       | 45 50 | 0  | 277 | 27.70 |
| `fps_unarm_after_spawn.lua`      | 00 50 | 11 | 384 | 38.40 |

## Interpretation

Cost decomposes into two independent paths:

1. **11-slot enemy_update_fns dispatch ≈ 21.6fps** when not CPU-bound by
   the publish path. Visible in `fps_unarm_after_spawn` (60 → 38.4).

2. **publish_pre + publish_live + heavy state-mirror block ≈ 32.3fps**
   when armed. Visible in `fps_armed_no_enemies` (60 → 27.7) — clearing
   the 11 enemies after spawn does not recover anything because the
   armed-state publishes already saturate the per-frame budget.

Once armed + publishing, adding the 11-enemy dispatch is invisible
(CPU-bound, costs combine non-linearly). That's why
`fps_armed_stress` and `fps_armed_no_enemies` both report 27.70fps.

## User-visible result

**Default A+B+C entry (no probe-arm magic) = 60fps clean.**

The probe-arm gating commit (229a690c) and SAT DMA fix (83c6ef0c) close
the user-reported lag in `project_debug_enter_stress_harness`. The
27.70fps reading only occurs when a diagnostic Lua probe explicitly
writes 'EP' to $FF73FC..$FF73FD before A+B+C — i.e., during the
diagnostic itself, not during gameplay.

Diagnostic-mode 27fps is acceptable for now: it does not affect
gameplay, and the parity / dispatch probes that depend on the heavy
state mirror are batch-readers, not interactive.

## Future work (deferred)

If diagnostic-mode FPS becomes a blocker:

- Split `enemy_loop_probe_is_armed()` into per-subsystem flags
  (publish, state-mirror, force-spawn) so probes opt-in to only what
  they need. The new flags live in `src/game/enemies/probes/` (no
  RoomRom edit required); the heavy state-mirror gate inside
  `roomrom_debug_publish_state_mirror` would still consult
  `enemy_loop_probe_is_armed()` unchanged, but that function would
  return 1 only when the state-mirror bit is set.
- Move the heavy-state-mirror payload computation out of RoomRom into
  a `src/game/debug_state_mirror.c` aggregator that RoomRom calls via
  a single thin wrapper. Per CLAUDE.md WT-5 a single `#include` +
  call-site edit in RoomRom is permitted; the body lives in src/game/.

Both deferred per "DO NOT WORK ON ROOMROM" + "ONLY DEBUG" directive
2026-05-09 — current state ships gameplay at 60fps; diagnostic
slowdown is not blocking.

## Probe file inventory (this session)

- `src/debug/probes/fps_profile.lua`           — single-window FPS measurement
- `src/debug/probes/fps_uw_vs_ow.lua`          — scene-toggle compare
- `src/debug/probes/fps_armed_stress.lua`      — armed + 11 enemies (worst)
- `src/debug/probes/fps_armed_no_enemies.lua`  — armed + cleared slots
- `src/debug/probes/fps_unarm_after_spawn.lua` — armed-then-unarmed isolation
- `src/debug/probes/fps_bypass_sweep.lua`      — placeholder; consumer for
  the per-subsystem bypass mask is not implemented (no RoomRom edits
  permitted to add the call-site bypass checks).
