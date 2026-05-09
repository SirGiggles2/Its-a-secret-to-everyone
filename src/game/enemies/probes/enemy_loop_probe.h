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
#define ENEMY_LOOP_PROBE_COUNT  14u

/* Step 4 live-tick block. Published every frame at end of
 * enemy_loop_tick() so probe_walker_tick_trace.lua can sample slot 1
 * cell evolution and prove the UPDATE chain is firing per frame even
 * when no sprite is visible (oam_router gap separately tracked).
 *
 * Layout @ ENEMY_LOOP_TICK_PROBE_BASE = 0xFF7F00:
 *   [0]  = 'T' (0x54) magic
 *   [1]  = 'K' (0x4B) magic
 *   [2..3] = frame_counter (be u16, increments per tick call)
 *   [4]  = ENEMY_ALIVE_FLAG(1)
 *   [5]  = ENEMY_TYPE(1)
 *   [6]  = ENEMY_X(1)
 *   [7]  = ENEMY_Y(1)
 *   [8]  = ENEMY_DIR(1)
 *   [9]  = ENEMY_ANIM_TIMER(1)
 *   [10] = ENEMY_DRAW_FRAME(1)
 *   [11] = ENEMY_MOVE_TIMER(1)
 *   [12] = ENEMY_STATE_TIMER(1)
 *   [13] = ENEMY_WALK_SPEED(1)
 *   [14] = LINK_X (slot 0)
 *   [15] = LINK_Y (slot 0)
 */
#define ENEMY_LOOP_TICK_PROBE_BASE 0x00FF7F00UL

/* Step 4 pre-tick block at $FF7F40 — same byte layout as live block but
 * published BEFORE the slot iterator runs each frame. If pre-tick TYPE
 * is $07 but post-tick TYPE is $00, the dispatch / update body zeroed
 * the cell. If pre-tick is already $00, something between init and the
 * first tick wiped it. */
#define ENEMY_LOOP_TICK_PRE_PROBE_BASE 0x00FF7F40UL

/* Step 8 multi-slot block at $FF7F80. 5 slots * 8 bytes = 40 bytes.
 * Per-slot layout (offset = (slot_idx-1) * 8 within block):
 *   [0] = ENEMY_ALIVE_FLAG
 *   [1] = ENEMY_TYPE
 *   [2] = ENEMY_X
 *   [3] = ENEMY_Y
 *   [4] = ENEMY_DIR
 *   [5] = ENEMY_ANIM_TIMER
 *   [6] = ENEMY_DRAW_FRAME
 *   [7] = ENEMY_WALK_SPEED
 *
 * Slot 1=octorock $07, 2=moblin $03, 3=goriya $05, 4=stalfos $2A,
 *      5=darknut $0B (step 11).
 * Used by step-8/11 multi-slot trace to verify walker dispatch rows
 * tick + move without crashing. */
#define ENEMY_LOOP_MULTI_SLOT_BASE 0x00FF7F80UL

/* Step 14 shot-scan block at $FF7FA8 (after multi-slot 5*8=40 bytes
 * ending at $FF7FA7). Scans slots 1..15 every frame for any ENEMY_TYPE
 * in $53..$5C (shot/arrow/boomerang). Records first 8 hits.
 * Layout:
 *   [0]   = 'S' (0x53) magic
 *   [1]   = 'H' (0x48) magic
 *   [2]   = ActiveMonsterShots ($034C)
 *   [3]   = scan_count (number of shot slots found, 0..8)
 *   [4..] = up to 8 entries x 4 bytes: [slot, type, x, y]
 * Total = 4 + 32 = 36 bytes. Block end = $FF7FCB.
 *
 * Used by step-14 probe extension to verify shot UPDATE rows fire on
 * dynamically-spawned shot slots. */
#define ENEMY_LOOP_SHOT_SCAN_BASE 0x00FF7FA8UL

#ifdef __cplusplus
extern "C" {
#endif

void enemy_loop_probe_run(void);
void enemy_loop_probe_publish_live(void);
void enemy_loop_probe_publish_pre(void);

#ifdef __cplusplus
}
#endif

#endif /* SRC_GAME_ENEMIES_PROBES_ENEMY_LOOP_PROBE_H */
