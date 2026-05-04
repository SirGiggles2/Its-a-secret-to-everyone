# Phase close gate — 11 ordered steps

Source: master plan "Phase Close Gate" section.

Every implementation phase closes in this exact order. Skipping a step or running them out of order = phase NOT closed.

## Steps

1. **Build with `REQUIRE_GENERATED_ASSETS=1`** (Task 1.11 strict gate).
   - Artifact: build log path; ROM SHA-256.

2. **Run focused probe set.**
   - Artifact: probe report path(s); ALL PASS or FAIL.

3. **Capture screenshot/state evidence; emit parity-oracle-schema instance per probe** (Task 2.8).
   - Artifact: schema instance path under `build/probes/<phase>/`.

4. **Diff each schema instance against matching `build/generated/nes_reference/` capture** (Phase 1.5).
   - Artifact: diff report path; pass/fail per scenario.

5. **Run `tools/run_regression_matrix.py`** (Workstream F).
   - Artifact: matrix output line; green required.

6. **Run `tools/state/verify_no_alias_collisions.py --scope <subsystems>`** if the phase touched `src/state/` (Workstream G).
   - The `--scope` list names the subsystems being promoted in this phase (e.g. `vram_map,palette` for Phase 2; `enemy` for Phase 7).
   - Out-of-scope collisions are reported as INFO and deferred to their owning phase per `docs/audit/state_contract.md` migration order.
   - Use `--strict-all` for the Phase 12 promotion gate.
   - Artifact: stdout log; status.

7. **Confirm per-subsystem `PROBE_CYCLE_LIMIT` envelope was not exceeded** (Workstream F cycle gate).
   - Artifact: cycle envelope readout; pass/fail.

8. **Run `superpowers:requesting-code-review`** against the diff + evidence.
   - Artifact: review thread URL or report path.

9. **Fix review findings or record technical deferrals in the phase report.**
   - Artifact: deferral entries in tracker `phases[i].deferrals[]`.

10. **Re-run focused probe set + regression matrix after fixes.**
    - Artifact: probe + matrix paths; green required.

11. **Commit the phase with the report paths in the commit message body** when the phase is substantial.
    - Artifact: commit SHA; commit message includes `Phase report: <path>`.

## Phase 12 special case

The Phase 12 promotion gate is **incremental** (Task 12.0): each phase that introduces a new subsystem evaluates promotion immediately. Late bulk promotion is forbidden. Use `verify_no_alias_collisions.py --strict-all` at Phase 12 — every subsystem must be green.

## Skill enforcement

`prime_guard.py --intent close-phase --phase <id>` walks all 11 steps in order. It refuses to emit phase-close commit guidance unless steps 1–10 each have an artifact recorded in the tracker `phases[i].evidence[]`. Step 11 commit is the final action and is itself an artifact.
