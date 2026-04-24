#ifndef ENEMY_RUNTIME_PRIVATE_H
#define ENEMY_RUNTIME_PRIVATE_H

#include "enemy_runtime.h"
#include "enemy_state.h"

extern void z07_animate_object_walking(unsigned int slot);
extern void z07_anim_set_obj_hflip(unsigned int slot);
extern unsigned char z07_anim_fetch_obj_pos(unsigned int slot);
extern void z07_anim_advance_and_fetch(unsigned int val, unsigned int slot);
extern void z07_destroy_monster(unsigned int slot);
extern unsigned char z01_anim_set_sprite_desc_attrs(unsigned int val);
extern unsigned char z01_check_link_collision(unsigned int slot);
extern unsigned char z01_abs(unsigned int val);
extern void wanderer_update_common(unsigned int turn_rate, unsigned int slot);
extern void c_walker_move(unsigned int slot);
extern void c_move_flyer(unsigned int slot);
extern void c_control_keese_flight(unsigned int slot);
extern void c_check_monster_collisions(unsigned int slot);
extern void c_draw_object_mirrored(unsigned int slot);
extern void c_draw_object_not_mirrored(unsigned int slot);
extern void c_draw_object_mirrored_with_frame(unsigned int frame, unsigned int slot);
extern void c_draw_object_not_mirrored_with_frame(unsigned int frame, unsigned int slot);
extern void c_aquamentus_move(unsigned int slot);
extern void c_aquamentus_shoot(unsigned int slot);
extern void c_aquamentus_draw(unsigned int slot);
extern void c_get_object_middle(unsigned int slot);
extern void c_check_monster_sword_collision(unsigned int monster_slot, unsigned int weapon_slot);
extern void c_reset_shove_info(unsigned int slot);
extern void c_check_link_collision(unsigned int slot);
extern unsigned int c_gel_move_splitting(unsigned int slot);
extern void c_update_zol_state(unsigned int slot);
extern void c_zol_check_collisions(unsigned int slot);
extern void c_gel_move(unsigned int slot);
extern void c_gel_check_collisions(unsigned int slot);
extern void c_update_burrower(unsigned int slot);
extern void z04_shoot_fireball(unsigned int dir, unsigned int slot);
extern unsigned char z04_is_dark_room_bank4(unsigned int room_idx);
extern unsigned int z07_find_empty_monster_slot(void);
extern unsigned char z07_get_unique_room_id(void);
extern void z07_set_type_and_clear_object(unsigned int type, unsigned int slot);
extern unsigned int z01_animate_world_fading(void);
extern unsigned char z07_reset_obj_state(unsigned int slot);
extern void z07_reset_obj_metastate(unsigned int slot);
extern void z07_reset_obj_metastate_and_timer(unsigned int slot);
extern void z04_flyer_compare_max_speed(unsigned char speed, unsigned int slot);
extern void z04_flyer_set_flying_state(unsigned int val, unsigned int slot);
extern void z04_update_common_wanderer(unsigned int turn_rate, unsigned int slot);
extern void z04_gleeok_set_segment_x(unsigned int val, unsigned int slot);
extern void z04_gleeok_set_segment_y(unsigned int val, unsigned int slot);
extern void z04_play_boss_death_cry_if_needed(unsigned int slot);
extern void z07_set_shove_info_with0(unsigned int val, unsigned int slot);
extern void z04_flyer_set_state_and_turns(unsigned int state, unsigned int slot);
extern const unsigned char Directions8[];
extern void z04_update_dodongo_bloated_sub_end(unsigned int slot);
extern void z04_end_init_flyer(unsigned int slot);
extern void z04_init_blue_keese(unsigned int slot);
extern unsigned char z01_get_room_flag_uw_item_state(void);
extern void z07_update_dead_dummy(unsigned int slot);
extern unsigned char z07_get_collidable_tile(unsigned int hotspot_offset, unsigned int slot);
extern unsigned char z07_get_collidable_tile_still(unsigned int slot);
extern const unsigned char TektiteStartingDirs[];
extern const unsigned char GanonStartXs[];
extern const unsigned char PolsVoiceWalkSpeedsX[];
extern const unsigned char LevelMasks[];
/* Boss-family asm helpers (IMPORT shims in c_shims.asm batch 88) */
extern void c_reverse_obj_dir8(unsigned int slot);
extern void c_bound_direction_horizontally(unsigned int slot);
extern void c_bound_direction_vertically(unsigned int slot);
extern void c_gohma_animate_and_draw(unsigned int eye_frame, unsigned int slot);
extern void c_gohma_check_collisions(unsigned int slot);
extern void c_gleeok_draw_body(void);
extern void c_gleeok_fetch_neck_addrs(void);
extern void c_gleeok_move_neck(void);
extern void c_gleeok_move_head(void);
extern void c_gleeok_draw_head_and_check_collisions(void);
extern void c_gleeok_draw_segment_and_check_collisions(unsigned int slot);
extern void c_gleeok_calc_segment_limits(unsigned int primary_dist, unsigned int axis);
extern void c_gleeok_stretch_neck(unsigned int slot);
extern void c_play_boss_hit_cry_if_needed(unsigned int slot);
extern void c_play_boss_death_cry(void);
extern void c_bound_flyer(unsigned int slot);
extern void c_turn_towards_player8(void);
extern unsigned char c_bound_by_room(unsigned int slot);
extern unsigned char c_get_colliding_tile_moving(unsigned int slot);
extern void c_reset_obj_metastate(unsigned int slot);
extern void c_write_blank_priority_sprites(void);
extern void c_shoot_fireball(unsigned int dir, unsigned int slot);
extern unsigned char c_find_empty_monster_slot(void);
extern void c_anim_advance_and_fetch(unsigned int val, unsigned int slot);
extern unsigned int c_shoot(unsigned int type);

/* --- ASM shim helpers used by enemy_common_runtime.c (Zol/Gel family) --- */
extern unsigned char z01_bound_by_room(unsigned int slot);
extern unsigned char z07_get_colliding_tile_moving(unsigned int slot);
extern void          c_move_object(unsigned short slot);
extern void c_change_tile_obj_tiles(unsigned int tile, unsigned int slot);
extern unsigned char c_get_opposite_dir(unsigned char dir);
extern void          c_wanderer_target_player(unsigned int slot);
extern unsigned int  c_shoot_limited(unsigned int slot);

/* --- External data / shim functions used by enemy_wanderer_runtime.c --- */
extern const unsigned char ReverseDirections[];
extern unsigned int c_shoot_if_wanted(unsigned int type, unsigned int slot);
extern void c_obj_shove(unsigned int slot);

#endif
