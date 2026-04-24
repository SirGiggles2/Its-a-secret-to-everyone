#ifndef CORE_RUNTIME_H
#define CORE_RUNTIME_H

#include "nes_abi.h"

void corert_play_character_sfx(void);
void corert_play_key_taken_tune(void);
void corert_take_power_triforce(void);
unsigned char corert_silence_all_sound(void);
void corert_post_debit(unsigned int amount);
void corert_init_one_simple_object(unsigned int slot);
void corert_destroy_object_wram(unsigned int val, unsigned int slot);
void corert_destroy_whirlwind(unsigned int slot);
void corert_unhalt_link(void);
void corert_inc_cave_state(void);
void corert_set_up_whirlwind(unsigned int slot);
void corert_uw_person_complex_state_delay_and_quit(void);
void corert_set_boomerang_speed(unsigned int val, unsigned int slot);
void corert_set_up_common_cave_objects(unsigned int x, unsigned int slot, unsigned int y);
unsigned char corert_anim_set_sprite_desc_attrs(unsigned int val);
void corert_post_credit(unsigned int val);
unsigned char corert_add_to_int16_at_0(unsigned int val);
unsigned char corert_add_to_int16_at_2(unsigned int val);
unsigned char corert_add_to_int16_at_4(unsigned int val);
void corert_map_screen_pos_to_ppu_addr(void);
void corert_reset_shove_info_and_inv_timer(unsigned int slot);
void corert_update_person_state_reset_char_offset(void);
void corert_begin_update_mode(void);
void corert_cue_transfer_buf_and_advance_state(unsigned int val);
void corert_take_one_rupee(void);
void corert_set_item_value(unsigned int val, unsigned int slot3);
void corert_init_whirlwind(unsigned int val, unsigned int slot);
unsigned char corert_add1_to_int16_at_0(void);
unsigned char corert_add1_to_int16_at_2(void);
unsigned char corert_add1_to_int16_at_4(void);
void corert_cue_transfer_blank_person_wares(void);
void corert_take_5_rupees(void);
unsigned int corert_get_opposite_dir(unsigned int dir);
unsigned char corert_abs(unsigned int val);
unsigned char corert_negate(unsigned int val);
void corert_play_effect(unsigned int val);
void corert_play_sample(unsigned int val);
void corert_play_parry_tune(void);
void corert_write_blank_priority_sprites(void);
void corert_copy_price_list_template(void);
unsigned char corert_compare_hearts_to_containers(void);
void corert_uw_person_complex_state_begin(void);
void corert_format_char_doublet(unsigned int val);
unsigned char corert_reset_cur_sprite_index(void);
void corert_play_boomerang_sfx(unsigned int sfx_id);
void corert_take_hearts_no_sound(void);
void corert_take_hearts(void);
unsigned int corert_sub1_from_int16_at4(void);

unsigned char corert_reset_obj_state(unsigned int slot);
void corert_set_shove_info_with0(unsigned int val, unsigned int slot);
void corert_reset_shove_info(unsigned int slot);
void corert_reset_obj_metastate(unsigned int slot);
void corert_reset_obj_metastate_and_timer(unsigned int slot);
void corert_decrement_invincibility_timer(unsigned int slot);
void corert_update_dead_dummy(unsigned int slot);
void corert_set_shot_spreading_state(unsigned int slot);
void corert_deactivate_shot(unsigned int slot);
void corert_deactivate_link_shot(void);
void corert_destroy_monster(unsigned int slot);
void corert_set_type_and_clear_object(unsigned int type, unsigned int slot);
void corert_init_tile_obj_or_item(unsigned int slot);
void corert_init_flute_secret(unsigned int slot);
void corert_ensure_object_aligned(unsigned int slot);
void corert_reverse_obj_dir(unsigned int slot);
unsigned char corert_reset_moving_dir(void);
void corert_do_nothing(void);
void corert_clear_ram0300_up_to(unsigned int end_hi, unsigned int start_off);
void corert_handle_shot_blocked(unsigned int slot);

#endif
