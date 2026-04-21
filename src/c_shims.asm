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

