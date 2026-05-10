# Phase 9 Task 9.4 — Consumer Wiring Status

Tracks which of the 14 OPTION_ID consumers are wired into Debug.md
behavior. Coverage probe (5 inventory-shape + 14 getter wire-up = 19
tests) verifies the wire-up; behavioral verification deferred until
specific gameplay scenarios are scriptable.

## Wired (6 of 14)

| Option | Site | Mode | Notes |
|---|---|---|---|
| START_HEARTS | `src/game/options/options_consumer.c::apply_inventory_at_start` | apply-at-start | Clamps 3..15, writes packed `heart_values` |
| BOMB_UPGRADE | `src/game/options/options_consumer.c::apply_inventory_at_start` | apply-at-start | VANILLA->8 / PLUS4->12 / PLUS8->16 |
| AB_SWAP | `RoomRom/src/main.c` (post `s_joy_prev`) | runtime gate | Swaps BUTTON_A/B in joy + pressed |
| SWORD_STYLE | `RoomRom/src/roomrom_combat.c::sword_style_allows_beam` | runtime gate | VANILLA full-HP / STAB_ONLY no-beam / BEAM_ALWAYS |
| LIKE_LIKE_BEHAVIOR | `src/game/enemies/enemy_special_bridge.c::enrt_update_like_like` | runtime gate | NO_EAT skips `INV_MAGIC_SHIELD = 0` write |
| NO_REDUCED_FLASHING | `src/game/world/draw_dispatch.c::{draw_item_by_slot,draw_animate_item_object}` | runtime gate | Photosensitive guard suppresses 7.5/30 Hz strobes |

## Deferred (8 of 14) — single-point hooks not yet identified in src/game/

Each entry lists the most likely hook location based on a search of
`src/`, plus the reason it cannot be wired without RoomRom edits or
deeper investigation. Per WT-5 RoomRom freeze, these wires must wait
for either: (a) a port of the relevant routine into `src/game/`, or
(b) a sanctioned single-line RoomRom touch with explicit user buy-in.

| Option | Hook candidate | Blocker |
|---|---|---|
| LOW_HEALTH_WARNING | HUD render / heart-tick beep — likely `RoomRom/src/roomrom_hud.c` or audio dispatch | No matching code in `src/game/` for the low-HP beep. |
| AUTOMAP | Underworld map-cell render — likely `RoomRom/src/atlas/*` or HUD pause-screen | Visible-map writer not yet ported to `src/game/`. |
| DUNGEON_COLORS | Per-level palette tint — `room_patch_and_cue_level_palettes_transfer` writes only the player tunic color, not dungeon walls; wall palette load lives in `src/oracle/room/room_mode_runtime.c` `LevelInfoBlock` consumer (deeper than a one-line gate). |
| VISIBLE_SECRETS | Secret-tile hint dot overlay — no existing implementation; new feature. |
| DIAGONAL_SWORD | 8-way sword swing dispatch — combat code lives in `RoomRom/src/roomrom_combat.c` (off-limits per WT-5 / "DO NOT WORK ON ROOMROM"). |
| AUTO_COLLECT_DROPS | Item-touch radius / magnet — pickup test is in `src/oracle/items/item_runtime.c`; native dispatch is `src/game/items/item_dispatch.{c,h}` but pickup-radius logic not exposed. |
| LOST_WOODS | Overworld direction-rule check — exit logic in `RoomRom/src/redux_overworld.c` or `src/oracle/room/room_mode_runtime.c`. |
| DARK_ROOM_LIGHT | Underworld torch/candle render — palette + sprite cull tied to `RoomRom/src/atlas/level_chr_swap.c` and dungeon-room render. |

## Coverage probe artifact

`task_9_4_options_consumer_probe_report_v2.txt` records the live result:
all 19 wire-up tests pass, magic = 'CN', version = 2, frame_counter
ticks > 0. The probe verifies the accessor surface; deferred consumers
return their stored option value but no behavior site reads them yet.

## Next concrete advance

When the WT-5 freeze is lifted (or a port of the relevant subsystem
into `src/game/` lands), the 8 deferred consumers can be wired one at
a time using the same pattern: include `options_consumer.h`, add a
single-line gate at the identified hook, rebuild Debug.md, re-run the
v2 consumer probe to verify regression-clean. Each consumer should be
its own commit with the live-probe output captured in
`docs/audit/phase9/`.
