# Phase 15 Task 15.11 — Input And Multiplayer Hardware Optimization

- **NES source**: NES single controller polled once per frame.
                  Genesis controller poll runs through SGDK joypad
                  API; 6-button + multitap detection inside adapter.
- **Drained C**:  `src/sgdk_adapter/joy_adapter.{c,h}` for
                  controller 1. Multi-controller / 6-button /
                  multitap routing NOT YET wired (Phase 13
                  DEFERRED_FEATURE).
- **Coverage**:   PARTIAL — single-controller path is poll-once-per-
                  frame already (cached decoded button state through
                  `input_state.h` consumers). 4-player decoding does
                  not exist; 1-player path NOT slowed by absent
                  multiplayer logic.
- **Stance**:     PARTIAL — single-controller path ADOPT; 4-player
                  stress probe + latency check deferred. Gated on
                  Phase 13 DEFERRED_FEATURE re-evaluation.

## Status

CLOSE (with Phase 13 gate) — Task 15.11 single-controller path
ADOPT; multiplayer optimization deferred end-to-end on
`phase13_optional_feature_deferred`.
