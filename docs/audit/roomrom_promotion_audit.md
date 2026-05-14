# RoomRom Promotion Audit (Phase 12 Task 12.1)

**Status:** Baseline pass — 2026-05-14
**Tool:** `tools/audit/check_incremental_promotion.py`
**Authority:** Master plan Phase 12 Task 12.1 + CLAUDE.md WT-5
(NEVER add new files to RoomRom/).

## Scope

`RoomRom/src/*.c` (36 TUs, 4.6 MB) + `RoomRom/data/*.c` (6 TUs).
`RoomRom/tools/` not in scope (build-time helpers).

## Classification

Four buckets per master plan Task 12.1:

- **harness-only** — Phase 12 leaves in RoomRom; not promoted.
- **shared-gameplay** — Phase 12.2 migrates to `src/game/<sub>/`.
- **generated-asset** — Phase 12.2 migrates to `data/<sub>/`.
- **obsolete-debug** — Phase 12 deletes.

## RoomRom/src/*.c (36 TUs)

| File                              | Bucket             | Target path                                | Notes |
|-----------------------------------|--------------------|--------------------------------------------|-------|
| `main.c`                          | harness-only       | stays in `RoomRom/src/`                    | Boot / dispatch loop; harness entrypoint. |
| `render_adapter_sgdk.c`           | harness-only       | stays                                      | RoomRom-local wrapper; SGDK adapter at `src/sgdk_adapter/render_adapter.c` is canonical. |
| `inventory.c`                     | shared-gameplay    | `src/state/inventory.{c,h}` (substrate)    | Phase 6 Task 6.10.4 singleton; move + leave `RoomRom/src/inventory.h` shim. |
| `roomrom_pause.c`                 | shared-gameplay    | `src/state/pause_state.{c,h}` (substrate)  | Phase 6 Task 6.10.1 `g_paused` flag. |
| `roomrom_rng.c`                   | shared-gameplay    | `src/state/rng_state.{c,h}` (substrate)    | NES RNG state machine. |
| `roomrom_link_damage.c`           | shared-gameplay    | `src/game/combat/link_damage.{c,h}`        | Link damage tick + shove. |
| `roomrom_combat.c`                | shared-gameplay    | `src/game/combat/combat_runtime.{c,h}`     | Sword swing + use-weapon dispatch. |
| `roomrom_arrow.c`                 | shared-gameplay    | `src/game/items/arrow.{c,h}`               | Arrow weapon. |
| `roomrom_bomb.c`                  | shared-gameplay    | `src/game/items/bomb.{c,h}`                | Bomb place + detonate. |
| `roomrom_boomerang.c`             | shared-gameplay    | `src/game/items/boomerang.{c,h}`           | Boomerang weapon. |
| `roomrom_candle_fire.c`           | shared-gameplay    | `src/game/items/candle_fire.{c,h}`         | Candle flame. |
| `roomrom_magic_shot.c`            | shared-gameplay    | `src/game/items/magic_shot.{c,h}`          | Wand projectile. |
| `roomrom_hud.c`                   | shared-gameplay    | `src/game/hud/hud_runtime.{c,h}`           | Active HUD render. |
| `roomrom_bg_palette.c`            | shared-gameplay    | `src/game/world/bg_palette.{c,h}`          | Per-room BG palette select. |
| `roomrom_ow_palette.c`            | shared-gameplay    | `src/game/world/ow_palette.{c,h}`          | OW palette table. |
| `roomrom_palette_tick.c`          | shared-gameplay    | `src/state/palette_tick.{c,h}` (already partially substrate) | Note: `src/state/palette_tick.c` already exists — merge or rename. |
| `roomrom_sprites.c`               | shared-gameplay    | `src/game/world/render/sprite_render.{c,h}` | OAM build + sprite write. |
| `roomrom_scene_load.c`            | shared-gameplay    | `src/game/world/scene_load.{c,h}`          | Scene-id → bank dispatch. |
| `roomrom_pushblock.c`             | shared-gameplay    | `src/game/world/pushblock.{c,h}`           | Push-block state machine. |
| `roomrom_world_transition.c`      | shared-gameplay    | `src/game/world/transition.{c,h}`          | World transition. |
| `ow_room_meta.c`                  | shared-gameplay    | `src/game/world/ow_meta.{c,h}`             | OW metadata accessor. |
| `ow_room_render_roomrom.c`        | shared-gameplay    | `src/game/world/render/ow_render.{c,h}`    | OW render. |
| `uw_room_render_roomrom.c`        | shared-gameplay    | `src/game/dungeon/uw_render.{c,h}`         | UW render. |
| `uw_walk_model.c`                 | shared-gameplay    | `src/game/dungeon/walk_model.{c,h}`        | UW walkability. |
| `uw_door_state.c`                 | shared-gameplay    | `src/game/dungeon/door_state.{c,h}`        | UW door state machine. |
| `uw_cellar_meta.c`                | shared-gameplay    | `src/game/dungeon/cellar_meta.{c,h}`       | UW cellar pairs accessor. |
| `uw_dark_meta.c`                  | shared-gameplay    | `src/game/dungeon/dark_meta.{c,h}`         | UW dark-room flag accessor. |
| `uw_item_room_meta.c`             | shared-gameplay    | `src/game/dungeon/item_room_meta.{c,h}`    | UW item-room metadata accessor. |
| `uw_push_block_meta.c`            | shared-gameplay    | `src/game/dungeon/push_block_meta.{c,h}`   | UW push-block manifest accessor. |
| `uw_collision_data.c`             | generated-asset    | `data/dungeon/uw_collision_data.c`         | 51 KB data table. |
| `uw_room_blob.c`                  | generated-asset    | `data/dungeon/uw_room_blob.c`              | 3.1 MB room blob. |
| `expanded_bg_chr.c`               | generated-asset    | `data/chr/expanded_bg_chr.c`               | 732 KB CHR expansion. |
| `redux_overworld.c`               | generated-asset    | `data/redux/redux_overworld.c`             | Redux OW data. |
| `redux_overworld_bg.c`            | generated-asset    | `data/redux/redux_overworld_bg.c`          | Redux OW BG. |
| `redux_uw_bg.c`                   | generated-asset    | `data/redux/redux_uw_bg.c`                 | Redux UW BG. |
| `redux_hud_chr.c`                 | generated-asset    | `data/redux/redux_hud_chr.c`               | Redux HUD CHR. |

Counts: 2 harness-only, 27 shared-gameplay, 7 generated-asset, 0
obsolete-debug.

## RoomRom/src/atlas/*.c (CHR atlas) + RoomRom/src/probes/*.c

Not in this audit pass — atlas is harness-adjacent (per-scene CHR
swap helpers); probes are RoomRom dev-loop scaffolds. Both land as
follow-up classification in Task 12.1 step 2.

## RoomRom/data/*.c (6 TUs)

All generated-asset bucket. Target: `data/rooms/` or `data/redux/`.
Per-file mapping in Task 12.2 implementation PR.

## Promotion order (Phase 12.2)

Family-at-a-time per master plan rule. Each family's PR:
1. Move shared-gameplay → `src/game/<sub>/`.
2. Move generated-asset → `data/<sub>/`.
3. Leave wrapper headers in RoomRom for any still-included shim.
4. Update `tools/debug/build_debug.py` TU lists.
5. Build Debug.md after each family move.
6. Tick `tools/audit/check_incremental_promotion.py` count.

Family order (smallest blast radius first):

1. **substrate-singletons** (3 TUs: inventory, pause, rng) →
   `src/state/`.
2. **palette + bg/ow palette** (3 TUs) → `src/state/` +
   `src/game/world/`.
3. **items** (5 TUs: arrow / bomb / boomerang / candle_fire /
   magic_shot) → `src/game/items/`.
4. **combat** (2 TUs: combat + link_damage) → `src/game/combat/`.
5. **HUD** (1 TU: hud) → `src/game/hud/`.
6. **world meta + render** (4 TUs: ow_room_meta, ow_render,
   sprites, scene_load, world_transition, pushblock) →
   `src/game/world/`.
7. **dungeon meta + render** (7 TUs: uw_render, walk_model,
   door_state, cellar_meta, dark_meta, item_room_meta,
   push_block_meta) → `src/game/dungeon/`.
8. **generated-asset** (7 TUs incl. redux_*) → `data/<sub>/`.

## Status

CLOSE — Task 12.1 baseline classification landed. 36 of 36
`RoomRom/src/*.c` TUs classified. Family-grouped migration order
specified. Tooling for `check_incremental_promotion.py` ships
alongside this doc as Task 12.0 deliverable.
