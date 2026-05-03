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

/* Clear an object slot's WRAM state (shove dir/dist, ObjTimer+slot,
 * ObjState, InvTimer, $0492 = 0xFF, metastate=1). NES DestroyObjectWram.
 * drain at core_runtime.c:42-50. */
void core_destroy_object_wram(unsigned int val, unsigned int slot);

/* core_destroy_object_wram(0, slot). NES DestroyWhirlwind.
 * drain at core_runtime.c:52-54. */
void core_destroy_whirlwind(unsigned int slot);

/* OBJ_TYPE(slot) = 0 + core_destroy_object_wram(0, slot). NES
 * DestroyMonster. drain at core_runtime.c:374. */
void core_destroy_monster(unsigned int slot);

/* Initialize a "simple" object slot from ZP scratch ($00 = type, $01 =
 * status flags). NES InitOneSimpleObject. drain at core_runtime.c:36-40. */
void core_init_one_simple_object(unsigned int slot);

/* Initialize a whirlwind in `slot`: copy Link's tile-Y, zero tile-X,
 * set OBJ_TYPE to 46. NES SetUpWhirlwind. drain at core_runtime.c:64-68. */
void core_set_up_whirlwind(unsigned int slot);

/* Init whirlwind: writes Link's tile-Y from `val` then runs
 * core_set_up_whirlwind. NES InitWhirlwind. drain at core_runtime.c:174-177. */
void core_init_whirlwind(unsigned int val, unsigned int slot);

/* Stash anim sprite-descriptor attrs into ZP $04/$05 + return val.
 * NES AnimSetSpriteDescAttrs. drain at core_runtime.c:101-105. */
unsigned char core_anim_set_sprite_desc_attrs(unsigned int val);

/* Set per-level item value. NES SetItemValue. drain at core_runtime.c:170-172. */
void core_set_item_value(unsigned int val, unsigned int slot3);

/* Get opposite of a single-bit direction. Walks the 4 dir bits and
 * returns (idx << 8) | opposite_dir. NES GetOppositeDir. drain at
 * core_runtime.c:202-217. */
unsigned int core_get_opposite_dir(unsigned int dir);

/* 6502 negate of a signed byte (~v + 1). NES Negate. drain at
 * core_runtime.c:224-227. */
unsigned char core_negate(unsigned int val);

/* Reset SUBMODE_VALUE + bump ROOM_MODE_TIMER. NES BeginUpdateMode.
 * drain at core_runtime.c:155-158. */
void core_begin_update_mode(void);

/* Bump ROOM_SFX_AUX with bitmask. NES PlayEffect. drain at
 * core_runtime.c:229-231. */
void core_play_effect(unsigned int val);

/* Bump RAM($0601) with bitmask. NES PlaySample. drain at core_runtime.c:233+. */
void core_play_sample(unsigned int val);

#ifdef __cplusplus
}
#endif

#endif /* CORE_DISPATCH_H */
