/* trap_dispatch.c — native trap subsystem dispatch (Phase 4).
 *
 * Drain MATCH (verified-by-use). Pure C; calls native core_* + enemy_*.
 * Drain provenance: src/oracle/world/trap_runtime.c.
 */

#include "trap_dispatch.h"
#include <stdint.h>
#include "platform_abi.h"      /* RAM, OBJ */
#include "trap_state.h"        /* TELEPORT_LEVEL_INDEX, TELEPORT_ACTIVE_FLAG,
                                * WHIRLWIND_ACTIVE_FLAG, MODE_TIMER,
                                * TRAP_OBJ_TYPE, TRAP_BASE_SLOT */
#include "world_state.h"       /* LINK_DIR, LINK_Y, LINK_ACTION_TIMER,
                                * WORLD_TMP0/_1 */
#include "progress_state.h"    /* MODE_VALUE, SUBMODE_VALUE */
#include "object_state.h"      /* OBJ_X, OBJ_Y */
#include "combat_state.h"      /* MON_TYPE, MON_STATUS_FLAGS */
#include "core/core_dispatch.h"     /* core_set_up_whirlwind, core_init_one_simple_object */
#include "enemies/enemy_dispatch.h" /* enemy_find_empty_monster_slot */

/* TeleportYs — Z_01.asm:1226. Per-level teleport Y coords. */
static const unsigned char k_teleport_ys[8] = {
    0x8Du, 0xADu, 0x8Du, 0x8Du, 0xADu, 0x8Du, 0xADu, 0x5Du
};

/* TrapXs — Z_01.asm:1297. */
static const unsigned char k_trap_xs[6] = {
    0x20u, 0x20u, 0xD0u, 0xD0u, 0x40u, 0xB0u
};

/* TrapYs — Z_01.asm:1301. */
static const unsigned char k_trap_ys[6] = {
    0x5Du, 0xBDu, 0x5Du, 0xBDu, 0x8Du, 0x8Du
};

/* LevelMasks — Z_01.asm. Used by SummonWhirlwind to gate teleport
 * cycling on completed dungeons. Same shape as the table baked
 * inside progress_dispatch.c (k_level_masks). */
static const unsigned char k_trap_level_masks[8] = {
    0x01u, 0x02u, 0x04u, 0x08u, 0x10u, 0x20u, 0x40u, 0x80u
};

void trap_advance_teleporting_level_index(void)
{
    /* drain at trap_runtime.c:81-86. NES AdvanceTeleportingLevelIndex.
     *
     *   INC TELEPORT_LEVEL_INDEX
     *   LDA LINK_DIR
     *   AND #$09        ; up ($08) | right ($01)
     *   BNE @Exit
     *   DEC TELEPORT_LEVEL_INDEX
     *   DEC TELEPORT_LEVEL_INDEX
     *
     * If LINK_DIR's up-or-right bits are clear, undo the increment
     * AND decrement once more (net -1 from original). */
    TELEPORT_LEVEL_INDEX = (uint8_t)(TELEPORT_LEVEL_INDEX + 1u);
    if ((LINK_DIR & 0x09u) == 0u) {
        TELEPORT_LEVEL_INDEX = (uint8_t)(TELEPORT_LEVEL_INDEX - 2u);
    }
}

void trap_check_init_whirlwind_and_begin_update(void)
{
    /* drain at trap_runtime.c:69-79. */
    if ((unsigned char)TELEPORT_ACTIVE_FLAG != 0u) {
        TELEPORT_ACTIVE_FLAG =
            (uint8_t)((unsigned char)TELEPORT_ACTIVE_FLAG + 1u);
        LINK_ACTION_TIMER = 64u;
        trap_advance_teleporting_level_index();
        LINK_Y = k_teleport_ys[(unsigned char)TELEPORT_LEVEL_INDEX & 7u];
        core_set_up_whirlwind(9u);
    }
    SUBMODE_VALUE = 0u;
    MODE_TIMER = (uint8_t)((unsigned char)MODE_TIMER + 1u);
}

void trap_summon_whirlwind(void)
{
    /* drain at trap_runtime.c:88-110. */
    if ((unsigned char)MODE_VALUE != 5u) {
        return;
    }
    trap_advance_teleporting_level_index();
    unsigned char mask =
        k_trap_level_masks[(unsigned char)TELEPORT_LEVEL_INDEX & 7u];
    for (;;) {
        const unsigned char triforce_pieces = (unsigned char)RAM(0x0671);
        if (triforce_pieces == 0u) {
            return;
        }
        if (triforce_pieces & mask) {
            break;
        }
        trap_advance_teleporting_level_index();
        if (LINK_DIR & 0x09u) {
            mask = (unsigned char)((mask << 1) | (mask >> 7));
        } else {
            mask = (unsigned char)((mask >> 1) | (mask << 7));
        }
    }
    if ((unsigned char)WHIRLWIND_ACTIVE_FLAG ||
        (unsigned char)TELEPORT_ACTIVE_FLAG) {
        return;
    }
    const unsigned int empty = enemy_find_empty_monster_slot();
    if (empty == 0u) {
        return;
    }
    WHIRLWIND_ACTIVE_FLAG =
        (uint8_t)((unsigned char)WHIRLWIND_ACTIVE_FLAG + 1u);
    core_set_up_whirlwind(empty);
}

void trap_init_trap_full(unsigned int slot)
{
    /* drain at trap_runtime.c:4-17. */
    WORLD_TMP1 = (uint8_t)MON_STATUS_FLAGS(slot);
    WORLD_TMP0 = TRAP_OBJ_TYPE;
    signed char count = ((unsigned char)MON_TYPE(slot) == TRAP_OBJ_TYPE) ? 5 : 3;
    do {
        const unsigned char ns =
            (unsigned char)((unsigned char)count +
                            (unsigned char)TRAP_BASE_SLOT);
        OBJ_X(ns) = k_trap_xs[(unsigned char)count];
        OBJ_Y(ns) = k_trap_ys[(unsigned char)count];
        core_init_one_simple_object(ns);
        --count;
    } while (count >= 0);
}
