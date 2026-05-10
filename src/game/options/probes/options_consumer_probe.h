/* Phase 9 Task 9.4 — Option consumer probe.
 *
 * Probe RAM contract ($FF7EB0..$FF7EBF):
 *   [0]   = 'C' (0x43) magic
 *   [1]   = 'N' (0x4E) magic
 *   [2]   = version (1)
 *   [3]   = total tests run
 *   [4]   = passes
 *   [5]   = test bits 0..4 (1 = pass)
 *   [6..15] reserved
 *
 * Tests:
 *   bit0: defaults_apply_yields_3_hearts_8_bombs
 *   bit1: start_hearts_7_yields_0x77
 *   bit2: bomb_upgrade_plus4_yields_12
 *   bit3: bomb_upgrade_plus8_yields_16
 *   bit4: start_hearts_16_clamps_to_15
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
