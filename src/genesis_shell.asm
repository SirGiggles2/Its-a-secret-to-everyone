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
; NES emulation constants
;==============================================================================
NES_RAM_BASE    equ $00FF0000   ; Maps NES $0000-$07FF (8 pages × 256 bytes)
NES_RAM_SIZE    equ $0800       ; 2KB NES work RAM
NES_STACK_INIT  equ $00FF0200   ; NES SP=$FF → A5 = NES_RAM+$0100+$FF+1 = $FF0200
PPU_STATE_SIZE  equ $40         ; 64 bytes: PPU ($FF0800-$FF080F) + MMC1 ($FF0810-$FF081F) + CHR buf ($FF0820-$FF083F)

;==============================================================================
; VDP command long-words (written to VDP_CTRL to set VRAM/CRAM address)
;==============================================================================

VRAM_WRITE_0000 equ $40000000       ; VRAM write to address $0000 (CD=%0100)
CRAM_WRITE_0000 equ $C0000000       ; CRAM write to address $0000 (CD=%1100)
VSRAM_WRITE_0000 equ $40000010      ; VSRAM write to address $0000

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
    dc.l    ExcBusError         ; vec  2: bus error
    dc.l    ExcAddrError        ; vec  3: address error
    rept    20
        dc.l    DefaultException    ; vec 4–23: exceptions + reserved
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
    moveq   #15,D0
.tmss_delay:
    dbra    D0,.tmss_delay              ; ~80 cycles delay for VDP unlock
.skip_tmss:

    ;--------------------------------------------------------------------------
    ; Stop Z80 — hold it in reset to prevent bus contention during init.
    ;--------------------------------------------------------------------------
    move.w  #$0100,(Z80_BUSREQ).l
    move.w  #$0100,(Z80_RESET).l
.z80wait:
    btst    #0,(Z80_BUSREQ).l            ; BUSACK = bit 0 of high byte $A11100;
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
    move.w  #$857C,(VDP_CTRL).l  ; Reg  5: Sprite table @ $F800 ($F800/$200=124 → $7C)
    move.w  #$8600,(VDP_CTRL).l  ; Reg  6: sprite table high bit = 0
    move.w  #$8700,(VDP_CTRL).l  ; Reg  7: BG color = palette 0, color 0
    move.w  #$8800,(VDP_CTRL).l  ; Reg  8: SMS compat = 0 (unused in M5)
    move.w  #$8900,(VDP_CTRL).l  ; Reg  9: SMS compat = 0 (unused in M5)
    move.w  #$8AFF,(VDP_CTRL).l  ; Reg 10: H-int counter = $FF (effectively disabled)
    move.w  #$8B00,(VDP_CTRL).l  ; Reg 11: full-screen V-scroll, full H-scroll
    move.w  #$8C00,(VDP_CTRL).l  ; Reg 12: H32 (bits7,0=0), no interlace, no shadow/hl
    move.w  #$8D3F,(VDP_CTRL).l  ; Reg 13: H-scroll table @ $FC00 ($FC00/$400=63 → $3F)
    move.w  #$8E00,(VDP_CTRL).l  ; Reg 14: pattern gen base = 0 (SMS compat, unused M5)
    move.w  #$8F02,(VDP_CTRL).l  ; Reg 15: auto-increment = 2 (word per VRAM access)
    move.w  #$9011,(VDP_CTRL).l  ; Reg 16: scroll size 64H × 64V → $11
    move.w  #$9100,(VDP_CTRL).l  ; Reg 17: window H position = 0
    move.w  #$9200,(VDP_CTRL).l  ; Reg 18: window V position = 0
    ; Regs 19-23 (DMA) intentionally SKIPPED — writing reg 23 arms the
    ; VDP DMA pending state on real hardware, causing subsequent CRAM/VRAM
    ; commands to be intercepted as DMA triggers.  DMA regs default to 0
    ; and must only be written immediately before a DMA operation.

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
    ; Plane B blank fill — write tile $0200 to entire Plane B nametable at
    ; $E000.  Prevents tile-0 pattern data from leaking through transparent
    ; Plane A pixels.  64×64 = 4096 entries (H32 mode, 64H×64V scroll size).
    ;--------------------------------------------------------------------------
    move.l  #$60000003,(VDP_CTRL).l  ; VRAM write to $E000
    move.w  #2047,D0
.planeb_fill:
    move.w  #$0200,(VDP_DATA).l
    dbra    D0,.planeb_fill

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
    ; Clear NES RAM ($FF0000–$FF07FF) — 2KB of NES work RAM mapped into
    ; Genesis RAM at the top of the address space.
    ; Also clears PPU state block ($FF0800–$FF080F) in the same pass.
    ;--------------------------------------------------------------------------
    movea.l #NES_RAM_BASE,A0
    move.w  #(NES_RAM_SIZE+PPU_STATE_SIZE)/2-1,D0  ; 1031 words
.nesramclear:
    move.w  #0,(A0)+
    dbra    D0,.nesramclear

    ;--------------------------------------------------------------------------
    ; T4: Initialize NES register equivalents before handing off to Zelda code.
    ;
    ;   A4 = NES_RAM_BASE ($FF0000) — base for all (offset,A4) NES RAM accesses
    ;   A5 = NES_STACK_INIT ($FF0200) — NES stack starts at SP=$FF, so the
    ;        first PHA decrements to $FF01FF.  A5 points one-past the top.
    ;   D7 = $FF — 6502 SP shadow (used by TSX/TXS and stack bound checks)
    ;--------------------------------------------------------------------------
    movea.l #NES_RAM_BASE,A4
    movea.l #NES_STACK_INIT,A5
    moveq   #-1,D7                  ; D7 = $FF (NES SP shadow)

    ; Pre-write tile buffer sentinel so the first NMI's TransferCurTileBuf
    ; doesn't parse zeroed RAM as phantom records.  DynTileBuf = NES $0302.
    move.b  #$FF,($0302,A4)

    ;--------------------------------------------------------------------------
    ; Lower interrupt mask so VBlank (level 6) can fire.
    ; A4/A5/D7 are initialised above — IsrNmi is now safe to execute.
    ; IPL=0: all interrupt levels pass (VBlank=6, NMI-like=7).
    ;--------------------------------------------------------------------------
    andi.w  #$F8FF,SR               ; IPL → 0: enable VBlank

    ;--------------------------------------------------------------------------
    ; Hand off to Zelda — jump to IsrReset (the NES Reset vector handler).
    ; IsrReset polls PPU $2002 (VBlank) twice, initialises MMC1, then jumps
    ; to RunGame which spins in LoopForever waiting for VBlank NMI.
    ;
    ; NOTE: VBlankISR below is wired to IsrNmi once T4 is validated.
    ; For T4, VBlank is masked by genesis boot SR ($2700) and IsrReset's SEI
    ; (now a NOP), so LoopForever just spins — that is the expected T4 state.
    ;--------------------------------------------------------------------------
    jsr     IsrReset                ; never returns (RunGame → LoopForever)

    ;--------------------------------------------------------------------------
    ; Safety net — should never be reached.
    ;--------------------------------------------------------------------------
HaltForever:
    stop    #$2700
    bra.s   HaltForever

;==============================================================================
; VBlankISR — T4: call IsrNmi (Zelda's NMI handler) then return.
; IsrNmi is defined in zelda_translated/z_07.asm (included below).
;
; T4 note: during boot, SR=$2700 so this ISR never fires while IsrReset runs.
; Once RunGame hits LoopForever and we lower SR (T5+), this fires every frame.
;==============================================================================
VBlankISR:
    movem.l D0-D7/A0-A6,-(SP)
    ; Only call IsrNmi if PPUCTRL bit 7 = 1 (NMI enable).
    ; On NES, VBlank NMI fires only when PPUCTRL.$80 is set.
    ; During IsrReset warmup PPUCTRL=0, so IsrNmi is suppressed
    ; until RunGame writes $A0 to $2000.
    btst    #7,($00FF0804).l        ; PPU_CTRL = $FF0804, bit 7 = NMI enable
    beq.s   .nmi_off
    jsr     IsrNmi
.nmi_off:
    movem.l (SP)+,D0-D7/A0-A6
    rte

;==============================================================================
; Exception forensics handlers
;
; On any exception: save type, stacked SR, faulting PC, and all data/address
; registers to a known RAM block at $FF0900 before spinning.  The T5 probe
; (and BizHawk debugger) can then read this block to identify the fault.
;
; 68000 stack frames:
;   Bus Error (vec 2) / Address Error (vec 3):
;     SP+0  function code / misc (word)
;     SP+2  access address (long)
;     SP+6  instruction register (word)
;     SP+8  SR at exception time
;     SP+10 PC of faulting instruction (long)
;   All other exceptions:
;     SP+0  SR at exception time
;     SP+2  PC of faulting instruction (long)
;
; Forensics RAM layout ($FF0900):
;   $FF0900: exception type byte (2=bus error, 3=addr error, 0=other)
;   $FF0901: (pad)
;   $FF0902: stacked SR (word)
;   $FF0904: faulting PC (long)
;   $FF0908: D0–D7, A0–A6 saved by MOVEM.L (15 longs = 60 bytes, ends $FF0943)
;==============================================================================

ExcBusError:
    move.b  #2,($FF0900).l
    move.w  8(SP),($FF0902).l
    move.l  10(SP),($FF0904).l
    movem.l D0-D7/A0-A6,($FF0908).l
.spin:
    bra.s   .spin

ExcAddrError:
    move.b  #3,($FF0900).l
    move.w  8(SP),($FF0902).l
    move.l  10(SP),($FF0904).l
    movem.l D0-D7/A0-A6,($FF0908).l
.spin:
    bra.s   .spin

DefaultException:
    move.b  #0,($FF0900).l
    move.w  (SP),($FF0902).l
    move.l  2(SP),($FF0904).l
    movem.l D0-D7/A0-A6,($FF0908).l
.spin:
    bra.s   .spin

;==============================================================================
; NES I/O emulation layer — real implementations of _ppu_*, _apu_*, _ctrl_*,
; _oam_dma, _mmc1_*, _indirect_stub.  Must be included BEFORE any bank file
; so all helpers are defined when z_XX.asm code references them.
; (With --no-stubs the bank files no longer emit these labels themselves.)
;==============================================================================
    include "nes_io.asm"

;==============================================================================
; Zelda translated code — generated by tools/transpile_6502.py --all --no-stubs
;
; z_07.asm is the NES fixed bank ($E000-$FFFF): IsrReset, IsrNmi, RunGame,
; and ALL shared equates (NES RAM variables).  It must be included first.
;
; z_00–z_06 are the switchable PRG banks.  They carry no equate block in
; --all mode (suppressed by transpiler to avoid vasm duplicate-symbol errors).
; All cross-bank import stubs are also suppressed — every symbol resolves
; directly by label across the flat Genesis ROM.
;
; vasm CWD is src/ (set by build.bat pushd), so paths are relative to src/.
;==============================================================================
    ; All 8 banks included in ascending order (z_00 first so its definitions of
    ; multiply-exported symbols like Exit are canonical).  z_07 is included last
    ; so its cross-bank stubs (which are suppressed for globally-exported symbols)
    ; don't conflict with real definitions from z_00-z_06.
    ; Equates are only in z_07 (other banks omit them in --all mode).
    include "zelda_translated/z_00.asm"
    include "zelda_translated/z_01.asm"
    include "zelda_translated/z_02.asm"
    include "zelda_translated/z_03.asm"
    include "zelda_translated/z_04.asm"
    include "zelda_translated/z_05.asm"
    include "zelda_translated/z_06.asm"
    include "zelda_translated/z_07.asm"

;==============================================================================
; End-of-ROM marker — used by ROM header dc.l RomEnd-1
;==============================================================================
RomEnd:
