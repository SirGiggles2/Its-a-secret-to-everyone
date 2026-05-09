#ifndef SRC_GAME_ENEMIES_PROBES_ENEMY_LOOP_PROBE_H
#define SRC_GAME_ENEMIES_PROBES_ENEMY_LOOP_PROBE_H

/* Phase 7 Task 7.2 step 2 — in-ROM verification probe.
 *
 * Runs at boot AFTER enemy_loop_room_init() + a deterministic
 * enemy_loop_force_spawn_slow_octorock() seed. Publishes (actual,
 * expected) u16 pairs to ENEMY_LOOP_PROBE_BASE so
 * tools/debug/probes/probe_walker_parity.lua can verify:
 *   - room_init clears slots
 *   - force_spawn writes the right cells (TYPE/X/Y/DIR/STATE_TIMER/ALIVE)
 *   - enemy_loop_alive_count + enemy_loop_get_type accessors agree
 *
 * Block layout @ ENEMY_LOOP_PROBE_BASE = 0xFF7E00 (free per
 * RoomRom Debug RAM Map; $FF7400..$FF77CF is OW raw-tile + UW door
 * persistence — DO NOT collide):
 *   [0]  = 'E'                        (0x45) magic
 *   [1]  = 'L'                        (0x4C) magic
 *   [2]  = check_count (count of u16 pairs that follow)
 *   [3]  = 0 (reserved)
 *   [4..] = check_count * 4 bytes: actual_be_u16 || expected_be_u16
 */

#define ENEMY_LOOP_PROBE_BASE   0x00FF7E00UL
#define ENEMY_LOOP_PROBE_COUNT  10u

#ifdef __cplusplus
extern "C" {
#endif

void enemy_loop_probe_run(void);

#ifdef __cplusplus
}
#endif

#endif /* SRC_GAME_ENEMIES_PROBES_ENEMY_LOOP_PROBE_H */
