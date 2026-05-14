# Phase 13 Task 13.1 — Generalize Player State

- **NES source**: NES Zelda 1 is single-player. No NES surface for
                  multi-player. Genesis-only feature.
- **Drained C**:  `src/state/link_state.h` (5.2 KB) is the existing
                  Link state header — single-Link assumption baked
                  into accessor macros (LINK_X, LINK_Y, LINK_HEARTS,
                  etc. resolve to fixed NES RAM addresses).
- **Coverage**:   NONE — Phase 13 substrate (multi-player state
                  array) not started.
- **Stance**:     DEFERRED_FEATURE — master plan tags Phase 13 as
                  "Optional 4-Player Genesis Mode". Per CLAUDE.md
                  decision priority (NES accuracy = spec, 4-player
                  is a Genesis-only extension): defer until 1-player
                  NES-faithful build is fully verified at Phase 14
                  (Full Quest Completion). Phase 13 is OFF the
                  critical path to game completion.

## Why DEFERRED_FEATURE

1. **NES accuracy first.** Multi-player adds zero NES parity and
   risks regressing 1-player behaviour if shared state isn't
   carefully segmented. Phases 14 / 15 / 16 / 17 protect 1-player
   parity, performance, and release readiness — those run before
   any optional feature.
2. **Substrate cost.** Generalising `LinkState` → `PlayerState[4]`
   touches every consumer of `LINK_*` macros — Phase 12 just
   migrated those out of RoomRom and they should settle before a
   sweeping rename pass.
3. **Sprite budget unknown.** Task 13.3 requires P2-P4 sprite tile
   + palette allocation; sprite atlas owns slots only after Phase
   11 + Phase 12 atlas-probes-subaudit completes.
4. **Save segmentation gate.** Phase 13 save-rule (versioned
   multiplayer SRAM range) needs save serializer (Phase 9.2
   ✓ shipped) PLUS continue/death modes (Phase 9.7 deferred) before
   the multi-player save path can attach.

## Implementation plan (when picked up)

1. Author `src/state/player_state.h` with a `PlayerState players[4]`
   array. `LINK_X` etc. become `PLAYER_X(0)` aliases for backward
   compat.
2. Replace every `LINK_*` consumer with `PLAYER_*(player_idx)`;
   1-player builds pass `0` everywhere.
3. Add `active_player_count` cell + spawn-position table.
4. Author multiplayer SRAM range at `$820..$87F` (32 bytes per
   extra player × 3 extra players = 96 bytes; rounds to 128 for
   alignment).
5. Add `multiplayer_version` byte at first cell of the new range
   so loading a 1-player save never reads multiplayer garbage.

## Status

DEFERRED_FEATURE — Task 13.1 not started; deliberate scoping
decision per CLAUDE.md priority. Re-evaluation gate: after Phase 14
Full Quest Completion proves 1-player end-to-end.
