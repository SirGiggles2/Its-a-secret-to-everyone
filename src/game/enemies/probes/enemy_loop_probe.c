/* Phase 7 Task 7.2 step 2 in-ROM probe — verifies the enemy slot
 * iterator framework at boot. See enemy_loop_probe.h for block layout.
 *
 * Probe seeds slot 1 with a SlowOctorock at fixed (X,Y,DIR) = ($80,$80,0)
 * via enemy_loop_force_spawn_slow_octorock, then publishes 10 (actual,
 * expected) u16 pairs into ENEMY_LOOP_PROBE_BASE. BizHawk reads the
 * 68K RAM domain at offset 0x7E00 to inspect.
 */

#include "enemy_loop_probe.h"
#include "../enemy_loop.h"
#include "../../../../RoomRom/src/roomrom_enemy_state.h"

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

    /* Stage 2 — deterministic seed. Slot 1, SlowOctorock at $80,$80
     * facing dir 0 (NES Z_07.asm InitSlowOctorockOrGhini target). */
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

    /* check[5]: ENEMY_DIR(1) == 0 (clear_slot_scratch zeros DIR before
     * force_spawn writes it back; final value must equal arg). */
    put_pair(block, 5, (unsigned short)ENEMY_DIR(1), 0x0000u);

    /* check[6]: ENEMY_STATE_TIMER(1) == 1 (NES InitObject preamble at
     * Z_07.asm:5466 stores slot index into ObjStateTimer). */
    put_pair(block, 6, (unsigned short)ENEMY_STATE_TIMER(1), 0x0001u);

    /* check[7]: ENEMY_ALIVE_FLAG(1) == 1. */
    put_pair(block, 7, (unsigned short)ENEMY_ALIVE_FLAG(1), 0x0001u);

    /* check[8]: enemy_loop_get_type(1) == 0x07 (accessor agrees with
     * direct macro read). */
    put_pair(block, 8, (unsigned short)enemy_loop_get_type(1u), 0x0007u);

    /* check[9]: enemy_loop_get_type(2) == 0 (slot 2 still empty). */
    put_pair(block, 9, (unsigned short)enemy_loop_get_type(2u), 0x0000u);
}
