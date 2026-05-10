/* Phase 9 Task 9.5 — HUD format probe (status-bar formatter contract).
 *
 * Probe RAM contract ($FF7EC0..$FF7ECF):
 *   [0]   = 'H' (0x48) magic
 *   [1]   = 'F' (0x46) magic
 *   [2]   = version (2 — adds rupee/bomb/key decimal coverage)
 *   [3]   = total tests run (15)
 *   [4]   = passes
 *   [5]   = bits  0..7  (1 = pass)
 *   [6]   = bits  8..14
 *   [7..15] reserved
 *
 * Tests verify the drained `hud_format_status_bar_text` (src/game/hud/
 * hud_dispatch.c) against hand-traced expected byte sequences over the
 * 41-byte transfer buffer at RAM($0302..$032A). This locks the status
 * bar format contract that any native Genesis-side HUD renderer (Task
 * 9.5 bullets 1-4) must consume unchanged.
 *
 * Bit map (Group A — heart row, 8 tests):
 *   bit0: template_loaded (header words + terminator)
 *   bit1: hearts_3_full   (hearts=$33, partial=0)
 *   bit2: hearts_3_max_1_cur (hearts=$31, partial=0)
 *   bit3: hearts_8_max_3_cur_high_partial (hearts=$83, partial=$80)
 *   bit4: hearts_8_max_3_cur_low_partial  (hearts=$83, partial=$40)
 *   bit5: hearts_15_full  (hearts=$FF, partial=0)
 *   bit6: hearts_zero     (hearts=$00, partial=0)
 *   bit7: hearts_7_full   (hearts=$77, partial=0)
 *
 * Bit map (Group B — decimal counters, 7 tests):
 *   bit8:  rupees_42      buf[25..27] = [$21, 4, 2]
 *   bit9:  rupees_0       buf[25..27] = [$21, 0, $24]
 *   bit10: rupees_255     buf[25..27] = [2, 5, 5]
 *   bit11: bombs_8        buf[37..39] = [$21, 8, $24]
 *   bit12: bombs_99       buf[37..39] = [$21, 9, 9]
 *   bit13: keys_5_no_mkey buf[31..33] = [$21, 5, $24], master_key=0
 *   bit14: master_key_dash buf[31..33] = [$21, 10, $24], master_key!=0
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
