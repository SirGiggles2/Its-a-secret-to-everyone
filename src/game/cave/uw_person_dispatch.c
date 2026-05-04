/* uw_person_dispatch.c — native underworld person subsystem dispatch
 * (Phase 4).
 *
 * Drain MATCH (verified-by-use). Pure C; calls native core_* +
 * progress_*. Drain provenance: src/oracle/cave/uw_person_runtime.c.
 */

#include "uw_person_dispatch.h"
#include <stdint.h>
#include "platform_abi.h"
#include "cave_state.h"        /* CAVE_DELAY_TIMER */
#include "object_state.h"      /* OBJ_STATE, OBJ_TILE_Y */
#include "link_state.h"        /* LINK_MOVING_DIR */
#include "item_state.h"        /* ITEM_SFX_PRIMARY */
#include "core/core_dispatch.h"      /* core_cue_transfer_buf_and_advance_state */
#include "world/progress_dispatch.h" /* progress_set_room_flag_uw_item_state */

/* z07_reset_moving_dir is `LINK_MOVING_DIR = 0` — inline to avoid the
 * not-yet-native core ASM-bridge wrapper. NES ResetMovingDir is one
 * STA, the helper exists only for cross-bank dispatch. */
static inline void uw_reset_moving_dir(void)
{
    LINK_MOVING_DIR = 0u;
}

void uw_person_update_life_or_money_state_0(void)
{
    /* drain at uw_person_runtime.c:88-91. */
    CAVE_DELAY_TIMER = 10u;
    core_cue_transfer_buf_and_advance_state(118u);
}

void uw_person_check_person_blocking(void)
{
    /* drain at uw_person_runtime.c:116-122. */
    if ((unsigned char)OBJ_TILE_Y(0) >= 0x8Eu) {
        return;
    }
    if (((unsigned char)LINK_MOVING_DIR & 0x08u) == 0u) {
        return;
    }
    uw_reset_moving_dir();
}

void uw_person_flag_item_taken_and_advance_state(void)
{
    /* drain at uw_person_runtime.c:110-114. */
    progress_set_room_flag_uw_item_state();
    CAVE_DELAY_TIMER = 64u;
    core_cue_transfer_buf_and_advance_state(30u);
}

void uw_person_update_grumble1(void)
{
    /* drain at uw_person_runtime.c:124-131. */
    const unsigned char val = (unsigned char)OBJ_STATE(15);
    if ((val & 0x80u) == 0u) {
        return;
    }
    OBJ_STATE(0) = 64u;
    ITEM_SFX_PRIMARY = 4u;
    uw_person_flag_item_taken_and_advance_state();
}
