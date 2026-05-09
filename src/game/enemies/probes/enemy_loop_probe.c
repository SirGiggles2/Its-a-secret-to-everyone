/* Phase 7 Task 7.2 step 3 in-ROM probe — verifies enemy slot iterator
 * + INIT dispatch row $07 (slow octorok / ghini). See enemy_loop_probe.h
 * for block layout.
 *
 * Step-3 wiring: enemy_init_fns[$07] = enrt_init_slow_octorock_or_ghini.
 * After force_spawn the init body runs: enrt_octorock_common(slot, 32)
 * → sets WALK_SPEED, MOVE_TIMER, OBJ_STATE=0, DRAW_FRAME=0, ANIM_TIMER=6,
 * → enrt_init_walker(slot) computes DIR from LINK_X/LINK_Y vs OBJ_X/Y.
 *
 * Probe pre-sets LINK_X = LINK_Y = $80 so DIR computation is
 * deterministic (link == obj → h_dir = 2, ties resolve to h_dir).
 *
 * Probe publishes 14 (actual, expected) u16 pairs into
 * ENEMY_LOOP_PROBE_BASE. BizHawk reads the 68K RAM domain at offset
 * 0x7E00 to inspect.
 */

#include "enemy_loop_probe.h"
#include "../enemy_loop.h"
#include "../../../../RoomRom/src/roomrom_enemy_state.h"
#include "object_state.h"   /* OBJ_STATE for step-3 forwarder check */

static void put_u16_be(volatile unsigned char *p, unsigned short v)
{
    p[0] = (unsigned char)(v >> 8);
    p[1] = (unsigned char)(v & 0xFFu);
}

static void put_pair(volatile unsigned char *block, unsigned char idx,
                     unsigned short actual, unsigned short expected)
{
    volatile unsigned char *slot = &block[4u + (unsigned short)idx * 4u];
    put_u16_be(slot,     actual);
    put_u16_be(slot + 2, expected);
}

void enemy_loop_probe_run(void)
{
    volatile unsigned char *block =
        (volatile unsigned char *)ENEMY_LOOP_PROBE_BASE;
    unsigned int alive_before;
    unsigned int alive_after;

    /* Stage 1 — start clean. enemy_loop_room_init was called from
     * roomrom_debug_enter just before this probe; verify it cleared
     * slot state. */
    alive_before = enemy_loop_alive_count();

    /* Stage 2 — pin LINK position so the wired enrt_init_walker DIR
     * computation is deterministic. With LINK at the same cell as the
     * spawn target, h_dir=2 (link_x >= obj_x), v_dir=4, diff_x=diff_y=0,
     * tie resolves to ENEMY_SCRATCH_Y (= h_dir). Final DIR = 2. */
    LINK_X = 0x80u;
    LINK_Y = 0x80u;

    /* Stage 3 — deterministic seed. Slot 1, SlowOctorock at $80,$80.
     * Pre-init dir arg overwritten by enrt_init_walker — value here is
     * irrelevant after step-3 wiring. Kept at 0 for clear_slot_scratch
     * sequencing parity. */
    enemy_loop_force_spawn_slow_octorock(1u, 0x80u, 0x80u, 0u);

    alive_after = enemy_loop_alive_count();

    /* Header. */
    block[0] = 0x45u;                          /* 'E' */
    block[1] = 0x4Cu;                          /* 'L' */
    block[2] = (unsigned char)ENEMY_LOOP_PROBE_COUNT;
    block[3] = 0u;

    /* check[0]: alive_count was 0 after room_init (all slots cleared). */
    put_pair(block, 0, (unsigned short)alive_before, 0x0000u);

    /* check[1]: alive_count is 1 after force_spawn. */
    put_pair(block, 1, (unsigned short)alive_after, 0x0001u);

    /* check[2]: ENEMY_TYPE(1) == 0x07 (RedSlowOctorock). */
    put_pair(block, 2, (unsigned short)ENEMY_TYPE(1), 0x0007u);

    /* check[3]: ENEMY_X(1) == 0x80. */
    put_pair(block, 3, (unsigned short)ENEMY_X(1), 0x0080u);

    /* check[4]: ENEMY_Y(1) == 0x80. */
    put_pair(block, 4, (unsigned short)ENEMY_Y(1), 0x0080u);

    /* check[5]: ENEMY_DIR(1) == 2 — enrt_init_walker computes h_dir
     * (=2 since link_x>=obj_x) and the diff_y(0)<diff_x(0) tie resolves
     * to ENEMY_SCRATCH_Y which holds h_dir. Pre-step-3 expected $00. */
    put_pair(block, 5, (unsigned short)ENEMY_DIR(1), 0x0002u);

    /* check[6]: ENEMY_STATE_TIMER(1) == 0 — overlapping NES cell.
     * ENEMY_STATE_TIMER and OBJ_STATE both map to OBJ($AC,slot). NES
     * InitObject preamble stores slot index into $AC, then octorok
     * init's z07_reset_obj_state zeroes the same byte. Pre-step-3
     * expected $01 (no init was wired); post-step-3 the forwarder
     * fires and the cell ends at 0. */
    put_pair(block, 6, (unsigned short)ENEMY_STATE_TIMER(1), 0x0000u);

    /* check[7]: ENEMY_ALIVE_FLAG(1) == 1. */
    put_pair(block, 7, (unsigned short)ENEMY_ALIVE_FLAG(1), 0x0001u);

    /* check[8]: enemy_loop_get_type(1) == 0x07 (accessor agrees with
     * direct macro read). */
    put_pair(block, 8, (unsigned short)enemy_loop_get_type(1u), 0x0007u);

    /* check[9]: enemy_loop_get_type(2) == 0 (slot 2 still empty). */
    put_pair(block, 9, (unsigned short)enemy_loop_get_type(2u), 0x0000u);

    /* Step-3 INIT-side checks. enrt_octorock_common(slot, 32) writes
     * these cells before delegating to enrt_init_walker. All four prove
     * the dispatch row $07 actually fired. */

    /* check[10]: ENEMY_WALK_SPEED(1) == 0x20 — speed arg passed
     * to enrt_octorock_common from enrt_init_slow_octorock_or_ghini. */
    put_pair(block, 10, (unsigned short)ENEMY_WALK_SPEED(1), 0x0020u);

    /* check[11]: ENEMY_MOVE_TIMER(1) == 0x20 — (slot+1)<<4 with slot=1
     * is 2<<4 = $20. NES seeds varied per slot to avoid tick-sync. */
    put_pair(block, 11, (unsigned short)ENEMY_MOVE_TIMER(1), 0x0020u);

    /* check[12]: ENEMY_ANIM_TIMER(1) == 6 — fixed cadence per
     * enrt_octorock_common. */
    put_pair(block, 12, (unsigned short)ENEMY_ANIM_TIMER(1), 0x0006u);

    /* check[13]: OBJ_STATE(1) == 0 — z07_reset_obj_state forwarder
     * dispatched to core_reset_obj_state and zeroed the cell. Proves
     * the forwarder linked + the drained body executed. */
    put_pair(block, 13, (unsigned short)OBJ_STATE(1), 0x0000u);
}
