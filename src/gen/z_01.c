/* z_01.c — C port of z_01 leaf functions.
 * Data tables and remaining code stay in z_01.asm.
 */

#include "../nes_abi.h"
#include "../core_runtime.h"
#include "../object_runtime.h"
#include "../uw_person_runtime.h"
#include "../cave_runtime.h"
#include "../hud_runtime.h"
#include "../item_runtime.h"
#include "../weapon_runtime.h"
#include "../world_runtime.h"
#include "../sprite_runtime.h"
#include "../combat_runtime.h"
#include "../collision_runtime.h"
#include "../link_collision_runtime.h"
#include "../progress_runtime.h"
#include "../targeting_runtime.h"
#include "../trap_runtime.h"

extern void z07_set_shove_info_with0(unsigned int val, unsigned int slot);
extern unsigned char z07_end_game_mode(void);
extern const unsigned char ObjTypeToDamagePoints[];

void z01_play_character_sfx(void) {
    corert_play_character_sfx();
}

unsigned char z01_reset_room_tile_obj_info(void) {
    return progrt_reset_room_tile_obj_info();
}

void z01_play_key_taken_tune(void) {
    corert_play_key_taken_tune();
}

void z01_take_power_triforce(void) {
    corert_take_power_triforce();
}

unsigned char z01_silence_all_sound(void) {
    return corert_silence_all_sound();
}

void z01_post_debit(unsigned int amount) {
    corert_post_debit(amount);
}

void z01_init_one_simple_object(unsigned int slot) {
    corert_init_one_simple_object(slot);
}

void z01_destroy_object_wram(unsigned int val, unsigned int slot) {
    corert_destroy_object_wram(val, slot);
}

void z01_destroy_whirlwind(unsigned int slot) {
    corert_destroy_whirlwind(slot);
}

void z01_unhalt_link(void) {
    corert_unhalt_link();
}

void z01_inc_cave_state(void) {
    corert_inc_cave_state();
}

void z01_set_up_whirlwind(unsigned int slot) {
    corert_set_up_whirlwind(slot);
}

void z01_uw_person_complex_state_delay_and_quit(void) {
    corert_uw_person_complex_state_delay_and_quit();
}

void z01_set_boomerang_speed(unsigned int val, unsigned int slot) {
    corert_set_boomerang_speed(val, slot);
}

void z01_set_up_common_cave_objects(unsigned int x, unsigned int slot, unsigned int y) {
    corert_set_up_common_cave_objects(x, slot, y);
}

unsigned char z01_anim_set_sprite_desc_attrs(unsigned int val) {
    return corert_anim_set_sprite_desc_attrs(val);
}

void z01_post_credit(unsigned int val) {
    corert_post_credit(val);
}

unsigned char z01_add_to_int16_at_0(unsigned int val) {
    return corert_add_to_int16_at_0(val);
}

unsigned char z01_add_to_int16_at_2(unsigned int val) {
    return corert_add_to_int16_at_2(val);
}

unsigned char z01_add_to_int16_at_4(unsigned int val) {
    return corert_add_to_int16_at_4(val);
}

void z01_map_screen_pos_to_ppu_addr(void) {
    corert_map_screen_pos_to_ppu_addr();
}

void z01_reset_shove_info_and_inv_timer(unsigned int slot) {
    corert_reset_shove_info_and_inv_timer(slot);
}

void z01_update_person_state_reset_char_offset(void) {
    corert_update_person_state_reset_char_offset();
}

void z01_begin_update_mode(void) {
    corert_begin_update_mode();
}

void z01_cue_transfer_buf_and_advance_state(unsigned int val) {
    corert_cue_transfer_buf_and_advance_state(val);
}

void z01_take_one_rupee(void) {
    corert_take_one_rupee();
}

void z01_set_item_value(unsigned int val, unsigned int slot3) {
    corert_set_item_value(val, slot3);
}

void z01_init_whirlwind(unsigned int val, unsigned int slot) {
    corert_init_whirlwind(val, slot);
}

unsigned char z01_add1_to_int16_at_2(void) {
    return corert_add1_to_int16_at_2();
}

unsigned char z01_add1_to_int16_at_4(void) {
    return corert_add1_to_int16_at_4();
}

void z01_cue_transfer_blank_person_wares(void) {
    corert_cue_transfer_blank_person_wares();
}

void z01_take_5_rupees(void) {
    corert_take_5_rupees();
}

unsigned int z01_get_opposite_dir(unsigned int dir) {
    return corert_get_opposite_dir(dir);
}

unsigned char z01_abs(unsigned int val) {
    return corert_abs(val);
}

unsigned char z01_negate(unsigned int val) {
    return corert_negate(val);
}

void z01_set_room_flag_uw_item_state(void) {
    progrt_set_room_flag_uw_item_state();
}

unsigned char z01_get_room_flag_uw_item_state(void) {
    return progrt_get_room_flag_uw_item_state();
}

void z01_play_effect(unsigned int val) {
    corert_play_effect(val);
}

void z01_play_sample(unsigned int val) {
    corert_play_sample(val);
}

void z01_play_parry_tune(void) {
    corert_play_parry_tune();
}

void z01_write_blank_priority_sprites(void) {
    corert_write_blank_priority_sprites();
}

void z01_init_underworld_person_b(unsigned int slot) {
    uwrt_init_underworld_person_b(slot);
}

void z01_copy_price_list_template(void) {
    corert_copy_price_list_template();
}

unsigned char z01_compare_hearts_to_containers(void) {
    return corert_compare_hearts_to_containers();
}

void z01_uw_person_complex_state_begin(void) {
    corert_uw_person_complex_state_begin();
}

void z01_format_char_doublet(unsigned int val) {
    corert_format_char_doublet(val);
}

unsigned char z01_reset_cur_sprite_index(void) {
    return corert_reset_cur_sprite_index();
}

void z01_play_boomerang_sfx(unsigned int sfx_id) {
    corert_play_boomerang_sfx(sfx_id);
}

void z01_take_hearts_no_sound(void) {
    corert_take_hearts_no_sound();
}

unsigned char z01_do_objects_collide_with_thresholds(void) {
    return colrt_do_objects_collide_with_thresholds();
}

extern void z07_destroy_monster(unsigned int slot);
extern const unsigned char UnderworldPersonTextSelectorsC[];

void z01_init_underworld_person_c(unsigned int slot) {
    uwrt_init_underworld_person_c(slot);
}

extern const unsigned char TextboxLineAddrsLo[];

void z01_init_grumble_full(unsigned int slot) {
    uwrt_init_grumble_full(slot);
}

extern const unsigned char RupeeStashXs[];
extern const unsigned char RupeeStashYs[];

void z01_init_rupee_stash_full(unsigned int slot) {
    uwrt_init_rupee_stash_full(slot);
}

extern void z07_reset_moving_dir(void);

void z01_update_uw_person_life_or_money_state_0(void) {
    uwrt_update_life_or_money_state_0();
}

void z01_underworld_person_destroy_if_taken(unsigned int slot) {
    uwrt_underworld_person_destroy_if_taken(slot);
}

void z01_init_uw_person_life_or_money_full(unsigned int slot) {
    uwrt_init_life_or_money_full(slot);
}

void z01_person_flag_item_taken_and_advance_state(void) {
    uwrt_person_flag_item_taken_and_advance_state();
}

void z01_check_person_blocking(void) {
    uwrt_check_person_blocking();
}

void z01_clear_prices_cave_flag(void) {
    cavert_clear_prices_cave_flag();
}

void z01_update_person_state_delay_then_hide(void) {
    cavert_update_person_state_delay_then_hide();
}

/* --- batch 40 --- */

void z01_update_person_state_do_nothing(void) {
}

void z01_update_cave_person_state_do_nothing(void) {
}

void z01_init_underworld_person_do_nothing(void) {
}

void z01_update_grumble1(void) {
    uwrt_update_grumble1();
}

/* --- batch 43 --- */

unsigned char z01_add1_to_int16_at_0(void) {
    return corert_add1_to_int16_at_0();
}

/* --- batch 49 --- */

extern void z01_play_key_taken_tune(void);
extern void z01_take_hearts_no_sound(void);

void z01_take_hearts(void) {
    corert_take_hearts();
}

/* --- batch 53 --- */

extern const unsigned char TeleportYs[];

void z01_check_init_whirlwind_and_begin_update(void) {
    trprt_check_init_whirlwind_and_begin_update();
}

/* --- batch 55 --- */

extern const unsigned char PaletteRow7TransferRecord[];
extern const unsigned char GanonColorTriples[];

void z01_advance_teleporting_level_index(void) {
    trprt_advance_teleporting_level_index();
}

void z01_replace_ganon_brown_palette_row(void) { progrt_replace_ganon_brown_palette_row(); }
void z01_replace_ganon_blue_palette_row(void) { progrt_replace_ganon_blue_palette_row(); }
void z01_replace_ashes_palette_row(void) { progrt_replace_ashes_palette_row(); }

/* --- batch 56 --- */

extern const unsigned char UnderworldPersonTextSelectorsA[];
extern const unsigned char LifeOrMoneyItemXs[];

void z01_init_underworld_person_a(unsigned int slot) {
    uwrt_init_underworld_person_a(slot);
}

void z01_update_uw_person_complex_state_sense_link(void) {
    uwrt_update_complex_state_sense_link();
}

void z01_update_uw_person_life_or_money_state_2(void) {
    uwrt_update_life_or_money_state_2();
}

/* --- batch 57 --- */

extern unsigned char z07_anim_fetch_obj_pos(unsigned int slot);
extern void c_check_monster_collisions(unsigned int slot);
extern void c_animate_item_object(unsigned char item_type, unsigned int slot);
extern void c_draw_object_mirrored(unsigned int slot);
extern void c_draw_object_not_mirrored(unsigned int slot);
extern void c_link_end_move_and_animate_bank1(void);
extern void c_update_person_state_textbox(void);
extern const unsigned char LifeOrMoneyItemTypes[];

void z01_person_check_collisions(unsigned int slot) {
    uwrt_person_check_collisions(slot);
}

void z01_person_draw_and_check_collisions(unsigned int slot) {
    uwrt_person_draw_and_check_collisions(slot);
}

void z01_draw_life_or_money_items(void) {
    uwrt_draw_life_or_money_items();
}

void z01_update_grumble3(void) {
    uwrt_update_grumble3();
}

void z01_update_uw_person_complex(unsigned int slot) {
    uwrt_update_person_complex(slot);
}

void z01_update_uw_person_full(unsigned int slot) {
    uwrt_update_person_full(slot);
}

void z01_update_grumble_full(unsigned int slot) {
    uwrt_update_grumble_full(slot);
}

void z01_update_uw_person_life_or_money_full(unsigned int slot) {
    uwrt_update_life_or_money_full(slot);
}

/* --- batch 58 --- */

extern void c_link_end_move_and_draw_bank1(void);
extern const unsigned char CaveWareXs[];
extern const unsigned char PersonTextAddrs[];
extern const unsigned char TextboxCharTransferRecTemplate[];
extern const unsigned char TextboxLineAddrsLo[];
void z01_take_item(unsigned char item_id);

void z01_draw_cave_person(unsigned int slot) {
    cavert_draw_cave_person(slot);
}

void z01_draw_cave_items(void) {
    cavert_draw_cave_items();
}

void z01_format_decimal_byte(unsigned char val) {
    cavert_format_decimal_byte(val);
}

void z01_write_prices_to_dynamic_transfer_buf(unsigned char price_char) {
    cavert_write_prices_to_dynamic_transfer_buf(price_char);
}

void z01_write_prices_transfer_buf(void) {
    cavert_write_prices_transfer_buf();
}

void z01_update_cave_person_state_transfer_prices(void) {
    cavert_update_transfer_prices();
}

void z01_update_person_state_textbox(void) {
    cavert_update_person_state_textbox();
}

/* --- batch 59 --- */

extern void c_take_item(unsigned char item_type);
extern const unsigned char HintCaveTextSelectors0[];

void z01_update_cave_person_state_talk_or_shop_or_door_charge(void) {
    cavert_update_talk_shop_or_door_charge();
}

void z01_update_cave_person_state_hint_or_money_game(void) {
    cavert_update_hint_or_money_game();
}

void z01_update_cave_person(unsigned int slot) {
    cavert_update_cave_person(slot);
}

/* --- batch 60 --- */

extern const unsigned char StatusBarTransferBufTemplate[];
extern void c_format_char_doublet(unsigned char ch);

void z01_format_hearts_in_text_buf(unsigned char start_off) {
    hudrt_format_hearts_in_text_buf(start_off);
}

void z01_copy_triplet_to_text_buf(void) {
    hudrt_copy_triplet_to_text_buf();
}

void z01_format_decimal_count_byte(unsigned char val) {
    hudrt_format_decimal_count_byte(val);
}

void z01_format_decimal_count_byte_in_text_buf(unsigned char val, unsigned char buf_offset) {
    hudrt_format_decimal_count_byte_in_text_buf(val, buf_offset);
}

void z01_format_status_bar_text(void) {
    hudrt_format_status_bar_text();
}

void z01_world_change_rupees(void) {
    hudrt_world_change_rupees();
}

/* --- batch 61 --- */

#define NES_SRAM_BASE 0x6000u

void z01_init_cave(unsigned int slot) {
    cavert_init_cave(slot);
}

void z01_try_take_item(unsigned int slot) {
    cavert_try_take_item(slot);
}

void z01_try_take_room_item(void) {
    cavert_try_take_room_item();
}

/* --- batch 62 --- */

extern const unsigned char LevelMasks[];
extern const unsigned char LinkColors_CommonCode[];
extern const unsigned char SaveSlotToPaletteRowOffset[];
extern unsigned char MenuPalettesTransferBuf[];
extern const unsigned char ItemIdToSlot[];
extern const unsigned char ItemIdToDescriptor[];

extern void z07_patch_and_cue_level_palettes_transfer(void);

void z01_take_item(unsigned char item_id) {
    itemrt_take_item(item_id);
}

/* --- batch 63 --- */
extern void c_move_object(unsigned short slot);

void z01_bound_direction_horizontally(unsigned int slot) {
    objrt_bound_direction_horizontally(slot);
}

void z01_bound_direction_vertically(unsigned int slot) {
    objrt_bound_direction_vertically(slot);
}

unsigned char z01_bound_by_room(unsigned int slot) {
    return objrt_bound_by_room(slot);
}

unsigned char z01_bound_by_room_with_a(unsigned char direction, unsigned int slot) {
    return objrt_bound_by_room_with_dir(direction, slot);
}

unsigned int z01_add_q_speed_to_position_fraction(unsigned int slot) {
    return objrt_add_q_speed_to_position_fraction(slot);
}

unsigned int z01_sub_q_speed_from_position_fraction(unsigned int slot) {
    return objrt_sub_q_speed_from_position_fraction(slot);
}

void z01_move_shot(unsigned char direction, unsigned int slot) {
    objrt_move_shot(direction, slot);
}

/* --- batch 64 --- */
unsigned char z01_get_one_direction_and_distance_to_target(unsigned char target_coord, unsigned char origin_coord) {
    return targrt_get_one_direction_and_distance_to_target(target_coord, origin_coord);
}

void z01_get_directions_and_distances_to_target(unsigned char target_slot, unsigned int origin_slot) {
    targrt_get_directions_and_distances_to_target(target_slot, origin_slot);
}

unsigned int z01_calc_diagonal_speed_index(unsigned int mid_speed_idx) {
    return targrt_calc_diagonal_speed_index(mid_speed_idx);
}

void z01_place_weapon(unsigned char offset, unsigned int slot) {
    weprt_place_weapon(offset, slot);
}

void z01_place_weapon_for_player_state(unsigned int slot) {
    weprt_place_weapon_for_player_state(slot);
}

void z01_place_weapon_for_player_state_and_anim(unsigned int slot) {
    weprt_place_weapon_for_player_state_and_anim(slot);
}

void z01_place_weapon_for_player_state_and_anim_and_weapon_state(unsigned char weapon_state, unsigned int slot) {
    weprt_place_weapon_for_player_state_and_anim_and_weapon_state(weapon_state, slot);
}

/* --- batch 65 --- */

unsigned int z01_sub1_from_int16_at4(void) {
    return corert_sub1_from_int16_at4();
}

void z01_wield_bomb(unsigned int slot) {
    weprt_wield_bomb(slot);
}

unsigned int z01_wield_candle(unsigned int slot) {
    return weprt_wield_candle(slot);
}

unsigned int z01_get_shortcut_or_item_xy_for_room(unsigned int room_id) {
    return worldrt_get_shortcut_or_item_xy_for_room(room_id);
}

unsigned int z01_get_shortcut_or_item_xy(void) {
    return worldrt_get_shortcut_or_item_xy();
}

/* --- batch 66 --- */
void z01_get_object_middle(unsigned int slot) {
    worldrt_get_object_middle(slot);
}

unsigned int z01_animate_world_fading(void) {
    return worldrt_animate_world_fading();
}

void z01_check_mazes(void) {
    worldrt_check_mazes();
}

/* --- batch 67 --- */
void z01_cycle_cur_sprite_index(void) {
    sprrt_cycle_cur_sprite_index();
}

unsigned char z01_cycle_sprite_index_in_a(unsigned char idx) {
    return sprrt_cycle_sprite_index_in_a(idx);
}

void z01_hide_object_sprites(void) {
    sprrt_hide_object_sprites();
}

void z01_show_link_sprites_behind_horizontal_doors(void) {
    sprrt_show_link_sprites_behind_horizontal_doors();
}

/* --- batch 68 --- */
extern void z07_update_dead_dummy(unsigned int slot);

void z01_play_parry_sound_for_damage_type(void) {
    cobrt_play_parry_sound_for_damage_type();
}

void z01_handle_monster_died(unsigned int slot) {
    cobrt_handle_monster_died(slot);
}

void z01_deal_damage(unsigned int slot) {
    cobrt_deal_damage(slot);
}

extern void c_call_gohma_handle_weapon_collision(unsigned int monster_slot, unsigned int weapon_slot);
extern void c_call_begin_shove(unsigned int monster_slot);

void z01_handle_monster_weapon_collision(unsigned int monster_slot, unsigned int weapon_slot) {
    colrt_handle_monster_weapon_collision(monster_slot, weapon_slot);
}

void z01_check_monster_weapon_collision(unsigned int monster_slot, unsigned int weapon_y_mid) {
    colrt_check_monster_weapon_collision(monster_slot, weapon_y_mid);
}

void z01_check_monster_slender_weapon_collision2(unsigned int monster_slot) {
    colrt_check_monster_slender_weapon_collision2(monster_slot);
}

void z01_check_monster_slender_weapon_collision(unsigned int monster_slot, unsigned int damage_points) {
    colrt_check_monster_slender_weapon_collision(monster_slot, damage_points);
}

void z01_parry_or_shove(unsigned int monster_slot, unsigned int weapon_slot) {
    colrt_parry_or_shove(monster_slot, weapon_slot);
}

void z01_check_monster_stabbing_collision(unsigned int monster_slot, unsigned int damage_points) {
    colrt_check_monster_stabbing_collision(monster_slot, damage_points);
}

void z01_check_monster_sword_collision(unsigned int monster_slot, unsigned int weapon_slot) {
    colrt_check_monster_sword_collision(monster_slot, weapon_slot);
}

void z01_check_monster_shot_collision(unsigned int monster_slot, unsigned int weapon_slot, unsigned int damage_points) {
    colrt_check_monster_shot_collision(monster_slot, weapon_slot, damage_points);
}

void z01_check_monster_arrow_or_rod_collision(unsigned int monster_slot, unsigned int weapon_slot) {
    colrt_check_monster_arrow_or_rod_collision(monster_slot, weapon_slot);
}

void z01_check_monster_boomerang_or_food_collision(unsigned int monster_slot, unsigned int weapon_slot) {
    colrt_check_monster_boomerang_or_food_collision(monster_slot, weapon_slot);
}

void z01_check_monster_sword_shot_or_magic_shot_collision(unsigned int monster_slot, unsigned int weapon_slot) {
    colrt_check_monster_sword_shot_or_magic_shot_collision(monster_slot, weapon_slot);
}

void z01_check_monster_bomb_or_fire_collision(unsigned int monster_slot, unsigned int weapon_slot) {
    colrt_check_monster_bomb_or_fire_collision(monster_slot, weapon_slot);
}

void z01_link_be_harmed(unsigned int monster_slot);

void z01_harm_link(unsigned int monster_slot) {
    lcrt_harm_link(monster_slot);
}

void z01_link_be_harmed(unsigned int monster_slot) {
    lcrt_link_be_harmed(monster_slot);
}

void z01_check_link_collision_preinit(unsigned int monster_slot) {
    lcrt_check_link_collision_preinit(monster_slot);
}

void z01_check_link_collision(unsigned int monster_slot) {
    lcrt_check_link_collision(monster_slot);
}

void z01_check_monster_collisions(unsigned int monster_slot) {
    lcrt_check_monster_collisions(monster_slot);
}

void z01_begin_shove(unsigned int monster_slot) {
    lcrt_begin_shove(monster_slot);
}

/* --- batch 73 --- */

unsigned char z01_do_objects_collide(unsigned int threshold) {
    return colrt_do_objects_collide(threshold);
}


/* --- batch 74 --- */

void z01_update_bomb_flash_effect(unsigned int slot) {
    progrt_update_bomb_flash_effect(slot);
}

void z01_update_position_marker(unsigned char room_id, unsigned int idx) {
    progrt_update_position_marker(room_id, idx);
}

void z01_update_player_position_marker(void) {
    progrt_update_player_position_marker();
}

/* --- batch 75 --- */

extern void z05_copy_column_to_tilebuf(void);
extern const unsigned char SaveFileAAddressSets[];

void z01_update_world_curtain_effect(void) {
    progrt_update_world_curtain_effect();
}

void z01_update_world_curtain_effect_bank2(void) {
    progrt_update_world_curtain_effect_bank2();
}

void z01_fetch_file_a_address_set(void) {
    progrt_fetch_file_a_address_set();
}

/* --- batch 76 --- */

void z01_check_tile_objects_blocking(void) {
    progrt_check_tile_objects_blocking();
}

void z01_check_power_triforce_fanfare(void) {
    progrt_check_power_triforce_fanfare();
}

/* --- batch 77 --- */

extern const unsigned char TrapXs[];
extern const unsigned char TrapYs[];

void z01_init_trap_full(unsigned int slot) {
    trprt_init_trap_full(slot);
}

extern void z07_anim_advance_and_fetch(unsigned int val, unsigned int slot);
extern void z07_anim_set_obj_hflip(unsigned int slot);
extern void c_draw_object_not_mirrored_with_frame(unsigned int frame, unsigned int slot);

void z01_draw_whirlwind(unsigned int slot) {
    trprt_draw_whirlwind(slot);
}

extern const unsigned char WhirlwindPrevRoomIdList[];
extern void c_go_to_next_mode_from_play(void);

void z01_update_whirlwind_full(unsigned int slot) {
    trprt_update_whirlwind_full(slot);
}

extern unsigned int z07_find_empty_monster_slot(void);

void z01_summon_whirlwind(void) {
    trprt_summon_whirlwind();
}

extern void c_draw_item_in_inventory(unsigned int d2, unsigned int d3);

void z01_update_rupee_stash_full(unsigned int slot) {
    trprt_update_rupee_stash_full(slot);
}

extern void z05_reset_inv_obj_state(void);
extern void c_init_mode_enter_room(void);
extern void c_link_end_move_and_animate(void);
extern void c_run_cross_room_tasks_no_cellar(void);

void z01_init_mode_b_enter_cave_bank5(void) {
    trprt_init_mode_b_enter_cave_bank5();
}

extern const unsigned char LinkToSquareOffsetsX[];
extern const unsigned char LinkToSquareOffsetsY[];
extern void z07_reset_obj_metastate(unsigned int slot);

void z01_check_passive_tile_objects(void) {
    trprt_check_passive_tile_objects();
}

/* --- batch 78 --- */

extern const unsigned char TrapAllowedDirs[];
extern void c_person_draw_and_check_collisions(unsigned int slot);

void z01_update_trap_full(unsigned int slot) {
    trprt_update_trap_full(slot);
}
