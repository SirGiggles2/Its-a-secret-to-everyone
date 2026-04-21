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

