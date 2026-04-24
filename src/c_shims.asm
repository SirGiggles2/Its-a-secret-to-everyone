;==============================================================================
; c_shims.asm — Stage 2c/2d: asm trampolines between the transpiled
; register-based ABI (D2=slot, D0.b=val, etc.) and GCC's m68k SysV C ABI
; (stack-passed args, D0/D1/A0/A1 caller-save, D2-D7/A2-A6 callee-save).
;
; Two classes of shim:
;
;   1. EXPORT side (asm caller -> C callee):
;      Asm caller jumps here with args in registers; we marshal them
;      to the stack and jsr the C function; pop args; rts.
;
;   2. IMPORT side (C caller -> asm callee):
;      C caller puts args on the stack per SysV ABI; we pull them into
;      the expected registers and jsr/jmp the asm function. These will
;      be wired up in Stage 2d when C-emitted banks need to call native
;      register-ABI helpers (_copy_bank_to_window, _ppu_write_6/7, etc).
;==============================================================================

    section "text",code

    xdef    _c_move_object_shim
    xdef    c_copy_bank_to_window
    xdef    c_ppu_read_2
    xdef    c_ppu_write_6
    xdef    c_ppu_write_7
    xdef    c_turn_off_all_video
    xdef    c_transfer_level_pattern_blocks
    xdef    c_init_mode2_submodes
    xdef    c_copy_common_data_to_ram
    xdef    c_update_mode2_load_full
    xdef    c_copy_column_to_tilebuf
    xdef    c_copy_row_to_tilebuf
    xdef    c_has_compass
    xdef    c_has_map
    xdef    c_calc_open_doorway_mask
    xdef    c_add_door_flags
    xdef    c_split_room_id
    xdef    c_is_dark_room
    xdef    c_set_door_flag
    xdef    c_reset_door_flag
    xdef    c_check_has_living_monsters
    xdef    c_silence_sound
    xdef    c_set_entering_doorway
    xdef    c_write_and_enable_sprite0
    xdef    c_put_link_behind_background
    xdef    c_reset_inv_obj_state
    xdef    c_mask_cur_ppu_mask_grayscale
    xdef    c_setup_obj_room_bounds
    xdef    c_hide_all_sprites
    xdef    c_get_unique_room_id
    xdef    c_clear_room_history
    xdef    c_reset_player_state
    xdef    c_reset_moving_dir
    xdef    c_ensure_object_aligned
    xdef    c_fill_play_area_attrs
    xdef    c_hide_sprites_over_link
    xdef    c_get_room_flags
    xdef    c_mark_room_visited
    xdef    c_play_character_sfx
    xdef    c_reset_room_tile_obj_info
    xdef    c_play_key_taken_tune
    xdef    c_take_power_triforce
    xdef    c_silence_all_sound
    xdef    c_post_debit
    xdef    c_init_one_simple_object
    xdef    c_destroy_object_wram
    xdef    c_destroy_whirlwind
    xdef    c_uw_person_delay_quit
    xdef    c_set_boomerang_speed
    xdef    c_animate_demo_p1s0
    xdef    c_animate_demo_p1s1
    xdef    c_disable_fallen_objects
    xdef    c_init_mode1_sub2
    xdef    c_set_up_common_cave_objects
    xdef    c_update_mode7_scroll_sub2
    xdef    c_update_mode7_scroll_sub7
    xdef    c_fetch_tile_map_addr
    xdef    c_copy_play_area_attrs_half
    xdef    c_reset_obj_state
    xdef    c_set_shot_spreading_state
    xdef    c_roll_over_anim_counter
    xdef    c_decrement_invincibility_timer
    xdef    c_update_dead_dummy
    xdef    c_play_secret_found_tune
    xdef    c_play_boss_death_cry
    xdef    c_dodongo_dec_bloated_timer
    xdef    c_gleeok_dec_head_timer
    xdef    c_gleeok_set_segment_x
    xdef    c_gohma_play_parry_tune
    xdef    c_end_game_mode
    xdef    c_set_shove_info_with0
    xdef    c_flyer_set_state_and_turns
    xdef    c_init_aquamentus
    xdef    c_reset_flyer_state
    xdef    c_reset_obj_metastate
    xdef    c_anim_fetch_obj_pos
    xdef    c_end_init_demo
    xdef    c_mode_e_reset_variables
    xdef    c_reset_button_repeat_state
    xdef    c_mode_e_set_name_cursor_sprite_x
    xdef    c_inc_submode
    xdef    c_inc_2_submodes
    xdef    c_init_mode4_go_to_sub0
    xdef    c_unhalt_link
    xdef    c_inc_cave_state
    xdef    c_set_up_whirlwind
    xdef    c_inc_subphase
    xdef    c_anim_set_obj_hflip
    xdef    c_anim_set_sprite_desc_attrs
    xdef    c_init_tektite
    xdef    c_ganon_randomize_location
    xdef    c_init_digdogger1
    xdef    c_fetch_profile_name_address
    xdef    c_map_screen_pos_to_ppu_addr
    xdef    c_init_mode_a_sub_a_go_to_mode4
    xdef    c_update_mode_d_save_sub2
    xdef    c_animate_demo_p1_end
    xdef    c_import_sram_commit
    xdef    c_import_demo_animate_objects
    xdef    c_animate_demo_p1_sub3
    xdef    c_manhandla_set_all_segments_direction
    xdef    c_extract_hit_point_value
    xdef    c_copy_column_or_row_to_tilebuf
    xdef    c_walker_alt_dir_get_opposite
    xdef    c_jumper_point_boulder_downward
    xdef    c_flyer_delay
    xdef    c_mode_e_sync_char_board_cursor
    xdef    c_cycle9_in_direction
    xdef    c_post_credit
    xdef    c_add_to_int16_at_0
    xdef    c_add_to_int16_at_2
    xdef    c_add_to_int16_at_4
    xdef    c_add_a_to_0f0e
    xdef    c_add_a_to_cfce
    xdef    c_end_init_flyer
    xdef    c_init_digdogger2
    xdef    c_update_dodongo_bloated_sub_end
    xdef    c_set_up_fairy_object
    xdef    c_reset_shove_info_and_inv_timer
    xdef    c_reset_push_timer
    xdef    c_set_dead_dummy_obj_type
    xdef    c_jumper_reset_vspeed_frac
    xdef    c_update_person_reset_char_offset
    xdef    c_begin_update_mode
    xdef    c_trigger_open_door
    xdef    c_update_mode11_death_sub6
    xdef    c_init_link_speed
    xdef    c_init_flute_secret
    xdef    c_reset_obj_metastate_and_timer
    xdef    c_cue_transfer_buf_advance_state
    xdef    c_take_one_rupee
    xdef    c_set_item_value
    xdef    c_init_whirlwind
    xdef    c_gleeok_set_segment_y
    xdef    c_reset_vscroll_lo
    xdef    c_deactivate_shot
    xdef    c_deactivate_link_shot
    xdef    c_walker_alt_dir_end_loop
    xdef    c_reset_shove_info
    xdef    c_go_to_next_mode
    xdef    c_add1_to_int16_at_2
    xdef    c_add1_to_int16_at_4
    xdef    c_cue_transfer_blank_person_wares
    xdef    c_take_5_rupees
    xdef    c_init_monster_shot
    xdef    c_init_boulder
    xdef    c_init_boulder_set
    xdef    c_get_opposite_dir
    xdef    c_abs
    xdef    c_negate
    xdef    c_find_empty_monster_slot
    xdef    c_destroy_monster
    xdef    c_set_type_and_clear_object
    xdef    c_init_tile_obj_or_item
    xdef    c_anim_advance_and_fetch
    xdef    c_set_room_flag_uw_item_state
    xdef    c_get_room_flag_uw_item_state
    xdef    c_play_boss_hit_cry_if_needed
    xdef    c_play_effect
    xdef    c_play_sample
    xdef    c_flyer_set_flying_state
    xdef    c_play_boss_death_cry_if_needed
    xdef    c_select_transfer_buf
    xdef    c_touch_door_wall
    xdef    c_go_to_next_mode_play_level_song
    xdef    c_go_to_next_mode_reset_grid_offset
    xdef    c_destroy_monster_shot
    xdef    c_destroy_counted_monster_shot
    xdef    c_play_parry_tune
    xdef    c_reverse_obj_dir
    xdef    c_patch_and_cue_level_palettes_transfer
    xdef    c_ganon_get_cur_cloud_bottom
    xdef    c_ganon_get_cur_cloud_right
    xdef    c_pols_voice_move_x
    xdef    c_init_blue_keese
    xdef    c_init_red_or_black_keese
    xdef    c_select_transfer_buf_and_inc_state
    xdef    c_destroy_monster_bank4
    xdef    c_ganon_get_cur_cloud_left
    xdef    c_ganon_get_cur_cloud_top
    xdef    c_write_blank_priority_sprites
    xdef    c_wallmaster_prepare_to_draw
    xdef    c_get_player_coords_for_direction
    xdef    c_copy_price_list_template
    xdef    c_shoot_fireball
    xdef    c_shoot_fireball_55
    xdef    c_gohma_set_sprite_attributes
    xdef    c_init_gohma
    xdef    c_block_at_wall
    xdef    c_init_underworld_person_b
    xdef    c_copy_next_row_to_transfer_buf
    xdef    c_copy_next_row_advance_submode
    xdef    c_is_quest_secret_mismatch
    xdef    c_is_distance_safe_to_spawn
    xdef    c_compare_hearts_to_containers
    xdef    c_uw_person_complex_state_begin
    xdef    c_format_char_doublet
    xdef    c_reset_cur_sprite_index
    xdef    c_set_fade_cycle_advance_submode
    xdef    c_set_moving_dir_switch_player
    xdef    c_link_modify_dir_in_doorway
    xdef    c_update_mode11_death_sub_c
    xdef    c_update_mode7_scroll_sub6
    xdef    c_get_collidable_tile
    xdef    c_get_collidable_tile_still
    xdef    c_get_colliding_tile_moving
    xdef    c_play_boomerang_sfx
    xdef    c_take_hearts_no_sound
    xdef    c_do_objects_collide_with_thresholds
    xdef    c_init_underworld_person_c
    xdef    c_init_grumble_full
    xdef    c_init_rupee_stash_full
    xdef    c_init_mode13_sub3
    xdef    c_pols_voice_get_colliding_tile
    xdef    c_wizzrobe_get_base_collidable_tile
    xdef    c_init_gleeok_head
    xdef    c_ganon_activate_room_item
    xdef    c_shoot
    xdef    c_cue_transfer_play_area_attrs_half_and_advance_submode
    xdef    c_update_mode11_death_sub2
    xdef    c_init_mode10
    xdef    c_setup_tile_object_ow
    xdef    c_world_fill_hearts
    xdef    c_update_uw_person_life_or_money_state_0
    xdef    c_underworld_person_destroy_if_taken
    xdef    c_init_uw_person_life_or_money_full
    xdef    c_person_flag_item_taken_and_advance_state
    xdef    c_check_person_blocking
    xdef    c_init_demo_subphase_play_title_song
    xdef    c_init_demo_subphase_transfer_title_palette
    xdef    c_init_demo_subphase_transfer_story_palette
    xdef    c_animate_demo_phase1_subphase4
    xdef    c_update_sprites_for_waterfall_crest
    xdef    c_update_sprites_for_waterfall_wave
    xdef    c_update_waterfall_animation
    xdef    c_init_mode13_sub4
    xdef    c_flyer_keese_decide_state
    xdef    c_flyer_peahat_decide_state
    xdef    c_update_dodongo_state2_stunned
    xdef    c_pols_voice_is_square_walkable
    xdef    c_clear_prices_cave_flag
    xdef    c_update_person_state_delay_then_hide
    xdef    c_init_peahat
    xdef    c_update_menu_common2
    xdef    c_update_menu_common3
    xdef    c_update_menu_common4
    xdef    c_update_menu5_ow
    xdef    c_l1433a_inc_submode
    xdef    c_init_mode7_finish
    xdef    c_update_person_state_do_nothing
    xdef    c_update_cave_person_state_do_nothing
    xdef    c_init_underworld_person_do_nothing
    xdef    c_update_grumble1
    xdef    c_init_pond_fairy
    xdef    c_init_dodongo
    xdef    c_switch_to_nt1
    xdef    c_update_mode11_death_set_timer_inc_submode
    xdef    c_update_mode11_death_sub4
    xdef    c_update_mode11_death_sub5
    xdef    c_update_mode11_death_sub9
    xdef    c_flyer_fairy_decide_state
    xdef    c_add1_to_int16_at_0
    xdef    c_check_boss_hit_reaction
    xdef    c_anim_set_sprite_desc_level_palette_row
    xdef    c_defer_bounce
    xdef    c_flyer_do_nothing
    xdef    c_flyer_ghini_decide_state
    xdef    c_flyer_gleeok_head_decide_state
    xdef    c_flyer_moldorm_decide_state
    xdef    c_flyer_patra_decide_state
    xdef    c_do_nothing_z07
    xdef    c_walker_alt_dir_get_random_perpendicular
    xdef    c_flyer_compare_max_speed
    xdef    c_init_grumble_z07
    xdef    c_init_rupee_stash_z07
    xdef    c_init_mode3_sub1_z07
    xdef    c_gleeok_ignore_segment
    xdef    c_gleeok_contract_segment_x
    xdef    c_gleeok_contract_segment_y
    xdef    c_is_dark_room_bank4
    xdef    c_dec_submenu_scroll
    xdef    c_flyer_slow_down
    xdef    c_flyer_speed_up
    xdef    c_set_flying_state_1
    xdef    c_gleeok_contract_segment
    xdef    c_take_hearts
    xdef    c_block_until_time
    xdef    c_wield_nothing
    xdef    c_end_prepare_mode
    xdef    c_init_mode9_transfer_attrs
    xdef    c_start_filling_hearts
    xdef    c_init_mode_b_sub1
    xdef    c_check_secret_trigger_none
    xdef    c_trigger_shutters
    xdef    c_return_false
    xdef    c_check_secret_trigger_all_dead
    xdef    c_check_secret_trigger_last_boss
    xdef    c_check_secret_trigger_money_or_life
    xdef    c_check_secret_trigger_block_door
    xdef    c_check_secret_trigger_ringleader
    xdef    c_touch_door_open
    xdef    c_touch_door_bombable
    xdef    c_init_mode3_sub2
    xdef    c_init_mode3_sub6
    xdef    c_init_mode3_sub7
    xdef    c_update_mode12_end_level_sub1
    xdef    c_touch_door_false
    xdef    c_init_mode_a_sub1
    xdef    c_end_game_mode12
    xdef    c_touch_door_shutter
    xdef    c_save_kill_count_ow
    xdef    c_cue_transfer_play_area_attrs_half_nt0
    xdef    c_init_leever
    xdef    c_check_init_whirlwind_and_begin_update
    xdef    c_update_dodongo_state1_bloated_sub_die
    xdef    c_init_walker
    xdef    c_init_bubble
    xdef    c_init_rope
    xdef    c_init_darknut
    xdef    c_init_slow_octorock_or_ghini
    xdef    c_init_fast_octorock
    xdef    c_init_mode3_sub3
    xdef    c_init_mode3_sub4
    xdef    c_init_mode3_sub5
    xdef    c_advance_teleporting_level_index
    xdef    c_init_underworld_person_a
    xdef    c_update_uw_person_complex_state_sense_link
    xdef    c_update_uw_person_life_or_money_state_2
    xdef    c_replace_ganon_brown_palette_row
    xdef    c_replace_ganon_blue_palette_row
    xdef    c_replace_ashes_palette_row
    xdef    c_init_gel
    xdef    c_person_check_collisions
    xdef    c_draw_life_or_money_items
    xdef    c_update_grumble3
    xdef    c_update_grumble_full
    xdef    c_update_uw_person_full
    xdef    c_update_uw_person_complex
    xdef    c_update_uw_person_life_or_money_full
    xdef    c_person_draw_and_check_collisions
    xdef    c_check_monster_collisions
    xdef    c_do_check_monster_collisions
    xdef    c_do_objects_collide
    xdef    c_update_bomb_flash_effect
    xdef    c_update_position_marker
    xdef    c_update_player_position_marker
    xdef    c_update_world_curtain_effect
    xdef    c_update_world_curtain_effect_bank2
    xdef    c_fetch_file_a_address_set
    xdef    c_check_tile_objects_blocking
    xdef    c_check_power_triforce_fanfare
    xdef    c_animate_item_object
    xdef    c_draw_object_mirrored
    xdef    c_draw_object_not_mirrored
    xdef    c_link_end_move_and_animate_bank1
    xdef    c_update_person_state_textbox
    xdef    c_draw_cave_person
    xdef    c_draw_cave_items
    xdef    c_format_decimal_byte
    xdef    c_write_prices_to_dynamic_transfer_buf
    xdef    c_write_prices_transfer_buf
    xdef    c_update_cave_person_state_transfer_prices
    xdef    c_link_end_move_and_draw_bank1
    xdef    c_update_cave_person_state_talk_or_shop_or_door_charge
    xdef    c_update_cave_person_state_hint_or_money_game
    xdef    c_update_cave_person
    xdef    c_take_item
    xdef    c_format_hearts_in_text_buf
    xdef    c_copy_triplet_to_text_buf
    xdef    c_format_decimal_count_byte
    xdef    c_format_decimal_count_byte_in_text_buf
    xdef    c_format_status_bar_text
    xdef    c_world_change_rupees
    xdef    c_init_cave
    xdef    c_try_take_item
    xdef    c_try_take_room_item
    xdef    c_bound_direction_horizontally
    xdef    c_bound_direction_vertically
    xdef    c_bound_by_room
    xdef    c_bound_by_room_with_a
    xdef    c_add_q_speed_to_position_fraction
    xdef    c_sub_q_speed_from_position_fraction
    xdef    c_move_shot
    xdef    c_get_one_direction_and_distance_to_target
    xdef    c_get_directions_and_distances_to_target
    xdef    c_calc_diagonal_speed_index
    xdef    c_place_weapon
    xdef    c_place_weapon_for_player_state
    xdef    c_place_weapon_for_player_state_and_anim
    xdef    c_place_weapon_for_player_state_and_anim_and_weapon_state
    xdef    c_sub1_from_int16_at4
    xdef    c_wield_bomb
    xdef    c_wield_candle
    xdef    c_get_shortcut_or_item_xy_for_room
    xdef    c_get_shortcut_or_item_xy
    xdef    c_get_object_middle
    xdef    c_animate_world_fading
    xdef    c_check_mazes
    xdef    c_cycle_cur_sprite_index
    xdef    c_hide_object_sprites
    xdef    c_show_link_sprites_behind_horizontal_doors
    xdef    c_play_parry_sound_for_damage_type
    xdef    c_handle_monster_died
    xdef    c_deal_damage
    xdef    c_handle_monster_weapon_collision
    xdef    c_check_monster_weapon_collision
    xdef    c_check_monster_slender_weapon_collision2
    xdef    c_check_monster_slender_weapon_collision
    xdef    c_check_monster_stabbing_collision
    xdef    c_check_monster_sword_collision
    xdef    c_parry_or_shove
    xdef    c_check_monster_shot_collision
    xdef    c_check_monster_arrow_or_rod_collision
    xdef    c_check_monster_boomerang_or_food_collision
    xdef    c_call_begin_shove
    xdef    c_call_gohma_handle_weapon_collision
    xdef    c_check_monster_sword_shot_or_magic_shot_collision
    xdef    c_check_monster_bomb_or_fire_collision
    xdef    c_call_handle_shot_blocked
    xdef    c_harm_link
    xdef    c_check_link_collision
    xdef    c_check_link_collision_preinit
    xdef    c_begin_shove
    xdef    c_link_be_harmed
    xdef    c_init_trap_full
    xdef    c_draw_whirlwind
    xdef    c_update_whirlwind_full
    xdef    c_summon_whirlwind
    xdef    c_update_rupee_stash_full
    xdef    c_init_mode_b_enter_cave_bank5
    xdef    c_check_passive_tile_objects
    xdef    c_draw_object_not_mirrored_with_frame
    xdef    c_draw_item_in_inventory
    xdef    c_go_to_next_mode_from_play
    xdef    c_init_mode_enter_room
    xdef    c_run_cross_room_tasks_no_cellar
    xdef    c_link_end_move_and_animate
    xdef    c_update_trap_full
    xdef    c_animate_object_walking
    xdef    c_animate_and_draw_common_object
    xdef    c_obj_shove
    xdef    c_walker_move
    xdef    c_update_common_wanderer
    xdef    c_wanderer_target_player
    xdef    c_move_flyer
    xdef    c_control_keese_flight
    xdef    c_update_bubble
    xdef    c_update_keese
    xdef    c_draw_object_mirrored_with_frame
    xdef    c_update_standing_fire
    xdef    c_update_zol
    xdef    c_update_gel
    xdef    c_update_zol_state
    xdef    c_zol_check_collisions
    xdef    c_gel_move
    xdef    c_gel_check_collisions
    xdef    c_shoot_limited
    xdef    c_update_zora
    xdef    c_update_candle
    xdef    c_update_boulder_set
    xdef    c_update_rope
    xdef    c_change_tile_obj_tiles
    xdef    c_shoot_if_wanted
    xdef    c_update_burrower
    xdef    c_draw_arrow
    xdef    c_draw_sword_shot_or_magic_shot
    xdef    c_update_block
    xdef    c_draw_block
    xdef    c_update_monster_shot
    xdef    c_draw_shot
    xdef    c_bounce_shot
    xdef    c_check_shot_link_collision
    xdef    c_update_fireball
    xdef    c_reverse_obj_dir8
    xdef    c_gohma_animate_and_draw
    xdef    c_gohma_check_collisions
    xdef    c_gleeok_draw_body
    xdef    c_gleeok_fetch_neck_addrs
    xdef    c_gleeok_move_neck
    xdef    c_gleeok_move_head
    xdef    c_gleeok_draw_head_and_check_collisions
    xdef    c_gleeok_draw_segment_and_check_collisions
    xdef    c_gleeok_calc_segment_limits
    xdef    c_gleeok_stretch_neck

    xref    c_move_object
    xref    z03_transfer_level_pattern_blocks
    xref    z06_init_mode2_submodes
    xref    z06_copy_common_data_to_ram
    xref    z06_update_mode2_load_full
    xref    z05_copy_column_to_tilebuf
    xref    z05_copy_row_to_tilebuf
    xref    z05_has_compass
    xref    z05_has_map
    xref    z05_calc_open_doorway_mask
    xref    z05_add_door_flags
    xref    z05_split_room_id
    xref    z05_is_dark_room
    xref    z05_set_door_flag
    xref    z05_reset_door_flag
    xref    z05_check_has_living_monsters
    xref    z05_silence_sound
    xref    z05_set_entering_doorway
    xref    z05_write_and_enable_sprite0
    xref    z05_put_link_behind_background
    xref    z05_reset_inv_obj_state
    xref    z05_mask_cur_ppu_mask_grayscale
    xref    z05_setup_obj_room_bounds
    xref    z07_hide_all_sprites
    xref    z07_get_unique_room_id
    xref    z07_clear_room_history
    xref    z07_reset_player_state
    xref    z07_reset_moving_dir
    xref    z07_ensure_object_aligned
    xref    z05_fill_play_area_attrs
    xref    z04_hide_sprites_over_link
    xref    z07_get_room_flags
    xref    z07_mark_room_visited
    xref    z01_play_character_sfx
    xref    z01_reset_room_tile_obj_info
    xref    z01_play_key_taken_tune
    xref    z01_take_power_triforce
    xref    z01_silence_all_sound
    xref    z01_post_debit
    xref    z01_init_one_simple_object
    xref    z01_destroy_object_wram
    xref    z01_destroy_whirlwind
    xref    z01_uw_person_complex_state_delay_and_quit
    xref    z01_set_boomerang_speed
    xref    z02_animate_demo_phase1_sub0
    xref    z02_animate_demo_phase1_sub1
    xref    z02_disable_fallen_objects
    xref    z02_init_mode1_sub2
    xref    z01_set_up_common_cave_objects
    xref    z05_update_mode7_scroll_sub2
    xref    z05_update_mode7_scroll_sub7
    xref    z05_fetch_tile_map_addr
    xref    z05_copy_play_area_attrs_half
    xref    z07_reset_obj_state
    xref    z07_set_shot_spreading_state
    xref    z07_roll_over_anim_counter
    xref    z07_decrement_invincibility_timer
    xref    z07_update_dead_dummy
    xref    z04_play_secret_found_tune
    xref    z04_play_boss_death_cry
    xref    z04_dodongo_dec_bloated_timer
    xref    z04_gleeok_dec_head_timer
    xref    z04_gleeok_set_segment_x
    xref    z04_gohma_play_parry_tune
    xref    z07_end_game_mode
    xref    z07_set_shove_info_with0
    xref    z04_flyer_set_state_and_turns
    xref    z04_init_aquamentus
    xref    z04_reset_flyer_state
    xref    z07_reset_obj_metastate
    xref    z07_anim_fetch_obj_pos
    xref    z02_end_init_demo
    xref    z02_mode_e_reset_variables
    xref    z02_reset_button_repeat_state
    xref    z02_mode_e_set_name_cursor_sprite_x
    xref    z05_inc_submode
    xref    z05_inc_2_submodes
    xref    z05_init_mode4_go_to_sub0
    xref    z01_unhalt_link
    xref    z01_inc_cave_state
    xref    z01_set_up_whirlwind
    xref    z02_inc_subphase
    xref    z07_anim_set_obj_hflip
    xref    z01_anim_set_sprite_desc_attrs
    xref    z04_init_tektite
    xref    z04_ganon_randomize_location
    xref    z04_init_digdogger1
    xref    z02_fetch_profile_name_address
    xref    z01_map_screen_pos_to_ppu_addr
    xref    z05_init_mode_a_sub_a_go_to_mode4
    xref    z02_update_mode_d_save_sub2
    xref    z02_animate_demo_p1_end
    xref    z02_animate_demo_p1_sub3
    xref    z04_manhandla_set_all_segments_direction
    xref    z04_extract_hit_point_value
    xref    z05_copy_column_or_row_to_tilebuf
    xref    z07_walker_alt_dir_get_opposite
    xref    z04_jumper_point_boulder_downward
    xref    z04_flyer_delay
    xref    z02_mode_e_sync_char_board_cursor
    xref    z05_cycle9_in_direction
    xref    z01_post_credit
    xref    z01_add_to_int16_at_0
    xref    z01_add_to_int16_at_2
    xref    z01_add_to_int16_at_4
    xref    z02_add_a_to_0f0e
    xref    z02_add_a_to_cfce
    xref    z04_end_init_flyer
    xref    z04_init_digdogger2
    xref    z04_update_dodongo_bloated_sub_end
    xref    z04_set_up_fairy_object
    xref    z01_reset_shove_info_and_inv_timer
    xref    z04_reset_push_timer
    xref    z04_set_dead_dummy_obj_type
    xref    z04_jumper_reset_vspeed_frac
    xref    z01_update_person_state_reset_char_offset
    xref    z01_begin_update_mode
    xref    z05_trigger_open_door
    xref    z05_update_mode11_death_sub6
    xref    z07_init_flute_secret
    xref    z07_reset_obj_metastate_and_timer
    xref    z01_cue_transfer_buf_and_advance_state
    xref    z01_take_one_rupee
    xref    z01_set_item_value
    xref    z01_init_whirlwind
    xref    z04_gleeok_set_segment_y
    xref    z05_reset_vscroll_lo
    xref    z07_deactivate_shot
    xref    z07_deactivate_link_shot
    xref    z07_walker_alt_dir_end_loop
    xref    z07_reset_shove_info
    xref    z07_go_to_next_mode
    xref    z01_add1_to_int16_at_2
    xref    z01_add1_to_int16_at_4
    xref    z01_cue_transfer_blank_person_wares
    xref    z01_take_5_rupees
    xref    z04_init_monster_shot
    xref    z04_init_boulder
    xref    z04_init_boulder_set
    xref    z01_get_opposite_dir
    xref    z01_abs
    xref    z01_negate
    xref    z07_find_empty_monster_slot
    xref    z07_destroy_monster
    xref    z07_set_type_and_clear_object
    xref    z07_init_tile_obj_or_item
    xref    z07_anim_advance_and_fetch
    xref    z01_set_room_flag_uw_item_state
    xref    z01_get_room_flag_uw_item_state
    xref    z04_play_boss_hit_cry_if_needed
    xref    z01_play_effect
    xref    z01_play_sample
    xref    z04_flyer_set_flying_state
    xref    z04_play_boss_death_cry_if_needed
    xref    z05_select_transfer_buf
    xref    z05_touch_door_wall
    xref    z07_go_to_next_mode_play_level_song
    xref    z07_go_to_next_mode_reset_grid_offset
    xref    z04_destroy_monster_shot
    xref    z04_destroy_counted_monster_shot
    xref    z01_play_parry_tune
    xref    z07_reverse_obj_dir
    xref    z07_patch_and_cue_level_palettes_transfer
    xref    z04_ganon_get_cur_cloud_bottom
    xref    z04_ganon_get_cur_cloud_right
    xref    z04_pols_voice_move_x
    xref    z04_init_blue_keese
    xref    z04_init_red_or_black_keese
    xref    z05_select_transfer_buf_and_inc_state
    xref    z04_destroy_monster_bank4
    xref    z04_ganon_get_cur_cloud_left
    xref    z04_ganon_get_cur_cloud_top
    xref    z01_write_blank_priority_sprites
    xref    z04_wallmaster_prepare_to_draw
    xref    z05_get_player_coords_for_direction
    xref    z01_copy_price_list_template
    xref    z04_shoot_fireball
    xref    z04_shoot_fireball_55
    xref    z04_gohma_set_sprite_attributes
    xref    z04_init_gohma
    xref    z05_block_at_wall
    xref    z01_init_underworld_person_b
    xref    z05_copy_next_row_to_transfer_buf
    xref    z05_copy_next_row_advance_submode
    xref    z04_is_quest_secret_mismatch
    xref    z05_is_distance_safe_to_spawn
    xref    z01_compare_hearts_to_containers
    xref    z01_uw_person_complex_state_begin
    xref    z01_format_char_doublet
    xref    z01_reset_cur_sprite_index
    xref    z05_set_fade_cycle_and_advance_submode
    xref    z05_set_moving_dir_and_switch_to_player_slot
    xref    z05_link_modify_dir_in_doorway
    xref    z05_update_mode11_death_sub_c
    xref    z05_update_mode7_scroll_sub6
    xref    z07_get_collidable_tile
    xref    z07_get_collidable_tile_still
    xref    z07_get_colliding_tile_moving
    xref    z01_play_boomerang_sfx
    xref    z01_take_hearts_no_sound
    xref    z01_do_objects_collide_with_thresholds
    xref    z01_init_underworld_person_c
    xref    z01_init_grumble_full
    xref    z01_init_rupee_stash_full
    xref    z02_init_mode13_sub3
    xref    z04_pols_voice_get_colliding_tile
    xref    z04_wizzrobe_get_base_collidable_tile
    xref    z04_init_gleeok_head
    xref    z04_ganon_activate_room_item
    xref    z04_shoot
    xref    z05_cue_transfer_play_area_attrs_half_and_advance_submode
    xref    z05_update_mode11_death_sub2
    xref    z05_init_mode10
    xref    z05_setup_tile_object_ow
    xref    z05_world_fill_hearts
    xref    z01_update_uw_person_life_or_money_state_0
    xref    z01_underworld_person_destroy_if_taken
    xref    z01_init_uw_person_life_or_money_full
    xref    z01_person_flag_item_taken_and_advance_state
    xref    z01_check_person_blocking
    xref    z02_init_demo_subphase_play_title_song
    xref    z02_init_demo_subphase_transfer_title_palette
    xref    z02_init_demo_subphase_transfer_story_palette
    xref    z02_animate_demo_phase1_subphase4
    xref    z02_update_sprites_for_waterfall_crest
    xref    z02_update_sprites_for_waterfall_wave
    xref    z02_update_waterfall_animation
    xref    z02_init_mode13_sub4
    xref    z04_flyer_keese_decide_state
    xref    z04_flyer_peahat_decide_state
    xref    z04_update_dodongo_state2_stunned
    xref    z04_pols_voice_is_square_walkable
    xref    z01_clear_prices_cave_flag
    xref    z01_update_person_state_delay_then_hide
    xref    z04_init_peahat
    xref    z05_update_menu_common2
    xref    z05_update_menu_common3
    xref    z05_update_menu_common4
    xref    z05_update_menu5_ow
    xref    z05_l1433a_inc_submode
    xref    z05_init_mode7_finish
    xref    z01_update_person_state_do_nothing
    xref    z01_update_cave_person_state_do_nothing
    xref    z01_init_underworld_person_do_nothing
    xref    z01_update_grumble1
    xref    z04_init_pond_fairy
    xref    z04_init_dodongo
    xref    z05_switch_to_nt1
    xref    z05_update_mode11_death_set_timer_inc_submode
    xref    z05_update_mode11_death_sub4
    xref    z05_update_mode11_death_sub5
    xref    z05_update_mode11_death_sub9
    xref    z04_flyer_fairy_decide_state
    xref    z01_add1_to_int16_at_0
    xref    z04_check_boss_hit_reaction
    xref    z04_anim_set_sprite_desc_level_palette_row
    xref    z04_defer_bounce
    xref    z04_flyer_do_nothing
    xref    z04_flyer_ghini_decide_state
    xref    z04_flyer_gleeok_head_decide_state
    xref    z04_flyer_moldorm_decide_state
    xref    z04_flyer_patra_decide_state
    xref    z07_do_nothing
    xref    z07_walker_alt_dir_get_random_perpendicular
    xref    z04_flyer_compare_max_speed
    xref    z07_init_grumble
    xref    z07_init_mode3_sub1
    xref    z07_init_rupee_stash
    xref    z04_gleeok_ignore_segment
    xref    z04_gleeok_contract_segment_x
    xref    z04_gleeok_contract_segment_y
    xref    z04_is_dark_room_bank4
    xref    z05_dec_submenu_scroll
    xref    z04_flyer_slow_down
    xref    z04_flyer_speed_up
    xref    z04_set_flying_state_1
    xref    z04_gleeok_contract_segment
    xref    z01_take_hearts
    xref    z05_block_until_time
    xref    z05_init_mode3_sub2
    xref    z05_init_mode3_sub6
    xref    z05_init_mode3_sub7
    xref    z05_update_mode12_end_level_sub1
    xref    z05_touch_door_false
    xref    z05_init_mode_a_sub1
    xref    z05_end_game_mode12
    xref    z05_touch_door_shutter
    xref    z05_save_kill_count_ow
    xref    z04_init_leever
    xref    z01_check_init_whirlwind_and_begin_update
    xref    z04_update_dodongo_state1_bloated_sub_die
    xref    z04_init_walker
    xref    z04_init_bubble
    xref    z04_init_rope
    xref    z04_init_darknut
    xref    z04_init_slow_octorock_or_ghini
    xref    z04_init_fast_octorock
    xref    z05_init_mode3_sub3
    xref    z05_init_mode3_sub4
    xref    z05_init_mode3_sub5
    xref    z01_advance_teleporting_level_index
    xref    z01_init_underworld_person_a
    xref    z01_update_uw_person_complex_state_sense_link
    xref    z01_update_uw_person_life_or_money_state_2
    xref    z01_replace_ganon_brown_palette_row
    xref    z01_replace_ganon_blue_palette_row
    xref    z01_replace_ashes_palette_row
    xref    z04_init_gel
    xref    z01_person_check_collisions
    xref    z01_draw_life_or_money_items
    xref    z01_update_grumble3
    xref    z01_update_grumble_full
    xref    z01_update_uw_person_full
    xref    z01_update_uw_person_complex
    xref    z01_update_uw_person_life_or_money_full
    xref    z01_person_draw_and_check_collisions
    ; CheckMonsterCollisions -- now stubbed to c_do_check_monster_collisions
    xref    AnimateItemObject
    xref    DrawObjectMirrored
    xref    DrawObjectNotMirrored
    xref    Link_EndMoveAndAnimate_Bank1
    xref    z01_update_person_state_textbox
    xref    z01_draw_cave_person
    xref    z01_draw_cave_items
    xref    z01_format_decimal_byte
    xref    z01_write_prices_to_dynamic_transfer_buf
    xref    z01_write_prices_transfer_buf
    xref    z01_update_cave_person_state_transfer_prices
    xref    Link_EndMoveAndDraw_Bank1
    xref    z01_update_cave_person_state_talk_or_shop_or_door_charge
    xref    z01_update_cave_person_state_hint_or_money_game
    xref    z01_update_cave_person
    xref    z01_take_item
    xref    z01_format_hearts_in_text_buf
    xref    z01_copy_triplet_to_text_buf
    xref    z01_format_decimal_count_byte
    xref    z01_format_decimal_count_byte_in_text_buf
    xref    z01_format_status_bar_text
    xref    z01_world_change_rupees
    xref    z01_init_cave
    xref    z01_try_take_item
    xref    z01_try_take_room_item
    xref    z01_bound_direction_horizontally
    xref    z01_bound_direction_vertically
    xref    z01_bound_by_room
    xref    z01_bound_by_room_with_a
    xref    z01_add_q_speed_to_position_fraction
    xref    z01_sub_q_speed_from_position_fraction
    xref    z01_move_shot
    xref    z01_get_one_direction_and_distance_to_target
    xref    z01_get_directions_and_distances_to_target
    xref    z01_calc_diagonal_speed_index
    xref    z01_place_weapon
    xref    z01_place_weapon_for_player_state
    xref    z01_place_weapon_for_player_state_and_anim
    xref    z01_place_weapon_for_player_state_and_anim_and_weapon_state
    xref    z01_sub1_from_int16_at4
    xref    z01_wield_bomb
    xref    z01_wield_candle
    xref    z01_get_shortcut_or_item_xy_for_room
    xref    z01_get_shortcut_or_item_xy
    xref    z01_get_object_middle
    xref    z01_animate_world_fading
    xref    z01_check_mazes
    xref    z01_cycle_cur_sprite_index
    xref    z01_cycle_sprite_index_in_a
    xref    z01_hide_object_sprites
    xref    z01_show_link_sprites_behind_horizontal_doors
    xref    z01_play_parry_sound_for_damage_type
    xref    z01_handle_monster_died
    xref    z01_deal_damage
    xref    z01_handle_monster_weapon_collision
    xref    z01_check_monster_weapon_collision
    xref    z01_check_monster_slender_weapon_collision2
    xref    z01_check_monster_slender_weapon_collision
    xref    z01_check_monster_stabbing_collision
    xref    z01_check_monster_sword_collision
    xref    z01_parry_or_shove
    xref    z01_check_monster_shot_collision
    xref    z01_check_monster_arrow_or_rod_collision
    xref    z01_check_monster_boomerang_or_food_collision
    xref    z01_check_monster_sword_shot_or_magic_shot_collision
    xref    z01_check_monster_bomb_or_fire_collision
    xref    z01_harm_link
    xref    z01_check_link_collision
    xref    z01_check_link_collision_preinit
    xref    z01_begin_shove
    xref    z01_link_be_harmed
    xref    z01_check_monster_collisions
    xref    z01_do_objects_collide
    xref    z01_update_bomb_flash_effect
    xref    z01_update_position_marker
    xref    z01_update_player_position_marker
    xref    z01_update_world_curtain_effect
    xref    z01_update_world_curtain_effect_bank2
    xref    z01_fetch_file_a_address_set
    xref    z01_check_tile_objects_blocking
    xref    z01_check_power_triforce_fanfare
    xref    z07_patch_and_cue_level_palettes_transfer
    xref    z05_wield_nothing
    xref    z05_end_prepare_mode
    xref    z05_init_mode9_transfer_attrs
    xref    z05_start_filling_hearts
    xref    z05_init_mode_b_sub1
    xref    z05_check_secret_trigger_none
    xref    z05_trigger_shutters
    xref    z05_return_false
    xref    z05_check_secret_trigger_all_dead
    xref    z05_check_secret_trigger_last_boss
    xref    z05_check_secret_trigger_money_or_life
    xref    z05_check_secret_trigger_block_door
    xref    z05_check_secret_trigger_ringleader
    xref    z05_touch_door_open
    xref    z05_touch_door_bombable
    xref    z01_init_trap_full
    xref    z01_draw_whirlwind
    xref    z01_update_whirlwind_full
    xref    z01_summon_whirlwind
    xref    z01_update_rupee_stash_full
    xref    z01_init_mode_b_enter_cave_bank5
    xref    z01_check_passive_tile_objects
    xref    z01_update_trap_full
    xref    z07_animate_object_walking
    xref    z04_animate_and_draw_common_object
    xref    z04_update_bubble
    xref    z04_update_keese
    xref    z04_update_moblin
    xref    Obj_Shove
    xref    Walker_Move
    xref    UpdateCommonWanderer
    xref    Wanderer_TargetPlayer
    xref    MoveFlyer
    xref    z04_move_flyer
    xref    z04_bound_flyer
    xref    ControlKeeseFlight
    xref    z04_update_gibdo
    xref    z04_update_aquamentus
    xref    Aquamentus_Move
    xref    Aquamentus_Shoot
    xref    Aquamentus_Draw
    xref    DrawItemInInventory
    xref    GoToNextModeFromPlay
    xref    InitMode_EnterRoom
    xref    RunCrossRoomTasksAndBeginUpdateMode_PlayModesNoCellar
    xref    Link_EndMoveAndAnimate
    xref    ChangeTileObjTiles

;------------------------------------------------------------------------------
; _c_move_object_shim — MoveObject trampoline.
;
; Asm contract (see tools/transpile_6502.py:5260-5264 P48 comment block):
;   Input:     D2 = slot (0..11)
;   Preserves: D2, A4, A5
;   Clobbers:  D0, D1, D3, A0
;   Returns:   via rts with unspecified CCR (callers never BCC).
;
; GCC side:
;   void c_move_object(unsigned short slot);
;     slot arrives as a 16-bit value on the stack.
;   GCC preserves D2-D7/A2-A6 across C calls (callee-save).
;   -ffixed-a4 globally reserves A4 so the pinned NES_RAM pointer is
;   never clobbered by gcc.
;   A5 is NOT touched by any C code (audit-enforced: no (A5)+ / -(A5)
;   semantics can exist in a pure C port).
;------------------------------------------------------------------------------
_c_move_object_shim:
    ; DEBUG canary: write $AA to NES RAM $0900 each time we're called
    move.b  #$AA,($0900,A4)
    ; GCC 13 m68k reads the first arg via `move.l 4(%sp),%d0` — a full
    ; 32-bit load at SP+4 (after the return address). Big-endian means
    ; the slot value must sit in the LOW byte of that longword, i.e.
    ; at SP+7. We push a zero-extended 32-bit longword with D2 in the
    ; low position. moveq is safe because slot range is 0..11.
    moveq   #0,D0
    move.w  D2,D0           ; D0.L = 0000:slot (zero-extended)
    move.l  D0,-(SP)        ; push 32-bit arg
    jsr     c_move_object
    addq.l  #4,SP           ; pop the 32-bit slot
    rts

;==============================================================================
; IMPORT side — C callers invoke these; we marshal stack args into registers
; and tail-call the native asm function.
;
; GCC 13 m68k passes the first int/ptr arg as a 32-bit value at SP+4.
; For byte/word args the caller still pushes a full longword (zero- or
; sign-extended).
;==============================================================================

;------------------------------------------------------------------------------
; void c_copy_bank_to_window(unsigned int bank);
; Native: D0.w = bank, then jsr _copy_bank_to_window.
;------------------------------------------------------------------------------
c_copy_bank_to_window:
    move.l  4(SP),D0        ; D0.L = bank (only low word matters)
    jmp     _copy_bank_to_window

;------------------------------------------------------------------------------
; unsigned char c_ppu_read_2(void);
; Native: jsr _ppu_read_2 → result in D0.b.
; C return: gcc expects result in D0.
;------------------------------------------------------------------------------
c_ppu_read_2:
    jmp     _ppu_read_2

;------------------------------------------------------------------------------
; void c_ppu_write_6(unsigned int val);
; Native: D0.b = val, then jsr _ppu_write_6.
;------------------------------------------------------------------------------
c_ppu_write_6:
    move.l  4(SP),D0
    jmp     _ppu_write_6

;------------------------------------------------------------------------------
; void c_ppu_write_7(unsigned int val);
; Native: D0.b = val, then jsr _ppu_write_7.
;------------------------------------------------------------------------------
c_ppu_write_7:
    move.l  4(SP),D0
    jmp     _ppu_write_7

;------------------------------------------------------------------------------
; void c_turn_off_all_video(void);
; Native: jsr TurnOffAllVideo (no register args, no return value).
;------------------------------------------------------------------------------
c_turn_off_all_video:
    jmp     TurnOffAllVideo

;==============================================================================
; EXPORT side — z_03 entry point.
; z_07.asm calls `jsr TransferLevelPatternBlocks`. When BANK_MODE_03="c",
; the transpiler emits that label pointing to this shim instead of the
; z_03 asm body. The C function takes no args and returns void.
;==============================================================================

;------------------------------------------------------------------------------
; TransferLevelPatternBlocks → c_transfer_level_pattern_blocks
; (No register args. Preserves D2-D7/A2-A6 via gcc callee-save.)
;------------------------------------------------------------------------------
c_transfer_level_pattern_blocks:
    jmp     z03_transfer_level_pattern_blocks

;==============================================================================
; EXPORT side — z_06 entry points (Stage 3a).
; No register args. Preserves D2-D7/A2-A6 via gcc callee-save.
;==============================================================================

c_init_mode2_submodes:
    jmp     z06_init_mode2_submodes

c_copy_common_data_to_ram:
    jmp     z06_copy_common_data_to_ram

c_update_mode2_load_full:
    jmp     z06_update_mode2_load_full

;==============================================================================
; EXPORT side — z_05 entry points (Stage 3b).
; No register args. Preserves D2-D7/A2-A6 via gcc callee-save.
;==============================================================================

c_copy_column_to_tilebuf:
    jmp     z05_copy_column_to_tilebuf

c_copy_row_to_tilebuf:
    jmp     z05_copy_row_to_tilebuf

;==============================================================================
; EXPORT side — z_05 entry points (Stage 4a).
;==============================================================================

; HasCompass/HasMap — returns D0.b with Z flag set for BNE/BEQ callers
c_has_compass:
    jsr     z05_has_compass
    tst.b   D0
    rts

c_has_map:
    jsr     z05_has_map
    tst.b   D0
    rts

; CalcOpenDoorwayMask — D0=attr, D2=dir_idx. Preserves D0 on return.
c_calc_open_doorway_mask:
    move.l  D0,-(SP)
    moveq   #0,D1
    move.b  D2,D1
    move.l  D1,-(SP)
    move.l  4(SP),D1
    andi.l  #$FF,D1
    move.l  D1,-(SP)
    jsr     z05_calc_open_doorway_mask
    addq.l  #8,SP
    move.l  (SP)+,D0
    rts

; AddDoorFlagsToCurOpenedDoors — no args, void return
c_add_door_flags:
    jmp     z05_add_door_flags

;==============================================================================
; EXPORT side — z_05 entry points (Stage 4b).
;==============================================================================

; SplitRoomId — reads RAM($EB), returns D2=row (hi nibble), D3=col (lo nibble).
; C function returns (row<<8)|col in D0; shim unpacks into D2/D3.
c_split_room_id:
    jsr     z05_split_room_id
    moveq   #0,D3
    move.b  D0,D3           ; col = low byte of return
    lsr.w   #8,D0
    moveq   #0,D2
    move.b  D0,D2           ; row = high byte of return
    rts

; IsDarkRoom_Bank5 — D3=column. Returns D0=$80 if dark, 0 otherwise.
; Sets CCR flags for callers that branch on BEQ/BNE.
c_is_dark_room:
    moveq   #0,D0
    move.w  D3,D0
    move.l  D0,-(SP)
    jsr     z05_is_dark_room
    addq.l  #4,SP
    tst.b   D0
    rts

; SetDoorFlag — D2=dir_idx. Calls get_room_flags internally, writes flag.
c_set_door_flag:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z05_set_door_flag
    addq.l  #4,SP
    rts

; ResetDoorFlag — D2=dir_idx.
c_reset_door_flag:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z05_reset_door_flag
    addq.l  #4,SP
    rts

; CheckHasLivingMonsters — no args, void return.
c_check_has_living_monsters:
    jmp     z05_check_has_living_monsters

; SilenceSound — no args, void return.
c_silence_sound:
    jmp     z05_silence_sound

; SetEnteringDoorwayAsCurOpenedDoors — no args, void return.
c_set_entering_doorway:
    jmp     z05_set_entering_doorway

;==============================================================================
; EXPORT side — z_05 entry points (Stage 4b batch 3).
;==============================================================================

; WriteAndEnableSprite0 — no args, void return.
c_write_and_enable_sprite0:
    jmp     z05_write_and_enable_sprite0

; PutLinkBehindBackground — no args, void return.
c_put_link_behind_background:
    jmp     z05_put_link_behind_background

; ResetInvObjState — no args, void return.
c_reset_inv_obj_state:
    jmp     z05_reset_inv_obj_state

; MaskCurPpuMaskGrayscale — no args, void return.
c_mask_cur_ppu_mask_grayscale:
    jmp     z05_mask_cur_ppu_mask_grayscale

; SetupObjRoomBounds — no args, void return.
c_setup_obj_room_bounds:
    jmp     z05_setup_obj_room_bounds

;==============================================================================
; EXPORT side — z_07 entry points (Stage 4b batch 4).
;==============================================================================

; HideAllSprites — no args, void return.
c_hide_all_sprites:
    jmp     z07_hide_all_sprites

; GetUniqueRoomId — no args, returns D0=unique room ID, D3=room ID.
c_get_unique_room_id:
    jsr     z07_get_unique_room_id
    moveq   #0,D3
    move.b  ($00EB,A4),D3
    rts

;==============================================================================
; EXPORT side — z_07 entry points (Stage 4b batch 5).
;==============================================================================

; ClearRoomHistory — no args, void return.
c_clear_room_history:
    jmp     z07_clear_room_history

; ResetPlayerState — no args, void return.
c_reset_player_state:
    jmp     z07_reset_player_state

; ResetMovingDir — no args, void return.
c_reset_moving_dir:
    jmp     z07_reset_moving_dir

; EnsureObjectAligned — D2=slot, void return.
c_ensure_object_aligned:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z07_ensure_object_aligned
    addq.l  #4,SP
    rts

;==============================================================================
; EXPORT side — z_05/z_04 entry points (Stage 4b batch 6).
;==============================================================================

; FillPlayAreaAttrs — D0=room ID (byte), void return.
c_fill_play_area_attrs:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z05_fill_play_area_attrs
    addq.l  #4,SP
    rts

; HideSpritesOverLink — no args, void return.
c_hide_sprites_over_link:
    jmp     z04_hide_sprites_over_link

;==============================================================================
; EXPORT side — z_07 entry points (Stage 4b batch 7).
;==============================================================================

; GetRoomFlags — no args, returns D0=flags, D3=room ID. Sets RAM $00/$01.
c_get_room_flags:
    jsr     z07_get_room_flags
    moveq   #0,D3
    move.b  ($00EB,A4),D3
    rts

; MarkRoomVisited — no args, void return.
c_mark_room_visited:
    jmp     z07_mark_room_visited

;==============================================================================
; EXPORT side — z_01 entry points (Stage 4b batch 8).
;==============================================================================

; PlayCharacterSfx — no args, void return.
c_play_character_sfx:
    jmp     z01_play_character_sfx

; ResetRoomTileObjInfo — no args, void return.
c_reset_room_tile_obj_info:
    jmp     z01_reset_room_tile_obj_info

; PlayKeyTakenTune — no args, void return.
c_play_key_taken_tune:
    jmp     z01_play_key_taken_tune

; TakePowerTriforce — no args, void return.
c_take_power_triforce:
    jmp     z01_take_power_triforce

; SilenceAllSound — no args, void return.
c_silence_all_sound:
    jmp     z01_silence_all_sound

; PostDebit — D0=amount. Adds to RAM($067E).
c_post_debit:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z01_post_debit
    addq.l  #4,SP
    rts

; InitOneSimpleObject — D2=slot. Reads RAM($00/$01).
c_init_one_simple_object:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_init_one_simple_object
    addq.l  #4,SP
    rts

; DestroyObject_WRAM — D0=val, D2=slot.
c_destroy_object_wram:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z01_destroy_object_wram
    addq.l  #8,SP
    rts

; DestroyWhirlwind — D2=slot, void return.
c_destroy_whirlwind:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_destroy_whirlwind
    addq.l  #4,SP
    rts

;==============================================================================
; EXPORT side — z_01 entry points (Stage 4b batch 9a).
;==============================================================================

; UpdateUnderworldPersonComplexState_DelayAndQuit — no args, void return.
c_uw_person_delay_quit:
    jmp     z01_uw_person_complex_state_delay_and_quit

; SetBoomerangSpeed — D0=val, D2=slot.
c_set_boomerang_speed:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z01_set_boomerang_speed
    addq.l  #8,SP
    rts

;==============================================================================
; EXPORT side — z_02 entry points (Stage 4b batch 9b).
;==============================================================================

; AnimateDemoPhase1Subphase0 — no args, void return.
c_animate_demo_p1s0:
    jmp     z02_animate_demo_phase1_sub0

; AnimateDemoPhase1Subphase1 — no args, void return.
c_animate_demo_p1s1:
    jmp     z02_animate_demo_phase1_sub1

; DisableFallenObjects — no args, void return.
c_disable_fallen_objects:
    jmp     z02_disable_fallen_objects

; InitMode1_Sub2 — no args, void return.
c_init_mode1_sub2:
    jmp     z02_init_mode1_sub2

;==============================================================================
; EXPORT side — batch 10.
;==============================================================================

; SetUpCommonCaveObjects — D0=x, D2=slot, D3=y.
c_set_up_common_cave_objects:
    moveq   #0,D1
    move.b  D3,D1
    move.l  D1,-(SP)
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z01_set_up_common_cave_objects
    lea     12(SP),SP
    rts

; UpdateMode7Scroll_Sub2 — no args, void return.
c_update_mode7_scroll_sub2:
    jmp     z05_update_mode7_scroll_sub2

; UpdateMode7Scroll_Sub7 — no args, void return.
c_update_mode7_scroll_sub7:
    jmp     z05_update_mode7_scroll_sub7

; FetchTileMapAddr — no args, void return.
c_fetch_tile_map_addr:
    jmp     z05_fetch_tile_map_addr

; CopyPlayAreaAttrsHalfToDynTransferBuf — D2=ppu_hi, D0=ppu_lo, D3=end_off.
c_copy_play_area_attrs_half:
    moveq   #0,D1
    move.b  D3,D1
    move.l  D1,-(SP)
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    moveq   #0,D1
    move.b  D2,D1
    move.l  D1,-(SP)
    jsr     z05_copy_play_area_attrs_half
    lea     12(SP),SP
    rts

;==============================================================================
; EXPORT side — z_07 batch 11.
;==============================================================================

; ResetObjState — D2=slot, void return.
c_reset_obj_state:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z07_reset_obj_state
    addq.l  #4,SP
    rts

; SetShotSpreadingState — D2=slot, void return.
c_set_shot_spreading_state:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z07_set_shot_spreading_state
    addq.l  #4,SP
    rts

; RollOverAnimCounter — D2=slot, void return.
c_roll_over_anim_counter:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z07_roll_over_anim_counter
    addq.l  #4,SP
    rts

; DecrementInvincibilityTimer — D2=slot, void return.
c_decrement_invincibility_timer:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z07_decrement_invincibility_timer
    addq.l  #4,SP
    rts

; UpdateDeadDummy — D2=slot, void return.
c_update_dead_dummy:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z07_update_dead_dummy
    addq.l  #4,SP
    rts

;==============================================================================
; EXPORT side — batch 12: z_04 + z_07 leaves.
;==============================================================================

; PlaySecretFoundTune — void→void.
c_play_secret_found_tune:
    jmp     z04_play_secret_found_tune

; PlayBossDeathCry — void→void.
c_play_boss_death_cry:
    jmp     z04_play_boss_death_cry

; L_Dodongo_DecrementBloatedTimer — D2=slot.
c_dodongo_dec_bloated_timer:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_dodongo_dec_bloated_timer
    addq.l  #4,SP
    rts

; Gleeok_DecHeadTimer — void→void.
c_gleeok_dec_head_timer:
    jmp     z04_gleeok_dec_head_timer

; L_Gleeok_SetSegmentX — D3=val, D2=slot.
c_gleeok_set_segment_x:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    moveq   #0,D0
    move.b  D3,D0
    move.l  D0,-(SP)
    jsr     z04_gleeok_set_segment_x
    addq.l  #8,SP
    rts

; Gohma_PlayParryTune — void→void.
c_gohma_play_parry_tune:
    jmp     z04_gohma_play_parry_tune

; EndGameMode — void→void.
c_end_game_mode:
    jmp     z07_end_game_mode

; SetShoveInfoWith0 — D0=val, D2=slot.
c_set_shove_info_with0:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z07_set_shove_info_with0
    addq.l  #8,SP
    rts

;==============================================================================
; EXPORT side — batch 13.
;==============================================================================

; Flyer_SetStateAndTurns — D3=state, D2=slot.
c_flyer_set_state_and_turns:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    moveq   #0,D0
    move.b  D3,D0
    move.l  D0,-(SP)
    jsr     z04_flyer_set_state_and_turns
    addq.l  #8,SP
    rts

; InitAquamentus — D2=slot.
c_init_aquamentus:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_init_aquamentus
    addq.l  #4,SP
    rts

; ResetFlyerState — D2=slot.
c_reset_flyer_state:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_reset_flyer_state
    addq.l  #4,SP
    rts

; ResetObjMetastate — D2=slot.
c_reset_obj_metastate:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z07_reset_obj_metastate
    addq.l  #4,SP
    rts

; Anim_FetchObjPosForSpriteDescriptor — D2=slot.
c_anim_fetch_obj_pos:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z07_anim_fetch_obj_pos
    addq.l  #4,SP
    rts

; EndInitDemo — D0=val.
c_end_init_demo:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z02_end_init_demo
    addq.l  #4,SP
    rts

; ModeE_ResetVariables — D0=val.
c_mode_e_reset_variables:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z02_mode_e_reset_variables
    addq.l  #4,SP
    rts

; ResetButtonRepeatState — D0=val.
c_reset_button_repeat_state:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z02_reset_button_repeat_state
    addq.l  #4,SP
    rts

; ModeE_SetNameCursorSpriteX — void→void.
c_mode_e_set_name_cursor_sprite_x:
    jmp     z02_mode_e_set_name_cursor_sprite_x

; IncSubmode — void→void.
c_inc_submode:
    jmp     z05_inc_submode

; Inc2Submodes — void→void.
c_inc_2_submodes:
    jmp     z05_inc_2_submodes

; InitMode4_GoToSub0 — void→void.
c_init_mode4_go_to_sub0:
    jmp     z05_init_mode4_go_to_sub0

;==============================================================================
; EXPORT side — batch 14.
;==============================================================================

; UnhaltLink — void→void.
c_unhalt_link:
    jmp     z01_unhalt_link

; IncCaveState — void→void.
c_inc_cave_state:
    jmp     z01_inc_cave_state

; SetUpWhirlwind — D2=slot.
c_set_up_whirlwind:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_set_up_whirlwind
    addq.l  #4,SP
    rts

; IncSubphase — void→void.
c_inc_subphase:
    jmp     z02_inc_subphase

; Anim_SetObjHFlipForSpriteDescriptor — D2=slot.
c_anim_set_obj_hflip:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z07_anim_set_obj_hflip
    addq.l  #4,SP
    rts

; InitTektite — D2=slot.
c_init_tektite:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_init_tektite
    addq.l  #4,SP
    rts

; Ganon_RandomizeLocation — D2=slot.
c_ganon_randomize_location:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_ganon_randomize_location
    addq.l  #4,SP
    rts

;==============================================================================
; EXPORT side — batch 17.
;==============================================================================

; InitDigdogger1 — D2=slot.
c_init_digdogger1:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_init_digdogger1
    addq.l  #4,SP
    rts

; FetchProfileNameAddress — void→void.
c_fetch_profile_name_address:
    jmp     z02_fetch_profile_name_address

; Anim_SetSpriteDescriptorAttributes — D0=val.
c_anim_set_sprite_desc_attrs:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z01_anim_set_sprite_desc_attrs
    addq.l  #4,SP
    rts

;==============================================================================
; EXPORT side — batch 18.
;==============================================================================

; MapScreenPosToPpuAddr — void→void.
c_map_screen_pos_to_ppu_addr:
    jmp     z01_map_screen_pos_to_ppu_addr

; InitModeA_SubA_GoToMode4 — void→void.
c_init_mode_a_sub_a_go_to_mode4:
    jmp     z05_init_mode_a_sub_a_go_to_mode4

; UpdateModeDSave_Sub2 — void→void.
c_update_mode_d_save_sub2:
    jmp     z02_update_mode_d_save_sub2

; AnimateDemoPhase1End_AnimateObjects — void→void.
c_animate_demo_p1_end:
    jmp     z02_animate_demo_p1_end

;==============================================================================
; IMPORT side — batch 18 (C calls ASM).
;==============================================================================

; _sram_commit_save_slots — void→void (nes_io.asm).
c_import_sram_commit:
    jmp     _sram_commit_save_slots

; Demo_AnimateObjects — void→void (z_02.asm).
c_import_demo_animate_objects:
    jmp     Demo_AnimateObjects

;==============================================================================
; EXPORT side — batch 19.
;==============================================================================

; AnimateDemoPhase1Subphase3 — void→void.
c_animate_demo_p1_sub3:
    jmp     z02_animate_demo_p1_sub3

; Manhandla_SetAllSegmentsDirection — D0=val.
c_manhandla_set_all_segments_direction:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z04_manhandla_set_all_segments_direction
    addq.l  #4,SP
    rts

; ExtractHitPointValue — D0=val, returns D0.
c_extract_hit_point_value:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z04_extract_hit_point_value
    addq.l  #4,SP
    rts

; CopyColumnOrRowToTileBuf — void→void.
c_copy_column_or_row_to_tilebuf:
    jmp     z05_copy_column_or_row_to_tilebuf

; Walker_AltDir_GetMovingOppositeDir — void→D0 return.
c_walker_alt_dir_get_opposite:
    jsr     z07_walker_alt_dir_get_opposite
    rts

;==============================================================================
; EXPORT side — batch 20.
;==============================================================================

; Jumper_PointBoulderDownward — D2=slot.
c_jumper_point_boulder_downward:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_jumper_point_boulder_downward
    addq.l  #4,SP
    rts

; Flyer_Delay — D2=slot.
c_flyer_delay:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_flyer_delay
    addq.l  #4,SP
    rts

; ModeE_SyncCharBoardCursorToIndex — void→void.
c_mode_e_sync_char_board_cursor:
    jmp     z02_mode_e_sync_char_board_cursor

;==============================================================================
; EXPORT side — batch 21.
;==============================================================================

; PostCredit — D0=val.
c_post_credit:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z01_post_credit
    addq.l  #4,SP
    rts

; AddToInt16At0 — D0=val.
c_add_to_int16_at_0:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z01_add_to_int16_at_0
    addq.l  #4,SP
    rts

; AddToInt16At2 — D0=val.
c_add_to_int16_at_2:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z01_add_to_int16_at_2
    addq.l  #4,SP
    rts

; AddToInt16At4 — D0=val.
c_add_to_int16_at_4:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z01_add_to_int16_at_4
    addq.l  #4,SP
    rts

; AddATo0F0E — D0=val.
c_add_a_to_0f0e:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z02_add_a_to_0f0e
    addq.l  #4,SP
    rts

; AddAToCFCE — D0=val.
c_add_a_to_cfce:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z02_add_a_to_cfce
    addq.l  #4,SP
    rts

; Cycle9InDirection — D3 in, D3 out.
c_cycle9_in_direction:
    moveq   #0,D0
    move.b  D3,D0
    move.l  D0,-(SP)
    jsr     z05_cycle9_in_direction
    addq.l  #4,SP
    move.b  D0,D3
    rts

;==============================================================================
; EXPORT side — batch 22: C→C chain functions.
;==============================================================================

; EndInitFlyer — D2=slot.
c_end_init_flyer:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_end_init_flyer
    addq.l  #4,SP
    rts

; InitDigdogger2 — D2=slot.
c_init_digdogger2:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_init_digdogger2
    addq.l  #4,SP
    rts

; UpdateDodongoState1_Bloated_Sub_End — D2=slot.
c_update_dodongo_bloated_sub_end:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_update_dodongo_bloated_sub_end
    addq.l  #4,SP
    rts

; SetUpFairyObject — D2=slot.
c_set_up_fairy_object:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_set_up_fairy_object
    addq.l  #4,SP
    rts

; ResetShoveInfoAndInvincibilityTimer — D2=slot. Fixes D0 clobber bug.
c_reset_shove_info_and_inv_timer:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_reset_shove_info_and_inv_timer
    addq.l  #4,SP
    rts

;==============================================================================
; EXPORT side — batch 23: simple leaf functions.
;==============================================================================

; ResetPushTimer — D2=slot.
c_reset_push_timer:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_reset_push_timer
    addq.l  #4,SP
    rts

; SetDeadDummyObjType — D2=slot.
c_set_dead_dummy_obj_type:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_set_dead_dummy_obj_type
    addq.l  #4,SP
    rts

; Jumper_ResetVSpeedFrac — D2=slot.
c_jumper_reset_vspeed_frac:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_jumper_reset_vspeed_frac
    addq.l  #4,SP
    rts

; UpdatePersonState_ResetCharOffset — no-arg.
c_update_person_reset_char_offset:
    jsr     z01_update_person_state_reset_char_offset
    rts

; BeginUpdateMode — no-arg.
c_begin_update_mode:
    jsr     z01_begin_update_mode
    rts

; TriggerOpenDoor — D0=val.
c_trigger_open_door:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z05_trigger_open_door
    addq.l  #4,SP
    rts

; UpdateMode11Death_Sub6 — no-arg, C→C chain to inc_submode.
c_update_mode11_death_sub6:
    jsr     z05_update_mode11_death_sub6
    rts

; InitLinkSpeed — no-arg, void.
c_init_link_speed:
    jsr     z05_init_link_speed
    rts

; InitFluteSecret — D2=slot, C→C chain.
c_init_flute_secret:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z07_init_flute_secret
    addq.l  #4,SP
    rts

; ResetObjMetastateAndTimer — D2=slot, C→C chain.
c_reset_obj_metastate_and_timer:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z07_reset_obj_metastate_and_timer
    addq.l  #4,SP
    rts

;==============================================================================
; EXPORT side — batch 24.
;==============================================================================

; CueTransferBufAndAdvanceState — D0=val, C→C chain to inc_cave_state.
c_cue_transfer_buf_advance_state:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z01_cue_transfer_buf_and_advance_state
    addq.l  #4,SP
    rts

; TakeOneRupee — no-arg.
c_take_one_rupee:
    jsr     z01_take_one_rupee
    rts

; SetItemValue — D0=val, D3=slot3.
c_set_item_value:
    moveq   #0,D1
    move.w  D3,D1
    move.l  D1,-(SP)
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z01_set_item_value
    addq.l  #8,SP
    rts

; InitWhirlwind — D0=val, D2=slot.
c_init_whirlwind:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z01_init_whirlwind
    addq.l  #8,SP
    rts

; L_Gleeok_SetSegmentY — D3=val, D2=slot.
c_gleeok_set_segment_y:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    moveq   #0,D0
    move.b  D3,D0
    move.l  D0,-(SP)
    jsr     z04_gleeok_set_segment_y
    addq.l  #8,SP
    rts

; ResetVScrollLo — no-arg, C→C chain to inc_submode.
c_reset_vscroll_lo:
    jsr     z05_reset_vscroll_lo
    rts

; DeactivateShot — D2=slot.
c_deactivate_shot:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z07_deactivate_shot
    addq.l  #4,SP
    rts

; DeactivateLinkShot — no-arg (hardcodes slot 14).
c_deactivate_link_shot:
    jsr     z07_deactivate_link_shot
    rts

;==============================================================================
; EXPORT side — batch 25.
;==============================================================================

; Walker_AltDir_EndLoop — no-arg.
c_walker_alt_dir_end_loop:
    jsr     z07_walker_alt_dir_end_loop
    rts

; ResetShoveInfo — D2=slot, C→C.
c_reset_shove_info:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z07_reset_shove_info
    addq.l  #4,SP
    rts

; GoToNextMode — no-arg, C→C.
c_go_to_next_mode:
    jsr     z07_go_to_next_mode
    rts

; Add1ToInt16At2 — no-arg, C→C.
c_add1_to_int16_at_2:
    jsr     z01_add1_to_int16_at_2
    rts

; Add1ToInt16At4 — no-arg, C→C.
c_add1_to_int16_at_4:
    jsr     z01_add1_to_int16_at_4
    rts

; UpdatePersonState_CueTransferBlankPersonWares — no-arg, C→C.
c_cue_transfer_blank_person_wares:
    jsr     z01_cue_transfer_blank_person_wares
    rts

; Take5Rupees — no-arg, loop.
c_take_5_rupees:
    jsr     z01_take_5_rupees
    rts

; InitMonsterShot — D2=slot.
c_init_monster_shot:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_init_monster_shot
    addq.l  #4,SP
    rts

; InitBoulder — D2=slot, C→C chain.
c_init_boulder:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_init_boulder
    addq.l  #4,SP
    rts

; InitBoulderSet — D2=slot, C→C chain.
c_init_boulder_set:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_init_boulder_set
    addq.l  #4,SP
    rts

;==============================================================================
; EXPORT side — batch 26.
;==============================================================================

; GetOppositeDir — D0=dir in, D0=opposite dir out, D3=reverse index out.
; C returns packed (index<<8)|dir; shim unpacks to D0 and D3.
c_get_opposite_dir:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z01_get_opposite_dir
    addq.l  #4,SP
    move.l  D0,D1
    lsr.w   #8,D1
    move.b  D1,D3
    rts

; Abs — D0.b in, D0.b out (absolute value).
c_abs:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z01_abs
    addq.l  #4,SP
    rts

; Negate — D0.b in, D0.b out (two's complement).
c_negate:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z01_negate
    addq.l  #4,SP
    rts

;==============================================================================
; EXPORT side — batch 27.
;==============================================================================

; FindEmptyMonsterSlot — no args. Returns D3=slot (or 0), Z flag set if not found.
c_find_empty_monster_slot:
    jsr     z07_find_empty_monster_slot
    move.b  D0,D3
    rts

; DestroyMonster — D2=slot. Sets type to 0, clears object.
c_destroy_monster:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z07_destroy_monster
    addq.l  #4,SP
    rts

; SetTypeAndClearObject — D0=type, D2=slot.
c_set_type_and_clear_object:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z07_set_type_and_clear_object
    addq.l  #8,SP
    rts

; InitTileObjOrItem — D2=slot.
c_init_tile_obj_or_item:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z07_init_tile_obj_or_item
    addq.l  #4,SP
    rts

; Anim_AdvanceAnimCounterAndSetObjPosForSpriteDescriptor — D0=val, D2=slot.
c_anim_advance_and_fetch:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z07_anim_advance_and_fetch
    addq.l  #8,SP
    rts

; SetRoomFlagUWItemState — no args (uses RAM state from GetRoomFlags).
c_set_room_flag_uw_item_state:
    jsr     z01_set_room_flag_uw_item_state
    rts

; GetRoomFlagUWItemState — no args. Returns D0 = flags & 0x10.
c_get_room_flag_uw_item_state:
    jsr     z01_get_room_flag_uw_item_state
    rts

; PlayBossHitCryIfNeeded — D2=slot.
c_play_boss_hit_cry_if_needed:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_play_boss_hit_cry_if_needed
    addq.l  #4,SP
    rts

;==============================================================================
; EXPORT side — batch 28.
;==============================================================================

; PlayEffect — D0=val. ORs into RAM($0603).
c_play_effect:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z01_play_effect
    addq.l  #4,SP
    rts

; PlaySample — D0=val. ORs into RAM($0601).
c_play_sample:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z01_play_sample
    addq.l  #4,SP
    rts

; Flyer_SetFlyingState — D0=val, D2=slot.
c_flyer_set_flying_state:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z04_flyer_set_flying_state
    addq.l  #8,SP
    rts

; PlayBossDeathCryIfNeeded — D2=slot.
c_play_boss_death_cry_if_needed:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_play_boss_death_cry_if_needed
    addq.l  #4,SP
    rts

; SelectTransferBuf — D0=val.
c_select_transfer_buf:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z05_select_transfer_buf
    addq.l  #4,SP
    rts

; TouchDoorWall — no args. Sets RAM($0E) = $FF.
c_touch_door_wall:
    jsr     z05_touch_door_wall
    rts

;==============================================================================
; EXPORT side — batch 29.
;==============================================================================

; GoToNextModePlayLevelSong — no args, C→C chain.
c_go_to_next_mode_play_level_song:
    jsr     z07_go_to_next_mode_play_level_song
    rts

; GoToNextModeResetGridOffset — no args, C→C chain.
c_go_to_next_mode_reset_grid_offset:
    jsr     z07_go_to_next_mode_reset_grid_offset
    rts

; DestroyMonsterShot — D2=slot.
c_destroy_monster_shot:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_destroy_monster_shot
    addq.l  #4,SP
    rts

; DestroyCountedMonsterShot — D2=slot.
c_destroy_counted_monster_shot:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_destroy_counted_monster_shot
    addq.l  #4,SP
    rts

; PlayParryTune — no args, leaf.
c_play_parry_tune:
    jsr     z01_play_parry_tune
    rts

; --- batch 30 ---

; ReverseObjDir — D2=slot.
c_reverse_obj_dir:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z07_reverse_obj_dir
    addq.l  #4,SP
    rts

; PatchAndCueLevelPalettesTransferAndAdvanceSubmode — no args.
c_patch_and_cue_level_palettes_transfer:
    jsr     z07_patch_and_cue_level_palettes_transfer
    rts

; Ganon_GetCurCloudBottom — D2=slot.
c_ganon_get_cur_cloud_bottom:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_ganon_get_cur_cloud_bottom
    addq.l  #4,SP
    rts

; Ganon_GetCurCloudRight — D2=slot.
c_ganon_get_cur_cloud_right:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_ganon_get_cur_cloud_right
    addq.l  #4,SP
    rts

; PolsVoice_MoveX — D2=slot.
c_pols_voice_move_x:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_pols_voice_move_x
    addq.l  #4,SP
    rts

; InitBlueKeese — D2=slot.
c_init_blue_keese:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_init_blue_keese
    addq.l  #4,SP
    rts

; InitRedOrBlackKeese — D2=slot.
c_init_red_or_black_keese:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_init_red_or_black_keese
    addq.l  #4,SP
    rts

; SelectTransferBufAndIncState — D0=val.
c_select_transfer_buf_and_inc_state:
    andi.l  #$FF,D0
    move.l  D0,-(SP)
    jsr     z05_select_transfer_buf_and_inc_state
    addq.l  #4,SP
    rts

; --- batch 31 ---

; DestroyMonster_Bank4 — D2=slot.
c_destroy_monster_bank4:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_destroy_monster_bank4
    addq.l  #4,SP
    rts

; Ganon_GetCurCloudLeft — D2=slot.
c_ganon_get_cur_cloud_left:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_ganon_get_cur_cloud_left
    addq.l  #4,SP
    rts

; Ganon_GetCurCloudTop — D2=slot.
c_ganon_get_cur_cloud_top:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_ganon_get_cur_cloud_top
    addq.l  #4,SP
    rts

; WriteBlankPrioritySprites — no args.
c_write_blank_priority_sprites:
    jsr     z01_write_blank_priority_sprites
    rts

; --- batch 32 ---

; Wallmaster_PrepareToDraw — D2=slot.
c_wallmaster_prepare_to_draw:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_wallmaster_prepare_to_draw
    addq.l  #4,SP
    rts

; GetPlayerCoordsForDirection — D0=dir.
c_get_player_coords_for_direction:
    andi.l  #$FF,D0
    move.l  D0,-(SP)
    jsr     z05_get_player_coords_for_direction
    addq.l  #4,SP
    rts

; CopyPriceListTemplate — no args.
c_copy_price_list_template:
    jsr     z01_copy_price_list_template
    rts

; --- batch 33 ---

; ShootFireball — D0=type, D2=source_slot.
c_shoot_fireball:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    andi.l  #$FF,D0
    move.l  D0,-(SP)
    jsr     z04_shoot_fireball
    addq.l  #8,SP
    rts

; ShootFireball55 — D2=source_slot.
c_shoot_fireball_55:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_shoot_fireball_55
    addq.l  #4,SP
    rts

; Gohma_SetSpriteAttributes — D2=slot.
c_gohma_set_sprite_attributes:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_gohma_set_sprite_attributes
    addq.l  #4,SP
    rts

; InitGohma — D2=slot.
c_init_gohma:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_init_gohma
    addq.l  #4,SP
    rts

; BlockAtWall — no args.
c_block_at_wall:
    jsr     z05_block_at_wall
    rts

; InitUnderworldPersonB — D2=slot.
c_init_underworld_person_b:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_init_underworld_person_b
    addq.l  #4,SP
    rts

;==============================================================================
; EXPORT side — carry-returning shims.
; Bit 8 of D0 = raw M68K carry. Extracted into CCR, then eori #$01,CCR
; reproduces the original function's carry normalization.
;==============================================================================

; CopyNextRowToTransferBuf — no args. Returns D0.b=row, carry in bit 8.
c_copy_next_row_to_transfer_buf:
    jsr     z05_copy_next_row_to_transfer_buf
    btst    #8,D0
    beq.s   .cc_cnr
    ori     #$01,CCR
    eori    #$01,CCR
    rts
.cc_cnr:
    andi    #$FE,CCR
    eori    #$01,CCR
    rts

; CopyNextRowToTransferBufAndAdvanceSubmodeWhenDone — no args. Carry-returning.
c_copy_next_row_advance_submode:
    jsr     z05_copy_next_row_advance_submode
    btst    #8,D0
    beq.s   .cc_cnras
    ori     #$01,CCR
    eori    #$01,CCR
    rts
.cc_cnras:
    andi    #$FE,CCR
    eori    #$01,CCR
    rts

; IsQuestSecretMismatch — no args. Returns carry in bit 8.
c_is_quest_secret_mismatch:
    jsr     z04_is_quest_secret_mismatch
    btst    #8,D0
    beq.s   .cc_iqsm
    ori     #$01,CCR
    eori    #$01,CCR
    rts
.cc_iqsm:
    andi    #$FE,CCR
    eori    #$01,CCR
    rts

; IsDistanceSafeToSpawn — D2=slot. Returns carry in bit 8.
c_is_distance_safe_to_spawn:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z05_is_distance_safe_to_spawn
    addq.l  #4,SP
    btst    #8,D0
    beq.s   .cc_idsts
    ori     #$01,CCR
    eori    #$01,CCR
    rts
.cc_idsts:
    andi    #$FE,CCR
    eori    #$01,CCR
    rts

;==============================================================================
; EXPORT side — batch 35 standard shims.
;==============================================================================

; CompareHeartsToContainers — no args. Returns D0.b = containers count.
c_compare_hearts_to_containers:
    jsr     z01_compare_hearts_to_containers
    rts

; UpdateUnderworldPersonComplexState_Begin — no args.
c_uw_person_complex_state_begin:
    jsr     z01_uw_person_complex_state_begin
    rts

; FormatCharDoublet — D0.b=character.
c_format_char_doublet:
    andi.l  #$FF,D0
    move.l  D0,-(SP)
    jsr     z01_format_char_doublet
    addq.l  #4,SP
    rts

; ResetCurSpriteIndex — no args. Returns D0=0.
c_reset_cur_sprite_index:
    jsr     z01_reset_cur_sprite_index
    rts

; SetFadeCycleAndAdvanceSubmode — D0.b=val.
c_set_fade_cycle_advance_submode:
    andi.l  #$FF,D0
    move.l  D0,-(SP)
    jsr     z05_set_fade_cycle_and_advance_submode
    addq.l  #4,SP
    rts

; SetMovingDirAndSwitchToPlayerSlot — D0.b=dir. Also sets D2=0.
c_set_moving_dir_switch_player:
    andi.l  #$FF,D0
    move.l  D0,-(SP)
    jsr     z05_set_moving_dir_and_switch_to_player_slot
    addq.l  #4,SP
    moveq   #0,D2
    rts

; Link_ModifyDirInDoorway — no args.
c_link_modify_dir_in_doorway:
    jsr     z05_link_modify_dir_in_doorway
    rts

; UpdateMode11Death_SubC — no args.
c_update_mode11_death_sub_c:
    jsr     z05_update_mode11_death_sub_c
    rts

; UpdateMode7Scroll_Sub6 — no args.
c_update_mode7_scroll_sub6:
    jsr     z05_update_mode7_scroll_sub6
    rts

;==============================================================================
; EXPORT side — batch 36: GetCollidableTile family.
;==============================================================================

; GetCollidableTile — D3=hotspot_offset, D2=slot. Returns D0.b=tile.
c_get_collidable_tile:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    moveq   #0,D0
    move.b  D3,D0
    move.l  D0,-(SP)
    jsr     z07_get_collidable_tile
    addq.l  #8,SP
    rts

; GetCollidableTileStill — D2=slot. Returns D0.b=tile.
c_get_collidable_tile_still:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z07_get_collidable_tile_still
    addq.l  #4,SP
    rts

; GetCollidingTileMoving — D2=slot. Returns D0.b=tile.
c_get_colliding_tile_moving:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z07_get_colliding_tile_moving
    addq.l  #4,SP
    rts

;==============================================================================
; EXPORT side — batch 37.
;==============================================================================

; PlayBoomerangSfx — D3=sfx_id.
c_play_boomerang_sfx:
    moveq   #0,D0
    move.b  D3,D0
    move.l  D0,-(SP)
    jsr     z01_play_boomerang_sfx
    addq.l  #4,SP
    rts

; TakeHeartsNoSound — no args, void return.
c_take_hearts_no_sound:
    jmp     z01_take_hearts_no_sound

; DoObjectsCollideWithThresholds — no explicit reg args (uses RAM temps).
; Returns D0.b = collision result.
c_do_objects_collide_with_thresholds:
    jsr     z01_do_objects_collide_with_thresholds
    rts

; InitUnderworldPersonC — D2=slot.
c_init_underworld_person_c:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_init_underworld_person_c
    addq.l  #4,SP
    rts

; InitGrumble_Full — D2=slot.
c_init_grumble_full:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_init_grumble_full
    addq.l  #4,SP
    rts

; InitRupeeStash_Full — D2=slot.
c_init_rupee_stash_full:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_init_rupee_stash_full
    addq.l  #4,SP
    rts

; InitMode13_Sub3 — no args, void return.
c_init_mode13_sub3:
    jmp     z02_init_mode13_sub3

; PolsVoice_GetCollidingTile — D2=slot. Returns carry in bit 8.
c_pols_voice_get_colliding_tile:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_pols_voice_get_colliding_tile
    addq.l  #4,SP
    btst    #8,D0
    beq.s   .cc_pvgct
    ori     #$01,CCR
    eori    #$01,CCR
    rts
.cc_pvgct:
    andi    #$FE,CCR
    eori    #$01,CCR
    rts

; Wizzrobe_GetBaseCollidableTile — D2=slot. Returns carry in bit 8.
c_wizzrobe_get_base_collidable_tile:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_wizzrobe_get_base_collidable_tile
    addq.l  #4,SP
    btst    #8,D0
    beq.s   .cc_wgbct
    ori     #$01,CCR
    eori    #$01,CCR
    rts
.cc_wgbct:
    andi    #$FE,CCR
    eori    #$01,CCR
    rts

; InitGleeokHead — D2=slot.
c_init_gleeok_head:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_init_gleeok_head
    addq.l  #4,SP
    rts

; Ganon_ActivateRoomItem — no args, void return.
c_ganon_activate_room_item:
    jmp     z04_ganon_activate_room_item

; Shoot — no explicit reg args (reads RAM temps). Returns carry=1 always.
c_shoot:
    jsr     z04_shoot
    btst    #8,D0
    beq.s   .cc_shoot
    ori     #$01,CCR
    rts
.cc_shoot:
    andi    #$FE,CCR
    rts

; CueTransferPlayAreaAttrsHalfAndAdvanceSubmode — D2=ppu_hi, D0=ppu_lo, D3=end_off.
c_cue_transfer_play_area_attrs_half_and_advance_submode:
    moveq   #0,D1
    move.b  D3,D1
    move.l  D1,-(SP)
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    moveq   #0,D1
    move.b  D2,D1
    move.l  D1,-(SP)
    jsr     z05_cue_transfer_play_area_attrs_half_and_advance_submode
    lea     12(SP),SP
    rts

; UpdateMode11Death_Sub2 — no args, void return.
c_update_mode11_death_sub2:
    jmp     z05_update_mode11_death_sub2

; InitMode10 — no args, void return.
c_init_mode10:
    jmp     z05_init_mode10

; SetupTileObjectOW — no args, void return.
c_setup_tile_object_ow:
    jmp     z05_setup_tile_object_ow

; World_FillHearts — no args, void return.
c_world_fill_hearts:
    jmp     z05_world_fill_hearts

; UpdateUnderworldPersonLifeOrMoneyState_0 — no args, void return.
c_update_uw_person_life_or_money_state_0:
    jmp     z01_update_uw_person_life_or_money_state_0

; UnderworldPerson_DestroyIfTaken — D2=slot.
c_underworld_person_destroy_if_taken:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_underworld_person_destroy_if_taken
    addq.l  #4,SP
    rts

; InitUnderworldPersonLifeOrMoney_Full — D2=slot.
c_init_uw_person_life_or_money_full:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_init_uw_person_life_or_money_full
    addq.l  #4,SP
    rts

; L_Person_FlagItemTakenAndAdvanceState — no args, void return.
c_person_flag_item_taken_and_advance_state:
    jmp     z01_person_flag_item_taken_and_advance_state

; CheckPersonBlocking — no args, void return.
c_check_person_blocking:
    jmp     z01_check_person_blocking

; InitDemoSubphasePlayTitleSong — no args, void return.
c_init_demo_subphase_play_title_song:
    jmp     z02_init_demo_subphase_play_title_song

; InitDemoSubphaseTransferTitlePalette — no args, void return.
c_init_demo_subphase_transfer_title_palette:
    jmp     z02_init_demo_subphase_transfer_title_palette

; InitDemoSubphaseTransferStoryPalette — no args, void return.
c_init_demo_subphase_transfer_story_palette:
    jmp     z02_init_demo_subphase_transfer_story_palette

; AnimateDemoPhase1Subphase4 — no args, void return.
c_animate_demo_phase1_subphase4:
    jmp     z02_animate_demo_phase1_subphase4

; UpdateSpritesForWaterfallCrest — no args, void return.
c_update_sprites_for_waterfall_crest:
    jmp     z02_update_sprites_for_waterfall_crest

; UpdateSpritesForWaterfallWave — D2=wave_idx, void return.
c_update_sprites_for_waterfall_wave:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z02_update_sprites_for_waterfall_wave
    addq.l  #4,SP
    rts

; UpdateWaterfallAnimation — no args, void return.
c_update_waterfall_animation:
    jmp     z02_update_waterfall_animation

; InitMode13_Sub4 — no args, void return.
c_init_mode13_sub4:
    jmp     z02_init_mode13_sub4

; Flyer_KeeseDecideState — D2=slot.
c_flyer_keese_decide_state:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_flyer_keese_decide_state
    addq.l  #4,SP
    rts

; Flyer_PeahatDecideState — D2=slot.
c_flyer_peahat_decide_state:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_flyer_peahat_decide_state
    addq.l  #4,SP
    rts

; UpdateDodongoState2_Stunned — D2=slot.
c_update_dodongo_state2_stunned:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_update_dodongo_state2_stunned
    addq.l  #4,SP
    rts

; PolsVoice_IsSquareWalkable — D2=slot, carry-returning.
c_pols_voice_is_square_walkable:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_pols_voice_is_square_walkable
    addq.l  #4,SP
    btst    #8,D0
    bne.s   _c_pols_voice_is_square_walkable_set
    andi    #$FE,CCR
    eori    #$01,CCR
    rts
_c_pols_voice_is_square_walkable_set:
    ori     #$01,CCR
    eori    #$01,CCR
    rts

; ClearPricesCaveFlag — no args, void return.
c_clear_prices_cave_flag:
    jmp     z01_clear_prices_cave_flag

; UpdatePersonState_DelayThenHide — no args, void return.
c_update_person_state_delay_then_hide:
    jmp     z01_update_person_state_delay_then_hide

; InitPeahat — D2=slot.
c_init_peahat:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_init_peahat
    addq.l  #4,SP
    rts

; UpdateMenuCommon2 — no args, void return.
c_update_menu_common2:
    jmp     z05_update_menu_common2

; UpdateMenuCommon3 — no args, void return.
c_update_menu_common3:
    jmp     z05_update_menu_common3

; UpdateMenuCommon4 — no args, void return.
c_update_menu_common4:
    jmp     z05_update_menu_common4

; UpdateMenu5OW — no args, void return.
c_update_menu5_ow:
    jmp     z05_update_menu5_ow

; L1433A_IncSubmode — no args, void return.
c_l1433a_inc_submode:
    jmp     z05_l1433a_inc_submode

; InitMode7_Finish — no args, void return.
c_init_mode7_finish:
    jmp     z05_init_mode7_finish

; --- batch 40 ---

; UpdatePersonState_DoNothing — no args, void return.
c_update_person_state_do_nothing:
    jmp     z01_update_person_state_do_nothing

; UpdateCavePersonState_DoNothing — no args, void return.
c_update_cave_person_state_do_nothing:
    jmp     z01_update_cave_person_state_do_nothing

; InitUnderworldPerson_DoNothing — no args, void return.
c_init_underworld_person_do_nothing:
    jmp     z01_init_underworld_person_do_nothing

; UpdateGrumble1 — no args, void return.
c_update_grumble1:
    jmp     z01_update_grumble1

; InitPondFairy — D2=slot.
c_init_pond_fairy:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_init_pond_fairy
    addq.l  #4,SP
    rts

; InitDodongo — D2=slot.
c_init_dodongo:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_init_dodongo
    addq.l  #4,SP
    rts

; SwitchToNT1 — no args, void return.
c_switch_to_nt1:
    jmp     z05_switch_to_nt1

; UpdateMode11Death_SetTimerIncSubmode — D0=val.
c_update_mode11_death_set_timer_inc_submode:
    andi.l  #$FF,D0
    move.l  D0,-(SP)
    jsr     z05_update_mode11_death_set_timer_inc_submode
    addq.l  #4,SP
    rts

; UpdateMode11Death_Sub4 — no args, void return.
c_update_mode11_death_sub4:
    jmp     z05_update_mode11_death_sub4

; UpdateMode11Death_Sub5 — no args, void return.
c_update_mode11_death_sub5:
    jmp     z05_update_mode11_death_sub5

; UpdateMode11Death_Sub9 — no args, void return.
c_update_mode11_death_sub9:
    jmp     z05_update_mode11_death_sub9

; --- batch 41 ---

; Flyer_FairyDecideState — D2=slot.
c_flyer_fairy_decide_state:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_flyer_fairy_decide_state
    addq.l  #4,SP
    rts

; Add1ToInt16At0 — no args, returns low byte in D0.
c_add1_to_int16_at_0:
    jsr     z01_add1_to_int16_at_0
    rts

; CheckBossHitReaction — D2=slot, void.
c_check_boss_hit_reaction:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_check_boss_hit_reaction
    addq.l  #4,SP
    rts

; Anim_SetSpriteDescriptorLevelPaletteRow — no args, void.
c_anim_set_sprite_desc_level_palette_row:
    jmp     z04_anim_set_sprite_desc_level_palette_row

; DeferBounce — D2=slot, D3=dir_idx, void.
c_defer_bounce:
    moveq   #0,D1
    move.w  D3,D1
    move.l  D1,-(SP)        ; arg2: dir_idx
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)        ; arg1: slot
    jsr     z04_defer_bounce
    addq.l  #8,SP
    rts

; Flyer_DoNothing — void, no args.
c_flyer_do_nothing:
    jmp     z04_flyer_do_nothing

; Flyer_GhiniDecideState — D2=slot, void.
c_flyer_ghini_decide_state:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_flyer_ghini_decide_state
    addq.l  #4,SP
    rts

; Flyer_GleeokHeadDecideState — D2=slot, void.
c_flyer_gleeok_head_decide_state:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_flyer_gleeok_head_decide_state
    addq.l  #4,SP
    rts

; Flyer_MoldormDecideState — D2=slot, void.
c_flyer_moldorm_decide_state:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_flyer_moldorm_decide_state
    addq.l  #4,SP
    rts

; Flyer_PatraDecideState — D2=slot, void.
c_flyer_patra_decide_state:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_flyer_patra_decide_state
    addq.l  #4,SP
    rts

; DoNothing (z07) — void, no args.
c_do_nothing_z07:
    jmp     z07_do_nothing

; Walker_AltDir_GetRandomObjPerpendicularDir — D2=slot, returns dir in D0.
c_walker_alt_dir_get_random_perpendicular:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z07_walker_alt_dir_get_random_perpendicular
    addq.l  #4,SP
    rts

; Flyer_CompareMaxSpeed — D0=speed (byte), D2=slot, void.
c_flyer_compare_max_speed:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    jsr     z04_flyer_compare_max_speed
    addq.l  #8,SP
    rts

; InitGrumble (z07 wrapper) — D2=slot, void.
c_init_grumble_z07:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z07_init_grumble
    addq.l  #4,SP
    rts

; InitRupeeStash (z07 wrapper) — D2=slot, void.
c_init_rupee_stash_z07:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z07_init_rupee_stash
    addq.l  #4,SP
    rts

; InitMode3Sub1 (z07) — no args, void.
c_init_mode3_sub1_z07:
    jsr     z07_init_mode3_sub1
    rts

; --- batch 46 ---

; GleeokIgnoreSegment — no args, void no-op.
c_gleeok_ignore_segment:
    jmp     z04_gleeok_ignore_segment

; GleeokContractSegmentX — D2=slot, void.
c_gleeok_contract_segment_x:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_gleeok_contract_segment_x
    addq.l  #4,SP
    rts

; GleeokContractSegmentY — D2=slot, void.
c_gleeok_contract_segment_y:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_gleeok_contract_segment_y
    addq.l  #4,SP
    rts

; IsDarkRoom_Bank4 — D3=room_idx, returns D0.
c_is_dark_room_bank4:
    moveq   #0,D0
    move.w  D3,D0
    move.l  D0,-(SP)
    jsr     z04_is_dark_room_bank4
    addq.l  #4,SP
    rts

; DecSubmenuScroll — no args, void.
c_dec_submenu_scroll:
    jsr     z05_dec_submenu_scroll
    rts

; --- batch 47 ---

; Flyer_SlowDown — D2=slot, void.
c_flyer_slow_down:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_flyer_slow_down
    addq.l  #4,SP
    rts

; Flyer_SpeedUp — D2=slot, void.
c_flyer_speed_up:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_flyer_speed_up
    addq.l  #4,SP
    rts

; SetFlyingState1 — D2=slot, void.
c_set_flying_state_1:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_set_flying_state_1
    addq.l  #4,SP
    rts

; --- batch 48 ---

; GleeokContractSegment — D2=slot, void.
c_gleeok_contract_segment:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_gleeok_contract_segment
    addq.l  #4,SP
    rts

; --- batch 49 ---

; TakeHearts — no args, void.
c_take_hearts:
    jsr     z01_take_hearts
    rts

; BlockUntilTime — no args, void.
c_block_until_time:
    jsr     z05_block_until_time
    rts

; WieldNothing — no args, void return.
c_wield_nothing:
    jmp     z05_wield_nothing

; EndPrepareMode — no args, void return.
c_end_prepare_mode:
    jmp     z05_end_prepare_mode

; InitMode9_TransferAttrs — no args, void return.
c_init_mode9_transfer_attrs:
    jmp     z05_init_mode9_transfer_attrs

; StartFillingHearts — no args, void return.
c_start_filling_hearts:
    jmp     z05_start_filling_hearts

; InitModeB_Sub1 — no args, void return.
c_init_mode_b_sub1:
    jmp     z05_init_mode_b_sub1

; --- batch 42 — carry-returning z_05 secret trigger helpers ---

; CheckSecretTriggerNone — no args, always returns C=0.
c_check_secret_trigger_none:
    jsr     z05_check_secret_trigger_none
    btst    #8,D0
    beq.s   .cc_cstn
    ori     #$01,CCR
    eori    #$01,CCR
    rts
.cc_cstn:
    andi    #$FE,CCR
    eori    #$01,CCR
    rts

; TriggerShutters — no args, always returns C=1.
c_trigger_shutters:
    jsr     z05_trigger_shutters
    btst    #8,D0
    beq.s   .cc_ts
    ori     #$01,CCR
    eori    #$01,CCR
    rts
.cc_ts:
    andi    #$FE,CCR
    eori    #$01,CCR
    rts

; ReturnFalse — no args, always returns C=0.
c_return_false:
    jsr     z05_return_false
    btst    #8,D0
    beq.s   .cc_rf
    ori     #$01,CCR
    eori    #$01,CCR
    rts
.cc_rf:
    andi    #$FE,CCR
    eori    #$01,CCR
    rts

; CheckSecretTriggerAllDead — no args, carry return.
c_check_secret_trigger_all_dead:
    jsr     z05_check_secret_trigger_all_dead
    btst    #8,D0
    beq.s   .cc_cstad
    ori     #$01,CCR
    eori    #$01,CCR
    rts
.cc_cstad:
    andi    #$FE,CCR
    eori    #$01,CCR
    rts

; CheckSecretTriggerLastBoss — no args, carry return.
c_check_secret_trigger_last_boss:
    jsr     z05_check_secret_trigger_last_boss
    btst    #8,D0
    beq.s   .cc_cstlb
    ori     #$01,CCR
    eori    #$01,CCR
    rts
.cc_cstlb:
    andi    #$FE,CCR
    eori    #$01,CCR
    rts

; CheckSecretTriggerMoneyOrLife — no args, carry return.
c_check_secret_trigger_money_or_life:
    jsr     z05_check_secret_trigger_money_or_life
    btst    #8,D0
    beq.s   .cc_cstmol
    ori     #$01,CCR
    eori    #$01,CCR
    rts
.cc_cstmol:
    andi    #$FE,CCR
    eori    #$01,CCR
    rts

; CheckSecretTriggerBlockDoor — no args, carry return.
c_check_secret_trigger_block_door:
    jsr     z05_check_secret_trigger_block_door
    btst    #8,D0
    beq.s   .cc_cstbd
    ori     #$01,CCR
    eori    #$01,CCR
    rts
.cc_cstbd:
    andi    #$FE,CCR
    eori    #$01,CCR
    rts

; CheckSecretTriggerRingleader — no args, carry return.
c_check_secret_trigger_ringleader:
    jsr     z05_check_secret_trigger_ringleader
    btst    #8,D0
    beq.s   .cc_cstrl
    ori     #$01,CCR
    eori    #$01,CCR
    rts
.cc_cstrl:
    andi    #$FE,CCR
    eori    #$01,CCR
    rts

; TouchDoorOpen — no args, no carry (void).
c_touch_door_open:
    jmp     z05_touch_door_open

; TouchDoorBombable — no args, void.
c_touch_door_bombable:
    jsr     z05_touch_door_bombable
    rts

; --- batch 50 ---

; InitMode3_Sub2 — no args, void.
c_init_mode3_sub2:
    jsr     z05_init_mode3_sub2
    rts

; InitMode3_Sub6 — no args, void.
c_init_mode3_sub6:
    jsr     z05_init_mode3_sub6
    rts

; InitMode3_Sub7 — no args, void.
c_init_mode3_sub7:
    jsr     z05_init_mode3_sub7
    rts

; UpdateMode12EndLevel_Sub1 — no args, void.
c_update_mode12_end_level_sub1:
    jsr     z05_update_mode12_end_level_sub1
    rts

; --- batch 51 ---

; InitModeA_Sub1 — no args, void.
c_init_mode_a_sub1:
    jsr     z05_init_mode_a_sub1
    rts

; EndGameMode12 — no args, void.
c_end_game_mode12:
    jsr     z05_end_game_mode12
    rts

; TouchDoorShutter — no args, void.
c_touch_door_shutter:
    jsr     z05_touch_door_shutter
    rts

; SaveKillCountOW — D3=slot.
c_save_kill_count_ow:
    moveq   #0,D0
    move.w  D3,D0
    move.l  D0,-(SP)
    jsr     z05_save_kill_count_ow
    addq.l  #4,SP
    rts

; --- batch 52 ---

; CueTransferPlayAreaAttrsHalfAndAdvanceSubmodeNT0 — no args. NT offset=35 fixed.
; Delegates to z05_cue_transfer_play_area_attrs_half_and_advance_submode(35, D0, D3).
c_cue_transfer_play_area_attrs_half_nt0:
    moveq   #0,D1
    move.b  D3,D1
    move.l  D1,-(SP)
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    move.l  #35,-(SP)
    jsr     z05_cue_transfer_play_area_attrs_half_and_advance_submode
    lea     12(SP),SP
    rts

; InitLeever — D2=slot, void.
c_init_leever:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_init_leever
    addq.l  #4,SP
    rts

; TouchDoorFalse — no args, carry-returning.
c_touch_door_false:
    jsr     z05_touch_door_false
    btst    #8,D0
    beq.s   .cc_tdf
    ori     #$01,CCR
    eori    #$01,CCR
    rts
.cc_tdf:
    andi    #$FE,CCR
    eori    #$01,CCR
    rts

; --- batch 53 ---

; CheckInitWhirlwindAndBeginUpdate — no args, void.
c_check_init_whirlwind_and_begin_update:
    jsr     z01_check_init_whirlwind_and_begin_update
    rts

; UpdateDodongoState1_Bloated_Sub_Die — D2=slot.
c_update_dodongo_state1_bloated_sub_die:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_update_dodongo_state1_bloated_sub_die
    addq.l  #4,SP
    rts

; --- batch 54 ---

; InitWalker — D2=slot, void.
c_init_walker:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_init_walker
    addq.l  #4,SP
    rts

; InitBubble — D2=slot, void.
c_init_bubble:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_init_bubble
    addq.l  #4,SP
    rts

; InitRope — D2=slot, void.
c_init_rope:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_init_rope
    addq.l  #4,SP
    rts

; InitDarknut — D2=slot, void.
c_init_darknut:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_init_darknut
    addq.l  #4,SP
    rts

; InitSlowOctorockOrGhini — D2=slot, void.
c_init_slow_octorock_or_ghini:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_init_slow_octorock_or_ghini
    addq.l  #4,SP
    rts

; InitFastOctorock — D2=slot, void.
c_init_fast_octorock:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_init_fast_octorock
    addq.l  #4,SP
    rts

; InitMode3_Sub3_TransferTopHalfAttrs — no args, void.
c_init_mode3_sub3:
    jsr     z05_init_mode3_sub3
    rts

; InitMode3_Sub4_TransferBottomHalfAttrs — no args, void.
c_init_mode3_sub4:
    jsr     z05_init_mode3_sub4
    rts

; InitMode3_Sub5 — no args, void.
c_init_mode3_sub5:
    jsr     z05_init_mode3_sub5
    rts

; --- batch 55 ---

; AdvanceTeleportingLevelIndex — no args, void.
c_advance_teleporting_level_index:
    jsr     z01_advance_teleporting_level_index
    rts

; ReplaceGanonBrownPaletteRow — no args, void.
c_replace_ganon_brown_palette_row:
    jsr     z01_replace_ganon_brown_palette_row
    rts

; ReplaceGanonBluePaletteRow — no args, void.
c_replace_ganon_blue_palette_row:
    jsr     z01_replace_ganon_blue_palette_row
    rts

; ReplaceAshesPaletteRow — no args, void.
c_replace_ashes_palette_row:
    jsr     z01_replace_ashes_palette_row
    rts

; InitGel — D2=slot, void.
c_init_gel:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_init_gel
    addq.l  #4,SP
    rts

; --- batch 56 ---

; InitUnderworldPersonA — D2=slot, void.
c_init_underworld_person_a:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_init_underworld_person_a
    addq.l  #4,SP
    rts

; UpdateUnderworldPersonComplexState_SenseLink — no args, void.
c_update_uw_person_complex_state_sense_link:
    jsr     z01_update_uw_person_complex_state_sense_link
    rts

; UpdateUnderworldPersonLifeOrMoneyState_2 — no args, void.
c_update_uw_person_life_or_money_state_2:
    jsr     z01_update_uw_person_life_or_money_state_2
    rts

; --- batch 57 ---

; Person_CheckCollisions — D2=slot, void.
c_person_check_collisions:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_person_check_collisions
    addq.l  #4,SP
    rts

; DrawLifeOrMoneyItems — no args, void.
c_draw_life_or_money_items:
    jsr     z01_draw_life_or_money_items
    rts

; UpdateGrumble3 — no args, void.
c_update_grumble3:
    jsr     z01_update_grumble3
    rts

; UpdateGrumble_Full — D2=slot, void.
c_update_grumble_full:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_update_grumble_full
    addq.l  #4,SP
    rts

; UpdateUnderworldPerson_Full — D2=slot, void.
c_update_uw_person_full:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_update_uw_person_full
    addq.l  #4,SP
    rts

; UpdateUnderworldPersonComplex — D2=slot, void.
c_update_uw_person_complex:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_update_uw_person_complex
    addq.l  #4,SP
    rts

; UpdateUnderworldPersonLifeOrMoney_Full — D2=slot, void.
c_update_uw_person_life_or_money_full:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_update_uw_person_life_or_money_full
    addq.l  #4,SP
    rts

; Person_DrawAndCheckCollisions — D2=slot, void.
c_person_draw_and_check_collisions:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_person_draw_and_check_collisions
    addq.l  #4,SP
    rts

; C→ASM import bridges (batch 57):

; CheckMonsterCollisions — C-callable, slot from stack → D2.
c_check_monster_collisions:
    move.l  4(SP),D2
    jsr     z01_check_monster_collisions
    rts

; AnimateItemObject — C-callable, (item_type, slot) from stack → (D0, D2).
c_animate_item_object:
    move.l  4(SP),D0
    move.l  8(SP),D2
    jsr     AnimateItemObject
    rts

; DrawObjectMirrored — C-callable, slot from stack → D2. Tail call.
c_draw_object_mirrored:
    move.l  4(SP),D2
    jmp     DrawObjectMirrored

; DrawObjectNotMirrored — C-callable, slot from stack → D2. Tail call.
c_draw_object_not_mirrored:
    move.l  4(SP),D2
    jmp     DrawObjectNotMirrored

; Link_EndMoveAndAnimate_Bank1 — C-callable, no args.
c_link_end_move_and_animate_bank1:
    jsr     Link_EndMoveAndAnimate_Bank1
    rts

; UpdatePersonState_Textbox — export-side shim (batch 58: now C).
c_update_person_state_textbox:
    jsr     z01_update_person_state_textbox
    rts

; --- batch 58 ---

; DrawCavePerson — D2=slot, void.
c_draw_cave_person:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_draw_cave_person
    addq.l  #4,SP
    rts

; DrawCaveItems — no args, void.
c_draw_cave_items:
    jsr     z01_draw_cave_items
    rts

; FormatDecimalByte — D0=val (export side; used as dummy stub target for DivideBy10 too).
c_format_decimal_byte:
    andi.l  #$FF,D0
    move.l  D0,-(SP)
    jsr     z01_format_decimal_byte
    addq.l  #4,SP
    rts

; WritePricesToDynamicTransferBuf — D0=price_char, void.
c_write_prices_to_dynamic_transfer_buf:
    andi.l  #$FF,D0
    move.l  D0,-(SP)
    jsr     z01_write_prices_to_dynamic_transfer_buf
    addq.l  #4,SP
    rts

; WritePricesTransferBuf — no args, void.
c_write_prices_transfer_buf:
    jsr     z01_write_prices_transfer_buf
    rts

; UpdateCavePersonState_TransferPrices — no args, void.
c_update_cave_person_state_transfer_prices:
    jsr     z01_update_cave_person_state_transfer_prices
    rts

; Link_EndMoveAndDraw_Bank1 — C-callable import bridge, no args.
c_link_end_move_and_draw_bank1:
    jsr     Link_EndMoveAndDraw_Bank1
    rts

; --- batch 59 ---

; UpdateCavePersonState_TalkOrShopOrDoorCharge — no args, void.
c_update_cave_person_state_talk_or_shop_or_door_charge:
    jsr     z01_update_cave_person_state_talk_or_shop_or_door_charge
    rts

; UpdateCavePersonState_HintOrMoneyGame — no args, void.
c_update_cave_person_state_hint_or_money_game:
    jsr     z01_update_cave_person_state_hint_or_money_game
    rts

; UpdateCavePerson — D2=slot, void.
c_update_cave_person:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_update_cave_person
    addq.l  #4,SP
    rts

; TakeItem — export-side shim (batch 62: now C).
c_take_item:
    move.l  4(SP),D0
    andi.l  #$FF,D0
    move.l  D0,-(SP)
    jsr     z01_take_item
    addq.l  #4,SP
    rts

; --- batch 60 ---

; FormatHeartsInTextBuf — D3=start_off, void.
c_format_hearts_in_text_buf:
    moveq   #0,D0
    move.b  D3,D0
    move.l  D0,-(SP)
    jsr     z01_format_hearts_in_text_buf
    addq.l  #4,SP
    rts

; CopyTripletToTextBuf — no args, void.
c_copy_triplet_to_text_buf:
    jsr     z01_copy_triplet_to_text_buf
    rts

; FormatDecimalCountByte — D0=val, void.
c_format_decimal_count_byte:
    andi.l  #$FF,D0
    move.l  D0,-(SP)
    jsr     z01_format_decimal_count_byte
    addq.l  #4,SP
    rts

; FormatDecimalCountByteInTextBuf — D0=val, D3=buf_offset, void.
c_format_decimal_count_byte_in_text_buf:
    moveq   #0,D1
    move.b  D3,D1
    move.l  D1,-(SP)
    andi.l  #$FF,D0
    move.l  D0,-(SP)
    jsr     z01_format_decimal_count_byte_in_text_buf
    addq.l  #8,SP
    rts

; FormatStatusBarText — no args, void.
c_format_status_bar_text:
    jsr     z01_format_status_bar_text
    rts

; WorldChangeRupees — no args, void.
c_world_change_rupees:
    jsr     z01_world_change_rupees
    rts

; --- batch 61 ---

; InitCave — D2=slot, void.
c_init_cave:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_init_cave
    addq.l  #4,SP
    rts

; TryTakeItem — D2=slot, void.
c_try_take_item:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_try_take_item
    addq.l  #4,SP
    rts

; TryTakeRoomItem — no args, void.
c_try_take_room_item:
    jsr     z01_try_take_room_item
    rts

; --- batch 63 ---

; BoundDirectionHorizontally — D2=slot, void.
c_bound_direction_horizontally:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_bound_direction_horizontally
    addq.l  #4,SP
    rts

; BoundDirectionVertically — D2=slot, void.
c_bound_direction_vertically:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_bound_direction_vertically
    addq.l  #4,SP
    rts

; BoundByRoom — D2=slot, returns D0.b = RAM[$0F] (0 if blocked).
c_bound_by_room:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_bound_by_room
    addq.l  #4,SP
    rts

; BoundByRoomWithA — D0=direction, D2=slot, returns D0.b = RAM[$0F].
c_bound_by_room_with_a:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    andi.l  #$FF,D0
    move.l  D0,-(SP)
    jsr     z01_bound_by_room_with_a
    addq.l  #8,SP
    rts

; AddQSpeedToPositionFraction — D2=slot. Returns carry in CCR (C=1 if advanced).
; ASM MoveObject_Right/Down consume this via `addx.b`, which reads CCR.X (bit 4).
; 6502 convention: X mirrors C. Set/clear both bits 0 (C) and 4 (X).
c_add_q_speed_to_position_fraction:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_add_q_speed_to_position_fraction
    addq.l  #4,SP
    btst    #8,D0
    beq.s   .cc_aqspf
    ori     #$11,CCR
    rts
.cc_aqspf:
    andi    #$EE,CCR
    rts

; SubQSpeedFromPositionFraction — D2=slot. Returns carry (C=0 if advanced).
; ASM MoveObject_Up/Left consume this via `subx.b` (reads CCR.X). Set X = C.
c_sub_q_speed_from_position_fraction:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_sub_q_speed_from_position_fraction
    addq.l  #4,SP
    btst    #8,D0
    beq.s   .cc_sqspf
    ori     #$11,CCR
    rts
.cc_sqspf:
    andi    #$EE,CCR
    rts

; MoveShot — D0=direction, D2=slot, void.
c_move_shot:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    andi.l  #$FF,D0
    move.l  D0,-(SP)
    jsr     z01_move_shot
    addq.l  #8,SP
    rts

; --- batch 64 ---

; GetOneDirectionAndDistanceToTarget — D0=target_coord, D3=origin_coord, returns D0=dist.
c_get_one_direction_and_distance_to_target:
    moveq   #0,D1
    move.b  D3,D1
    move.l  D1,-(SP)
    andi.l  #$FF,D0
    move.l  D0,-(SP)
    jsr     z01_get_one_direction_and_distance_to_target
    addq.l  #8,SP
    rts

; GetDirectionsAndDistancesToTarget — D0=target_slot, D2=origin_slot, void.
c_get_directions_and_distances_to_target:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    andi.l  #$FF,D0
    move.l  D0,-(SP)
    jsr     z01_get_directions_and_distances_to_target
    addq.l  #8,SP
    rts

; _CalcDiagonalSpeedIndex — D3=mid_speed_idx, returns D3=result.
c_calc_diagonal_speed_index:
    moveq   #0,D0
    move.b  D3,D0
    move.l  D0,-(SP)
    jsr     z01_calc_diagonal_speed_index
    addq.l  #4,SP
    moveq   #0,D3
    move.b  D0,D3
    rts

; PlaceWeapon — D0=offset, D2=slot, void.
c_place_weapon:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    andi.l  #$FF,D0
    move.l  D0,-(SP)
    jsr     z01_place_weapon
    addq.l  #8,SP
    rts

; PlaceWeaponForPlayerState — D2=slot, void.
c_place_weapon_for_player_state:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_place_weapon_for_player_state
    addq.l  #4,SP
    rts

; PlaceWeaponForPlayerStateAndAnim — D2=slot, void.
c_place_weapon_for_player_state_and_anim:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_place_weapon_for_player_state_and_anim
    addq.l  #4,SP
    rts

; PlaceWeaponForPlayerStateAndAnimAndWeaponState — D0=weapon_state, D2=slot, void.
c_place_weapon_for_player_state_and_anim_and_weapon_state:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    andi.l  #$FF,D0
    move.l  D0,-(SP)
    jsr     z01_place_weapon_for_player_state_and_anim_and_weapon_state
    addq.l  #8,SP
    rts

; Sub1FromInt16At4 — no args, carry-returning.
c_sub1_from_int16_at4:
    jsr     z01_sub1_from_int16_at4
    btst    #8,D0
    beq.s   .cc_s1i16
    ori     #$01,CCR
    rts
.cc_s1i16:
    andi    #$FE,CCR
    rts

; WieldBomb — D2=slot, void.
c_wield_bomb:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_wield_bomb
    addq.l  #4,SP
    rts

; WieldCandle — D2=slot, void (carry ignored by caller).
c_wield_candle:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_wield_candle
    addq.l  #4,SP
    rts

; GetShortcutOrItemXYForRoom — D3=room_id, returns D0=X(hi), D3=Y(lo).
c_get_shortcut_or_item_xy_for_room:
    moveq   #0,D0
    move.b  D3,D0
    move.l  D0,-(SP)
    jsr     z01_get_shortcut_or_item_xy_for_room
    addq.l  #4,SP
    move.b  D0,D3
    lsr.l   #8,D0
    rts

; GetShortcutOrItemXY — no args, returns D0=X, D3=Y.
c_get_shortcut_or_item_xy:
    jsr     z01_get_shortcut_or_item_xy
    move.b  D0,D3
    lsr.l   #8,D0
    rts

; GetObjectMiddle — D2=slot, void.
c_get_object_middle:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_get_object_middle
    addq.l  #4,SP
    rts

; AnimateWorldFading — no args, returns D0 (Z=1 if done).
c_animate_world_fading:
    jsr     z01_animate_world_fading
    tst.l   D0
    rts

; CheckMazes — no args, void.
c_check_mazes:
    jsr     z01_check_mazes
    rts

; CycleCurSpriteIndex — no args, void.
c_cycle_cur_sprite_index:
    jsr     z01_cycle_cur_sprite_index
    rts

; CycleSpriteIndexInA — D0=idx in, D0=new_idx out.
c_cycle_sprite_index_in_a:
    andi.l  #$FF,D0
    move.l  D0,-(SP)
    jsr     z01_cycle_sprite_index_in_a
    addq.l  #4,SP
    rts

; HideObjectSprites — no args, void (caller ignores carry).
c_hide_object_sprites:
    jsr     z01_hide_object_sprites
    rts

; ShowLinkSpritesBehindHorizontalDoors — no args, void (caller ignores carry).
c_show_link_sprites_behind_horizontal_doors:
    jsr     z01_show_link_sprites_behind_horizontal_doors
    rts

; L_PlayParrySoundForDamageType — no args, void.
c_play_parry_sound_for_damage_type:
    jsr     z01_play_parry_sound_for_damage_type
    rts

; HandleMonsterDied — D2=slot, void.
c_handle_monster_died:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_handle_monster_died
    addq.l  #4,SP
    rts

; DealDamage — D2=slot, void.
c_deal_damage:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z01_deal_damage
    addq.l  #4,SP
    rts

; HandleMonsterWeaponCollision — D2=monster_slot, D3=weapon_slot, void.
c_handle_monster_weapon_collision:
    move.l  D3,-(SP)
    move.l  D2,-(SP)
    jsr     z01_handle_monster_weapon_collision
    addq.l  #8,SP
    rts

; CheckMonsterWeaponCollision — D2=monster_slot, D0=weapon_y_mid, void.
c_check_monster_weapon_collision:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    move.l  D2,-(SP)
    jsr     z01_check_monster_weapon_collision
    addq.l  #8,SP
    rts

; CheckMonsterSlenderWeaponCollision2 — D2=monster_slot, void.
c_check_monster_slender_weapon_collision2:
    move.l  D2,-(SP)
    jsr     z01_check_monster_slender_weapon_collision2
    addq.l  #4,SP
    rts

; CheckMonsterSlenderWeaponCollision — D2=monster_slot, D0=damage_points, void.
c_check_monster_slender_weapon_collision:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    move.l  D2,-(SP)
    jsr     z01_check_monster_slender_weapon_collision
    addq.l  #8,SP
    rts

; CheckMonsterStabbingCollision — D2=monster_slot, D0=damage_points, void.
c_check_monster_stabbing_collision:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    move.l  D2,-(SP)
    jsr     z01_check_monster_stabbing_collision
    addq.l  #8,SP
    rts

; CheckMonsterSwordCollision — D2=monster_slot, D3=weapon_slot, void.
c_check_monster_sword_collision:
    move.l  D3,-(SP)
    move.l  D2,-(SP)
    jsr     z01_check_monster_sword_collision
    addq.l  #8,SP
    rts

; ParryOrShove — D2=monster_slot, D3=weapon_slot, void.
c_parry_or_shove:
    move.l  D3,-(SP)
    move.l  D2,-(SP)
    jsr     z01_parry_or_shove
    addq.l  #8,SP
    rts

; CheckMonsterShotCollision — D2=monster_slot, D3=weapon_slot, D0=damage_points, void.
c_check_monster_shot_collision:
    moveq   #0,D1
    move.b  D0,D1
    move.l  D1,-(SP)
    move.l  D3,-(SP)
    move.l  D2,-(SP)
    jsr     z01_check_monster_shot_collision
    add.l   #12,SP
    rts

; CheckMonsterArrowOrRodCollision — D2=monster_slot, D3=weapon_slot, void.
c_check_monster_arrow_or_rod_collision:
    move.l  D3,-(SP)
    move.l  D2,-(SP)
    jsr     z01_check_monster_arrow_or_rod_collision
    addq.l  #8,SP
    rts

; CheckMonsterBoomerangOrFoodCollision — D2=monster_slot, D3=weapon_slot, void.
c_check_monster_boomerang_or_food_collision:
    move.l  D3,-(SP)
    move.l  D2,-(SP)
    jsr     z01_check_monster_boomerang_or_food_collision
    addq.l  #8,SP
    rts

; c_call_begin_shove — C calls with (unsigned int monster_slot). Sets D2, tail-calls BeginShove.
c_call_begin_shove:
    move.l  4(SP),D2
    jmp     BeginShove

; c_call_gohma_handle_weapon_collision — C calls with (monster_slot, weapon_slot).
c_call_gohma_handle_weapon_collision:
    move.l  4(SP),D2
    move.l  8(SP),D3
    jmp     Gohma_HandleWeaponCollision

; CheckMonsterSwordShotOrMagicShotCollision — D2=monster_slot, D3=weapon_slot, void.
c_check_monster_sword_shot_or_magic_shot_collision:
    move.l  D3,-(SP)
    move.l  D2,-(SP)
    jsr     z01_check_monster_sword_shot_or_magic_shot_collision
    addq.l  #8,SP
    rts

; CheckMonsterBombOrFireCollision — D2=monster_slot, D3=weapon_slot, void.
c_check_monster_bomb_or_fire_collision:
    move.l  D3,-(SP)
    move.l  D2,-(SP)
    jsr     z01_check_monster_bomb_or_fire_collision
    addq.l  #8,SP
    rts

; c_call_handle_shot_blocked — C calls with (unsigned int weapon_slot). Sets D2, tail-calls HandleShotBlocked.
c_call_handle_shot_blocked:
    move.l  4(SP),D2
    jmp     HandleShotBlocked

; HarmLink — D2=monster_slot, void.
c_harm_link:
    move.l  D2,-(SP)
    jsr     z01_harm_link
    addq.l  #4,SP
    rts

; CheckLinkCollision — D2=monster_slot, void.
c_check_link_collision:
    move.l  D2,-(SP)
    jsr     z01_check_link_collision
    addq.l  #4,SP
    rts

; CheckLinkCollisionPreinit — D2=monster_slot, void.
c_check_link_collision_preinit:
    move.l  D2,-(SP)
    jsr     z01_check_link_collision_preinit
    addq.l  #4,SP
    rts



; BeginShove — D2=monster_slot, void.
c_begin_shove:
    move.l  D2,-(SP)
    jsr     z01_begin_shove
    addq.l  #4,SP
    rts

; Link_BeHarmed — D2=monster_slot, void.
c_link_be_harmed:
    move.l  D2,-(SP)
    jsr     z01_link_be_harmed
    addq.l  #4,SP
    rts

; CheckMonsterCollisions ASM stub → C export shim.
c_do_check_monster_collisions:
    move.l  D2,-(SP)
    jsr     z01_check_monster_collisions
    addq.l  #4,SP
    rts

; DoObjectsCollide — D0=threshold (byte), sets [0D]=[0E]=threshold then collide.
c_do_objects_collide:
    move.l  D0,-(SP)
    jsr     z01_do_objects_collide
    addq.l  #4,SP
    rts


; UpdateBombFlashEffect — D2=slot, void.
c_update_bomb_flash_effect:
    move.l  D2,-(SP)
    jsr     z01_update_bomb_flash_effect
    addq.l  #4,SP
    rts

; UpdatePositionMarker — D0=room_id (byte), D2=idx, void.
c_update_position_marker:
    move.l  D2,-(SP)
    move.l  D0,-(SP)
    jsr     z01_update_position_marker
    addq.l  #8,SP
    rts

; UpdatePlayerPositionMarker — no args, void.
c_update_player_position_marker:
    jsr     z01_update_player_position_marker
    rts

; UpdateWorldCurtainEffect — no args, void.
c_update_world_curtain_effect:
    jsr     z01_update_world_curtain_effect
    rts

; UpdateWorldCurtainEffect_Bank2 — no args, void.
c_update_world_curtain_effect_bank2:
    jsr     z01_update_world_curtain_effect_bank2
    rts

; FetchFileAAddressSet — no args, void.
c_fetch_file_a_address_set:
    jsr     z01_fetch_file_a_address_set
    rts

; CheckTileObjectsBlocking — no D2 slot arg (uses fixed range), void.
c_check_tile_objects_blocking:
    jsr     z01_check_tile_objects_blocking
    rts

; CheckPowerTriforceFanfare — no args, void.
c_check_power_triforce_fanfare:
    jsr     z01_check_power_triforce_fanfare
    rts

; --- batch 77 export shims ---

; InitTrap_Full(slot) — export: D2=slot
c_init_trap_full:
    move.l  D2,-(SP)
    move.l  4+4(SP),D2
    jsr     z01_init_trap_full
    move.l  (SP)+,D2
    rts

; DrawWhirlwind(slot) — export: D2=slot
c_draw_whirlwind:
    move.l  D2,-(SP)
    move.l  4+4(SP),D2
    jsr     z01_draw_whirlwind
    move.l  (SP)+,D2
    rts

; UpdateWhirlwind_Full(slot) — export: D2=slot
c_update_whirlwind_full:
    move.l  D2,-(SP)
    move.l  4+4(SP),D2
    jsr     z01_update_whirlwind_full
    move.l  (SP)+,D2
    rts

; SummonWhirlwind() — no args, void
c_summon_whirlwind:
    jsr     z01_summon_whirlwind
    rts

; UpdateRupeeStash_Full(slot) — export: D2=slot
c_update_rupee_stash_full:
    move.l  D2,-(SP)
    move.l  4+4(SP),D2
    jsr     z01_update_rupee_stash_full
    move.l  (SP)+,D2
    rts

; InitModeB_EnterCave_Bank5() — no args, void
c_init_mode_b_enter_cave_bank5:
    jsr     z01_init_mode_b_enter_cave_bank5
    rts

; CheckPassiveTileObjects() — no args, sets D2=0 on exit (ASM convention)
c_check_passive_tile_objects:
    jsr     z01_check_passive_tile_objects
    moveq   #0,D2
    rts

; --- batch 77 import shims (C-callable ASM wrappers) ---

; DrawObjectNotMirrored(frame, slot) — D0=frame, D2=slot, tail-call
c_draw_object_not_mirrored_with_frame:
    move.l  8(SP),D2
    move.l  4(SP),D0
    jmp     DrawObjectNotMirrored

; DrawItemInInventory(d2, d3) — D2=first arg, D3=second arg
c_draw_item_in_inventory:
    move.l  8(SP),D3
    move.l  4(SP),D2
    jsr     DrawItemInInventory
    rts

; GoToNextModeFromPlay() — no args, void
c_go_to_next_mode_from_play:
    jsr     GoToNextModeFromPlay
    rts

; InitMode_EnterRoom() — no args, void
c_init_mode_enter_room:
    jsr     InitMode_EnterRoom
    rts

; RunCrossRoomTasksAndBeginUpdateMode_PlayModesNoCellar() — no args, void
c_run_cross_room_tasks_no_cellar:
    jsr     RunCrossRoomTasksAndBeginUpdateMode_PlayModesNoCellar
    rts

; Link_EndMoveAndAnimate() — no args, void
c_link_end_move_and_animate:
    jsr     Link_EndMoveAndAnimate
    rts

; --- batch 78 export shims ---

; AnimateObjectWalking(slot) — D2=slot, no return value
c_animate_object_walking:
    move.l  D2,-(SP)
    move.l  4+4(SP),D2
    jsr     z07_animate_object_walking
    move.l  (SP)+,D2
    rts

; AnimateAndDrawCommonObject(val, slot) — ASM: D0=val, D2=slot
c_animate_and_draw_common_object:
    move.l  D2,-(SP)        ; save D2
    move.l  D2,-(SP)        ; push slot (arg2, pushed first = at SP+4 after jsr)
    move.l  D0,-(SP)        ; push val  (arg1, pushed last  = at SP+8 after jsr)
    ; wait — GCC right-to-left: arg2 pushed first, arg1 second
    ; before jsr: SP→[val | slot | D2_save | ret]
    ; after jsr:  SP→[callee_ret | val | slot | D2_save | ret]
    ;              SP+4=val=arg1, SP+8=slot=arg2 ✓
    jsr     z04_animate_and_draw_common_object
    addq.l  #8,SP           ; pop val+slot
    move.l  (SP)+,D2        ; restore D2
    rts

; UpdateTrap_Full(slot) — D2=slot
c_update_trap_full:
    move.l  D2,-(SP)
    move.l  4+4(SP),D2
    jsr     z01_update_trap_full
    move.l  (SP)+,D2
    rts

; --- batch 80 import shims (ASM wrappers callable from C) ---
; C ABI convention: after push D2 to save, SP+8=arg1, SP+12=arg2 (one-arg: SP+8=slot)

; ObjShove(slot) — D2=slot
c_obj_shove:
    move.l  D2,-(SP)
    move.l  8(SP),D2
    jsr     Obj_Shove
    move.l  (SP)+,D2
    rts

; WalkerMove(slot) — D2=slot
c_walker_move:
    move.l  D2,-(SP)
    move.l  8(SP),D2
    jsr     Walker_Move
    move.l  (SP)+,D2
    rts

; UpdateCommonWanderer(turn_rate, slot) — drained → forwards via z04_*
c_update_common_wanderer:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    moveq   #0,D1
    move.w  D0,D1
    move.l  D1,-(SP)
    jsr     z04_update_common_wanderer
    addq.l  #8,SP
    rts

; WandererTargetPlayer(slot) — drained → z04_*
c_wanderer_target_player:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_wanderer_target_player
    addq.l  #4,SP
    rts

; MoveFlyer(slot) — D2=slot
c_move_flyer:
    jmp     z04_move_flyer

; ControlKeeseFlight(slot) — D2=slot
c_control_keese_flight:
    move.l  D2,-(SP)
    move.l  8(SP),D2
    jsr     ControlKeeseFlight
    move.l  (SP)+,D2
    rts

; --- batch 80 export shims ---

; UpdateBubble(slot) — D2=slot
c_update_bubble:
    move.l  D2,-(SP)
    move.l  8(SP),D2
    jsr     z04_update_bubble
    move.l  (SP)+,D2
    rts

; UpdateKeese(slot) — D2=slot
c_update_keese:
    move.l  D2,-(SP)
    move.l  8(SP),D2
    jsr     z04_update_keese
    move.l  (SP)+,D2
    rts

; UpdateMoblin(slot) — D2=slot
c_update_moblin:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_update_moblin
    addq.l  #4,SP
    rts

; DrawObjectMirrored with explicit frame — (frame, slot): D0=frame, D2=slot
c_draw_object_mirrored_with_frame:
    move.l  8(SP),D2
    move.l  4(SP),D0
    jmp     DrawObjectMirrored

;==============================================================================
; BATCH 81 — UpdateStandingFire, UpdateZol, UpdateGel
;==============================================================================

    xref    z04_update_standing_fire
    xref    z04_update_zol
    xref    z04_update_gel

; Import shims — z_04.asm sub-functions callable from C (D2=slot, void).
; These export otherwise-private z_04 functions so C can call them.

; UpdateZolState — drained → z04_*
c_update_zol_state:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_update_zol_state
    addq.l  #4,SP
    rts

; Zol_CheckCollisions — drained → z04_*
c_zol_check_collisions:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_zol_check_collisions
    addq.l  #4,SP
    rts

; Gel_Move — drained → z04_*
c_gel_move:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_gel_move
    addq.l  #4,SP
    rts

; Gel_CheckCollisions — drained → z04_*
c_gel_check_collisions:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_gel_check_collisions
    addq.l  #4,SP
    rts

; ShootLimited — D2=slot in; ASM returns D3=child slot, C=success.
; C side: unsigned int c_shoot_limited(unsigned int slot);
;   returns (carry ? 0x100 : 0) | (child_slot & 0xFF) in D0.
    xref    ShootLimited
c_shoot_limited:
    move.l  D2,-(SP)        ; preserve D2
    move.l  D3,-(SP)        ; preserve D3 (ASM clobbers it)
    move.l  12(SP),D2       ; slot arg → D2
    jsr     ShootLimited
    moveq   #0,D0
    bcc.s   .csl_no_carry
    ori.l   #$100,D0
.csl_no_carry:
    move.b  D3,D0           ; low byte = new child slot
    move.l  (SP)+,D3
    move.l  (SP)+,D2
    rts

; Export shims — C functions exposed to ASM.
c_update_standing_fire:
    move.l  D2,-(SP)
    move.l  8(SP),D2
    jsr     z04_update_standing_fire
    move.l  (SP)+,D2
    rts

c_update_zol:
    move.l  D2,-(SP)
    move.l  8(SP),D2
    jsr     z04_update_zol
    move.l  (SP)+,D2
    rts

c_update_gel:
    move.l  D2,-(SP)
    move.l  8(SP),D2
    jsr     z04_update_gel
    move.l  (SP)+,D2
    rts

;==============================================================================
; BATCH 82 — UpdateZora, UpdateCandle, UpdateBoulderSet
;==============================================================================

    xref    z04_update_zora
    xref    z04_update_candle
    xref    z04_update_boulder_set
    xref    z04_update_rope

; Import shim: UpdateBurrower — D2=slot, void.
c_update_burrower:
    move.l  D2,-(SP)
    move.l  8(SP),D2
    jsr     UpdateBurrower
    move.l  (SP)+,D2
    rts

; Export shims.
c_update_zora:
    move.l  D2,-(SP)
    move.l  8(SP),D2
    jsr     z04_update_zora
    move.l  (SP)+,D2
    rts

; UpdateCandle takes no slot arg — just call C directly.
c_update_candle:
    jsr     z04_update_candle
    rts

c_update_boulder_set:
    move.l  D2,-(SP)
    move.l  8(SP),D2
    jsr     z04_update_boulder_set
    move.l  (SP)+,D2
    rts

;==============================================================================
; BATCH 83 — UpdateRope
;==============================================================================

c_update_rope:
    move.l  D2,-(SP)
    move.l  8(SP),D2
    jsr     z04_update_rope
    move.l  (SP)+,D2
    rts

;==============================================================================
; BATCH 84 — block-push family helper (IMPORT shim)
;==============================================================================

; ChangeTileObjTiles(tile, slot) — D0=tile (low byte), D2=slot.
; Used by enrt_update_block_0_idle / _1_moving in C land.
c_change_tile_obj_tiles:
    move.l  D2,-(SP)
    move.l  8(SP),D0    ; arg1 = tile (now SP+8 after push)
    move.l  12(SP),D2   ; arg2 = slot (now SP+12 after push)
    jsr     ChangeTileObjTiles
    move.l  (SP)+,D2
    rts

;==============================================================================
; BATCH 85 — Monster Shot / Fireball draw helpers (IMPORT shims: C calls ASM)
;==============================================================================

; DrawArrow — slot from C stack -> D2, tail-call ASM.
c_draw_arrow:
    move.l  4(SP),D2
    jmp     DrawArrow

; DrawSwordShotOrMagicShot — slot from C stack -> D2, tail-call ASM.
c_draw_sword_shot_or_magic_shot:
    move.l  4(SP),D2
    jmp     DrawSwordShotOrMagicShot

;==============================================================================
; BATCH 86 — z_04 drained entry shims (asm jmp c_<name> -> push slot -> jsr z04_)
;==============================================================================

; Block push family
c_update_block:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_update_block
    addq.l  #4,SP
    rts

c_draw_block:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_draw_block
    addq.l  #4,SP
    rts

; Monster shot / Fireball family
c_update_monster_shot:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_update_monster_shot
    addq.l  #4,SP
    rts

c_draw_shot:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_draw_shot
    addq.l  #4,SP
    rts

c_bounce_shot:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_bounce_shot
    addq.l  #4,SP
    rts

c_check_shot_link_collision:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_check_shot_link_collision
    addq.l  #4,SP
    rts

c_update_fireball:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_update_fireball
    addq.l  #4,SP
    rts

;==============================================================================
; BATCH 87 — Common Wanderer / Goriya family helper (IMPORT shim)
;==============================================================================

    xref    _ShootIfWanted

; ShootIfWanted(type, slot)
;   D0 = shot type (low byte), D2 = monster slot.
;   On success returns D0 = 0x100 | shot_slot, on failure returns D0 = 0.
;   Used by enrt_walker_set_input_dir_and_try_shooting_boomerang.
c_shoot_if_wanted:
    move.l  D2,-(SP)
    move.l  8(SP),D0        ; arg1 = type (after D2 push: SP+8)
    move.l  12(SP),D2       ; arg2 = slot
    jsr     _ShootIfWanted
    bcc.s   .csiw_fail
    moveq   #0,D0
    move.b  D3,D0           ; D0 = shot slot (low byte)
    ori.l   #$100,D0        ; D0 |= CARRY_SET
    bra.s   .csiw_done
.csiw_fail:
    moveq   #0,D0
.csiw_done:
    move.l  (SP)+,D2
    rts

;==============================================================================
; BATCH 88 — Gohma + Gleeok boss family helpers (IMPORT shims: C calls ASM)
;==============================================================================

    xref    ReverseObjDir8
    xref    Gohma_AnimateAndDraw
    xref    Gohma_CheckCollisions
    xref    Gleeok_DrawBody
    xref    Gleeok_FetchNeckAddrs
    xref    Gleeok_MoveNeck
    xref    Gleeok_MoveHead
    xref    Gleeok_DrawHeadAndCheckCollisions
    xref    Gleeok_DrawSegmentAndCheckCollisions
    xref    Gleeok_CalcSegmentLimits
    xref    Gleeok_StretchNeck

; ReverseObjDir8(slot) — D2=slot. Reverses ENEMY_DIR for an 8-direction object.
c_reverse_obj_dir8:
    move.l  D2,-(SP)
    move.l  8(SP),D2
    jsr     ReverseObjDir8
    move.l  (SP)+,D2
    rts

; Gohma_AnimateAndDraw(eye_frame, slot) — D0=eye frame image, D2=slot.
c_gohma_animate_and_draw:
    move.l  D2,-(SP)
    move.l  8(SP),D0       ; arg1 = eye_frame (after D2 push: SP+8)
    move.l  12(SP),D2      ; arg2 = slot
    jsr     Gohma_AnimateAndDraw
    move.l  (SP)+,D2
    rts

; Gohma_CheckCollisions(slot) — D2=slot.
c_gohma_check_collisions:
    move.l  D2,-(SP)
    move.l  8(SP),D2
    jsr     Gohma_CheckCollisions
    move.l  (SP)+,D2
    rts

; Gleeok_DrawBody — no args.
c_gleeok_draw_body:
    jsr     Gleeok_DrawBody
    rts

; Gleeok_FetchNeckAddrs — no register-arg input (reads RAM[$04D7]).
;   Side effect: writes neck-data pointers to RAM[$00..$05] and sets D3=5.
c_gleeok_fetch_neck_addrs:
    move.l  D2,-(SP)
    jsr     Gleeok_FetchNeckAddrs
    move.l  (SP)+,D2
    rts

; Gleeok_MoveNeck — no args; reads head/base coords from RAM, may JMP into
; L_Gleeok_StoreRefSegDistance (now drained; reachable via its trampoline).
c_gleeok_move_neck:
    move.l  D2,-(SP)
    jsr     Gleeok_MoveNeck
    move.l  (SP)+,D2
    rts

; Gleeok_MoveHead — no args.
c_gleeok_move_head:
    move.l  D2,-(SP)
    jsr     Gleeok_MoveHead
    move.l  (SP)+,D2
    rts

; Gleeok_DrawHeadAndCheckCollisions — no args (sets D2=5 internally).
c_gleeok_draw_head_and_check_collisions:
    move.l  D2,-(SP)
    jsr     Gleeok_DrawHeadAndCheckCollisions
    move.l  (SP)+,D2
    rts

; Gleeok_DrawSegmentAndCheckCollisions(slot) — D2=segment slot.
c_gleeok_draw_segment_and_check_collisions:
    move.l  D2,-(SP)
    move.l  8(SP),D2
    jsr     Gleeok_DrawSegmentAndCheckCollisions
    move.l  (SP)+,D2
    rts

; Gleeok_CalcSegmentLimits(primary_dist, axis) — D0=primary distance,
; D2=0 horizontal / 1 vertical. Writes 2nd & 3rd tier ref limits to RAM.
c_gleeok_calc_segment_limits:
    move.l  D2,-(SP)
    move.l  8(SP),D0
    move.l  12(SP),D2
    jsr     Gleeok_CalcSegmentLimits
    move.l  (SP)+,D2
    rts

; Gleeok_StretchNeck(slot) — D2=segment slot.
c_gleeok_stretch_neck:
    move.l  D2,-(SP)
    move.l  8(SP),D2
    jsr     Gleeok_StretchNeck
    move.l  (SP)+,D2
    rts

;==============================================================================
; BATCH 89 — Demo / intro mode dispatcher (IMPORT shims: C calls ASM).
; Used by the C ports of InitDemo_RunTasks / UpdateMode0Demo / AnimateDemo
; in src/frontend_runtime.c. Each subphase callee remains in z_02.asm.
;==============================================================================

    xdef    c_import_init_demo_subphase_clear_artifacts
    xdef    c_import_init_demo_subphase_transfer_title_palette
    xdef    c_import_init_demo_subphase_play_title_song
    xdef    c_import_init_demo_subphase_transfer_story_palette
    xdef    c_import_init_demo_subphase_transfer_story_tiles
    xdef    c_import_animate_demo_phase0_subphase0
    xdef    c_import_animate_demo_phase0_subphase1
    xdef    c_import_animate_demo_phase1_subphase0
    xdef    c_import_animate_demo_phase1_subphase1
    xdef    c_import_animate_demo_phase1_subphase2
    xdef    c_import_animate_demo_phase1_subphase3
    xdef    c_import_animate_demo_phase1_subphase4
    xdef    c_import_update_mode0_demo_sub1
    xdef    c_import_format_file_a

    xref    InitDemoSubphaseClearArtifacts
    xref    InitDemoSubphaseTransferTitlePalette
    xref    InitDemoSubphasePlayTitleSong
    xref    InitDemoSubphaseTransferStoryPalette
    xref    InitDemoSubphaseTransferStoryTiles
    xref    AnimateDemoPhase0Subphase0
    xref    AnimateDemoPhase0Subphase1
    xref    AnimateDemoPhase1Subphase0
    xref    AnimateDemoPhase1Subphase1
    xref    AnimateDemoPhase1Subphase2
    xref    AnimateDemoPhase1Subphase3
    xref    AnimateDemoPhase1Subphase4
    xref    UpdateMode0Demo_Sub1
    xref    FormatFileA

c_import_init_demo_subphase_clear_artifacts:
    jmp     InitDemoSubphaseClearArtifacts

c_import_init_demo_subphase_transfer_title_palette:
    jmp     InitDemoSubphaseTransferTitlePalette

c_import_init_demo_subphase_play_title_song:
    jmp     InitDemoSubphasePlayTitleSong

c_import_init_demo_subphase_transfer_story_palette:
    jmp     InitDemoSubphaseTransferStoryPalette

c_import_init_demo_subphase_transfer_story_tiles:
    jmp     InitDemoSubphaseTransferStoryTiles

c_import_animate_demo_phase0_subphase0:
    jmp     AnimateDemoPhase0Subphase0

c_import_animate_demo_phase0_subphase1:
    jmp     AnimateDemoPhase0Subphase1

c_import_animate_demo_phase1_subphase0:
    jmp     AnimateDemoPhase1Subphase0

c_import_animate_demo_phase1_subphase1:
    jmp     AnimateDemoPhase1Subphase1

c_import_animate_demo_phase1_subphase2:
    jmp     AnimateDemoPhase1Subphase2

c_import_animate_demo_phase1_subphase3:
    jmp     AnimateDemoPhase1Subphase3

c_import_animate_demo_phase1_subphase4:
    jmp     AnimateDemoPhase1Subphase4

c_import_update_mode0_demo_sub1:
    jmp     UpdateMode0Demo_Sub1

c_import_format_file_a:
    jmp     FormatFileA

;==============================================================================
; BATCH 90 — Save-menu / submenu dispatchers (IMPORT shims: C calls ASM).
; Used by the C ports of UpdateMenu / UpdateMenuAndMeters /
; UpdateMenuCommon1 / UpdateMenu5UW / UpdateMenuScrollDown* in
; src/save_menu_runtime.c. Each callee remains in z_05.asm or z_07.asm.
;==============================================================================

    xdef    c_move_position_markers
    xdef    c_update_triforce_position_marker
    xdef    c_update_hearts_and_rupees
    xdef    c_submenu_cue_transfer_row_uw
    xdef    c_submenu_cue_transfer_row_ow
    xdef    c_update_menu_active
    xdef    c_update_menu_scroll_up
    xdef    c_update_menu_start_ow
    xdef    c_update_goriya
    xdef    c_gel_move_splitting
    xdef    c_update_normal_zol_or_gel
    xdef    c_update_gohma
    xdef    c_update_gleeok
    xdef    c_l_gleeok_store_ref_seg_distance
    xdef    c_gleeok_check_collisions
    xdef    c_update_menu_and_meters
    xdef    c_update_menu
    xdef    c_update_menu_common1
    xdef    c_update_menu5_uw
    xdef    c_update_menu_scroll_down_ow
    xdef    c_update_menu_scroll_down_uw
    xdef    c_init_demo_run_tasks
    xdef    c_init_demo_phase1
    xdef    c_update_mode0_demo
    xdef    c_update_mode0_demo_sub0
    xdef    c_update_mode0_demo_sub2
    xdef    c_animate_demo
    xdef    c_animate_demo_phase1
    xdef    c_wallmaster_calc_start_position
    xdef    c_wallmaster_put_sprite_behind_bg_if_needed
    xdef    c_wallmaster_put_sprites_behind_bg_if_needed

    xref    MovePositionMarkers
    xref    UpdateTriforcePositionMarker
    xref    UpdateHeartsAndRupees
    xref    Submenu_CueTransferRowUW
    xref    Submenu_CueTransferRowOW
    xref    UpdateMenuActive
    xref    UpdateMenuScrollUp
    xref    UpdateMenuStartOW

; void c_move_position_markers(unsigned int vel);
; Native: D0.b = vel, then jmp MovePositionMarkers.
c_move_position_markers:
    move.l  4(SP),D0
    jmp     MovePositionMarkers

c_update_triforce_position_marker:
    jmp     UpdateTriforcePositionMarker

c_update_hearts_and_rupees:
    jmp     UpdateHeartsAndRupees

c_submenu_cue_transfer_row_uw:
    jmp     Submenu_CueTransferRowUW

c_submenu_cue_transfer_row_ow:
    jmp     Submenu_CueTransferRowOW

c_update_menu_active:
    jmp     UpdateMenuActive

c_update_menu_scroll_up:
    jmp     UpdateMenuScrollUp

c_update_menu_start_ow:
    jmp     UpdateMenuStartOW

;==============================================================================
; drain_finalize: z_04 drained entry shims
;==============================================================================
c_update_goriya:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_update_goriya
    addq.l  #4,SP
    rts

c_gel_move_splitting:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_gel_move_splitting
    addq.l  #4,SP
    btst    #8,D0
    beq.s   ._no_carry_c_gel_move_splitting
    ori.b   #$11,CCR
    bra.s   ._done_c_gel_move_splitting
._no_carry_c_gel_move_splitting:
    andi.b  #$EE,CCR
._done_c_gel_move_splitting:
    rts

c_update_normal_zol_or_gel:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    moveq   #0,D1
    move.w  D0,D1
    move.l  D1,-(SP)
    jsr     z04_update_normal_zol_or_gel
    addq.l  #8,SP
    rts

c_update_gohma:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_update_gohma
    addq.l  #4,SP
    rts

c_update_gleeok:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_update_gleeok
    addq.l  #4,SP
    rts

c_l_gleeok_store_ref_seg_distance:
    moveq   #0,D1
    move.w  D0,D1
    move.l  D1,-(SP)
    jsr     z04_l_gleeok_store_ref_seg_distance
    addq.l  #4,SP
    rts

c_gleeok_check_collisions:
    moveq   #0,D0
    move.w  D2,D0
    move.l  D0,-(SP)
    jsr     z04_gleeok_check_collisions
    addq.l  #4,SP
    rts

;==============================================================================
; drain_finalize: z_05 drained entry shims
;==============================================================================
c_update_menu_and_meters:
    jsr     z05_update_menu_and_meters
    rts

c_update_menu:
    jsr     z05_update_menu
    rts

c_update_menu_common1:
    jsr     z05_update_menu_common1
    rts

c_update_menu5_uw:
    jsr     z05_update_menu5_uw
    rts

c_update_menu_scroll_down_ow:
    jsr     z05_update_menu_scroll_down_ow
    rts

c_update_menu_scroll_down_uw:
    jsr     z05_update_menu_scroll_down_uw
    rts

;==============================================================================
; drain_finalize: z_02 drained entry shims
;==============================================================================
c_init_demo_run_tasks:
    jsr     z02_init_demo_run_tasks
    rts

c_init_demo_phase1:
    jsr     z02_init_demo_phase1
    rts

c_update_mode0_demo:
    jsr     z02_update_mode0_demo
    rts

c_update_mode0_demo_sub0:
    jsr     z02_update_mode0_demo_sub0
    rts

c_update_mode0_demo_sub2:
    jsr     z02_update_mode0_demo_sub2
    rts

c_animate_demo:
    jsr     z02_animate_demo
    rts

c_animate_demo_phase1:
    jsr     z02_animate_demo_phase1
    rts

; --- Batch 91: Wallmaster family ---

; Wallmaster_CalcStartPosition — D0=instr_offset, D3=init_major_min, D2=slot.
; Returns index 0/1 in D3 (caller uses it to index an initial-coord table).
c_wallmaster_calc_start_position:
    moveq   #0,D1
    move.w  D2,D1                ; arg3 slot
    move.l  D1,-(SP)
    moveq   #0,D1
    move.b  D3,D1
    andi.l  #$FF,D1
    move.l  D1,-(SP)              ; arg2 init_major_min
    moveq   #0,D1
    move.b  D0,D1
    andi.l  #$FF,D1
    move.l  D1,-(SP)              ; arg1 instr_offset
    jsr     z04_wallmaster_calc_start_position
    lea     (12,SP),SP
    moveq   #0,D3
    move.b  D0,D3                 ; return value -> D3
    rts

; Wallmaster_PutSpriteBehindBgIfNeeded — D3=sprite_byte_off.
c_wallmaster_put_sprite_behind_bg_if_needed:
    moveq   #0,D0
    move.b  D3,D0
    andi.l  #$FF,D0
    move.l  D0,-(SP)
    jsr     z04_wallmaster_put_sprite_behind_bg_if_needed
    addq.l  #4,SP
    rts

; Wallmaster_PutSpritesBehindBgIfNeeded — no args.
c_wallmaster_put_sprites_behind_bg_if_needed:
    jsr     z04_wallmaster_put_sprites_behind_bg_if_needed
    rts

;==============================================================================
; --- Batch 92: Dodongo family (drained from z_04.asm) ---
; Asm callers go through these export shims so that the Dodongo bodies in
; z_04.asm can be reduced to `jmp c_dodongo_*` stubs that reach the owned
; C in src/enemy_boss_runtime.c via the gen/ forwarders.
;==============================================================================

    xdef    c_dodongo_check_collisions
    xdef    c_dodongo_check_collisions_standard_size
    xdef    c_dodongo_check_bomb_hit
    xdef    c_dodongo_try_eat_bomb
    xdef    c_dodongo_is_bomb_in_range
    xdef    c_dodongo_draw

    xref    z04_dodongo_check_collisions
    xref    z04_dodongo_check_collisions_standard_size
    xref    z04_dodongo_check_bomb_hit
    xref    z04_dodongo_try_eat_bomb
    xref    z04_dodongo_is_bomb_in_range
    xref    z04_dodongo_draw

; Dodongo_CheckCollisions — D2=slot, void.
c_dodongo_check_collisions:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_dodongo_check_collisions
    addq.l  #4,SP
    rts

; Dodongo_CheckCollisionsStandardSize — D2=slot, void.
c_dodongo_check_collisions_standard_size:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_dodongo_check_collisions_standard_size
    addq.l  #4,SP
    rts

; Dodongo_CheckBombHit — D2=slot, void.
c_dodongo_check_bomb_hit:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_dodongo_check_bomb_hit
    addq.l  #4,SP
    rts

; Dodongo_TryEatBomb — D2=slot, void.
c_dodongo_try_eat_bomb:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_dodongo_try_eat_bomb
    addq.l  #4,SP
    rts

; Dodongo_IsBombInRange — D3=limit_idx in, returns A in D0 (Z=1 if in range).
c_dodongo_is_bomb_in_range:
    moveq   #0,D1
    move.w  D3,D1
    move.l  D1,-(SP)
    jsr     z04_dodongo_is_bomb_in_range
    addq.l  #4,SP
    tst.b   D0
    rts

; Dodongo_Draw — D2=slot, void.
c_dodongo_draw:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_dodongo_draw
    addq.l  #4,SP
    rts

;==============================================================================
; --- Batch 93: Manhandla family (drained from z_04.asm) ---
;==============================================================================

    xdef    c_bound_flyer
    xdef    c_init_manhandla
    xdef    c_update_manhandla
    xdef    c_manhandla_check_collisions
    xdef    c_manhandla_move
    xdef    c_manhandla_draw

    xref    BoundFlyer
    xref    z04_init_manhandla
    xref    z04_update_manhandla
    xref    z04_manhandla_check_collisions
    xref    z04_manhandla_move
    xref    z04_manhandla_draw

; BoundFlyer — C-callable helper, D2=slot.
c_bound_flyer:
    jmp     z04_bound_flyer

;==============================================================================
; --- Batch 107: z_04 moblin / gibdo / aquamentus ---
;==============================================================================

    xdef    c_update_gibdo
    xdef    c_update_aquamentus
    xdef    c_aquamentus_move
    xdef    c_aquamentus_shoot
    xdef    c_aquamentus_draw

c_update_gibdo:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_update_gibdo
    addq.l  #4,SP
    rts

c_update_aquamentus:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_update_aquamentus
    addq.l  #4,SP
    rts

c_aquamentus_move:
    move.l  4(SP),D2
    jsr     Aquamentus_Move
    rts

c_aquamentus_shoot:
    move.l  4(SP),D2
    jsr     Aquamentus_Shoot
    rts

c_aquamentus_draw:
    move.l  4(SP),D2
    jsr     Aquamentus_Draw
    rts

; InitManhandla — D2=slot, void.
c_init_manhandla:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_init_manhandla
    addq.l  #4,SP
    rts

; UpdateManhandla — D2=slot, void.
c_update_manhandla:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_update_manhandla
    addq.l  #4,SP
    rts

; Manhandla_CheckCollisions — D2=slot, void.
c_manhandla_check_collisions:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_manhandla_check_collisions
    addq.l  #4,SP
    rts

; Manhandla_Move — D2=slot, void.
c_manhandla_move:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_manhandla_move
    addq.l  #4,SP
    rts

; Manhandla_Draw — D2=slot, void.
c_manhandla_draw:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_manhandla_draw
    addq.l  #4,SP
    rts

;==============================================================================
; --- Batch 94: Lamnola family (drained from z_04.asm) ---
;==============================================================================

    xdef    c_init_lamnola
    xdef    c_lamnola_update_head
    xdef    c_lamnola_move

    xref    z04_init_lamnola
    xref    z04_lamnola_update_head
    xref    z04_lamnola_move

; InitLamnola — D2=slot, void.
c_init_lamnola:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_init_lamnola
    addq.l  #4,SP
    rts

; Lamnola_UpdateHead — D2=slot, void.
c_lamnola_update_head:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_lamnola_update_head
    addq.l  #4,SP
    rts

; Lamnola_Move — D2=slot, void.
c_lamnola_move:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_lamnola_move
    addq.l  #4,SP
    rts

;==============================================================================
; --- Batch 95: Vire family (drained from z_04.asm) ---
;==============================================================================

    xdef    c_update_vire
    xdef    c_update_vire_state
    xdef    c_check_vire_collisions
    xdef    c_draw_vire

    xref    z04_update_vire
    xref    z04_update_vire_state
    xref    z04_check_vire_collisions
    xref    z04_draw_vire

c_update_vire:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_update_vire
    addq.l  #4,SP
    rts

c_update_vire_state:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_update_vire_state
    addq.l  #4,SP
    rts

c_check_vire_collisions:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_check_vire_collisions
    addq.l  #4,SP
    rts

c_draw_vire:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_draw_vire
    addq.l  #4,SP
    rts

;==============================================================================
; --- Batch 96: Statue family (drained from z_04.asm) ---
;==============================================================================

    xdef    c_update_statues

    xref    z04_update_statues

c_update_statues:
    jsr     z04_update_statues
    rts

;==============================================================================
; --- Batch 97: Tektite / Boulder family (drained from z_04.asm) ---
;==============================================================================

    xdef    c_turn_towards_player8
    xdef    c_turn_randomly_dir8
    xdef    c_update_tektite_or_boulder

    xref    TurnTowardsPlayer8
    xref    TurnRandomlyDir8
    xref    z04_update_tektite_or_boulder

c_turn_towards_player8:
    jsr     TurnTowardsPlayer8
    rts

; TurnRandomlyDir8 — D2=slot.
c_turn_randomly_dir8:
    move.l  4(SP),D2
    jsr     TurnRandomlyDir8
    rts

c_update_tektite_or_boulder:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_update_tektite_or_boulder
    addq.l  #4,SP
    rts

;==============================================================================
; --- Batch 98: z_07 room edge helper ---
;==============================================================================

    xdef    c_check_screen_edge
    xref    z07_check_screen_edge

c_check_screen_edge:
    jsr     z07_check_screen_edge
    rts

;==============================================================================
; --- Batch 99: z_07 RAM clear helper ---
;==============================================================================

    xdef    c_clear_ram0300_up_to
    xref    z07_clear_ram0300_up_to

c_clear_ram0300_up_to:
    moveq   #0,D1
    move.w  D3,D1
    move.l  D1,-(SP)
    moveq   #0,D1
    move.w  D0,D1
    move.l  D1,-(SP)
    jsr     z07_clear_ram0300_up_to
    addq.l  #8,SP
    rts

;==============================================================================
; --- Batch 100: z_07 shot-block helper ---
;==============================================================================

    xdef    c_handle_shot_blocked
    xref    z07_handle_shot_blocked

c_handle_shot_blocked:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z07_handle_shot_blocked
    addq.l  #4,SP
    rts

;==============================================================================
; --- Batch 101: z_04 Stalfos (drained from z_04.asm) ---
;==============================================================================

    xdef    c_update_stalfos
    xref    z04_update_stalfos

c_update_stalfos:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_update_stalfos
    addq.l  #4,SP
    rts

;==============================================================================
; --- Batch 102: z_04 Ghini (drained from z_04.asm) ---
;==============================================================================

    xdef    c_update_ghini
    xdef    c_draw_ghini_and_check_collisions
    xref    z04_update_ghini
    xref    z04_draw_ghini_and_check_collisions

c_update_ghini:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_update_ghini
    addq.l  #4,SP
    rts

c_draw_ghini_and_check_collisions:
    moveq   #0,D1
    move.w  D2,D1
    move.l  D1,-(SP)
    jsr     z04_draw_ghini_and_check_collisions
    addq.l  #4,SP
    rts

;==============================================================================
