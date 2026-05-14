# Phase 9 Task 9.4 — Wire Option Consumers

- **NES source**: NONE for the Redux options themselves; per-consumer
                  gate sites land inside drained NES bodies:
                  - `RoomRom/src/main.c` (room scroll + A/B input).
                  - `RoomRom/src/roomrom_combat.c` (sword swing style).
                  - `src/game/enemies/enemy_special_bridge.c`
                    (LikeLike capture behaviour, Z_04.asm:6818).
                  - `src/game/world/draw_dispatch.c` (flashing /
                    photosensitive guard, draw-pipeline).
- **Drained C**:  Consumer interface declared in
                  `src/game/options/options_consumer.{h,c}`. Per
                  option, the *gate site* lives inside drained
                  per-subsystem bodies (sword, like-like, draw, input)
                  — those bodies already drained earlier; the option
                  read is a thin Redux pre-gate at the top of the
                  drained logic.
- **Coverage**:   PARTIAL — 6 of 14 master-plan consumers wired
                  end-to-end at call sites:
                  - `start_hearts` + `bomb_upgrade` via
                    `options_consumer_apply_inventory_at_start()`
                    (RoomRom/src/main.c:1328, game-start hook).
                  - `room_scroll` (RoomRom/src/main.c:217).
                  - `ab_swap` (RoomRom/src/main.c:1555).
                  - `sword_style` (roomrom_combat.c:336).
                  - `like_like_behavior` (enemy_special_bridge.c:227).
                  - `no_reduced_flashing` (draw_dispatch.c:568 + :640).
                  Remaining 8 consumers (low_health_warning, automap,
                  dungeon_colors, visible_secrets, diagonal_sword,
                  lost_woods, dark_room_light, auto_collect_drops) are
                  Redux-only features whose gate sites do not yet
                  exist — most depend on Phase 9.5 HUD render layer
                  (automap / dungeon_colors / visible_secrets), Phase
                  9.6 pause subscreen (low_health_warning indicator),
                  Phase 5 dungeon-core polish (dark_room_light), or
                  Phase 7 enemy-loop callsite (auto_collect_drops).
- **Stance**:     PARTIAL (GREENFIELD per-consumer; gate sites are
                  thin pre-checks inside drained subsystem bodies).
                  Remaining 8 consumers tracked as Phase 9 deferrals;
                  recording does not invalidate phase close because
                  options framework (Task 9.1-9.3) is fully operational
                  and committed consumers are visibly distinct under
                  probe.

## Wired call sites (current)

| Option (master plan label)        | Call site                                                    | Drained body |
|-----------------------------------|--------------------------------------------------------------|--------------|
| start_hearts (game-start)         | `RoomRom/src/main.c:1328` `options_consumer_apply_inventory_at_start` | Inventory init at room enter |
| bomb_upgrade (game-start)         | same                                                          | same |
| room_scroll                        | `RoomRom/src/main.c:217`                                     | Scroll mode select (classic vs Redux) |
| ab_swap                            | `RoomRom/src/main.c:1555`                                    | Input dispatch |
| sword_style                        | `RoomRom/src/roomrom_combat.c:336`                           | UseWeapon / sword fork |
| like_like_behavior                 | `src/game/enemies/enemy_special_bridge.c:227`                | UpdateLikeLike (Z_04.asm:6818) |
| no_reduced_flashing                | `src/game/world/draw_dispatch.c:568`, `:640`                 | Draw-pipeline (photosensitive guard) |

## Deferred consumers (Phase 9 deferrals)

The remaining 8 consumers wait on a downstream surface that is not yet
shipped:

| Option                | Blocked on                                       |
|-----------------------|--------------------------------------------------|
| low_health_warning    | Phase 9.6 pause / HUD warning indicator surface  |
| automap               | Phase 9.5 native HUD map render                  |
| dungeon_colors        | Phase 9.5 dungeon-tinted palette pipeline        |
| visible_secrets       | Phase 9.5 HUD secret-hint glyph layer            |
| diagonal_sword        | Phase 5 / Phase 6 sword-swing 8-way input rewrite |
| lost_woods            | Phase 4 overworld traversal door selector        |
| dark_room_light       | Phase 5 dungeon-core dark-room polish            |
| auto_collect_drops    | Phase 7 enemy-drop pickup callsite               |

Each landing PR will:
1. Resolve the downstream blocker.
2. Add a 1-line gate using the existing `options_consumer_get_*`
   accessor.
3. Add a probe row to `options_consumer_probe.c` and bump the consumer
   coverage matrix.

## Probe

`src/game/options/probes/options_consumer_probe.c` — contract probe
that flips each option, then asserts the matching `options_consumer_get_*`
accessor returns the expected value. Confirms the consumer surface
exists for all 14 options even when the call site is not yet wired —
this guarantees the consumer API contract is stable while wiring is
incremental.

## Build verification

```
REQUIRE_GENERATED_ASSETS=1 python tools/debug/build_debug.py
→ builds/Debug.md
```

Clean build; `options_consumer.o` + `options_consumer_probe.o` linked.

## Status

CLOSE (with deferrals) — Task 9.4 Wire Option Consumers PARTIAL.
Framework, accessor surface, and 6 / 14 call sites shipped. Remaining 8
recorded as phase-9 deferrals tied to specific downstream phases.
