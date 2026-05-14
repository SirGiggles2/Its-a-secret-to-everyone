# Phase 17 Task 17.5 — Final Release Gate

- **NES source**: N/A — final orchestrator.
- **Drained C**:  N/A.
- **Coverage**:   NONE — final release gate fires only after every
                  upstream Phase 17 task is complete + Phase 14 GREEN
                  + Phase 16 hardware smoke complete.
- **Stance**:     DEFERRED_RELEASE — Task 17.5 is the terminal
                  release-tag gate.

## Master plan checklist (final orchestration)

1. Run package checker (Task 17.1 deferred — `phase17_package_check_tool`).
2. Run from-scratch builder gate (Task 17.3 deferred — `phase17_from_scratch_build_gate`).
3. Run full quest smoke (Phase 14 deferred — `phase14_dungeon_harness_population`).
4. Run hardware smoke (Phase 16 deferred — `phase16_hardware_tests`).
5. Tag release — git tag `release/v1.0`.
6. Archive final build manifest — `builds/manifests/release-v1.0.json`.
7. Commit as `release: package legal builder`.

## Deferral

`phase17_final_release_gate` — terminal release-tag orchestration.
Fires only after:
- `phase14_dungeon_harness_population` GREEN
- `phase16_hardware_tests` GREEN
- `phase17_package_check_tool` shipped
- `phase17_from_scratch_build_gate` shipped
- `phase17_release_documentation` shipped

## Status

DEFERRED_RELEASE — Task 17.5 terminal gate. All upstream Phase 14 /
16 / 17 deferrals must resolve first.

---

## Master plan completion note

Phase 17 close completes the master plan phase ladder
(`docs/superpowers/plans/2026-05-02-title-roomrom-full-port-master-plan.md`).
Subsequent work is deferral-resolution and release-tag execution; the
phase scaffolding + audit + contract surface is complete.
