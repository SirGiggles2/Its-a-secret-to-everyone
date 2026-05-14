# Phase 16 Task 16.4 — Accessibility And Safety

- **NES source**: NES Zelda 1 has no accessibility surface. Redux
                  options layer (Phase 9) adds accessibility toggles
                  per `OPTION_BOOL_*` bitfields in
                  `src/game/options/options_state.h`.
- **Drained C**:  `src/game/options/options_consumer.c` exposes
                  per-option accessor; some consumers wired
                  (`no_reduced_flashing` at `draw_dispatch.c:568+640`),
                  others deferred (Phase 9.4 `phase94_eight_unwired_consumers`).
- **Coverage**:   PARTIAL — option framework FULL; per-option live
                  verification gated on Phase 9.4 + Phase 14 GREEN.
- **Stance**:     PARTIAL — accessibility framework ADOPT; live
                  per-option verification deferred.

## Accessibility checklist

| Option                       | Wired? | Live-verified?                |
|------------------------------|--------|-------------------------------|
| no_reduced_flashing          | ✓      | Phase 14 deferred             |
| low_health_warning           | ✗      | Phase 9.4 unwired-consumer    |
| ab_swap                      | ✓      | Phase 14 deferred             |
| text speed                   | (n/a)  | Not in master plan options    |

Photosensitivity option documentation: lives in
`src/game/options/options_state.h` `OPTION_BOOL_NO_REDUCED_FLASHING`
bit + per-consumer call sites at `draw_dispatch.c`.

## Status

PARTIAL — Task 16.4 framework ADOPT; live verification gated on
Phase 9.4 unwired-consumer + Phase 14 GREEN runs.
