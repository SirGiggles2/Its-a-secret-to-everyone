/* link_collision_dispatch.c — native link-collision subsystem dispatch
 * (Phase 4).
 *
 * Drain MATCH (verified-by-use). Pure C; calls native core_* + room_*.
 * Drain provenance: src/oracle/combat/link_collision_runtime.c.
 */

#include "link_collision_dispatch.h"
#include <stdint.h>
#include "platform_abi.h"
#include "combat_state.h"      /* MON_TYPE, ROOM_KILL_COUNT,
                                * ROOM_CHAIN_KILL_COUNT, ROOM_CHAIN_KILL_BONUS,
                                * COMBAT_THRESHOLD_X/Y, LINK_HEARTS,
                                * LINK_PARTIAL_HEART, LINK_RING_LEVEL,
                                * LINK_ACTION_TIMER, LINK_DIR */
#include "progress_state.h"    /* MODE_VALUE */
#include "core/core_dispatch.h"      /* core_play_sample */
#include "room/room_dispatch.h"      /* room_end_game_mode */

void link_collision_link_be_harmed(unsigned int monster_slot)
{
    /* drain at link_collision_runtime.c:6-46. */
    if ((unsigned char)MON_TYPE(monster_slot) != 0x2Eu) {
        core_play_sample(8u);
    }
    {
        unsigned char rings = (unsigned char)LINK_RING_LEVEL;
        while (rings--) {
            const unsigned char carry =
                (unsigned char)((unsigned char)COMBAT_THRESHOLD_X & 1u);
            COMBAT_THRESHOLD_X =
                (uint8_t)((unsigned char)COMBAT_THRESHOLD_X >> 1);
            COMBAT_THRESHOLD_Y =
                (uint8_t)(((carry) << 7) |
                          ((unsigned char)COMBAT_THRESHOLD_Y >> 1));
        }
    }
    ROOM_KILL_COUNT = 0u;
    ROOM_CHAIN_KILL_COUNT = 0u;
    ROOM_CHAIN_KILL_BONUS = 0u;
    for (;;) {
        const unsigned char partial = (unsigned char)LINK_PARTIAL_HEART;
        const unsigned char dmg_lo = (unsigned char)COMBAT_THRESHOLD_Y;
        if (partial >= dmg_lo) {
            LINK_PARTIAL_HEART = (uint8_t)(partial - dmg_lo);
            if ((unsigned char)COMBAT_THRESHOLD_X >
                ((unsigned char)LINK_HEARTS & 0x0Fu)) {
                break;
            }
            LINK_HEARTS = (uint8_t)((unsigned char)LINK_HEARTS -
                                    (unsigned char)COMBAT_THRESHOLD_X);
            return;
        }
        COMBAT_THRESHOLD_Y = (uint8_t)(dmg_lo - partial);
        if (((unsigned char)LINK_HEARTS & 0x0Fu) == 0u) {
            break;
        }
        LINK_HEARTS = (uint8_t)((unsigned char)LINK_HEARTS - 1u);
        LINK_PARTIAL_HEART = 0xFFu;
    }
    LINK_HEARTS = (uint8_t)((unsigned char)LINK_HEARTS & 0xF0u);
    (void)room_end_game_mode();
    LINK_PARTIAL_HEART = 0u;
    LINK_ACTION_TIMER = 0u;
    MODE_VALUE = 17u;
    LINK_DIR = 4u;
}
