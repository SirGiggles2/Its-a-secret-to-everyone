# Phase 13 Task 13.2 — Input Adapter

- **NES source**: NES uses single controller. No NES surface for
                  multi-controller input.
- **Drained C**:  `src/sgdk_adapter/joy_adapter.{c,h}` exists for
                  controller 1 only. Genesis hardware natively
                  supports 2 controllers via the joypad ports; 3-4
                  player needs Sega multitap / Team Player adapter
                  detection.
- **Coverage**:   NONE — Phase 13 multi-controller substrate not
                  started.
- **Stance**:     DEFERRED_FEATURE — see Task 13.1 rationale.
                  Multi-input is meaningless without multi-player
                  state.

## Implementation plan (when picked up)

1. Extend `joy_adapter` to enumerate ports 1 + 2 every frame.
2. Detect Team Player (`$A10003` magic bytes) on either port; if
   detected, fan out to 4 logical inputs.
3. Author `player_input[4]` struct array; per-player A/B/Start/etc.
   bitfields.
4. Map `players[i].input = player_input[i]` in the gameplay loop.
5. Option-routed per-player A/B swap via existing `ab_swap` (Phase
   9.4 consumer); reuse the existing single-player gate so 1-player
   behaviour is unchanged.

## Status

DEFERRED_FEATURE — gated on Task 13.1 completion.
