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

#ifdef __cplusplus
}
#endif

#endif /* CORE_DISPATCH_H */
