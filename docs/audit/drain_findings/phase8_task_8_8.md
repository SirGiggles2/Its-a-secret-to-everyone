# Phase 8 Task 8.8 — Patra

- **NES source**: `reference/aldonunez/Z_07.asm:5295` UpdateObject_JumpTable
                  rows `$47` Patra1 / `$48` Patra2 → `Z_04.asm:10070`
                  UpdatePatra umbrella + `Z_04.asm:10124`
                  ControlPatraFlight. Rows `$25` PatraChild1 / `$26`
                  PatraChild2 → `Z_04.asm:10164` UpdatePatraChild.
                  `Z_07.asm:5601` InitObject_JumpTable rows `$47`/`$48` →
                  `Z_04.asm:9552` InitPatra (seeds slots 2..9 with children
                  inside the init body — `$25`/`$26` have NO InitObject row).
                  PatraManeuverTime table at `Z_04.asm:10064` with the
                  NES OOB quirk ([D3] read beyond [1] reaches bank-4 ROM —
                  bounded in the bridge by `kPatraManeuverTime`).
- **Drained C**:  `src/oracle/enemies/enemy_patra_runtime.c` — helpers
                  (`enrt_flyer_speed_up`, `enrt_flyer_patra_decide_state`,
                  `enrt_animate_and_draw_common_object`,
                  `enrt_play_boss_*_cry_if_needed`) + child body
                  (`enrt_update_patra_child` — state 0 staged spawn off
                  slot-2 child's angle, state 1 orbit + draw + collision
                  + dead-dummy transition). Top-level `UpdatePatra` +
                  `ControlPatraFlight` NOT drained — native bridge body
                  at `src/game/enemies/bosses/boss_patra.c` carries the
                  orchestrator.
- **Coverage**:   FULL — `boss_patra_update` orchestrator composes drained
                  primitives + `c_control_keese_flight` for FlyingState
                  2/3 (Chase / Wander). Child body fully drained.
                  TryChangeManeuver flip mirrors the NES quirk bounded
                  with `kPatraManeuverTime` so non-debug paths produce
                  `$FF` (ManeuverTime[0]).
- **Stance**:     ADOPT (children + helpers) + PARTIAL (top-level Patra
                  orchestrator native-ported from per-line `Z_04.asm`
                  transcription). Bridge supplies only the
                  UpdatePatra+ControlPatraFlight umbrella; every callee
                  is drained.

## Wired pipeline (`src/game/enemies/enemy_loop.c`)

```
[0x47] = enrt_init_patra,        /* Patra1 */
[0x48] = enrt_init_patra,        /* Patra2 */
[0x47] = boss_patra_update,      /* Patra1 (orchestrator bridge) */
[0x48] = boss_patra_update,      /* Patra2 (orchestrator bridge) */
[0x25] = enrt_update_patra_child,/* PatraChild1 */
[0x26] = enrt_update_patra_child,/* PatraChild2 */
```

INIT for `$25`/`$26` PatraChild* is intentionally absent — children are
seeded inside `enrt_init_patra`'s slot-2..9 loop (NES `Z_04.asm:9552`).

## Build verification

```
REQUIRE_GENERATED_ASSETS=1 python tools/debug/build_debug.py
→ builds/Debug.md
```

Clean build; only pre-existing `LINK_X` / `LINK_Y` redefinition warnings.

## Status

CLOSE — Task 8.8 Patra ADOPT + PARTIAL wired. Bridge orchestrator
`boss_patra_update` carries the un-drained UpdatePatra +
ControlPatraFlight slice; everything else is drained.
