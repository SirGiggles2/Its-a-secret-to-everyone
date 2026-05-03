/* trap_dispatch.c — native trap subsystem dispatch (Phase 4).
 *
 * Phase 4 first batch: advance_teleporting_level_index trivial.
 * Drain MATCH per finding 4_5n.
 */

#include "trap_dispatch.h"
#include "platform_abi.h"      /* RAM */
#include "trap_state.h"        /* TELEPORT_LEVEL_INDEX */
#include "world_state.h"       /* LINK_DIR */

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
