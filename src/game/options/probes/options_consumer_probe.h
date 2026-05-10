/* Phase 9 Task 9.4 — Option consumer probe.
 *
 * Probe RAM contract ($FF7EB0..$FF7EBF):
 *   [0]   = 'C' (0x43) magic
 *   [1]   = 'N' (0x4E) magic
 *   [2]   = version (2 — 14-getter coverage extension)
 *   [3]   = total tests run (19)
 *   [4]   = passes
 *   [5]   = bits  0..7  (1 = pass)
 *   [6]   = bits  8..15 (1 = pass)
 *   [7]   = bits 16..18 (1 = pass) — only low 3 bits live
 *   [8..15] reserved
 *
 * Tests (bit -> name):
 *   bit0:  defaults_apply_yields_3_hearts_8_bombs
 *   bit1:  start_hearts_7_yields_0x77
 *   bit2:  bomb_upgrade_plus4_yields_12
 *   bit3:  bomb_upgrade_plus8_yields_16
 *   bit4:  start_hearts_16_clamps_to_15
 *   bit5:  getter_low_health_warning_set_returns_one
 *   bit6:  getter_automap_set_returns_one
 *   bit7:  getter_dungeon_colors_set_returns_one
 *   bit8:  getter_visible_secrets_set_returns_one
 *   bit9:  getter_diagonal_sword_set_returns_one
 *   bit10: getter_no_reduced_flashing_set_returns_one
 *   bit11: getter_ab_swap_set_returns_one
 *   bit12: getter_auto_collect_drops_set_returns_one
 *   bit13: getter_sword_style_beam_always_returns_two
 *   bit14: getter_like_like_no_eat_returns_one
 *   bit15: getter_bomb_upgrade_plus8_returns_two
 *   bit16: getter_lost_woods_relaxed_returns_one
 *   bit17: getter_dark_room_bright_returns_two
 *   bit18: getter_start_hearts_5_returns_5
 */

#ifndef SRC_GAME_OPTIONS_PROBES_OPTIONS_CONSUMER_PROBE_H
#define SRC_GAME_OPTIONS_PROBES_OPTIONS_CONSUMER_PROBE_H

#define OPTIONS_CONSUMER_PROBE_BASE  0x00FF7EB0UL

#ifdef __cplusplus
extern "C" {
#endif

void options_consumer_probe_run(void);

#ifdef __cplusplus
}
#endif

#endif /* SRC_GAME_OPTIONS_PROBES_OPTIONS_CONSUMER_PROBE_H */
