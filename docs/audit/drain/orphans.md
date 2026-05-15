# Drain Orphans

> Drained C functions with NO master plan task header citing them.
> Either dead code, hidden coverage we forgot to plan around, or the
> task header is incomplete.

| File | Function | Subsystem |
|------|----------|-----------|
| `src/game/combat/combat_runtime.c` | `compute_state` | combat |
| `src/game/combat/combat_runtime.c` | `recompute_y_bias` | combat |
| `src/game/combat/combat_runtime.c` | `roomrom_combat_init` | combat |
| `src/game/combat/combat_runtime.c` | `roomrom_combat_link_locked` | combat |
| `src/game/combat/combat_runtime.c` | `roomrom_combat_set_redux` | combat |
| `src/game/combat/combat_runtime.c` | `roomrom_combat_set_uw` | combat |
| `src/game/combat/combat_runtime.c` | `roomrom_combat_try_swing` | combat |
| `src/game/combat/combat_runtime.c` | `roomrom_combat_update` | combat |
| `src/game/combat/combat_runtime.c` | `spawn_beam` | combat |
| `src/game/combat/combat_runtime.c` | `sword_style_allows_beam` | combat |
| `src/game/combat/combat_runtime.c` | `sword_subpal_for_items` | combat |
| `src/game/combat/combat_runtime.c` | `update_beam` | combat |
| `src/game/hud/hud_runtime.c` | `apply_attr_byte` | hud |
| `src/game/hud/hud_runtime.c` | `apply_transfer_macro` | hud |
| `src/game/hud/hud_runtime.c` | `clear_hud_b` | hud |
| `src/game/hud/hud_runtime.c` | `clear_hud_pal` | hud |
| `src/game/hud/hud_runtime.c` | `clear_hud_window` | hud |
| `src/game/hud/hud_runtime.c` | `draw_count_cell` | hud |
| `src/game/hud/hud_runtime.c` | `draw_hearts_row` | hud |
| `src/game/hud/hud_runtime.c` | `draw_hud_dynamic` | hud |
| `src/game/hud/hud_runtime.c` | `draw_hud_tile` | hud |
| `src/game/hud/hud_runtime.c` | `draw_hud_tile_attr` | hud |
| `src/game/hud/hud_runtime.c` | `draw_hud_tile_b` | hud |
| `src/game/hud/hud_runtime.c` | `draw_original_map_marker` | hud |
| `src/game/hud/hud_runtime.c` | `draw_status_counts_original` | hud |
| `src/game/hud/hud_runtime.c` | `draw_status_counts_redux` | hud |
| `src/game/hud/hud_runtime.c` | `hud_word` | hud |
| `src/game/hud/hud_runtime.c` | `roomrom_hud_draw` | hud |
| `src/game/hud/hud_runtime.c` | `roomrom_hud_refresh_dynamic` | hud |
| `src/game/hud/hud_runtime.c` | `roomrom_hud_upload_chr` | hud |
| `src/game/hud/hud_runtime.c` | `upload_common_hud_chr` | hud |
| `src/game/hud/hud_runtime.c` | `upload_common_hud_tile` | hud |
| `src/game/hud/hud_runtime.c` | `upload_common_hud_tile_range` | hud |
| `src/game/hud/hud_runtime.c` | `upload_redux_automap_chr` | hud |
| `src/game/options/options_runtime.c` | `bool_bit_for_id` | options |
| `src/game/options/options_runtime.c` | `compute_checksum` | options |
| `src/game/options/options_runtime.c` | `load_defaults_into` | options |
| `src/game/options/options_runtime.c` | `migrate_image` | options |
| `src/game/options/options_runtime.c` | `options_get` | options |
| `src/game/options/options_runtime.c` | `options_get_version` | options |
| `src/game/options/options_runtime.c` | `options_runtime_apply` | options |
| `src/game/options/options_runtime.c` | `options_runtime_init` | options |
| `src/game/options/options_runtime.c` | `options_runtime_peek` | options |
| `src/game/options/options_runtime.c` | `options_runtime_serialize` | options |
| `src/game/options/options_runtime.c` | `options_runtime_validate` | options |
| `src/game/options/options_runtime.c` | `options_set` | options |
| `src/game/options/options_runtime.c` | `read_be_u16` | options |
| `src/game/options/options_runtime.c` | `read_bool_bit` | options |
| `src/game/options/options_runtime.c` | `recheck_after_write` | options |
| `src/game/options/options_runtime.c` | `write_be_u16` | options |
| `src/game/options/options_runtime.c` | `write_bool_bit` | options |
| `src/game/world/palette_tick_runtime.c` | `roomrom_palette_tick_frame` | world |
| `src/game/world/palette_tick_runtime.c` | `roomrom_palette_tick_init` | world |
