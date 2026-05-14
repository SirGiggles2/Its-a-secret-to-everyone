# Phase 15 Task 15.12 — Optimization Regression Gate

- **NES source**: N/A — regression-gate task.
- **Drained C**:  N/A — orchestrator over per-subsystem pre/post
                  dumps + screenshots + RoomRom smoke + Debug.md
                  smoke + hardware smoke (Phase 16).
- **Coverage**:   PARTIAL — `tools/compare_perf.py` exists for
                  pre/post comparison; full regression-gate
                  orchestration script NOT shipped.
- **Stance**:     PARTIAL — comparison tool ADOPT; orchestrator +
                  per-subsystem pre/post dump capture deferred to
                  Phase 15 measurement-driven re-pass.

## Master plan checklist

| Item                                          | Status |
|-----------------------------------------------|--------|
| Pre-optimization reference dumps per subsystem | DEFERRED |
| Post-optimization dumps                        | DEFERRED |
| State schema diff                              | DEFERRED |
| Plane/SAT/CRAM diff                            | DEFERRED |
| Screenshot diff                                | DEFERRED |
| RoomRom smoke                                  | DEFERRED |
| Debug.md smoke                                 | DEFERRED |
| Hardware smoke (Phase 16)                      | DEFERRED |

All deferred under `phase15_optimization_regression_gate` — fires
only AFTER measured optimization PRs land. Currently no measured
optimizations are in scope (every 15.2-15.11 task is deferred),
so the regression gate is dormant by design.

## Status

CLOSE (with dormant-gate stance) — Task 15.12 framework adopt;
gate fires only after a measured-optimization PR lands per
master plan rule. Recorded as deferral
`phase15_optimization_regression_gate` so any future optimization
PR is required to run the gate.
