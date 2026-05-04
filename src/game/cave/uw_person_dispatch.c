/* uw_person_dispatch.c — native underworld person subsystem dispatch
 * (Phase 4).
 *
 * Drain MATCH (verified-by-use). Pure C; calls native core_* +
 * progress_*. Drain provenance: src/oracle/cave/uw_person_runtime.c.
 */

#include "uw_person_dispatch.h"
#include <stdint.h>
#include "platform_abi.h"
#include "cave_state.h"        /* CAVE_DELAY_TIMER, CAVE_TEXT_SELECTOR,
                                * CAVE_TEXT_LINE_ADDR_LO, CAVE_ROOM_TYPE */
#include "object_state.h"      /* OBJ_STATE, OBJ_TILE_Y, OBJ_TYPE */
#include "link_state.h"        /* LINK_MOVING_DIR */
#include "item_state.h"        /* ITEM_SFX_PRIMARY */
#include "core/core_dispatch.h"      /* core_cue_transfer_buf_and_advance_state,
                                      * core_set_up_common_cave_objects,
                                      * core_play_character_sfx,
                                      * core_destroy_monster */
#include "world/progress_dispatch.h" /* progress_set_room_flag_uw_item_state,
                                      * progress_get_room_flag_uw_item_state */

/* Z_01.asm UnderworldPersonTextSelectorsB[8]. drain at
 * uw_person_runtime.c:35. */
static const unsigned char k_underworld_person_text_selectors_b[8] = {
    0x2Au, 0x38u, 0x3Au, 0x2Cu, 0x40u, 0x42u, 0x42u, 0x3Cu
};

/* Z_01.asm UnderworldPersonTextSelectorsA[8]. */
static const unsigned char k_underworld_person_text_selectors_a[8] = {
    0x28u, 0x26u, 0x2Eu, 0x30u, 0x32u, 0x3Eu, 0x3Eu, 0x34u
};

/* Z_01.asm TextboxLineAddrsLo[3]. */
static const unsigned char k_uw_textbox_line_addrs_lo[3] = {
    0xC4u, 0xE4u, 0xA4u
};

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

void uw_person_init_underworld_person_b(unsigned int slot)
{
    /* drain at uw_person_runtime.c:34-43. */
    core_set_up_common_cave_objects(120u, slot, 0x80u);
    const unsigned char obj_type = (unsigned char)OBJ_TYPE(slot);
    const unsigned char idx = (unsigned char)(obj_type - 0x4Bu);
    CAVE_TEXT_SELECTOR = k_underworld_person_text_selectors_b[idx & 7u];
    core_play_character_sfx();
}

void uw_person_destroy_if_taken(unsigned int slot)
{
    /* drain at uw_person_runtime.c:93-101. */
    const unsigned char item_state = progress_get_room_flag_uw_item_state();
    if (item_state == 0u) {
        core_play_character_sfx();
        return;
    }
    OBJ_STATE(0) = 0u;
    core_destroy_monster(slot);
}

void uw_person_init_underworld_person_a(unsigned int slot)
{
    /* drain at uw_person_runtime.c:133-143. */
    core_set_up_common_cave_objects(120u, slot, 0x80u);
    const unsigned char idx =
        (unsigned char)((unsigned char)OBJ_TYPE(slot) - 0x4Bu);
    CAVE_TEXT_SELECTOR = k_underworld_person_text_selectors_a[idx & 7u];
    if ((unsigned char)CAVE_ROOM_TYPE == 0x4Fu) {
        uw_person_destroy_if_taken(slot);
        return;
    }
    core_play_character_sfx();
}

void uw_person_init_life_or_money_full(unsigned int slot)
{
    /* drain at uw_person_runtime.c:103-108. */
    core_set_up_common_cave_objects(120u, slot, 0x80u);
    CAVE_TEXT_SELECTOR = 54u;
    CAVE_TEXT_LINE_ADDR_LO = k_uw_textbox_line_addrs_lo[2];
    uw_person_destroy_if_taken(slot);
}
