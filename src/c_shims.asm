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

