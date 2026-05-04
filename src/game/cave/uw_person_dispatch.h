/* uw_person_dispatch.h — native underworld person subsystem dispatch
 * (Phase 4).
 *
 * Native rewrite of select leaves from
 * src/oracle/cave/uw_person_runtime.c. Both ROMs link.
 *
 * Phase 4 first batch: trivial leaves that don't call c_draw_object_*
 * / c_animate_item_object / c_update_person_state_textbox shims —
 * those defer until a native draw + textbox port lands.
 */

#ifndef UW_PERSON_DISPATCH_H
#define UW_PERSON_DISPATCH_H

#ifdef __cplusplus
extern "C" {
#endif

/* CAVE_DELAY_TIMER = 10; cue transfer buf 118; advance state.
 * NES UpdateLifeOrMoneyState_0. drain at uw_person_runtime.c:88-91. */
void uw_person_update_life_or_money_state_0(void);

/* If LINK_MOVING_DIR has the up bit ($08) set and Link's tile-Y is
 * above $8E, clear LINK_MOVING_DIR (block walk-through). NES
 * CheckPersonBlocking. drain at uw_person_runtime.c:116-122. */
void uw_person_check_person_blocking(void);

/* set_room_flag_uw_item_state; CAVE_DELAY_TIMER = 64;
 * cue_transfer_buf_and_advance_state(30). NES
 * PersonFlagItemTakenAndAdvanceState.
 * drain at uw_person_runtime.c:110-114. */
void uw_person_flag_item_taken_and_advance_state(void);

/* If OBJ_STATE($0F) has bit 7 set (grumble Link bumped), set Link
 * action timer + sfx + advance state. NES UpdateGrumble1.
 * drain at uw_person_runtime.c:124-131. */
void uw_person_update_grumble1(void);

#ifdef __cplusplus
}
#endif

#endif /* UW_PERSON_DISPATCH_H */
