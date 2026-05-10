/* Phase 9 Task 9.5 — HUD format probe (heart row formatter contract).
 *
 * Probe RAM contract ($FF7EC0..$FF7ECF):
 *   [0]   = 'H' (0x48) magic
 *   [1]   = 'F' (0x46) magic
 *   [2]   = version (1)
 *   [3]   = total tests run (8)
 *   [4]   = passes
 *   [5]   = bits 0..7  (1 = pass)
 *   [6..15] reserved
 *
 * Tests verify the drained `hud_format_status_bar_text` (src/game/hud/
 * hud_dispatch.c) against hand-traced expected byte sequences over the
 * 41-byte transfer buffer at RAM($0302..$032A). This locks the heart-
 * row format contract that any native Genesis-side HUD renderer (Task
 * 9.5 bullets 1-9) must consume unchanged.
 *
 * Bit map:
 *   bit0: template_loaded (header words + terminator)
 *   bit1: hearts_3_full   (hearts=$33, partial=0)
 *   bit2: hearts_3_max_1_cur (hearts=$31, partial=0)
 *   bit3: hearts_8_max_3_cur_high_partial (hearts=$83, partial=$80)
 *   bit4: hearts_8_max_3_cur_low_partial  (hearts=$83, partial=$40)
 *   bit5: hearts_15_full  (hearts=$FF, partial=0)
 *   bit6: hearts_zero     (hearts=$00, partial=0)
 *   bit7: hearts_7_full   (hearts=$77, partial=0)
 */

#ifndef SRC_GAME_HUD_PROBES_HUD_FORMAT_PROBE_H
#define SRC_GAME_HUD_PROBES_HUD_FORMAT_PROBE_H

#define HUD_FORMAT_PROBE_BASE  0x00FF7EC0UL

#ifdef __cplusplus
extern "C" {
#endif

void hud_format_probe_run(void);

#ifdef __cplusplus
}
#endif

#endif /* SRC_GAME_HUD_PROBES_HUD_FORMAT_PROBE_H */
