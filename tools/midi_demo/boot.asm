;==============================================================================
; midi_demo/boot.asm — standalone Genesis ROM boot.
;
; Boots, performs TMSS handshake, stops Z80, sets up VDP for H32 V32 plane,
; jumps to C main().  No NES emulation, no shell.
;==============================================================================

VDP_DATA        equ $00C00000
VDP_CTRL        equ $00C00004
VERSION_PORT    equ $00A10001
TMSS_PORT       equ $00A14000
Z80_BUSREQ      equ $00A11100
Z80_RESET       equ $00A11200
STACK_TOP       equ $00FFFFFE

;------------------------------------------------------------------------------
; Vector table (64 vectors x 4 bytes = $100)
;------------------------------------------------------------------------------
    section "vectors",code

    dc.l    STACK_TOP
    dc.l    EntryPoint
    rept    62
        dc.l    DefaultException
    endr

;------------------------------------------------------------------------------
; ROM header
;------------------------------------------------------------------------------
    section "header",data

    dc.b    "SEGA MEGA DRIVE "                  ; system
    dc.b    "(C)JAKEDIGZ 2026"                  ; copyright
    dc.b    "MIDI DEMO                       "  ; domestic name (48)
    dc.b    "                "                  ; pad
    dc.b    "MIDI DEMO                       "  ; overseas name
    dc.b    "                "                  ; pad
    dc.b    "GM 00000000-00"                    ; serial
    dc.w    0                                   ; checksum (fix later)
    dc.b    "J               "                  ; I/O
    dc.l    $00000000                           ; ROM start
    dc.l    $0007FFFF                           ; ROM end (512 KB pad)
    dc.l    $00FF0000                           ; RAM start
    dc.l    $00FFFFFF                           ; RAM end
    dc.b    "            "                      ; SRAM/modem (12)
    dc.b    "            "                      ; pad
    rept    40
        dc.b    $20
    endr
    dc.b    "JUE             "                  ; regions

;------------------------------------------------------------------------------
; EntryPoint
;------------------------------------------------------------------------------
    section "text",code

    xdef    EntryPoint

EntryPoint:
    ; TMSS handshake
    move.b  (VERSION_PORT).l,D0
    andi.b  #$0F,D0
    beq.s   .skip_tmss
    move.l  #$53454741,(TMSS_PORT).l
    moveq   #15,D0
.tmss_delay:
    dbra    D0,.tmss_delay
.skip_tmss:

    ; Stop Z80
    move.w  #$0100,(Z80_BUSREQ).l
    move.w  #$0100,(Z80_RESET).l
.z80wait:
    btst    #0,(Z80_BUSREQ).l
    bne.s   .z80wait

    ; VDP register init — H32 mode, plane size H32 V32, display OFF during init.
    move.w  #$8004,(VDP_CTRL).l   ; Reg  0: HINT off (bit 4 = 0)
    move.w  #$8134,(VDP_CTRL).l   ; Reg  1: display OFF, VINT on, M5
    move.w  #$8230,(VDP_CTRL).l   ; Reg  2: Plane A @ $C000
    move.w  #$832C,(VDP_CTRL).l   ; Reg  3: Window  @ $B000
    move.w  #$8407,(VDP_CTRL).l   ; Reg  4: Plane B @ $E000
    move.w  #$857C,(VDP_CTRL).l   ; Reg  5: Sprite table @ $F800
    move.w  #$8600,(VDP_CTRL).l
    move.w  #$8700,(VDP_CTRL).l   ; Reg  7: BG = pal0 col0
    move.w  #$8800,(VDP_CTRL).l
    move.w  #$8900,(VDP_CTRL).l
    move.w  #$8AFF,(VDP_CTRL).l   ; Reg 10: HINT count = $FF (off)
    move.w  #$8B00,(VDP_CTRL).l   ; Reg 11: full-screen scroll
    move.w  #$8C00,(VDP_CTRL).l   ; Reg 12: H32 mode
    move.w  #$8D3F,(VDP_CTRL).l   ; Reg 13: H-scroll table @ $FC00
    move.w  #$8E00,(VDP_CTRL).l
    move.w  #$8F02,(VDP_CTRL).l   ; Reg 15: auto-inc = 2
    move.w  #$9000,(VDP_CTRL).l   ; Reg 16: plane size H32 x V32
    move.w  #$9100,(VDP_CTRL).l
    move.w  #$9200,(VDP_CTRL).l

    ; Establish stack
    move.l  #STACK_TOP,A7

    jsr     main

.halt:
    bra.s   .halt

DefaultException:
    rte
