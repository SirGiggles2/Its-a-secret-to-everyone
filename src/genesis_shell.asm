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
NES_STACK_INIT  equ $00FF0200   ; NES SP=$FF -> A5 = NES_RAM+$0100+$FF+1 = $FF0200
PPU_STATE_SIZE  equ $40         ; 64 bytes: PPU ($FF0800-$FF080F) + MMC1 ($FF0810-$FF081F) + CHR buf ($FF0820-$FF083F)

; Active H-int event queue for the frame currently being rendered.
; _ags_prearm promotes staged state into this queue and HBlankISR consumes it.
; Q1 remains available for future chained events but is currently unused.
HINT_Q_COUNT    equ $00FF0816  ; byte: pending active events (0, 1, or 2)
HINT_Q0_CTR     equ $00FF0817  ; byte: Reg 10 counter for active event 0 (abs scanline)
HINT_Q0_VSRAM   equ $00FF0818  ; word: VSRAM to write at active event 0
HINT_Q1_CTR     equ $00FF081A  ; byte: Reg 10 reload for active event 1 (delta)
HINT_Q1_VSRAM   equ $00FF081C  ; word: VSRAM to write at active event 1

; Active-frame debug state. Probes sample these after the frame has been staged
; and/or rendered to distinguish direct scroll from one-shot H-int composition.
HINT_PEND_SPLIT equ $00FF081E  ; byte: 1 = current frame has an armed H-int split
INTRO_SCROLL_MODE equ $00FF081F ; byte: active scroll mode for the current frame

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
;   $0000–$1FFF   Sprite CHR copy 0 (sub-pal 0, bias +4) — 256 tiles
;   $2000–$3FFF   BG CHR (nametable tiles) — 256 tiles
;   $4000–$5FFF   Sprite CHR copy 1 (sub-pal 1, bias +8) — 256 tiles
;   $6000–$7FFF   Sprite CHR copy 2 (sub-pal 2, bias +C) — 256 tiles
;   $8000–$9FFF   Sprite CHR copy 3 (sub-pal 3, bias +4, OAM=PAL1) — 256 tiles
;   $A000–$AFFF   Free / reserved tile area
;   $B000–$B7FF   Window plane   32×32 × 2 bytes = $800  (HUD strip)
;   $C000–$CFFF   Plane A        64×32 × 2 bytes = $1000 (main playfield)
;   $D800–$DA7F   Sprite attr    80 × 8 bytes = $280
;   $DC00–$DF7F   H-scroll tbl   224 × 4 bytes = $380 (line-scroll mode)
;   $E000–$EFFF   Plane B        64×32 × 2 bytes = $1000 (transition staging)
;   $F000–$FFFF   Free / reserved
;
; T-CHR v8 sprite sub-palette packing (each NES sprite CHR tile is uploaded
; to 4 VRAM copies with pre-biased pixel values — _chr_upload_sprite_4x):
;   sub-pal 0 → copy 0 @ $0000, pixels+$4 → CRAM PAL0[4..7]
;   sub-pal 1 → copy 1 @ $4000, pixels+$8 → CRAM PAL0[8..11]
;   sub-pal 2 → copy 2 @ $6000, pixels+$C → CRAM PAL0[12..15]
;   sub-pal 3 → copy 3 @ $8000, pixels+$4 → CRAM PAL1[4..7]
; BG palettes PAL0[0..3]/PAL1[0..3]/PAL2/PAL3 remain 100% untouched.
; OAM dispatch (_oam_dma) selects the correct VRAM copy via tile bias and
; the correct Gen palette (PAL0 for sub-pal 0/1/2, PAL1 for sub-pal 3).
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
    dc.l    HBlankISR           ; vec 28: IRQ level 4 (H-int)
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
    ; $1B0 SRAM declaration — Phase 9.7.  "RA" + $F8 (odd-byte battery)
    ; + $20 (pad).  Start = $200001, end = $203FFF (4 KB of odd bytes).
    ; gpgx requires both the marker and matching start/end addresses.
    dc.b    "RA",$F8,$20                        ; $1B0 SRAM marker      (4)
    dc.l    $00200001                           ; $1B4 SRAM start
    dc.l    $00203FFF                           ; $1B8 SRAM end
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
    move.w  #$9100,(VDP_CTRL).l  ; Reg 17: window H position = 0 (H window off)
    ; Phase 2: enable Window plane for top 8 rows (HUD isolation).
    ; Reg 18 = $08 → bit 7 = 0 (window above V pos), value 8 = 8*8 = 64px = 8 rows.
    ; NES nametable writes $2000-$20FF (rows 0-7, HUD range) route to Window
    ; nametable at $B000 instead of Plane A at $C000.  Cave/menu bulk writes to
    ; Plane A then cannot stomp HUD VRAM — Window overlays Plane A structurally.
    move.w  #$9208,(VDP_CTRL).l  ; Reg 18: window V position = 8 (covers rows 0-7)
    ; Regs 19-23 (DMA) intentionally SKIPPED — writing reg 23 arms the
    ; VDP DMA pending state on real hardware, causing subsequent CRAM/VRAM
    ; commands to be intercepted as DMA triggers.  DMA regs default to 0
    ; and must only be written immediately before a DMA operation.

    ;--------------------------------------------------------------------------
    ; Phase 6.2: Clear VRAM via VDP DMA fill.
    ; With display off and no other DMA pending, a single 64 KB byte-fill
    ; completes in ~38 µs on real hardware (vs. ~3.5 ms for the previous
    ; 32768-word CPU loop), reclaiming ~6 frames of boot time.
    ;
    ; Sequence:
    ;   1. Reg 15 (auto-increment) = 1 → byte stride for the fill.
    ;   2. Regs 19/20 (DMA length low/high) = 0 → documented VDP quirk:
    ;      length $0000 means "fill 65536 bytes" (full 64 KB).
    ;   3. Reg 23 (DMA source high) = $80 → VRAM-fill mode.
    ;   4. Write address command to VDP_CTRL with DMA bit (CD5=1) set.
    ;   5. Write fill word to VDP_DATA — DMA begins using the upper byte as
    ;      the fill value.  We write $0000 so the fill byte is $00.
    ;   6. Poll VDP status until DMA-busy bit (bit 1) clears.
    ;   7. Restore auto-increment to 2 for normal word writes later.
    ;--------------------------------------------------------------------------
    move.w  #$8F01,(VDP_CTRL).l  ; Reg 15: auto-increment = 1 (byte stride)
    move.w  #$9300,(VDP_CTRL).l  ; Reg 19: DMA length low  = $00
    move.w  #$9400,(VDP_CTRL).l  ; Reg 20: DMA length high = $00 ($0000 = 65536)
    move.w  #$9780,(VDP_CTRL).l  ; Reg 23: DMA mode = VRAM fill
    move.l  #$40000080,(VDP_CTRL).l  ; VRAM write $0000 + DMA bit (CD5=1)
    move.w  #$0000,(VDP_DATA).l  ; Fill byte = upper byte = $00; DMA begins
.vram_dma_wait:
    move.w  (VDP_CTRL).l,D0
    btst    #1,D0                ; bit 1 = DMA busy
    bne.s   .vram_dma_wait
    move.w  #$8F02,(VDP_CTRL).l  ; Reg 15: restore auto-increment = 2

    ;--------------------------------------------------------------------------
    ; Plane B blank fill — use tile $05FF (VRAM $BFE0) as a dedicated blank.
    ; Tile $05FF lives in the gap between Zelda CHR ($0000-$BE00 worst case)
    ; and Plane A nametable ($C000), so Zelda's dynamic CHR uploads never
    ; stomp it. Upload 32 zero bytes to tile $05FF explicitly (VRAM is already
    ; zeroed above, but we re-assert post-CHR-load safety by keeping the tile
    ; outside the Zelda CHR window). Fill plane B with tile index $05FF.
    ; This replaces tile $0200, which was inside Zelda's BG CHR bank and
    ; held octorok-sprite data after CHR upload → visible blue-checker
    ; leak through transparent plane A pixels during intro story scroll.
    ;--------------------------------------------------------------------------
    move.l  #$BFE00003,(VDP_CTRL).l  ; VRAM write to $BFE0 (tile $5FF data)
    moveq   #15,D0
.blank_tile_fill:
    move.w  #0,(VDP_DATA).l
    dbra    D0,.blank_tile_fill
    ;--------------------------------------------------------------------------
    ; Plane B fill — 2048 words of tile $05FF.
    ; Phase 6.3 (VRAM→VRAM DMA propagate-copy) was attempted here but caused
    ; an ExcBusError under gpgx; reverted to the CPU loop since the savings
    ; (~0.3 frames) aren't worth risking the baseline.
    ;--------------------------------------------------------------------------
    move.l  #$60000003,(VDP_CTRL).l  ; VRAM write to $E000 (plane B map)
    move.w  #2047,D0
.planeb_fill:
    move.w  #$05FF,(VDP_DATA).l
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

    ; Phase 1: clear SAT_SHADOW double-buffer + SAT_ACTIVE_BANK flag.
    ; Genesis sprite Y=0 lies 128px above screen → all shadow sprites start
    ; off-screen.  First _oam_dma fill overrides with real game state.
    movea.l #SAT_SHADOW_A,A0
    move.w  #(SAT_SHADOW_SIZE*2)/2-1,D0   ; 2 banks × 512 bytes → 512 words
.sat_shadow_clear:
    move.w  #0,(A0)+
    dbra    D0,.sat_shadow_clear
    clr.b   (SAT_ACTIVE_BANK).l            ; start with bank A active

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

    jsr     audio_init              ; Initialize YM2612 + PSG

    ; Request the title/demo song on boot as a smoke test for the native
    ; M68K music player.  music_tick (called from VBlank) will pick this
    ; up on the first frame after SR is lowered.
    move.b  #$80,(m_song_req).l

    ; Pre-write tile buffer sentinel so the first NMI's TransferCurTileBuf
    ; doesn't parse zeroed RAM as phantom records.  DynTileBuf = NES $0302.
    move.b  #$FF,($0302,A4)

    ; Seed LAST_GAMEMODE to $FF so the first _mode_transition_check always
    ; fires a transition (harmless because PPU latches are already zero but
    ; forces a clean VSRAM init).
    move.b  #$FF,($00FF083E).l       ; LAST_GAMEMODE
    move.b  #$FF,(_current_window_bank).l ; P33: force first bank-window copy

    ;--------------------------------------------------------------------------
    ; Phase 9.7 — Cartridge SRAM declared in header at $1B0-$1BB.  The header
    ; alone is enough for gpgx to allocate the SRAM domain, but writes to
    ; $200001+ via the M68K bus are routed to ROM unless the SRAM mapper
    ; port at $A130F1 is set to $01 (verified by bizhawk_sram_smoke probe:
    ; without the port write the bus reads back $FF, with it the writes
    ; persist into the gpgx SRAM domain).
    ;--------------------------------------------------------------------------
    ;--------------------------------------------------------------------------
    ; Controller port 1 — set TH pin as output once during init.
    ; Doing this inside _ctrl_strobe on every call caused rapid CTRL-register
    ; writes that destabilised the 3-button pad multiplexer on real hardware,
    ; producing inconsistent reads that trapped the ReadOneController
    ; debounce loop in an infinite retry → d-pad freeze while held.
    ;--------------------------------------------------------------------------
    move.b  #$40,($A10009).l        ; Port 1 CTRL: bit6 (TH) = output
    move.b  #$40,($A10003).l        ; Port 1 DATA: TH=1 (idle state)

    move.b  #$01,($A130F1).l        ; SRAM mapper enable (write-only port)
    ; Phase 9.7 SRAM self-test: write a sentinel pattern to the LAST four
    ; odd-byte slots of cart SRAM ($203FF9/$203FFB/$203FFD/$203FFF).  This
    ; lives at the very end of the declared SRAM window, far away from
    ; the NES save-slot range that Phase 9.8 will use ($200001-$200CFF
    ; covering NES $6000-$67FF).  Purpose: gives the smoke probe a
    ; deterministic check that the M68K bus path actually writes through
    ; the cart mapper into the gpgx SRAM file (BizHawk's Lua "M68K BUS"
    ; domain bypasses the mapper and is unreliable for this).
    move.b  #$5A,($203FF9).l
    move.b  #$A5,($203FFB).l
    move.b  #$C3,($203FFD).l
    move.b  #$3C,($203FFF).l
    ; Phase 9.8 — Restore the three NES save slots (NES $6000-$67FF) from
    ; cart SRAM into the work-RAM mirror at $FF6000 BEFORE Zelda runs.
    ; The mirror is what z_02 reads/writes via NES_SRAM equ $FF6000.
    ; Without this restore, every cold boot would see all-$FF SRAM data.
    jsr     _sram_load_save_slots

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
    addq.b  #1,($00FF1003).l        ; Phase 2.4: NMI probe counter
    ; Phase 1 (HW adoption): flush previous frame's SAT_SHADOW to VRAM $F800
    ; via 68k→VRAM DMA.  Must run before _ags_prearm/IsrNmi so the DMA
    ; trigger fires early in vblank (IsrNmi can extend into active display).
    ; _oam_dma_flush also flips SAT_ACTIVE_BANK so the NEXT IsrNmi fill
    ; populates the other bank.
    bsr     _oam_dma_flush
    ; Pre-arm pending VSRAM + H-int state from previous frame's _ags_flush.
    ; Must run BEFORE IsrNmi: IsrNmi can extend into active display past
    ; scanline 40, so doing the VDP writes after-the-fact (inside _ags_flush)
    ; misses the pinned-title band. _ags_prearm guarantees the write lands
    ; in vblank.
    bsr     _ags_prearm
    ; Phase 1 mode-transition purge — catches GameMode changes and zeroes
    ; PPU latches + direct-writes VSRAM[0]/[1] inside the blanking window
    ; so VSRAM bleed from the prior mode cannot contaminate the first frame
    ; of the new mode.  Must run BEFORE IsrNmi (IsrNmi would otherwise
    ; apply the stale scroll shadows mid-NMI).
    bsr     _mode_transition_check
    jsr     IsrNmi
    ; Advance the native music player one tick (YM2612 + PSG writes).
    ; Mirrors the original NES engine which drove music from NMI.
    bsr     music_tick
    ; Flush PPU scroll shadows → VDP VSRAM / H-scroll / H-int queue.
    ; Deferred to here (post-NMI, still in VBlank) so the two transpiler-
    ; injected `bsr _apply_genesis_scroll` sites inside IsrNmi cannot
    ; double-program the VDP mid-NMI. _ags_flush reads CurVScroll/
    ; CurHScroll/IsSprite0CheckActive from NES zero-page via A4, which
    ; VBlankISR's movem preserved from the interrupted caller (RunGame
    ; establishes A4 = $FF0000 before LoopForever).
    bsr     _ags_flush
.nmi_off:
    movem.l (SP)+,D0-D7/A0-A6
    rte

;==============================================================================
; HBlankISR — queue-popping H-int dispatcher + DMC DAC streamer.
;
; Two fundamentally different uses of HINT now share this ISR:
;
;   (a) Scroll splits.  1-2 HINTs per frame fire at specific lines, drain
;       the HINT_Q* queue, write VSRAM, then self-disable HINT via reg 0.
;       This is the original behaviour, unchanged.
;
;   (b) DMC DAC streaming.  While audio_driver's dmc_trigger is active,
;       HINT is armed every line (reg 10 = 0) and this ISR streams one PCM
;       byte per fire to YM2612 reg $2A.  Detected by dmc_active != 0 at
;       ISR entry.  In DMC mode we bypass the scroll queue entirely —
;       title screen and intro don't use scroll splits anyway.
;
; Detection is at the very top of the ISR so the DMC path has minimal
; latency.  dmc_hint_tick is defined in audio_driver.asm and handles the
; full stream-one-byte-or-end-of-sample logic.
;
; State contract for scroll-path (unchanged):
;   _ags_flush   writes NEXT-frame staged state (STAGED_*)
;   _ags_prearm  promotes STAGED_* -> active HINT_Q* before display starts
;   HINT_Q_COUNT ≥ 1 when H-int is armed via Reg 0 bit 4 for the CURRENT frame
;   HINT_Q0_CTR  = initial Reg 10 value for the current frame
;   HINT_Q0_VSRAM = VSRAM value to write when the current frame's H-int fires
;   HINT_Q1_* remain available for future chained events
;==============================================================================
HBlankISR:
    tst.b   (dmc_active).l                  ; DMC streaming?
    beq.s   .scroll_path                    ; no → scroll queue handler
    movem.l D0/A0,-(SP)
    bsr     dmc_hint_tick
    movem.l (SP)+,D0/A0
    rte

.scroll_path:
    movem.l D0-D1/A0,-(SP)
    lea     (HINT_Q_COUNT).l,A0
    move.b  (A0),D0
    beq.s   .hi_disable                     ; defensive: empty queue
    subq.b  #1,(A0)                         ; decrement remaining count
    ; Write queued VSRAM FIRST (critical path)
    move.l  #VSRAM_WRITE_0000,(VDP_CTRL).l
    move.w  (HINT_Q0_VSRAM).l,(VDP_DATA).l
    ; If another event is pending, re-arm Reg 10 and promote Q1 → Q0
    tst.b   (A0)
    beq.s   .hi_disable
    moveq   #0,D1
    move.b  (HINT_Q1_CTR).l,D1
    or.w    #$8A00,D1
    move.w  D1,(VDP_CTRL).l                 ; Reg 10 = delta to next event
    move.w  (HINT_Q1_VSRAM).l,(HINT_Q0_VSRAM).l
    bra.s   .hi_done
.hi_disable:
    move.w  #$8004,(VDP_CTRL).l             ; Reg 0: disable H-int
.hi_done:
    movem.l (SP)+,D0-D1/A0
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
    include "audio_driver.asm"
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
