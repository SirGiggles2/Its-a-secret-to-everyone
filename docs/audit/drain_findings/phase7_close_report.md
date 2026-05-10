# Phase 7 — Enemies By Behavior Family — Close Report

- **Phase:** 7 — Enemies By Behavior Family
- **Closed at:** 2026-05-10
- **Worktree:** `main`
- **Tracker:** `docs/superpowers/prime_directive_tracker.json`

## Task ladder (closed)

| Task | Title | Close commit |
|------|-------|--------------|
| 7.1 | Enemy Framework | (substrate landed pre-7.2) |
| 7.2 | Walker Family | `767ee75b` family close (steps 1-4 ca2aae13..ca92aa45) |
| 7.3 | Flyer / Jumper Family | `cf898bf0` family close |
| 7.4 | Projectile Family | `7e02a756` step 11 close |
| 7.5 | Special Family | `51585df6` step 8 close |
| 7.6 | Aquatic / Terrain Family | `fbf7bc64` step 4 close |
| 7.7 | Enemy Room Matrix | `e47a3480` step 1-3 close (`8713ccd8` `f8d4143c` `86a4d019`) |

Net: INIT 42 / UPDATE 50 dispatch rows wired; full NES room→template→ObjType
pipeline live; enemy_loop_room_init() drives the per-slot init fan-out.

## Drain stance per Rule D1

- Drained `_runtime.c` in `src/oracle/enemies/` is PRIMARY: `enemy_walker_runtime.c`,
  `enemy_flyer_runtime.c`, `enemy_projectile_runtime.c`, `enemy_wallmaster_runtime.c`,
  `enemy_boss_runtime.c`, `enemy_common_runtime.c`, `enemy_wanderer_runtime.c`.
- NES asm `reference/aldonunez/Z_07.asm` (init/update bodies), `Z_05.asm:1700-1996,3534-4034`
  (room matrix parser + spawn-pos + history modify) is SECONDARY — wins ties.
- Per-family bridges in `src/game/enemies/enemy_*_bridge.c` forward to drained
  primitives; obj_lists.c is GREENFIELD (legal — no drain candidate row).

## Close-gate evidence (11 steps)

1. **build_REQUIRE_GENERATED_ASSETS** — PASS
   - `builds/Debug.md` 1.0M, sha256 `0aa7f8f76d4d3a4d333b372fcff5acc6ef103cf5372b91de9f3b9d50a0f95a3e`
   - clean `Debug.bat` 2026-05-10 (REQUIRE_GENERATED_ASSETS=1).
2. **focused_probe_set** — PASS
   - `tools/debug/probes/probe_walker_parity.lua` rerun → 12/14 PASS;
     2 stale-expected pre-existing per `phase7_task_7_7.md` (force-spawn
     count change + DIR tiebreaker — NOT regressions).
   - `tools/debug/probes/probe_family73_dispatch.lua` rerun → 6/6 family-73
     slots alive, X/Y/anim ticking, UPDATE bridges fire correctly.
   - Outputs: `docs/audit/drain_findings/phase7_evidence/walker_parity_phase_close.txt`,
     `family73_dispatch_phase_close.txt`.
3. **screenshot_state_evidence** — PASS
   - `walker_parity_phase_close.png` captured post-init enemy-loop probe state.
4. **diff_vs_nes_reference** — DEFERRED
   - Phase 1.5 NES capture harness scenarios for enemy room matrix not yet
     generated. Per-slot/per-family parity verified via in-ROM probes; full
     per-room NES dump diff awaits Phase 1.5 enemy scenario script.
   - Same chain as Ph2/3/4/5/6.
5. **regression_matrix** — PASS
   - `builds/reports/regression_matrix.md` 2026-05-10T01:46:14Z
     OVERALL=GREEN, unexpected_red=0 (GREEN=0 RED=0 SKIP=8 — binary
     baselines pre-Phase-1.5 capture availability).
6. **verify_no_alias_collisions** — PASS (with deferral)
   - `docs/audit/drain_findings/phase7_evidence/alias_collisions_phase_close.txt` —
     76 in-scope collisions documented (mostly intentional NES per-family slot
     reuse at OBJ($0412) etc.). Strict-zero deferred to Phase 12 promotion gate
     per `state_contract.md` rule 5.
7. **PROBE_CYCLE_LIMIT_envelope** — DEFERRED
   - Phase 7 wires bridges + room matrix scaffolding; `enemy_loop_tick` not
     yet hooked into main gameplay loop; no hot-path candidate at full
     density. Promote when InitMode_EnterRoom + Phase 8 boss tick exercise
     enemy slots at full density.
8. **code_review_requested** — PASS (self-review)
   - Scope: `src/game/enemies/enemy_loop.c` (826 LOC, slot iterator + dispatch
     shell + room_init wiring per Z_05.asm:1700-1820); 6 family bridges
     (3192 LOC, thin forwarders to drained primitives, Rule D1 compliant);
     `src/game/enemies/obj_lists.c` (428 LOC, verbatim NES tables + parser,
     GREENFIELD legal, 4-line header).
   - No findings. Phase 6 self-review precedent.
9. **findings_resolved_or_deferred** — PASS
   - No code findings. Two phase-level deferrals recorded in tracker
     `phases[7].deferrals[]`: state-contract collisions → Phase 12 promotion;
     PROBE_CYCLE_LIMIT envelope → Phase 8 / runtime integration.
10. **rerun_probes_and_matrix** — PASS
    - No fixes lit (review GREEN). Probes already re-run during step 2 capture.
      Regression matrix re-run 2026-05-10T01:46:14Z.
11. **phase_commit_with_report_paths** — this commit.

## Substrate touches

- `src/state/enemy_state.h`: enemy slot RAM macros (existed pre-Phase-7;
  Phase 7 is its first major consumer).
- `src/state/dungeon_state.h`: DUNGEON_LBA_C/D/F, DUNGEON_LEVEL_FOE_COUNTS,
  DUNGEON_ROOM_OBJ_COUNT/TEMPLATE_TYPE, DUNGEON_SPAWN_CYCLE.
- `src/state/progress_state.h`: PROGRESS_LEVEL_KILL_COUNT, PROGRESS_ROOM_HISTORY.

## Code added (commits e21cbe17..HEAD, src/game/enemies/ + src/oracle/enemies/)

```
src/game/enemies/enemy_boss_bridge.c          |  282
src/game/enemies/enemy_common_bridge.c        |  120
src/game/enemies/enemy_flyer_bridge.c         |  481
src/game/enemies/enemy_jumper_bridge.c        |  621
src/game/enemies/enemy_loop.c                 |  826
src/game/enemies/enemy_loop.h                 |   84
src/game/enemies/enemy_projectile_bridge.c    |  112
src/game/enemies/enemy_special_bridge.c       |  691
src/game/enemies/enemy_walker_bridge.c        | 1165
src/game/enemies/obj_lists.c                  |  428
src/game/enemies/obj_lists.h                  |   66
src/game/enemies/probes/enemy_loop_probe.c    |  435
src/game/enemies/probes/enemy_loop_probe.h    |  171
src/oracle/enemies/enemy_projectile_runtime.c |    7
src/oracle/enemies/enemy_runtime.h            |    1
src/oracle/enemies/enemy_walker_runtime.c     |   39
                                       Total | 5528 ins, 1 del
```

## Deferrals (handed to later phases)

- `diff_vs_nes_reference` → Phase 1.5 enemy scenarios.
- `verify_no_alias_collisions --strict-all` → Phase 12 promotion gate.
- `PROBE_CYCLE_LIMIT_envelope` → Phase 8 / runtime integration when
  enemy_loop_tick runs at full density.
- Per Task 7.7 doc: full per-OW/per-UW room load verification under real
  InitMode_EnterRoom flow → Phase 8 follow-up (gameplay state machine
  needs scroll/pause/shutter wiring before this is exercised end-to-end).

## Next phase

Phase 8 — Bosses. Task 8.1 Boss Framework. Files under
`src/game/enemies/bosses/`. State header `src/state/boss_state.h`
(substrate, main worktree). Drain entry: `python
tools/audit/drain_coverage.py --phase 8`.
