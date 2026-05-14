# Phase 16 Task 16.3 — Emulator Matrix

- **NES source**: N/A — cross-emulator verification.
- **Drained C**:  N/A.
- **Coverage**:   PARTIAL — BizHawk/GPGX is primary dev emulator
                  (per memory `skill_bizhawk_script` +
                  `feedback_use_bizhawk_skill`). BlastEm + Genesis
                  Plus GX standalone + flash cart runtime NOT yet
                  exercised.
- **Stance**:     PARTIAL — primary BizHawk/GPGX ADOPT; cross-emu
                  matrix deferred.

## Emulator matrix

| Emulator                        | Status                                   |
|---------------------------------|------------------------------------------|
| BizHawk / Genplus-gx core       | ✓ (primary dev target; all probes run here) |
| BlastEm                         | DEFERRED                                 |
| Genesis Plus GX standalone      | DEFERRED                                 |
| Flash cart runtime              | DEFERRED (Task 16.2 hardware gate)       |

## Deferred work

`phase16_cross_emulator_matrix` — run Debug.md on BlastEm + GPGX
standalone + flash cart; record per-emulator deltas at
`docs/audit/emulator_matrix.md`.

## Status

DEFERRED (with cross-emu deferral) — Task 16.3 primary emulator
ADOPT; cross-emulator deferred.
