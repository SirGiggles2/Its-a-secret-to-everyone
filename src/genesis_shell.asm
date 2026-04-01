;==============================================================================
; genesis_shell.asm — Genesis boot shell (T1 milestone)
;
; No Zelda code. Boots, inits VDP with verified H32 register set, clears
; VRAM, writes a green test color to CRAM[0], turns on the display.
; Screen should be solid green — use this to confirm VDP init is correct
; before attaching any NES I/O or translated Zelda code.
;
; COLORFIX: VDP register 0 is ALWAYS $8004 (NOT $8000).
;   bit 2 is reserved and must be 1. Writing $8000 produces dingy/dark
;   colors on real hardware even when CRAM data is correct.
;
; H32 mode: confirmed by Reg 12 = $00 (RS0=bit0=0, RS1=bit7=0).
;   256 pixels wide, 32 tiles per row.
;==============================================================================

;==============================================================================
; Hardware addresses
;==============================================================================

STACK_TOP       equ $00FFFFFE
VDP_DATA        equ $00C00000
VDP_CTRL        equ $00C00004
VERSION_PORT    equ $00A10001
TMSS_PORT       equ $00A14000
Z80_BUSREQ      equ $00A11100
Z80_RESET       equ $00A11200

;==============================================================================
; VDP command long-words (written to VDP_CTRL to set VRAM/CRAM address)
;==============================================================================

VRAM_WRITE_0000 equ $40000000       ; VRAM write to address $0000 (CD=%0100)
CRAM_WRITE_0000 equ $C0000000       ; CRAM write to address $0000 (CD=%1100)

;==============================================================================
; Genesis CRAM color: ---BBB-GGG-RRR
;   Bits [11:9]=Blue, [7:5]=Green, [3:1]=Red  (3 bits each)
;==============================================================================

COLOR_GREEN     equ $00E0           ; pure green (G=7 → bits[7:5]=111)
COLOR_BLACK     equ $0000

;==============================================================================
; VRAM layout
;
;   $0000–$AFFF   Tiles (CHR-RAM fills dynamically, space for 1408 tiles)
;   $B000–$B7FF   Window plane   32×32 × 2 bytes = $800  (HUD strip)
;   $C000–$CFFF   Plane A        64×32 × 2 bytes = $1000 (main playfield)
;   $D800–$DA7F   Sprite attr    80 × 8 bytes = $280
;   $DC00–$DF7F   H-scroll tbl   224 × 4 bytes = $380 (line-scroll mode)
;   $E000–$EFFF   Plane B        64×32 × 2 bytes = $1000 (transition staging)
;   $F000–$FFFF   Free / reserved
;==============================================================================

;==============================================================================
; $000000 — 68000 Exception Vector Table (64 vectors × 4 bytes = $100 bytes)
;
; Vector layout:
;   0:  Initial SSP
;   1:  Initial PC (Reset)
;   2–11: exception handlers
;   12–23: reserved
;   24: spurious interrupt
;   25–27: IRQ level 1–3 auto-vectors
;   28: IRQ level 4 auto-vector (H-int / HBlank)
;   29: IRQ level 5 auto-vector
;   30: IRQ level 6 auto-vector (V-int / VBlank) ← at $000078
;   31: IRQ level 7 auto-vector
;   32–63: TRAP + user-defined
;==============================================================================

    org     $000000

    dc.l    STACK_TOP           ; vec  0: initial SSP
    dc.l    EntryPoint          ; vec  1: initial PC → boot code
    rept    22
        dc.l    DefaultException    ; vec 2–23: exceptions + reserved
    endr
    dc.l    DefaultException    ; vec 24: spurious interrupt
    dc.l    DefaultException    ; vec 25: IRQ level 1 (auto)
    dc.l    DefaultException    ; vec 26: IRQ level 2 (EXT)
    dc.l    DefaultException    ; vec 27: IRQ level 3 (auto)
    dc.l    DefaultException    ; vec 28: IRQ level 4 (H-int)
    dc.l    DefaultException    ; vec 29: IRQ level 5 (auto)
    dc.l    VBlankISR           ; vec 30: IRQ level 6 (V-int / VBlank) ←
    dc.l    DefaultException    ; vec 31: IRQ level 7 (NMI)
    rept    32
        dc.l    DefaultException    ; vec 32–63: TRAP + user-defined
    endr

;==============================================================================
; $000100 — Genesis ROM Header
;==============================================================================

    org     $000100

    dc.b    "SEGA MEGA DRIVE "                  ; $100 system type     (16)
    dc.b    "(C)JAKEDIGZ 2026"                  ; $110 copyright        (16)
    dc.b    "THE LEGEND OF ZELDA             "  ; $120 domestic name    (32)
    dc.b    "                "                  ; $140 (pad to 48)      (16)
    dc.b    "THE LEGEND OF ZELDA             "  ; $150 overseas name    (32)
    dc.b    "                "                  ; $170 (pad to 48)      (16)
    dc.b    "GM 00000000-00"                    ; $180 serial           (14)
    dc.w    0                                   ; $18E checksum (fix_checksum.py)
    dc.b    "J               "                  ; $190 I/O: 3-btn joy   (16)
    dc.l    $00000000                           ; $1A0 ROM start
    dc.l    RomEnd-1                            ; $1A4 ROM end
    dc.l    $00FF0000                           ; $1A8 RAM start
    dc.l    $00FFFFFF                           ; $1AC RAM end
    dc.b    $00,$00,$00,$00,$00,$00,$00,$00     ; $1B0 no SRAM          (12)
    dc.b    $00,$00,$00,$00
    rept    12
        dc.b    $20                             ; $1BC modem (spaces)   (12)
    endr
    rept    40
        dc.b    $20                             ; $1C8 notes (spaces)   (40)
    endr
    dc.b    "JUE             "                  ; $1F0 regions          (16)

;==============================================================================
; $000200 — Boot code
;==============================================================================

    org     $000200

;------------------------------------------------------------------------------
; EntryPoint — 68000 reset vector lands here.
; The 68000 boots with SR = $2700 (supervisor, all IRQs masked). We leave
; interrupts masked through the entire init sequence and lower the mask at
; the end of MainLoop via the STOP instruction.
;------------------------------------------------------------------------------
EntryPoint:
    ;--------------------------------------------------------------------------
    ; TMSS handshake — check VERSION_PORT bit[0]; if set, this is a TMSS
    ; hardware revision that requires writing 'SEGA' ($53454741) to $A14000
    ; before VDP access is allowed. Safe to skip on pre-TMSS hardware.
    ;--------------------------------------------------------------------------
    move.b  (VERSION_PORT).l,D0
    andi.b  #$0F,D0
    beq.s   .skip_tmss
    move.l  #$53454741,(TMSS_PORT).l   ; 'S','E','G','A'
.skip_tmss:

    ;--------------------------------------------------------------------------
    ; Stop Z80 — hold it in reset to prevent bus contention during init.
    ;--------------------------------------------------------------------------
    move.w  #$0100,(Z80_BUSREQ).l
    move.w  #$0100,(Z80_RESET).l
.z80wait:
    btst    #0,(Z80_BUSREQ+1).l         ; BUSACK = byte at $A11101 bit 0;
    bne.s   .z80wait                    ; wait until Z80 releases the bus

    ;--------------------------------------------------------------------------
    ; VDP register init — H32 mode, display OFF during init.
    ;
    ; COLORFIX: Reg 0 = $8004. bit 2 MUST BE 1.
    ;   $8000 (bit2=0) → dingy/dark colors on hardware despite correct CRAM.
    ;   $8004 (bit2=1) → correct colors.
    ;--------------------------------------------------------------------------
    move.w  #$8004,(VDP_CTRL).l  ; Reg  0: bit2=1 (colorfix), no H-int, no left-blank
    move.w  #$8134,(VDP_CTRL).l  ; Reg  1: display OFF, VBlank IRQ, DMA, M5 (Genesis)
    move.w  #$8230,(VDP_CTRL).l  ; Reg  2: Plane A @ $C000  ($C000/$2000=6 → $30)
    move.w  #$832C,(VDP_CTRL).l  ; Reg  3: Window  @ $B000  (bits[5:1]=22 → $2C)
    move.w  #$8407,(VDP_CTRL).l  ; Reg  4: Plane B @ $E000  ($E000/$2000=7 → $07)
    move.w  #$856C,(VDP_CTRL).l  ; Reg  5: Sprite table @ $D800 ($D800/$200=108 → $6C)
    move.w  #$8600,(VDP_CTRL).l  ; Reg  6: sprite table high bit = 0
    move.w  #$8700,(VDP_CTRL).l  ; Reg  7: BG color = palette 0, color 0
    move.w  #$8800,(VDP_CTRL).l  ; Reg  8: SMS compat = 0 (unused in M5)
    move.w  #$8900,(VDP_CTRL).l  ; Reg  9: SMS compat = 0 (unused in M5)
    move.w  #$8AFF,(VDP_CTRL).l  ; Reg 10: H-int counter = $FF (effectively disabled)
    move.w  #$8B00,(VDP_CTRL).l  ; Reg 11: full-screen V-scroll, full H-scroll
    move.w  #$8C00,(VDP_CTRL).l  ; Reg 12: H32 (bits7,0=0), no interlace, no shadow/hl
    move.w  #$8D37,(VDP_CTRL).l  ; Reg 13: H-scroll table @ $DC00 ($DC00/$400=55 → $37)
    move.w  #$8E00,(VDP_CTRL).l  ; Reg 14: pattern gen base = 0 (SMS compat, unused M5)
    move.w  #$8F02,(VDP_CTRL).l  ; Reg 15: auto-increment = 2 (word per VRAM access)
    move.w  #$9001,(VDP_CTRL).l  ; Reg 16: scroll size 64H × 32V → $01
    move.w  #$9100,(VDP_CTRL).l  ; Reg 17: window H position = 0
    move.w  #$9200,(VDP_CTRL).l  ; Reg 18: window V position = 0
    move.w  #$9300,(VDP_CTRL).l  ; Reg 19: DMA length low = 0
    move.w  #$9400,(VDP_CTRL).l  ; Reg 20: DMA length high = 0
    move.w  #$9500,(VDP_CTRL).l  ; Reg 21: DMA source low = 0
    move.w  #$9600,(VDP_CTRL).l  ; Reg 22: DMA source mid = 0
    move.w  #$9700,(VDP_CTRL).l  ; Reg 23: DMA source high/type = 0 (ROM→VRAM)

    ;--------------------------------------------------------------------------
    ; Clear VRAM — write 0 to all 32768 words (64KB) via CPU loop.
    ; Auto-increment = 2 is set by Reg 15 above.
    ;--------------------------------------------------------------------------
    move.l  #VRAM_WRITE_0000,(VDP_CTRL).l
    move.w  #32767,D0
.vramclear:
    move.w  #0,(VDP_DATA).l
    dbra    D0,.vramclear

    ;--------------------------------------------------------------------------
    ; Write test palette — pure green to CRAM[0] (background color slot).
    ; Reg 7 above set background = palette 0, color 0 → CRAM entry 0.
    ;
    ; Result on screen: solid green = VDP init correct (colorfix working).
    ; Dingy/dark green = check that Reg 0 is $8004, NOT $8000.
    ;--------------------------------------------------------------------------
    move.l  #CRAM_WRITE_0000,(VDP_CTRL).l
    move.w  #COLOR_GREEN,(VDP_DATA).l

    ;--------------------------------------------------------------------------
    ; Display on
    ;--------------------------------------------------------------------------
    move.w  #$8174,(VDP_CTRL).l  ; Reg 1: DISP=1, VBlank IRQ, DMA, M5

    ;--------------------------------------------------------------------------
    ; Enable interrupts via STOP. SR = $2000 → IPL mask = 0 → all IRQs pass.
    ; VBlank (level 6) will now fire every frame.
    ;--------------------------------------------------------------------------
MainLoop:
    stop    #$2000                  ; halts CPU, sets SR=$2000, wakes on interrupt
    bra.s   MainLoop

;==============================================================================
; VBlankISR — T1 stub. Does nothing except return.
; Replace with Zelda NMI dispatch once NES I/O is wired up.
;==============================================================================
VBlankISR:
    rte

;==============================================================================
; DefaultException — spin on any unhandled exception.
; BizHawk will show PC stuck in this loop when an exception fires.
; Interrupts remain at their current level (caller's SR restored by exception).
;==============================================================================
DefaultException:
    bra.s   DefaultException

;==============================================================================
; End-of-ROM marker — used by ROM header dc.l RomEnd-1
;==============================================================================
RomEnd:
