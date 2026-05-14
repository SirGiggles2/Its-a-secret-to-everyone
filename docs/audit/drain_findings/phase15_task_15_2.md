# Phase 15 Task 15.2 — Establish Baseline Budgets

- **NES source**: N/A — Genesis hardware budget measurement.
- **Drained C**:  N/A.
- **Coverage**:   PARTIAL — baseline doc scaffold shipped at
                  `docs/audit/genesis_budget_baseline.md` (104 LOC,
                  placeholder with policy: "every budget must be
                  measured before any optimization claim is
                  accepted"). 10 per-scenario rows specced (title /
                  story / FS / OW idle / OW enemy-heavy / cave /
                  dungeon / dungeon enemy-heavy / boss / 4-player
                  stress). Per-row CPU / VBlank / DMA / sprite /
                  audio maxima all NULL pending live capture pass.
- **Stance**:     PARTIAL — substrate ADOPT; population gated on
                  Phase 14 GREEN per master plan rule "broad
                  rewrites allowed ONLY when probes show real
                  budget risk".

## Status

CLOSE (with measurement deferral) — Task 15.2 baseline doc + 10-row
scenario table specced. Per-scenario measurements deferred with
`phase15_baseline_measurements`.
