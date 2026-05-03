/* core_dispatch.h — native core subsystem dispatch (Phase 4 cross-cut).
 *
 * Native rewrite of select trivial helpers from src/core/core_runtime.c.
 * Both ROMs link. Pure C, no transpile shims.
 *
 * Phase 4 first batch focuses on the helpers that unblock Phase 3 cave
 * deferred stubs: cue_transfer_buf_and_advance_state, inc_cave_state,
 * unhalt_link, abs.
 */

#ifndef CORE_DISPATCH_H
#define CORE_DISPATCH_H

#ifdef __cplusplus
extern "C" {
#endif

/* Clear OBJ_STATE(0) ($00AC) — un-halt Link after a delay/dialog state.
 * Mirrors NES UnhaltLink (Z_01.asm:100): `LDA #0 / STA ObjState`.
 * drain at src/core/core_runtime.c:56-58. */
void core_unhalt_link(void);

/* Increment OBJ_STATE(1) ($00AD = CAVE_PERSON_STATE) — advance cave-
 * person state machine by one. Mirrors NES IncCaveState. drain at
 * src/core/core_runtime.c:60-62. */
void core_inc_cave_state(void);

/* Set ROOM_TRANSFER_BUF_SELECT to the given selector value, then
 * advance the cave person state. Mirrors NES
 * CueTransferBufAndAdvanceState. drain at src/core/core_runtime.c:160-163. */
void core_cue_transfer_buf_and_advance_state(unsigned int val);

/* 6502 abs(signed_byte). NES Abs (Z_01.asm). drain at
 * src/core/core_runtime.c:219+. */
unsigned char core_abs(unsigned int val);

/* Rupee debit/credit accumulators. NES uses lazy deferred animation:
 * gameplay code adjusts $067E (debit pending) or $067D (credit pending),
 * the HUD per-frame ticks the actual LinkRupees down or up by 1 with
 * a tune. drain at core_runtime.c:32-34 (debit), 107-109 (credit). */
void core_post_debit(unsigned int amount);
void core_post_credit(unsigned int val);

/* Increment credit accumulator by 1 + set DEATH_FRAME_COUNTER = 1
 * (HUD anim trigger). drain at core_runtime.c:165-168. */
void core_take_one_rupee(void);

/* Loop core_take_one_rupee 5 times. drain at core_runtime.c:195-200. */
void core_take_5_rupees(void);

/* cue_transfer_buf_and_advance_state(42) — used by cave state-arms
 * 3 + 6 in cavert_update_cave_person dispatch. drain at
 * core_runtime.c:191-193. */
void core_cue_transfer_blank_person_wares(void);

/* Initialize the 3 cave-person object slots with their tile + grid +
 * tilebuf positions. NES SetUpCommonCaveObjects (Z_01.asm). drain at
 * core_runtime.c:87-99. Used by NES InitCave to seed the cave's
 * primary, ware, and rupee-display object slots before InitCaveContinue
 * loads the per-cave-id text/wares tables. */
void core_set_up_common_cave_objects(unsigned int x, unsigned int slot,
                                     unsigned int y);

#ifdef __cplusplus
}
#endif

#endif /* CORE_DISPATCH_H */
