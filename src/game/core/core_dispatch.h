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

/* Heart-container hearts >> 4. NES CompareHeartsToContainers.
 * drain at core_runtime.c:260-262. */
unsigned char core_compare_hearts_to_containers(void);

/* Format a doublet character into ZP $02/$03 — $02 = val, $03 = $24
 * (space). NES FormatCharDoublet. drain at core_runtime.c:272-275. */
void core_format_char_doublet(unsigned int val);

/* RAM($0341) = 0; return 0. NES ResetCurSpriteIndex.
 * drain at core_runtime.c:277-280. (Already file-static inline in
 * sprite_dispatch; this is the public z01_-callable wrapper.) */
unsigned char core_reset_cur_sprite_index(void);

/* UW person complex state begin: if room obj type 0 = $4F, set
 * ROOM_TRANSFER_BUF_SELECT = 108; then $0029 = 10 + cave_state++.
 * NES UWPersonComplexStateBegin. drain at core_runtime.c:264-270. */
void core_uw_person_complex_state_begin(void);

/* Boomerang sfx with refractory timer: if RAM($003B) != 0, skip;
 * else play_effect(sfx_id) + reset timer to 10. NES PlayBoomerangSfx.
 * drain at core_runtime.c:282-288. */
void core_play_boomerang_sfx(unsigned int sfx_id);

/* SFX trivials. drain at core_runtime.c:9-30, 237-247. */
void core_play_character_sfx(void);
void core_play_key_taken_tune(void);
void core_play_parry_tune(void);
unsigned char core_silence_all_sound(void);
void core_take_power_triforce(void);

/* Write blank-priority sprite template (8-byte pattern $3D $1C $20 $00
 * $DD $1C $20 $00) into OAM bytes 0..$3F. NES WriteBlankPrioritySprites.
 * drain at core_runtime.c:241-247. */
void core_write_blank_priority_sprites(void);

/* 16-bit add helpers: add `val` to ZP int16 at $00/$01, $02/$03,
 * or $04/$05; carry out increments the high byte. Return the low
 * byte. NES AddToInt16AtX. drain at core_runtime.c:111-138. */
unsigned char core_add_to_int16_at_0(unsigned int val);
unsigned char core_add_to_int16_at_2(unsigned int val);
unsigned char core_add_to_int16_at_4(unsigned int val);

/* +1 variants. drain at core_runtime.c:179-189. */
unsigned char core_add1_to_int16_at_0(void);
unsigned char core_add1_to_int16_at_2(void);
unsigned char core_add1_to_int16_at_4(void);

/* 16-bit sub-1 helper at $04/$05; returns CARRY_SET when no borrow,
 * else 0. NES Sub1FromInt16At4. drain at core_runtime.c:315-323. */
unsigned int core_sub1_from_int16_at4(void);

/* Quit complex UW person state if delay timer expired (RAM($0029) == 0
 * → ROOM_OBJ_TYPE(0) = 0). NES UWPersonComplexStateDelayAndQuit.
 * drain at core_runtime.c:70-74. */
void core_uw_person_complex_state_delay_and_quit(void);

/* Set boomerang speed for a slot. Halves speed + decrements timer if
 * state nibble is $40. NES SetBoomerangSpeed. drain at core_runtime.c:76-85. */
void core_set_boomerang_speed(unsigned int val, unsigned int slot);

/* Compute PPU nametable address from screen pixel position in
 * RAM($02 = Y, $03 = X). Result lands at RAM($00/$01) as a 16-bit
 * PPU address. NES MapScreenPosToPpuAddr. drain at core_runtime.c:138-143. */
void core_map_screen_pos_to_ppu_addr(void);

/* Reset RAM($0416) (CAVE_TEXT_CHAR_INDEX) to 0 and increment
 * OBJ_STATE(1) (cave-person state machine). NES
 * UpdatePersonState_ResetCharOffset. drain at core_runtime.c:150-153. */
void core_update_person_state_reset_char_offset(void);

#ifdef __cplusplus
}
#endif

#endif /* CORE_DISPATCH_H */
