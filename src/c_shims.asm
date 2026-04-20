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
    xref    c_move_object

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
