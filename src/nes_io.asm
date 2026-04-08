;==============================================================================
; nes_io.asm — NES I/O emulation layer
;
; Included by genesis_shell.asm BEFORE z_07.asm (and all other bank files).
; Provides real implementations of all _ppu_*, _apu_*, _ctrl_*, _oam_*,
; _mmc1_* helpers that the transpiled Zelda code calls via BSR/JSR.
;
; T5 milestone: PPUADDR two-write latch + PPUDATA → Genesis VDP VRAM byte writes.
;
; Register contract (must match transpiler mapping):
;   D0  = NES accumulator A
;   D2  = NES X index
;   D3  = NES Y index
;   D7  = NES SP shadow
;   A4  = NES RAM base ($FF0000)
;   A5  = NES stack pointer (NES_RAM + $0100 region)
;
; All NES I/O functions must preserve D1–D7, A0–A6 except as documented.
; They receive their argument in D0.b and return results in D0.b.
;==============================================================================

;------------------------------------------------------------------------------
; CHR_EXPANSION_ENABLED — feature flag for the 4x sprite CHR expansion.
;
; When 1: every sprite CHR tile is stored in Gen VRAM as 4 copies, each with
;   pixel values pre-biased +0/+4/+8/+12 to index into packed PAL2 slots
;   0..15.  _oam_dma selects the copy via tile-index bias; tile word palette
;   bits are always %10 (PAL2).  NES $3F10-$3F1F palette writes pack into
;   PAL2 slots 0..15 sequentially.  This preserves all 4 NES sprite sub-
;   palettes simultaneously, eliminating the multiplex loss.
;
; When 0: legacy last-write-wins sprite palette multiplex (SP0,SP2→PAL2,
;   SP1,SP3→PAL3).  Default until the expansion path is fully verified.
;
; See memory/project_chr_expansion.md for the staged rollout plan.
;------------------------------------------------------------------------------
CHR_EXPANSION_ENABLED equ 1

;------------------------------------------------------------------------------
; PPU state RAM — placed at $FF0800 (immediately after 2KB NES work RAM).
; Initialised to zero by genesis_shell before jsr IsrReset.
;
; Layout (12 bytes):
;   +0  PPU_LATCH   (byte) write-toggle shared by $2005/$2006 (0=1st, 1=2nd)
;   +1  (pad)
;   +2  PPU_VADDR   (word) assembled 16-bit VRAM address
;   +4  PPU_CTRL    (byte) PPUCTRL  ($2000) shadow
;   +5  PPU_MASK    (byte) PPUMASK  ($2001) shadow
;   +6  PPU_SCRL_X  (byte) scroll X (from first  $2005 write)
;   +7  PPU_SCRL_Y  (byte) scroll Y (from second $2005 write)
;   +8  PPU_DBUF    (byte) PPUDATA even-address byte buffer
;   +9  PPU_DHALF   (byte) 1 when an even-address byte is buffered
;   +10 (pad × 2)
;------------------------------------------------------------------------------
PPU_STATE_BASE  equ $00FF0800

PPU_LATCH       equ PPU_STATE_BASE+0    ; byte: w register (0=first write)
PPU_VADDR       equ PPU_STATE_BASE+2    ; word: current VRAM address
PPU_CTRL        equ PPU_STATE_BASE+4    ; byte: PPUCTRL shadow
PPU_MASK        equ PPU_STATE_BASE+5    ; byte: PPUMASK shadow
PPU_SCRL_X      equ PPU_STATE_BASE+6    ; byte: horizontal scroll value
PPU_SCRL_Y      equ PPU_STATE_BASE+7    ; byte: vertical scroll value
PPU_DBUF        equ PPU_STATE_BASE+8    ; byte: buffered even-addr byte
PPU_DHALF       equ PPU_STATE_BASE+9    ; byte: 1 if even-addr byte pending
AGS_PREDICT_NEXT equ PPU_STATE_BASE+1   ; byte: transient flag for predictive intro staging

;------------------------------------------------------------------------------
; MMC1 state RAM — placed at $FF0810 (immediately after 16-byte PPU block).
; Initialised to zero by genesis_shell before jsr IsrReset.
;
; Layout (6 bytes):
;   +0  MMC1_SHIFT  (byte) shift register accumulator (LSB-first)
;   +1  MMC1_COUNT  (byte) number of bits accumulated (0–4)
;   +2  MMC1_CTRL   (byte) MMC1 control register ($8000 target)
;   +3  MMC1_CHR0   (byte) CHR bank 0 register   ($A000 target)
;   +4  MMC1_CHR1   (byte) CHR bank 1 register   ($C000 target)
;   +5  MMC1_PRG    (byte) PRG bank register      ($E000 target)
;------------------------------------------------------------------------------
MMC1_STATE_BASE equ PPU_STATE_BASE+$10  ; $FF0810

MMC1_SHIFT      equ MMC1_STATE_BASE+0   ; byte: shift accumulator
MMC1_COUNT      equ MMC1_STATE_BASE+1   ; byte: bits accumulated (0-4)
MMC1_CTRL       equ MMC1_STATE_BASE+2   ; byte: control reg ($8000)
MMC1_CHR0       equ MMC1_STATE_BASE+3   ; byte: CHR bank 0 ($A000)
MMC1_CHR1       equ MMC1_STATE_BASE+4   ; byte: CHR bank 1 ($C000)
MMC1_PRG        equ MMC1_STATE_BASE+5   ; byte: PRG bank ($E000)

;------------------------------------------------------------------------------
; CHR tile upload buffer — placed at $FF0820.
; Accumulates one 16-byte NES 2BPP tile then converts it to Genesis 4BPP (32 bytes)
; and DMA-writes the result to VDP VRAM.
;
; Layout (21 bytes):
;   +0…+15  CHR_TILE_BUF  (16 bytes) raw NES 2BPP tile data
;              bytes 0–7  = plane 0 (bit 0 of each pixel, row 0 first)
;              bytes 8–15 = plane 1 (bit 1 of each pixel, row 0 first)
;   +16     CHR_BUF_CNT   (byte) number of bytes accumulated (0–15)
;   +17     (pad byte — keeps CHR_BUF_VADDR word-aligned)
;   +18–19  CHR_BUF_VADDR (word) NES PPU address at start of this tile  ← $FF0832 (even)
;   +20     CHR_HIT_COUNT (byte) total CHR write calls (debug counter)
;------------------------------------------------------------------------------
CHR_STATE_BASE  equ PPU_STATE_BASE+$20  ; $FF0820

CHR_TILE_BUF    equ CHR_STATE_BASE+0    ; 16 bytes: raw NES tile bytes
CHR_BUF_CNT     equ CHR_STATE_BASE+16   ; byte: bytes accumulated
                                         ; +17: pad byte (alignment)
CHR_BUF_VADDR   equ CHR_STATE_BASE+18   ; word: tile's NES base address ($FF0832, even)
CHR_HIT_COUNT   equ CHR_STATE_BASE+20   ; byte: total CHR write calls (debug counter)

;------------------------------------------------------------------------------
; Nametable tile-index cache — placed at $FF0840.
; 32 × 60 = 1920 bytes (NT0 rows 0-29 + NT1 rows 30-59 for V64 plane).
; NT_CACHE[row*32 + col] = tile index.  NT1 entries at offset 960.
;------------------------------------------------------------------------------
NT_CACHE_BASE   equ CHR_STATE_BASE+$20  ; $FF0840  (32×60 = 1920 bytes)

;------------------------------------------------------------------------------
; CHR tile write cache — placed at $FF0FC0 (right after NT_CACHE).
; 512 tiles × 16 bytes = 8192 bytes.  Indexed by (NES_addr & $1FF0).
; Tiles $0000-$0FFF = sprite half (256 tiles), $1000-$1FFF = BG half (256 tiles).
; On each tile upload, compare new data vs cache.  If identical, skip the
; VRAM write entirely.  For sprite tiles this saves 4× VRAM copies.
;------------------------------------------------------------------------------
CHR_CACHE_BASE  equ $FF0FC0              ; 8192 bytes: $FF0FC0..$FF2FBF
CHR_CACHE_HITS  equ $FF2FC0              ; word: cache hit count (debug)
CHR_CACHE_MISS  equ $FF2FC2              ; word: cache miss count (debug)

;------------------------------------------------------------------------------
; Scroll register cache — skip VDP writes when values are unchanged.
; Placed at $FF2FC4 (right after CHR cache debug counters).
; 8 bytes: $FF2FC4..$FF2FCB.  Cleared to zero by genesis_shell RAM init.
;------------------------------------------------------------------------------
PREV_SCROLL_MODE equ $FF2FC4             ; byte: last-written INTRO_SCROLL_MODE
PREV_HINT_CTR    equ $FF2FC5             ; byte: last-written H-int Reg 10 counter
PREV_BASE_VSRAM  equ $FF2FC6             ; word: last-written base VSRAM value
PREV_EVENT_VSRAM equ $FF2FC8             ; word: last-written event VSRAM value
PREV_HSCROLL     equ $FF2FCA             ; word: last-written H-scroll value

;------------------------------------------------------------------------------
; Staged scroll state written by _ags_flush and consumed by _ags_prearm on the
; next frame. Lives in the unused tail of the PPU shadow block at $FF080A..0F.
;------------------------------------------------------------------------------
STAGED_SCROLL_MODE equ PPU_STATE_BASE+$0A ; byte: next-frame mode
STAGED_HINT_CTR    equ PPU_STATE_BASE+$0B ; byte: next-frame Reg 10 counter
STAGED_BASE_VSRAM  equ PPU_STATE_BASE+$0C ; word: next-frame start-of-frame VSRAM
STAGED_EVENT_VSRAM equ PPU_STATE_BASE+$0E ; word: next-frame H-int VSRAM

;------------------------------------------------------------------------------
; Active scroll state promoted by _ags_prearm and consumed by the currently
; rendered frame. Stored in the unused tail between CHR state and NT cache.
;------------------------------------------------------------------------------
ACTIVE_BASE_VSRAM  equ CHR_STATE_BASE+$16 ; $FF0836 word: current-frame base VSRAM
ACTIVE_EVENT_VSRAM equ CHR_STATE_BASE+$18 ; $FF0838 word: current-frame event VSRAM
ACTIVE_HINT_CTR    equ CHR_STATE_BASE+$1A ; $FF083A byte: current-frame Reg 10 counter
STAGED_SEGMENT     equ CHR_STATE_BASE+$1B ; $FF083B byte: next-frame story segment
ACTIVE_SEGMENT     equ CHR_STATE_BASE+$1C ; $FF083C byte: current-frame story segment

;------------------------------------------------------------------------------
; Scroll composition modes shared between staged state and INTRO_SCROLL_MODE.
; Mode 1 is gameplay sprite-0 split only; intro phase 1 uses mode 2.
;------------------------------------------------------------------------------
INTRO_SCROLL_NO_SPLIT   equ 0
INTRO_SCROLL_GAME_SPLIT equ 1
INTRO_SCROLL_DZ_SKIP    equ 2

;------------------------------------------------------------------------------
; Story segment classifier used by _ags_compute_stage and the live hook.
;------------------------------------------------------------------------------
AGS_SEG_OTHER               equ 0
AGS_SEG_STORY0_SCROLL_ON    equ 1
AGS_SEG_STORY2_SCROLL_BODY  equ 2
AGS_SEG_STORY2_HOLD_STOP    equ 3
AGS_SEG_STORY2_WRAP_RELEASE equ 4
AGS_SEG_ITEM_BODY_DIRECT    equ 5
AGS_SEG_ITEM_BODY_WRAP      equ 6
AGS_SEG_ITEM_TAIL_RELEASE   equ 7

;==============================================================================
; PPU register reads ($2000–$2007 → _ppu_read_0 … _ppu_read_7)
;==============================================================================

;------------------------------------------------------------------------------
; _ppu_read_0 — PPUCTRL ($2000) — write-only on real NES, reads return open bus.
; Return 0 so caller's AND/BEQ tests see nothing set.
;------------------------------------------------------------------------------
_ppu_read_0:
    moveq   #0,D0
    rts

;------------------------------------------------------------------------------
; _ppu_read_1 — PPUMASK ($2001) — write-only, open bus.
;------------------------------------------------------------------------------
_ppu_read_1:
    moveq   #0,D0
    rts

;------------------------------------------------------------------------------
; _ppu_read_2 — PPUSTATUS ($2002)
;
; Bit 7 = VBlank flag.  Cleared on read.  The shared write-latch (w) is also
; reset on any $2002 read.
;
; T5 implementation: always returns $80 (VBlank always set) so IsrReset's
; two warmup polling loops exit immediately.  A real VBlank flag will be
; wired in T6 (software flag toggled by VBlankISR).
;
; IMPORTANT: must reset the PPU write-latch (PPU_LATCH).
;------------------------------------------------------------------------------
_ppu_read_2:
    clr.b   (PPU_LATCH).l          ; reading $2002 resets the w register
    move.b  #$80,D0                ; VBlank flag set (warmup loops will exit)
    rts

;------------------------------------------------------------------------------
; _ppu_read_3 — OAM addr ($2003) — write-only.
; _ppu_read_4 — OAM data ($2004) — return 0 for now.
; _ppu_read_5 — PPUSCROLL ($2005) — write-only.
; _ppu_read_6 — PPUADDR  ($2006) — write-only.
;------------------------------------------------------------------------------
_ppu_read_3:
_ppu_read_4:
_ppu_read_5:
_ppu_read_6:
    moveq   #0,D0
    rts

;------------------------------------------------------------------------------
; _ppu_read_7 — PPUDATA ($2007) read
;
; T5: return 0.  Palette reads have a special one-cycle-delay buffer on real
; NES hardware.  No reads of $2007 in Zelda's critical path; defer to T8+.
;------------------------------------------------------------------------------
_ppu_read_7:
    moveq   #0,D0
    rts

;==============================================================================
; PPU register writes ($2000–$2007 → _ppu_write_0 … _ppu_write_7)
;==============================================================================

;------------------------------------------------------------------------------
; _ppu_write_0 — PPUCTRL ($2000)
;
; D0.b = value to write.
; Bits of interest:
;   bit 2 = VRAM address increment (0 → +1 horizontal, 1 → +32 vertical)
;   bit 7 = NMI enable (0 = disable, 1 = enable on VBlank)
;
; We store the value so _ppu_write_7 can read the increment flag.
; NMI enable is handled at the hardware level (VBlank ISR always fires);
; Zelda controls this register to gate per-frame updates.
;------------------------------------------------------------------------------
_ppu_write_0:
    ; Check if bit 4 (BG pattern table) changed — if so, update Plane A tiles
    move.b  (PPU_CTRL).l,D1
    eor.b   D0,D1                   ; D1 = changed bits
    move.b  D0,(PPU_CTRL).l         ; store new value
    btst    #4,D1
    bne.s   .ppuw0_pt_changed
    rts
.ppuw0_pt_changed:
    ; BG pattern table bit changed.  Rebuild all 960 Plane A tile words from
    ; NT_CACHE, applying the new PPUCTRL bit 4 offset.  Palette bits are set
    ; to 0 (subsequent attribute processing will restore correct palettes).
    movem.l D0-D5/A0-A1,-(SP)

    lea     (NT_CACHE_BASE).l,A0
    move.w  #$C000,D2               ; Plane A VDP address

    moveq   #30-1,D3                ; 30 rows
.ppuw0_row:
    moveq   #32-1,D4                ; 32 cols
.ppuw0_col:
    ; Build tile word from NT_CACHE
    moveq   #0,D0
    move.b  (A0)+,D0                ; raw tile index from cache
    bsr     _compose_bg_tile_word

    ; Issue VDP write command for current Plane A address
    moveq   #0,D1
    move.w  D2,D1
    andi.l  #$00003FFF,D1
    swap    D1
    ori.l   #$40000003,D1
    move.l  D1,(VDP_CTRL).l
    move.w  D0,(VDP_DATA).l

    addq.w  #2,D2                   ; next col
    dbf     D4,.ppuw0_col

    addi.w  #$40,D2                 ; skip 32 unused cols in 64-wide plane
    dbf     D3,.ppuw0_row

    movem.l (SP)+,D0-D5/A0-A1
    rts

;------------------------------------------------------------------------------
; _ppu_write_1 — PPUMASK ($2001)
; Store shadow for potential video-enable logic in T6+.
;------------------------------------------------------------------------------
_ppu_write_1:
    move.b  D0,(PPU_MASK).l
    ; Toggle VDP display enable to match NES PPUMASK rendering state.
    ; When NES BG+sprites are off (bits 3-4 = 0), blank the Genesis display
    ; to prevent stale VRAM content from showing during mode transitions.
    move.w  D0,-(SP)
    andi.b  #$18,D0                 ; isolate BG (bit 3) + sprites (bit 4)
    bne.s   .ppuw1_display_on
    ; Display OFF: VDP Reg 1 = $34 (display disabled, VBlank IRQ, DMA, M5)
    move.w  #$8134,(VDP_CTRL).l
    move.w  (SP)+,D0
    rts
.ppuw1_display_on:
    ; Display ON: VDP Reg 1 = $74 (display enabled, VBlank IRQ, DMA, M5)
    move.w  #$8174,(VDP_CTRL).l
    move.w  (SP)+,D0
    rts

;------------------------------------------------------------------------------
; _ppu_write_2 — PPUSTATUS ($2002) — write-only on real NES (no effect).
;------------------------------------------------------------------------------
_ppu_write_2:
    rts

;------------------------------------------------------------------------------
; _ppu_write_3 — OAM address ($2003) — store for future OAM DMA logic.
;------------------------------------------------------------------------------
_ppu_write_3:
    rts

;------------------------------------------------------------------------------
; _ppu_write_4 — OAM data ($2004) — T5: stub (OAM DMA via $4014 covers Zelda).
;------------------------------------------------------------------------------
_ppu_write_4:
    rts

;------------------------------------------------------------------------------
; _ppu_write_5 — PPUSCROLL ($2005)
;
; First  write (PPU_LATCH=0): horizontal scroll → PPU_SCRL_X, latch → 1.
; Second write (PPU_LATCH=1): vertical   scroll → PPU_SCRL_Y, latch → 0.
;
; Writing to VDP scroll registers is deferred to T6 (visual output pass).
; For T5 we just store the values so they're available when needed.
;------------------------------------------------------------------------------
_ppu_write_5:
    movem.l D1,-(SP)
    move.b  (PPU_LATCH).l,D1
    tst.b   D1
    bne.s   .second_write_5
    ; First write — horizontal scroll
    move.b  D0,(PPU_SCRL_X).l
    move.b  #1,(PPU_LATCH).l
    movem.l (SP)+,D1
    rts
.second_write_5:
    ; Second write — vertical scroll
    move.b  D0,(PPU_SCRL_Y).l
    clr.b   (PPU_LATCH).l
    movem.l (SP)+,D1
    rts

;------------------------------------------------------------------------------
; _apply_genesis_scroll — current-frame scroll apply hook.
;
; The transpiler injects `bsr _apply_genesis_scroll` twice inside IsrNmi:
;   P1 after SetScroll updates the current frame's PPU shadows
;   P2 after later game logic may have prepared next-frame shadows
;
; We want the CURRENT frame's VDP state to come from the latest finalized
; scroll shadows that are still available during vblank. So each hook always
; recomputes staged state, but it only promotes/applies that state while the
; VDP still reports vblank active. Once vblank has ended, the hook stages
; state for the NEXT frame only and leaves the live frame alone.
;
; Preserves: D5-D7, A0-A6.
;------------------------------------------------------------------------------
_apply_genesis_scroll:
    movem.l D0-D4,-(SP)
    bsr     _ags_compute_stage
    ; Story frames are owned entirely by PREARM's promoted active state. If a
    ; later IsrNmi hook rewrites VSRAM mid-NMI, visible rows can come from two
    ; different frame states and the full screen appears to vibrate/teleport.
    cmpi.b  #AGS_SEG_STORY2_HOLD_STOP,D4
    beq.s   .ags_maybe_apply
    tst.b   D4
    bne.s   .ags_hook_done
.ags_maybe_apply:
    move.w  (VDP_CTRL).l,D0            ; VDP status read
    btst    #3,D0                      ; bit 3 = VBlank active
    beq.s   .ags_hook_done
    bsr     _ags_activate_staged
    bsr     _ags_apply_active
.ags_hook_done:
    movem.l (SP)+,D0-D4
    rts

;------------------------------------------------------------------------------
; _ags_compute_stage — Convert current NES scroll shadows into staged Genesis
;                      composition state for one whole frame.
;
; Assumes A4 = NES RAM base ($FF0000). Writes STAGED_* only.
; Clobbers D0-D4, leaving D4 = AGS_SEG_* for the staged story segment.
;------------------------------------------------------------------------------
_ags_compute_stage:
    ; --- Compute base VSRAM: vs + 8 + (nt ? 240 : 0) ---
    moveq   #0,D0
    move.b  ($00FC,A4),D0               ; CurVScroll (0-239)
    addi.w  #8,D0                       ; +8px overscan
    move.b  ($00FF,A4),D1               ; CurPpuControl
    tst.b   ($005C,A4)                  ; SwitchNameTablesReq pending?
    beq.s   .agc_no_pending
    eori.b  #$02,D1                     ; pre-toggle NT select bit
.agc_no_pending:
    btst    #1,D1                       ; nametable Y select?
    beq.s   .agc_no_nt_offset
    addi.w  #240,D0                     ; NT1: +240
.agc_no_nt_offset:
    ; D0 = raw base VSRAM (8-487)
    move.w  D0,D2                       ; D2 = current raw base before prediction

    ; Story segment classifier. Story frames are staged for PREARM ownership;
    ; gameplay and everything else stay on the old live-apply path.
    moveq   #AGS_SEG_OTHER,D4
    tst.b   ($0012,A4)                  ; gameMode == 0?
    bne.s   .agc_have_segment
    cmpi.b  #$01,($042C,A4)             ; phase == 1?
    bne.s   .agc_have_segment
    move.b  ($042D,A4),D4               ; subphase
    beq.s   .agc_seg_story0
    cmpi.b  #$02,D4
    bne.s   .agc_seg_other
    cmpi.b  #$05,($042E,A4)             ; item-roll pages start at text index 5
    bcc.s   .agc_seg_item
    moveq   #AGS_SEG_STORY2_SCROLL_BODY,D4
    cmpi.b  #$E0,($00FC,A4)             ; first full-screen E0 frame predicts
    bne.s   .agc_story2_hold_ctrl       ; the next frame's pause/hold state
    move.b  (PPU_SCRL_Y).l,D3
    cmp.b   ($00FC,A4),D3
    bne.s   .agc_seg_story2_hold
.agc_story2_hold_ctrl:
    btst    #7,($00FF,A4)               ; transient hold frame clears NMI bit
    bne.s   .agc_have_segment
 .agc_seg_story2_hold:
    moveq   #AGS_SEG_STORY2_HOLD_STOP,D4
    bra.s   .agc_have_segment
.agc_seg_item:
    moveq   #AGS_SEG_ITEM_BODY_DIRECT,D4
    tst.b   ($005C,A4)                  ; wrapped item-roll seam pending?
    beq.s   .agc_have_segment
    tst.b   ($00FC,A4)                  ; only classify the seam at curV == 0
    bne.s   .agc_have_segment
    cmpi.b  #$0B,($042E,A4)             ; final item page uses a distinct tail release
    bcs.s   .agc_seg_item_wrap
    moveq   #AGS_SEG_ITEM_TAIL_RELEASE,D4
    bra.s   .agc_have_segment
.agc_seg_item_wrap:
    moveq   #AGS_SEG_ITEM_BODY_WRAP,D4
    bra.s   .agc_have_segment
.agc_seg_story0:
    moveq   #AGS_SEG_STORY0_SCROLL_ON,D4
    bra.s   .agc_have_segment
.agc_seg_other:
    moveq   #AGS_SEG_OTHER,D4
.agc_have_segment:
    move.b  D4,(STAGED_SEGMENT).l

    ; Phase-1/subphase-2 body frames (story tail + attract item roll) do not
    ; want the freshly-updated CurVScroll as their visible source. The NES-like
    ; cadence in these long direct-scroll windows comes from the current frame's
    ; visible scroll shadow ($2005 Y / PPU_SCRL_Y), which lags CurVScroll by one
    ; half-step. Using CurVScroll here advances the whole picture on the wrong
    ; half of the two-frame cadence and makes the item/text roll jump.
    cmpi.b  #AGS_SEG_STORY2_SCROLL_BODY,D4
    beq.s   .agc_phase12_body_base
    cmpi.b  #AGS_SEG_ITEM_BODY_DIRECT,D4
    beq.s   .agc_phase12_body_base
    cmpi.b  #AGS_SEG_ITEM_BODY_WRAP,D4
    beq.s   .agc_phase12_body_base
    cmpi.b  #AGS_SEG_ITEM_TAIL_RELEASE,D4
    beq.s   .agc_item_tail_base
    bne.s   .agc_story0_base_setup
.agc_phase12_body_base:
    moveq   #0,D0
    move.b  (PPU_SCRL_Y).l,D0
    addi.w  #8,D0
    move.b  ($00FF,A4),D1
    tst.b   ($005C,A4)
    beq.s   .agc_story2_no_pending
    eori.b  #$02,D1
.agc_story2_no_pending:
    btst    #1,D1
    beq.s   .agc_story2_base_ready
    addi.w  #240,D0
.agc_story2_base_ready:
    move.w  D0,D2
    bra.s   .agc_story0_base_setup

.agc_item_tail_base:
    moveq   #0,D0
    move.b  ($00FC,A4),D0
    addi.w  #8,D0
    move.b  ($00FF,A4),D1
    tst.b   ($005C,A4)
    beq.s   .agc_item_tail_no_pending
    eori.b  #$02,D1
.agc_item_tail_no_pending:
    btst    #1,D1
    beq.s   .agc_item_tail_base_ready
    addi.w  #240,D0
.agc_item_tail_base_ready:
    move.w  D0,D2

 .agc_story0_base_setup:
    ; Scroll-on frames need two distinct formulas:
    ;   before the page fills the screen, follow the prebuilt V64 page using
    ;   the visible PPU scroll shadow
    ;   after the page has wrapped once, follow CurVScroll directly so the
    ;   fully-visible story keeps the NES move/hold cadence instead of
    ;   jumping when the NES nametable bit flips
    cmpi.b  #AGS_SEG_STORY0_SCROLL_ON,D4
    bne.s   .agc_story0_base_done
    moveq   #0,D0
    tst.b   ($0415,A4)                   ; DemoNTWraps == 0 until the story
    bne.s   .agc_story0_post_top         ; first reaches the top of the screen
    move.b  (PPU_SCRL_Y).l,D0            ; visible scroll shadow for the
                                         ; prebuilt story page
    addi.w  #40,D0                       ; overscan + V64 dead-zone
    addi.w  #240,D0                      ; story page starts in the upper half
    bra.s   .agc_story0_have_base_src
.agc_story0_post_top:
    move.b  ($00FC,A4),D0                ; once fully on-screen, CurVScroll
    addi.w  #7,D0                        ; gives the NES-consistent cadence
.agc_story0_have_base_src:
    move.w  D0,D2
.agc_story0_base_done:

    ; _ags_flush stages the NEXT intro frame before that frame's NMI runs.
    ; During phase 1, UpdateMode advances the demo/item scroll every other
    ; frame after FrameCounter increments inside IsrNmi. We only need to
    ; predict that next tick while approaching the seam/hold logic; predicting
    ; ordinary direct-scroll frames makes the item roll move one frame earlier
    ; than the NES and causes the text/items to "jump" on the wrong half of
    ; the two-frame cadence.
    cmpi.b  #AGS_SEG_OTHER,D4
    beq.s   .agc_have_prediction
    cmpi.b  #AGS_SEG_STORY0_SCROLL_ON,D4
    beq.s   .agc_have_prediction         ; story0 already stages the visible
                                         ; frame; predicting it causes the
                                         ; top-hit teleport cadence
    tst.b   (AGS_PREDICT_NEXT).l
    beq.s   .agc_have_prediction
    cmpi.b  #AGS_SEG_STORY2_SCROLL_BODY,D4
    beq.s   .agc_body_predict_parity
    cmpi.b  #AGS_SEG_ITEM_BODY_DIRECT,D4
    beq.s   .agc_body_predict_parity
    cmpi.b  #AGS_SEG_ITEM_BODY_WRAP,D4
    beq.s   .agc_item_wrap_predict
    cmpi.b  #AGS_SEG_ITEM_TAIL_RELEASE,D4
    beq.s   .agc_have_prediction        ; tail release shows the new-page
                                        ; curV=0 frame before ordinary body
                                        ; cadence resumes on the next frame
    bne.s   .agc_default_predict
.agc_item_wrap_predict:
    move.w  #$0007,D0                   ; first wrapped item-body frame aligns to NT0 top perfectly (-1px for NES deferred wrap)
    bra.s   .agc_have_prediction
.agc_body_predict_parity:
    btst    #0,($0015,A4)               ; body cadence: odd frame -> next frame
    beq.s   .agc_have_prediction        ; advances one visible tick
    bra.s   .agc_do_predict
.agc_default_predict:
    btst    #0,($0015,A4)               ; FrameCounter odd?
    bne.s   .agc_have_prediction        ; odd => next frame keeps same scroll
.agc_do_predict:
    addq.w  #1,D0                       ; predict one visible scroll tick
.agc_have_prediction:
    move.w  D0,D3                       ; D3 = predicted raw base before wrap

    ; Story scroll-on uses the full 0..511 V64 range. Do not collapse the
    ; final dead-zone rows into 0..31 until the seam is actually crossed.
    cmpi.b  #AGS_SEG_STORY0_SCROLL_ON,D4
    bne.s   .agc_case3_collapse
    cmpi.w  #512,D0
    blo.s   .agc_story0_have_base
    subi.w  #512,D0
.agc_story0_have_base:
    move.b  #INTRO_SCROLL_NO_SPLIT,(STAGED_SCROLL_MODE).l
    move.w  D0,(STAGED_BASE_VSRAM).l
    clr.b   (STAGED_HINT_CTR).l
    move.w  D0,(STAGED_EVENT_VSRAM).l
    rts

    ; --- Case 3 collapse: raw VSRAM >= 472 → wrap to top of the 480px map ---
.agc_case3_collapse:
    cmpi.w  #472,D0
    blt.s   .agc_have_base
    subi.w  #480,D0
.agc_have_base:
    ; D0 = effective base VSRAM (0..479)

    ; --- Default staged state: direct scroll, no H-int event ---
    move.b  #INTRO_SCROLL_NO_SPLIT,(STAGED_SCROLL_MODE).l
    move.w  D0,(STAGED_BASE_VSRAM).l
    clr.b   (STAGED_HINT_CTR).l
    move.w  D0,(STAGED_EVENT_VSRAM).l

    ; Gameplay sprite-0 split: pin the top band at VSRAM=0, then switch to
    ; the real base at scanline 40.
    tst.b   ($00E3,A4)                  ; IsSprite0CheckActive
    bne     .agc_stage_game_split

    ; Transient full-screen hold frame: preserve the already-promoted active
    ; base for this frame and keep H-int disabled.
    cmpi.b  #AGS_SEG_STORY2_HOLD_STOP,D4
    bne.s   .agc_story_phase2
    move.w  (ACTIVE_EVENT_VSRAM).l,D1
    move.w  D1,(STAGED_BASE_VSRAM).l
    clr.b   (STAGED_HINT_CTR).l
    move.w  D1,(STAGED_EVENT_VSRAM).l
    rts

.agc_story_phase2:
    ; Intro phase 1 story scroll is treated as an explicit composition state
    ; machine:
    ;   direct scroll      -> story not intersecting the V64 dead-zone
    ;   enter/full wrap    -> split from wrapped base to wrapped base+32
    ;   exit wrap          -> one release frame from $01FF -> $0000
    ;   offscreen finish   -> pure direct scroll after the release frame
    cmpi.b  #AGS_SEG_STORY2_SCROLL_BODY,D4
    beq.s   .agc_story_phase2_active
    cmpi.b  #AGS_SEG_STORY2_WRAP_RELEASE,D4
    beq.s   .agc_story_phase2_active
    cmpi.b  #AGS_SEG_ITEM_BODY_DIRECT,D4
    beq.s   .agc_item_dz_check
    bra     .agc_done
.agc_item_dz_check:
    cmpi.w  #257,D3
    blo     .agc_done
    cmpi.w  #480,D3
    bhs     .agc_done
    bra.s   .agc_story_enter_wrap
.agc_story_phase2_active:
    cmpi.w  #257,D3
    blo     .agc_done                      ; story_full_scroll / offscreen_finish
    cmpi.w  #472,D3
    bhi     .agc_done                      ; wrapped direct scroll after release
    move.b  ($00FC,A4),D1
    cmpi.b  #$E8,D1
    bne.s   .agc_story_phase2_seam_checks
    cmp.b   (PPU_SCRL_Y).l,D1
    bne     .agc_done                      ; first E8 frame: next frame is
                                          ; plain direct-scroll $0000
.agc_story_phase2_seam_checks:
    cmpi.w  #472,D3
    beq.s   .agc_story_seam_frame          ; first seam frame: predicted next scroll lands on seam
.agc_story_enter_wrap:
    move.b  #INTRO_SCROLL_DZ_SKIP,(STAGED_SCROLL_MODE).l
    move.w  (STAGED_BASE_VSRAM).l,D1
    addi.w  #32,D1
    move.w  D1,(STAGED_EVENT_VSRAM).l
    move.w  #480,D1                     ; dead zone starts at V64 row 480
    sub.w   D3,D1
    subq.w  #1,D1
    move.b  D1,(STAGED_HINT_CTR).l
    rts

.agc_story_seam_frame:
    move.b  #AGS_SEG_STORY2_WRAP_RELEASE,(STAGED_SEGMENT).l
    moveq   #AGS_SEG_STORY2_WRAP_RELEASE,D4
    ; Predicted seam frame: let the new top-of-page content appear immediately
    ; in the top band, but keep the old wrapped seam in the lower band until
    ; visible row 24. This matches the NES's last seam transition much more
    ; closely than "top old / bottom new".
    move.b  #INTRO_SCROLL_DZ_SKIP,(STAGED_SCROLL_MODE).l
    clr.w   (STAGED_BASE_VSRAM).l
    move.w  #$01FF,(STAGED_EVENT_VSRAM).l
    move.b  #23,(STAGED_HINT_CTR).l        ; release lower band at visible row 24
    rts

.agc_stage_game_split:
    move.b  #INTRO_SCROLL_GAME_SPLIT,(STAGED_SCROLL_MODE).l
    clr.w   (STAGED_BASE_VSRAM).l
    move.b  #39,(STAGED_HINT_CTR).l
    move.w  D0,(STAGED_EVENT_VSRAM).l
.agc_done:
    rts

;------------------------------------------------------------------------------
; _ags_flush — Stage the NEXT frame's Genesis composition state and write
;              H-scroll after IsrNmi has finalized the scroll shadows.
;
; This must not touch active-frame VSRAM/H-int state; the first
; _apply_genesis_scroll hook inside IsrNmi owns current-frame application.
;
; Preserves: D5-D7, A0-A6.
;------------------------------------------------------------------------------
_ags_flush:
    movem.l D0-D4,-(SP)
    move.b  #1,(AGS_PREDICT_NEXT).l
    bsr     _ags_compute_stage
    clr.b   (AGS_PREDICT_NEXT).l

.ags_hscroll:
    ; --- H-scroll (Plane A H-scroll table entry 0) ---
    moveq   #0,D0
    move.b  ($00FD,A4),D0              ; CurHScroll
    neg.w   D0
    andi.w  #$01FF,D0
    cmp.w   (PREV_HSCROLL).l,D0
    beq.s   .ags_hscroll_skip          ; unchanged — skip VRAM write
    move.w  D0,(PREV_HSCROLL).l
    move.l  #$7C000003,(VDP_CTRL).l    ; VRAM write at $FC00
    move.w  D0,(VDP_DATA).l            ; Plane A H-scroll
    moveq   #0,D0
    move.w  D0,(VDP_DATA).l            ; Plane B H-scroll = 0
.ags_hscroll_skip:
    movem.l (SP)+,D0-D4
    rts

;------------------------------------------------------------------------------
; _ags_prearm — Promote the previously staged scroll state into the active
;               queue at START of vblank, BEFORE IsrNmi runs. This guarantees
;               a coherent current-frame fallback even if the post-NMI flush
;               finishes too late to safely touch VDP state for the same frame.
;
; Promotes the staged scroll state prepared by the previous frame's _ags_flush
; into the active queue consumed by HBlankISR, then applies it immediately.
;
; Reads:  STAGED_SCROLL_MODE, STAGED_HINT_CTR, STAGED_BASE_VSRAM,
;         STAGED_EVENT_VSRAM
; Writes: HINT_Q_COUNT, HINT_Q0_CTR, HINT_Q0_VSRAM, HINT_PEND_SPLIT,
;         INTRO_SCROLL_MODE
; Preserves: D1-D7, A0-A6  (clobbers D0 internally, saved/restored)
;------------------------------------------------------------------------------
_ags_prearm:
    movem.l D0,-(SP)
    bsr     _ags_activate_staged
    bsr     _ags_apply_active
    movem.l (SP)+,D0
    rts

;------------------------------------------------------------------------------
; _ags_activate_staged — Promote STAGED_* into the active queue/debug state.
; Clobbers D0.
;------------------------------------------------------------------------------
_ags_activate_staged:
    move.b  (STAGED_SCROLL_MODE).l,D0
    move.b  D0,(INTRO_SCROLL_MODE).l
    move.w  (STAGED_BASE_VSRAM).l,(ACTIVE_BASE_VSRAM).l
    move.w  (STAGED_EVENT_VSRAM).l,(ACTIVE_EVENT_VSRAM).l
    move.b  (STAGED_HINT_CTR).l,(ACTIVE_HINT_CTR).l
    move.b  (STAGED_SEGMENT).l,(ACTIVE_SEGMENT).l
    cmpi.b  #INTRO_SCROLL_NO_SPLIT,D0
    beq.s   .aas_no_split
    move.b  #1,(HINT_PEND_SPLIT).l
    move.b  #1,(HINT_Q_COUNT).l
    move.b  (STAGED_HINT_CTR).l,(HINT_Q0_CTR).l
    move.w  (STAGED_EVENT_VSRAM).l,(HINT_Q0_VSRAM).l
    rts
.aas_no_split:
    move.b  #0,(HINT_PEND_SPLIT).l
    move.b  #0,(HINT_Q_COUNT).l
    rts

;------------------------------------------------------------------------------
; _ags_apply_active — Program VDP VSRAM/H-int state for the current frame from
; the active queue/debug state set by _ags_activate_staged. For no-split and
; intro dead-zone modes, the base VSRAM comes from ACTIVE_BASE_VSRAM.
;
; Clobbers D0.
;------------------------------------------------------------------------------
_ags_apply_active:
    ; --- Scroll register cache: skip VDP writes if nothing changed ---
    move.b  (INTRO_SCROLL_MODE).l,D0
    cmp.b   (PREV_SCROLL_MODE).l,D0
    bne.s   .aaa_changed
    move.w  (ACTIVE_BASE_VSRAM).l,D0
    cmp.w   (PREV_BASE_VSRAM).l,D0
    bne.s   .aaa_changed
    move.w  (ACTIVE_EVENT_VSRAM).l,D0
    cmp.w   (PREV_EVENT_VSRAM).l,D0
    bne.s   .aaa_changed
    move.b  (ACTIVE_HINT_CTR).l,D0
    cmp.b   (PREV_HINT_CTR).l,D0
    bne.s   .aaa_changed
    rts                                         ; all unchanged — skip VDP writes
.aaa_changed:
    ; Update previous-value cache
    move.b  (INTRO_SCROLL_MODE).l,(PREV_SCROLL_MODE).l
    move.w  (ACTIVE_BASE_VSRAM).l,(PREV_BASE_VSRAM).l
    move.w  (ACTIVE_EVENT_VSRAM).l,(PREV_EVENT_VSRAM).l
    move.b  (ACTIVE_HINT_CTR).l,(PREV_HINT_CTR).l

    cmpi.b  #INTRO_SCROLL_NO_SPLIT,(INTRO_SCROLL_MODE).l
    bne.s   .aaa_split
    move.w  #$8AFF,(VDP_CTRL).l             ; Reg 10 = $FF (inactive)
    move.w  #$8004,(VDP_CTRL).l             ; Reg 0: H-int off
    move.l  #VSRAM_WRITE_0000,(VDP_CTRL).l
    move.w  (ACTIVE_BASE_VSRAM).l,(VDP_DATA).l
    moveq   #0,D0
    move.w  D0,(VDP_DATA).l
    rts
.aaa_split:
    move.l  #VSRAM_WRITE_0000,(VDP_CTRL).l
    moveq   #0,D0
    cmpi.b  #INTRO_SCROLL_GAME_SPLIT,(INTRO_SCROLL_MODE).l
    beq.s   .aaa_base_ready
    move.w  (ACTIVE_BASE_VSRAM).l,D0
.aaa_base_ready:
    move.w  D0,(VDP_DATA).l
    moveq   #0,D0
    move.w  D0,(VDP_DATA).l
    moveq   #0,D0
    move.b  (HINT_Q0_CTR).l,D0
    andi.w  #$00FF,D0
    or.w    #$8A00,D0
    move.w  D0,(VDP_CTRL).l                 ; Reg 10 = active H-int scanline
    move.w  #$8014,(VDP_CTRL).l             ; Reg 0: enable H-int (+colorfix bit)
    rts



;------------------------------------------------------------------------------
; _ppu_write_6 — PPUADDR ($2006)  ← T5 key implementation
;
; The NES PPU address register uses a two-write protocol (shared "w" latch):
;   First  write: high byte of 15-bit VRAM address (bit 14 is forced clear by
;                 hardware — valid VRAM is $0000–$3FFF).
;   Second write: low byte.  After this write PPU_VADDR is fully updated and
;                 the latch resets to 0.
;
; Side effect: resets the even-byte PPUDATA buffer (PPU_DHALF = 0) so that a
; fresh address is always treated as the start of a new word-pair.
;
; Preserves: D1.
;------------------------------------------------------------------------------
_ppu_write_6:
    movem.l D1,-(SP)
    move.b  (PPU_LATCH).l,D1
    tst.b   D1
    bne.s   .second_write_6
    ; ---- First write: high byte ----
    ; High byte goes into PPU_VADDR+0.  Force bit 6 (addr bit 14) clear to
    ; keep address in the valid $0000–$3FFF window (matches NES hardware).
    andi.b  #$3F,D0
    move.b  D0,(PPU_VADDR).l        ; store high byte
    move.b  #1,(PPU_LATCH).l
    movem.l (SP)+,D1
    rts
.second_write_6:
    ; ---- Second write: low byte ----
    move.b  D0,(PPU_VADDR+1).l      ; store low byte
    clr.b   (PPU_LATCH).l           ; reset w register
    clr.b   (PPU_DHALF).l           ; discard any pending even-byte buffer
    movem.l (SP)+,D1
    rts

;------------------------------------------------------------------------------
; _ppu_write_7 — PPUDATA ($2007)  ← T16 full implementation
;
; Routes byte writes to one of two paths based on PPU_VADDR:
;
;   CHR-RAM path  (PPU_VADDR $0000–$1FFF):
;     Accumulates 16 bytes per NES tile in CHR_TILE_BUF, then on the 16th
;     byte converts the 2BPP NES tile to 4BPP Genesis format and writes the
;     32-byte result to VDP VRAM at Genesis addr = NES_addr × 2.
;
;   Nametable/palette path (PPU_VADDR $2000–$3FFF):
;     Buffers even-address bytes and flushes pairs as 16-bit VDP words
;     (unchanged from T5 — correct for nametable clears and palette writes).
;
; NES 2BPP → Genesis 4BPP conversion:
;   16 bytes in: 8 bytes plane-0 then 8 bytes plane-1 (one bit per pixel)
;   32 bytes out: 4 bytes per row, 2 pixels per byte, high-nibble = left pixel
;   Pixel color = (plane1_bit << 1) | plane0_bit   (values 0–3)
;
; VDP auto-increment = 2 (Reg 15 = $8F02 set by genesis_shell).
; PPU_VADDR increments by 1 (horizontal mode, bit 2 of PPUCTRL = 0).
;
; Preserves: D0–D6, A0–A6 (all saved/restored).
;------------------------------------------------------------------------------
_ppu_write_7:
    movem.l D0-D6/A0-A1,-(SP)       ; save all working registers (A1 used by LUT in .chr_convert_upload)

    move.w  (PPU_VADDR).l,D1        ; D1 = current NES PPU address

    ; Route: CHR range ($0000–$1FFF) vs nametable/palette ($2000–$3FFF)
    cmpi.w  #$2000,D1
    bhs     .nt_write               ; ≥$2000 → nametable / palette path

    ;==========================================================================
    ; CHR TILE BUFFER PATH
    ;==========================================================================
    ; Buffer each byte.  On the 16th byte, convert the tile and upload it.
    addq.b  #1,(CHR_HIT_COUNT).l   ; DEBUG: count every CHR path entry (wraps at 255)
    moveq   #0,D2
    move.b  (CHR_BUF_CNT).l,D2     ; D2 = bytes accumulated so far (0–15)

    ; Save this tile's base address on the first byte (aligned to 16 bytes)
    tst.b   D2
    bne.s   .chr_store_byte
    move.w  D1,D3
    andi.w  #$FFF0,D3               ; round down to 16-byte tile boundary
    move.w  D3,(CHR_BUF_VADDR).l

.chr_store_byte:
    lea     (CHR_TILE_BUF).l,A0
    move.b  D0,(A0,D2.w)            ; CHR_TILE_BUF[count] = byte
    addq.b  #1,(CHR_BUF_CNT).l     ; increment count
    bsr     .inc_ppuaddr            ; advance PPU_VADDR

    cmpi.b  #16,(CHR_BUF_CNT).l
    bne.s   .chr_ret                ; not yet 16 bytes — keep buffering

    ; Complete tile — check cache, then convert 2BPP → 4BPP and upload to VDP VRAM
    ifne CHR_EXPANSION_ENABLED
    ; --- Tile write cache: skip VRAM upload if tile data unchanged ---
    move.w  (CHR_BUF_VADDR).l,D2
    andi.w  #$1FF0,D2               ; cache offset (0..$1FF0)
    lea     (CHR_CACHE_BASE).l,A1
    adda.w  D2,A1                   ; A1 → cached tile entry
    lea     (CHR_TILE_BUF).l,A0
    move.l  (A0),D3
    cmp.l   (A1),D3
    bne.s   .chr_cache_miss
    move.l  4(A0),D3
    cmp.l   4(A1),D3
    bne.s   .chr_cache_miss
    move.l  8(A0),D3
    cmp.l   8(A1),D3
    bne.s   .chr_cache_miss
    move.l  12(A0),D3
    cmp.l   12(A1),D3
    bne.s   .chr_cache_miss
    ; Cache hit — tile unchanged, skip VRAM upload
    addq.w  #1,(CHR_CACHE_HITS).l
    bra.s   .chr_uploaded

.chr_cache_miss:
    ; Update cache with new tile data
    move.l  (A0)+,(A1)+
    move.l  (A0)+,(A1)+
    move.l  (A0)+,(A1)+
    move.l  (A0)+,(A1)+
    addq.w  #1,(CHR_CACHE_MISS).l

    ; Dispatch by NES address bit 12:
    ;   bit12=0 ($0000-$0FFF) → sprite half → _chr_upload_sprite_4x (4 copies)
    ;   bit12=1 ($1000-$1FFF) → BG half     → _chr_convert_upload   (1 copy)
    move.w  (CHR_BUF_VADDR).l,D2
    btst    #12,D2
    bne.s   .chr_bg_dispatch
    bsr     _chr_upload_sprite_4x
    bra.s   .chr_uploaded
.chr_bg_dispatch:
    bsr     _chr_convert_upload
    btst    #5,(PPU_CTRL).l
    beq.s   .chr_uploaded
    move.w  (CHR_BUF_VADDR).l,D0
    cmpi.w  #$1F20,D0
    blo.s   .chr_uploaded
    cmpi.w  #$1F40,D0
    bhs.s   .chr_uploaded
    bsr     _chr_upload_sprite_4x
.chr_uploaded:
    else
    bsr     _chr_convert_upload
    endc
    clr.b   (CHR_BUF_CNT).l

.chr_ret:
    movem.l (SP)+,D0-D6/A0-A1
    rts

    ;==========================================================================
    ; NAMETABLE / PALETTE PATH  (PPU_VADDR $2000–$3FFF)
    ;==========================================================================
    ; Word-pair buffering: buffer even-address byte, flush word on odd address.
    ;==========================================================================
.nt_write:
    ;======================================================================
    ; Nametable → Genesis Plane A row mapping:
    ;   NES NT_A tiles ($2000–$23BF, and mirrored $2400–$27BF)
    ;       → Plane A rows 0–29  (VDP $C000–$C5FF)
    ;   NES NT_B tiles ($2800–$2BBF, and mirrored $2C00–$2FBF)
    ;       → Plane A rows 30–59 (VDP $CF00–$D4FF)
    ;
    ; Zelda uses vertical mirroring so NT_A and NT_B are the only two
    ; physical nametables. Story-scroll (intro) writes new rows to NT_B
    ; via $2800+ as the scroll crosses the NT boundary — previously these
    ; writes were dropped, leaving Plane A rows 30..59 stale.
    ;
    ; Each row is 64 tiles × 2 bytes = $80 bytes wide in Plane A.
    ;   vdp_addr = $C000 + row * $80 + col * 2
    ;======================================================================
    ; Fold $2C00 mirror → $2800 (vertical mirroring alias for NT_B).
    cmpi.w  #$2C00,D1
    blo.s   .nt_no_b_mirror
    cmpi.w  #$3000,D1
    bhs.s   .nt_no_b_mirror
    subi.w  #$0400,D1
.nt_no_b_mirror:
    ; Fold $2400 mirror → $2000 (vertical mirroring alias for NT_A).
    cmpi.w  #$2400,D1
    blo.s   .nt_no_a_mirror
    cmpi.w  #$2800,D1
    bhs.s   .nt_no_a_mirror
    subi.w  #$0400,D1
.nt_no_a_mirror:

    ; Dispatch on NT_A vs NT_B tile ranges.
    cmpi.w  #$2800,D1
    blo     .nt_write_a              ; $2000-$27FF → NT_A path
    cmpi.w  #$2C00,D1
    bhs     .nt_noop                 ; ≥$2C00 → palette/skip
    cmpi.w  #$2BC0,D1
    bhs     .nt_attr_b               ; $2BC0-$2BFF → NT_B attribute decode

    ; ---- NT_B tile write: $2800-$2BBF → Plane A rows 30..59 ----
    move.w  D1,D2
    subi.w  #$2800,D2                ; D2.w = index within NT_B (0…$3BF)

    ; T21: cache raw tile index for attribute palette updates.
    ; NT_B cache lives at NT_CACHE_BASE + 960 (rows 30..59 slot).
    andi.w  #$00FF,D0                ; D0.w = tile index
    move.w  D2,D3
    addi.w  #960,D3                  ; D3.w = NT_B cache offset (960..1919)
    lea     (NT_CACHE_BASE).l,A0
    move.b  D0,(A0,D3.W)

    move.w  D2,D3
    andi.w  #$001F,D3
    lsl.w   #1,D3                    ; D3.w = col * 2

    lsr.w   #5,D2                    ; D2.w = row within NT_B (0…29)
    addi.w  #30,D2                   ; offset into Plane A rows 30..59
    mulu.w  #$0080,D2                ; D2.l = row * $80 (row ≤ 59)
    add.w   D3,D2
    addi.w  #$C000,D2                ; D2.w = VDP VRAM addr

    move.l  D2,D3
    andi.l  #$00003FFF,D3
    swap    D3
    ori.l   #$40000003,D3
    move.l  D3,(VDP_CTRL).l

    bsr     _compose_bg_tile_word
    move.w  D0,(VDP_DATA).l

    movem.l (SP)+,D0-D6/A0-A1
    rts

    ;======================================================================
    ; NT_B attribute decode ($2BC0-$2BFF) — parallel to NT_A .nt_noop path
    ; but writes to Plane A rows 30..59 by adding +30 to tile_base_row.
    ; _attr_write_one_tile reads NT_CACHE[row*32+col], so row≥30 naturally
    ; indexes into the NT_B cache slot at offset 960+.
    ;======================================================================
.nt_attr_b:
    cmpi.w  #$2C00,D1
    bhs     .nt_skip_write           ; safety: ≥$2C00 handled upstream

    move.w  D1,D2
    subi.w  #$2BC0,D2                ; D2.w = attribute offset (0..63)

    move.w  D2,D3
    lsr.w   #3,D3
    lsl.w   #2,D3                    ; D3.w = tile_base_row (0..28)
    addi.w  #30,D3                   ; +30: NT_B rows 30..59
    andi.w  #$0007,D2
    lsl.w   #2,D2                    ; D2.w = tile_base_col (0..28)

    move.b  D0,D4

    ; Quadrant 0: bits [1:0]
    move.w  D4,D5
    andi.w  #$0003,D5
    lsl.w   #5,D5
    lsl.w   #8,D5                    ; D5.w = palette<<13
    bsr     _attr_write_2x2

    ; Quadrant 1: bits [3:2], col_off=+2
    move.w  D4,D5
    lsr.w   #2,D5
    andi.w  #$0003,D5
    lsl.w   #5,D5
    lsl.w   #8,D5
    addq.w  #2,D2
    bsr     _attr_write_2x2
    subq.w  #2,D2

    ; Quadrant 2: bits [5:4], row_off=+2
    move.w  D4,D5
    lsr.w   #4,D5
    andi.w  #$0003,D5
    lsl.w   #5,D5
    lsl.w   #8,D5
    addq.w  #2,D3
    bsr     _attr_write_2x2
    subq.w  #2,D3

    ; Quadrant 3: bits [7:6], row_off=+2, col_off=+2
    move.w  D4,D5
    lsr.w   #6,D5
    andi.w  #$0003,D5
    lsl.w   #5,D5
    lsl.w   #8,D5
    addq.w  #2,D2
    addq.w  #2,D3
    bsr     _attr_write_2x2
    subq.w  #2,D2
    subq.w  #2,D3

    bra     .nt_skip_write

.nt_write_a:
    cmpi.w  #$23C0,D1
    bhs     .nt_noop                ; ≥$23C0: attribute / palette / overflow — no-op

    move.w  D1,D2
    subi.w  #$2000,D2               ; D2.w = index (0…$3BF)

    move.w  D2,D3
    andi.w  #$001F,D3               ; D3.w = col (0…31)
    lsl.w   #1,D3                   ; D3.w = col * 2
    move.w  D3,D5                   ; D5.w = cached col * 2 for tail-row mirror

    lsr.w   #5,D2                   ; D2.w = row (0…29)
    move.w  D2,D4                   ; D4.w = cached row for tail-row mirror
    mulu.w  #$0080,D2               ; D2.l = row * $80  (fits in 16 bits; row ≤ 29)
    add.w   D3,D2                   ; D2.w = row*$80 + col*2
    addi.w  #$C000,D2               ; D2.w = VDP VRAM address (Plane A base $C000)

    ; Issue VDP VRAM write command.
    ; Plane A is at $C000+ so A[15:14]=11 → lower word of command = 3.
    ; Full command: $40000000 | ((addr & $3FFF) << 16) | 3
    move.l  D2,D3
    andi.l  #$00003FFF,D3           ; D3.l = addr & $3FFF
    swap    D3                      ; D3.l = (addr & $3FFF) << 16
    ori.l   #$40000003,D3           ; add CD bits + A[15:14]=3
    move.l  D3,(VDP_CTRL).l

    ; Write Genesis tile word: tile index + BG pattern table offset
    andi.w  #$00FF,D0               ; D0.w = tile index (0…255)

    ; T20: cache raw tile index for attribute palette updates
    ; (cache BEFORE applying offset so _attr_write_one_tile can re-apply)
    move.w  D1,D3
    subi.w  #$2000,D3               ; D3.w = cache offset (0…$3BF)
    lea     (NT_CACHE_BASE).l,A0
    move.b  D0,(A0,D3.W)            ; NT_CACHE[offset] = raw tile index

    bsr     _compose_bg_tile_word
    move.w  D0,(VDP_DATA).l         ; write tile word to Plane A

    ; Mirror top rows 0..3 into rows 60..63 during intro phase-1
    ; (all subphases) so the V64 dead zone is always filled with valid
    ; content, eliminating DZ_SKIP H-int artifacts.
    tst.b   ($0012,A4)
    bne.s   .nt_noop
    cmpi.b  #$01,($042C,A4)
    bne.s   .nt_noop
    cmpi.w  #4,D4
    bhs.s   .nt_noop
    move.w  D4,D2
    addi.w  #60,D2
    mulu.w  #$0080,D2
    add.w   D5,D2
    addi.w  #$C000,D2
    move.l  D2,D3
    andi.l  #$00003FFF,D3
    swap    D3
    ori.l   #$40000003,D3
    move.l  D3,(VDP_CTRL).l
    move.w  D0,(VDP_DATA).l

.nt_noop:
    ;======================================================================
    ; T20: Attribute byte ($23C0–$23FF) → Genesis tile word palette bits.
    ;
    ; Each NES attribute byte covers a 4×4 tile block.  Two bits per quadrant:
    ;   bits [1:0] = palette for quadrant 0 (top-left  2×2 tiles)
    ;   bits [3:2] = palette for quadrant 1 (top-right 2×2 tiles)
    ;   bits [5:4] = palette for quadrant 2 (bot-left  2×2 tiles)
    ;   bits [7:6] = palette for quadrant 3 (bot-right 2×2 tiles)
    ;
    ; For each of the 16 affected tiles, look up the cached tile index
    ; from NT_CACHE_BASE[row*32+col] and write the tile word to Plane A
    ; with bits [12:11] set to the palette.  No VDP VRAM read required.
    ;======================================================================
    cmpi.w  #$3F00,D1
    bhs.s   .t19_palette            ; ≥$3F00: check palette range
    cmpi.w  #$23C0,D1
    blo     .nt_skip_write          ; $23C0 not reached yet — skip (shouldn't happen)
    cmpi.w  #$2400,D1
    bhs     .nt_skip_write          ; ≥$2400: overflow past attr table — skip

    ; ── T20 attribute decode ───────────────────────────────────────────
    ; offset = PPU_VADDR - $23C0 (0..63)
    move.w  D1,D2
    subi.w  #$23C0,D2               ; D2.w = attribute offset (0..63)

    ; tile_base_col = (offset & 7) * 4,  tile_base_row = (offset >> 3) * 4
    move.w  D2,D3
    lsr.w   #3,D3
    lsl.w   #2,D3                   ; D3.w = tile_base_row (0..28)
    andi.w  #$0007,D2
    lsl.w   #2,D2                   ; D2.w = tile_base_col (0..28)

    ; Save attribute byte in D4; process 4 quadrants using D5 = palette<<13
    ; Genesis tile word palette field = bits [14:13].
    ; palette<<13: lsl.w #5 then lsl.w #8 = total 13 bits  (immediate max is 8; both valid).
    move.b  D0,D4

    ; Quadrant 0: bits [1:0], row_off=0, col_off=0
    move.w  D4,D5
    andi.w  #$0003,D5
    lsl.w   #5,D5
    lsl.w   #8,D5                   ; D5.w = palette<<13  (bits [14:13])
    bsr     _attr_write_2x2

    ; Quadrant 1: bits [3:2], row_off=0, col_off=+2
    move.w  D4,D5
    lsr.w   #2,D5
    andi.w  #$0003,D5
    lsl.w   #5,D5
    lsl.w   #8,D5
    addq.w  #2,D2
    bsr     _attr_write_2x2
    subq.w  #2,D2

    ; Quadrant 2: bits [5:4], row_off=+2, col_off=0
    move.w  D4,D5
    lsr.w   #4,D5
    andi.w  #$0003,D5
    lsl.w   #5,D5
    lsl.w   #8,D5
    addq.w  #2,D3
    bsr     _attr_write_2x2
    subq.w  #2,D3

    ; Quadrant 3: bits [7:6], row_off=+2, col_off=+2
    move.w  D4,D5
    lsr.w   #6,D5
    andi.w  #$0003,D5
    lsl.w   #5,D5
    lsl.w   #8,D5
    addq.w  #2,D2
    addq.w  #2,D3
    bsr     _attr_write_2x2
    subq.w  #2,D2
    subq.w  #2,D3

    bra.s   .nt_skip_write

    ;======================================================================
    ; T19: Palette writes ($3F00–$3F1F) → Genesis CRAM.
    ;======================================================================
.t19_palette:
    cmpi.w  #$3F20,D1
    bhs.s   .nt_skip_write          ; ≥$3F20: mirror / overflow — skip

    ; Compute CRAM address from PPU_VADDR
    move.w  D1,D2
    subi.w  #$3F00,D2               ; D2.w = offset (0..31)
    andi.w  #$001F,D2               ; mask to 5 bits

    ; NES palette handling:
    ; Offsets 0-15  ($3F00-$3F0F): BG palettes → Genesis CRAM pal 0-3
    ; Offset entry-0s (0,4,8,12,16,20,24,28): universal BG color mirror
    ; Offsets 16-31 ($3F10-$3F1F): sprite palettes → Genesis CRAM pal 2-3
    ;   (NES sprite pal 0,2→Genesis pal 2; NES sprite pal 1,3→Genesis pal 3)
    ; Sequential last-write-wins: sprite pals 2,3 end up in PAL2/PAL3 which
    ; gives correct sprite colors (red hearts, green grass) while BG text
    ; only uses PAL0/PAL1 during the story phase, so BG2/BG3 clobber is OK.
    ; _oam_dma maps NES sprite pal bits → Gen pal 2/3 to match.
    cmpi.w  #$10,D2
    blo.s   .t19_bg_color           ; offset < 16: BG palette
    ; Sprite palette (offset 16-31)
    move.w  D2,D3
    andi.w  #$0003,D3               ; color slot within palette
    beq.s   .t19_spr_entry0         ; slot 0 → BG mirror
    ; Non-entry-0 sprite color: remap
    ifne CHR_EXPANSION_ENABLED
    ; T-CHR S8 (v2): pack sprite sub-palettes into unused tail slots of BG
    ; palettes so BG PAL0-3[0..3] stay untouched.
    ;   sub-pal 0 → PAL0[4..7]   (CRAM base $08, bias +4 pixels)
    ;   sub-pal 1 → PAL0[8..11]  (CRAM base $10, bias +8 pixels)
    ;   sub-pal 2 → PAL0[12..15] (CRAM base $18, bias +12 pixels)
    ;   sub-pal 3 → PAL1[4..7]   (CRAM base $28, bias +4 pixels, different palette)
    move.w  D2,D3
    subi.w  #$10,D3                 ; D3 = 0..15 within sprite range
    lsr.w   #2,D3                   ; D3 = sub-pal (0..3)
    add.w   D3,D3                   ; * 2 for word index
    lea     (.t19_spr_cram_base).l,A1
    move.w  (A1,D3.W),D3            ; D3 = CRAM base for this sub-pal
    move.w  D2,D4
    andi.w  #$0003,D4               ; color slot (1..3)
    add.w   D4,D4                   ; * 2
    add.w   D4,D3                   ; D3 = CRAM address
    else
    ; Legacy last-write-wins: NES sprite pal 0-3 → Gen pal 2|3 (2,3,2,3).
    move.w  D2,D3
    subi.w  #$10,D3                 ; 0-15 range
    lsr.w   #2,D3                   ; NES sprite pal (0-3)
    ori.w   #$0002,D3               ; Genesis pal = NES_pal | 2 (→ 2,3,2,3)
    lsl.w   #5,D3                   ; * $20 = CRAM palette base
    move.w  D2,D2
    andi.w  #$0003,D2               ; color slot (1-3)
    lsl.w   #1,D2                   ; * 2
    add.w   D2,D3                   ; D3 = CRAM address
    endc
    bra.s   .t19_have_cram
.t19_spr_entry0:
    ; Sprite entry-0 = BG mirror: remap 16→0, 20→4, 24→8, 28→12
    subi.w  #$10,D2
.t19_bg_color:
    move.w  D2,D3
    lsr.w   #2,D3                   ; D3.w = palette index (0..3)
    lsl.w   #5,D3                   ; D3.w = palette * $20
    andi.w  #$0003,D2               ; D2.w = color slot (0..3)
    lsl.w   #1,D2                   ; D2.w = color * 2
    add.w   D2,D3                   ; D3.w = CRAM address (0..$66)
.t19_have_cram:

    ; Issue VDP CRAM write command
    moveq   #0,D2
    move.w  D3,D2
    swap    D2                      ; D2 = CRAM_addr << 16
    ori.l   #$C0000000,D2           ; VDP CRAM-write command ($C0 = CD bits for CRAM write)
    move.l  D2,(VDP_CTRL).l

    ; Look up NES color index (D0.b, 0..63) in NES→Genesis 16-bit color table
    andi.w  #$003F,D0               ; D0.w = NES color index (mask high bits)
    lea     (nes_palette_to_genesis).l,A0
    lsl.w   #1,D0                   ; D0.w = byte offset into 16-bit word table
    move.w  (A0,D0.W),D2            ; D2.w = Genesis color word ($0BGR)
    move.w  D2,(VDP_DATA).l         ; write Genesis color to CRAM

.nt_skip_write:
    bsr     .inc_ppuaddr
    movem.l (SP)+,D0-D6/A0-A1
    rts

    ifne CHR_EXPANSION_ENABLED
    ; T-CHR S8 v2: NES sprite sub-palette → CRAM base address (PAL slot 4).
    ; Slots 1..3 (color indices 1..3) are written relative to this base.
.t19_spr_cram_base:
    dc.w    $08                 ; sub-pal 0 → PAL0[4]  (CRAM $08..$0E)
    dc.w    $10                 ; sub-pal 1 → PAL0[8]  (CRAM $10..$16)
    dc.w    $18                 ; sub-pal 2 → PAL0[12] (CRAM $18..$1E)
    dc.w    $28                 ; sub-pal 3 → PAL1[4]  (CRAM $28..$2E)
    endc

    ;==========================================================================
    ; .inc_ppuaddr — advance PPU_VADDR by 1 or 32.
    ; PPUCTRL bit 2: 0 → +1 horizontal, 1 → +32 vertical.
    ; Modifies D1.w.
    ;==========================================================================
.inc_ppuaddr:
    move.w  (PPU_VADDR).l,D1
    btst    #2,(PPU_CTRL).l
    bne.s   .inc32
    addq.w  #1,D1
    bra.s   .store_inc
.inc32:
    addi.w  #32,D1
.store_inc:
    andi.w  #$3FFF,D1               ; clamp to valid PPU address range
    move.w  D1,(PPU_VADDR).l
    rts

    ;==========================================================================
    ; .chr_convert_upload — convert 16-byte NES 2BPP tile to 32-byte Genesis
    ;                        4BPP and write to VDP VRAM.
    ;
    ; Input: CHR_TILE_BUF holds the 16 tile bytes.
    ;        CHR_BUF_VADDR holds the NES CHR base address (× 16-aligned).
    ;
    ; Genesis VRAM tile address = CHR_BUF_VADDR × 2 (tiles are 32 bytes each).
    ;
    ; For each of 8 rows:
    ;   plane0_row = CHR_TILE_BUF[row]       (bit 0 of each of 8 pixels)
    ;   plane1_row = CHR_TILE_BUF[row+8]     (bit 1 of each of 8 pixels)
    ;
    ; Pixel color = (plane1_bit << 1) | plane0_bit  →  4-bit Genesis nibble
    ;
    ; Output format per row (4 Genesis bytes = 2 VDP words):
    ;   byte 0: pixels 0,1  (high nibble = pixel 0, low nibble = pixel 1)
    ;   byte 1: pixels 2,3
    ;   byte 2: pixels 4,5
    ;   byte 3: pixels 6,7
    ;
    ; expand_nibble(n) helper: scatters 4-bit value n to positions 12,8,4,0
    ; of a 16-bit word (one bit per nibble).  Then OR-ing plane0 expansion
    ; with (plane1 expansion << 1) gives the correct Genesis word.
    ;
    ; Uses D0–D5/A0 (all caller-saved at _ppu_write_7 entry).
    ;==========================================================================
_chr_convert_upload:
    ; Set VDP write address: Genesis tile addr = NES CHR addr × 2
    move.w  (CHR_BUF_VADDR).l,D1
    add.w   D1,D1                   ; D1.w = NES_addr × 2  (lsl #1)
    ; VDP VRAM write command for D1.w (< $4000, so upper word = 0):
    ; Use moveq+move.w to guarantee D2 upper = 0 before swap.
    ; (plain move.l D1,D2 would propagate garbage from D1 upper 16 bits
    ;  into the CD/address bits of the VDP command after swap.)
    moveq   #0,D2
    move.w  D1,D2                   ; D2.w = NES_addr × 2  (D2 upper guaranteed 0)
    swap    D2                      ; D2 = (NES_addr × 2) << 16
    ori.l   #$40000000,D2           ; VDP VRAM-write command
    move.l  D2,(VDP_CTRL).l

    lea     (CHR_TILE_BUF).l,A0     ; A0 → plane-0 row bytes (0..7)
    lea     (.expand_nibble_lut).l,A1 ; A1 → LUT (kept across all rows)
    moveq   #7,D5                   ; 8 rows, counter 7..0

.ccu_row:
    move.b  0(A0),D3                ; D3.b = plane 0 for this row
    move.b  8(A0),D4                ; D4.b = plane 1 for this row
    addq.l  #1,A0                   ; advance to next plane-0 row byte

    ; ---- Pixels 0-3 (upper nibbles of D3 and D4) ----
    move.b  D3,D1
    lsr.b   #4,D1                   ; D1.b = upper nibble of plane0 (pix 0-3)
    andi.b  #$0F,D1
    bsr     .expand_nibble          ; D2.w = plane0 expansion (bit0 of each nibble)
    move.w  D2,D6                   ; save plane0 expansion in D6 (D0 clobbered by expand)

    move.b  D4,D1
    lsr.b   #4,D1                   ; D1.b = upper nibble of plane1 (pix 0-3)
    andi.b  #$0F,D1
    bsr     .expand_nibble          ; D2.w = plane1 expansion
    lsl.w   #1,D2                   ; ×2 → puts plane1 bits in bit1 of each nibble
    or.w    D6,D2                   ; combine: each nibble = (p1_bit<<1)|p0_bit
    move.w  D2,(VDP_DATA).l         ; write pixels 0-3 (2 VDP bytes via auto-incr)

    ; ---- Pixels 4-7 (lower nibbles of D3 and D4) ----
    move.b  D3,D1
    andi.b  #$0F,D1                 ; D1.b = lower nibble of plane0 (pix 4-7)
    bsr     .expand_nibble
    move.w  D2,D6                   ; save plane0 expansion in D6

    move.b  D4,D1
    andi.b  #$0F,D1                 ; D1.b = lower nibble of plane1 (pix 4-7)
    bsr     .expand_nibble
    lsl.w   #1,D2                   ; ×2 for plane1
    or.w    D6,D2
    move.w  D2,(VDP_DATA).l         ; write pixels 4-7

    subq.b  #1,D5
    bge.s   .ccu_row                ; loop for all 8 rows
    rts

    ;==========================================================================
    ; .expand_nibble — scatter 4-bit nibble to bit-0 of each output nibble.
    ;
    ; Input:  D1.b = 4-bit value n (bits 3..0 = pixels 0..3 of one plane)
    ; Output: D2.w = bit3→pos12, bit2→pos8, bit1→pos4, bit0→pos0
    ;
    ; Uses lookup table for speed: 2 instructions instead of ~24.
    ;==========================================================================
.expand_nibble:
    andi.w  #$000F,D1               ; mask to 4 bits, zero-extend
    add.w   D1,D1                   ; word offset into table
    move.w  (A1,D1.W),D2            ; D2.w = expanded nibble (A1 = LUT base)
    rts

    ;==========================================================================
    ; 16-entry lookup table: nibble → scattered bits.
    ;   Entry n: bit3→bit12, bit2→bit8, bit1→bit4, bit0→bit0
    ;   e.g. $F (1111) → $1111, $A (1010) → $1010, $5 (0101) → $0101
    ;==========================================================================
    even
.expand_nibble_lut:
    dc.w    $0000   ; 0000
    dc.w    $0001   ; 0001
    dc.w    $0010   ; 0010
    dc.w    $0011   ; 0011
    dc.w    $0100   ; 0100
    dc.w    $0101   ; 0101
    dc.w    $0110   ; 0110
    dc.w    $0111   ; 0111
    dc.w    $1000   ; 1000
    dc.w    $1001   ; 1001
    dc.w    $1010   ; 1010
    dc.w    $1011   ; 1011
    dc.w    $1100   ; 1100
    dc.w    $1101   ; 1101
    dc.w    $1110   ; 1110
    dc.w    $1111   ; 1111

    rts

    ifne CHR_EXPANSION_ENABLED
;==============================================================================
; _chr_upload_sprite_4x — upload one NES sprite CHR tile to 4 Gen VRAM copies
;                         with pre-biased pixel values.
;
; Input:  CHR_TILE_BUF     = 16 NES 2bpp tile bytes
;         CHR_BUF_VADDR    = NES CHR address (16-aligned)
;
; Output: lower-half sprite CHR populates the normal sprite-copy banks.
;         upper-half CHR during NES 8x16 mode populates only the safe banks
;         used by the nonzero sprite sub-palettes, so BG pattern-table 1 tiles
;         are not clobbered.
;
; Pixel 0 (transparent) is preserved across all 4 copies — bias is only
; applied to nonzero pixels via a nibble mask.
;
; Bias mechanism (mask-based, no per-copy LUTs):
;   1. expand plane0 and plane1 via existing 16-entry .expand_nibble_lut
;   2. nonzero_mask = plane0_exp | plane1_exp  ($0 or $1 per nibble)
;   3. bias_word_per_copy:  $0000, $4444, $8888, $CCCC
;   4. mask_F = mask | mask<<1 | mask<<2 | mask<<3 ($0 or $F per nibble)
;   5. bias_add = mask_F & bias_word  ($0 or bias per nonzero nibble)
;   6. final = orig_pixels | bias_add  (no nibble overflow: orig <= 3, bias <= 12)
;
; Clobbers D0-D7, A0-A2.
;==============================================================================
_chr_upload_sprite_4x:
    movem.l D0-D7/A0-A2,-(SP)           ; save everything (helper clobbers D0-D7, A0-A2)
    move.w  (CHR_BUF_VADDR).l,D0
    btst    #12,D0
    beq.s   .csfx_use_lo_tbl
    btst    #5,(PPU_CTRL).l
    beq.s   .csfx_use_lo_tbl
    lea     (.csfx_hi_copy_base_tbl).l,A2
    moveq   #1,D5                       ; upper-half 8x16 support: banks B/C only
    bra.s   .csfx_copy_loop
.csfx_use_lo_tbl:
    lea     (.csfx_copy_base_tbl).l,A2
    moveq   #3,D5                       ; 4 copies, counter 3..0
.csfx_copy_loop:
    ; Recompute tile offset each iteration because .csfx_row (below) clobbers
    ; D3/D4 with plane0/plane1 row bytes. Previously this lived before the
    ; loop and caused copies 1-3 to land at misaligned VRAM addresses.
    move.w  (CHR_BUF_VADDR).l,D3
    add.w   D3,D3                       ; D3.w = gen tile offset (NES_addr * 2)
    andi.l  #$0000FFFF,D3               ; zero-extend for safe .l math
    move.l  (A2)+,D4                    ; D4.l = copy base VRAM addr
    add.l   D3,D4                       ; D4.l = tile VRAM addr for this copy
    move.l  (A2)+,D7                    ; D7.l = bias word (low 16 bits used)
    ; Build VDP VRAM write command in D2.l:
    ;   cmd = $40000000 | ((addr & $3FFF) << 16) | ((addr >> 14) & $0003)
    move.l  D4,D0
    andi.l  #$00003FFF,D0
    swap    D0
    ori.l   #$40000000,D0
    move.l  D4,D2
    lsr.l   #8,D2
    lsr.l   #6,D2
    andi.l  #$00000003,D2
    or.l    D2,D0
    move.l  D0,(VDP_CTRL).l

    lea     (CHR_TILE_BUF).l,A0
    lea     (.csfx_expand_lut).l,A1
    move.l  #7,D0
    ; Using D0 as row counter conflicts with expand_nibble which clobbers D0/D1/D2.
    ; Save row counter on stack per iteration.
.csfx_row:
    move.l  D0,-(SP)                    ; save row counter
    move.b  0(A0),D3                    ; D3.b = plane0 row
    move.b  8(A0),D4                    ; D4.b = plane1 row
    addq.l  #1,A0

    ; ---- Pixels 0-3 (upper nibbles) ----
    move.b  D3,D1
    lsr.b   #4,D1
    andi.b  #$0F,D1
    bsr     .csfx_expand                ; D2.w = plane0 expand
    move.w  D2,D6                       ; D6 = plane0 expand
    move.b  D4,D1
    lsr.b   #4,D1
    andi.b  #$0F,D1
    bsr     .csfx_expand              ; D2.w = plane1 expand
    move.w  D2,D0                       ; D0.w = plane1 expand
    or.w    D6,D0                       ; D0.w = nonzero mask ($0/$1 per nibble)
    lsl.w   #1,D2
    or.w    D6,D2                       ; D2.w = raw pixel nibbles
    bsr     .csfx_apply_bias            ; merges bias using D0(mask), D7(bias)
    move.w  D2,(VDP_DATA).l

    ; ---- Pixels 4-7 (lower nibbles) ----
    move.b  D3,D1
    andi.b  #$0F,D1
    bsr     .csfx_expand
    move.w  D2,D6
    move.b  D4,D1
    andi.b  #$0F,D1
    bsr     .csfx_expand
    move.w  D2,D0
    or.w    D6,D0
    lsl.w   #1,D2
    or.w    D6,D2
    bsr     .csfx_apply_bias
    move.w  D2,(VDP_DATA).l

    move.l  (SP)+,D0                    ; restore row counter
    subq.l  #1,D0
    bge.s   .csfx_row

    dbra    D5,.csfx_copy_loop
    movem.l (SP)+,D0-D7/A0-A2
    rts

    ;==========================================================================
    ; .csfx_apply_bias — add per-copy bias to nonzero pixel nibbles.
    ; In:  D0.w = nonzero mask ($0/$1 per nibble)
    ;      D2.w = raw pixel nibbles
    ;      D7.w = bias word ($0000/$4444/$8888/$CCCC)
    ; Out: D2.w = biased pixel nibbles
    ; Clobbers D0, D1.
    ;==========================================================================
.csfx_apply_bias:
    move.w  D0,D1
    lsl.w   #1,D1
    or.w    D1,D0
    move.w  D0,D1
    lsl.w   #2,D1
    or.w    D1,D0                       ; D0 now has $F per nonzero nibble
    and.w   D7,D0                       ; D0 = bias_add (bias per nonzero nibble)
    or.w    D0,D2                       ; merge into pixel nibbles
    rts

    ;==========================================================================
    ; .csfx_expand — local copy of the nibble expander used by _chr_convert_upload.
    ; In:  D1.b = 4-bit nibble, A1 = .csfx_expand_lut
    ; Out: D2.w = bit3→pos12, bit2→pos8, bit1→pos4, bit0→pos0
    ;==========================================================================
.csfx_expand:
    andi.w  #$000F,D1
    add.w   D1,D1
    move.w  (A1,D1.W),D2
    rts

    even
.csfx_expand_lut:
    dc.w    $0000,$0001,$0010,$0011
    dc.w    $0100,$0101,$0110,$0111
    dc.w    $1000,$1001,$1010,$1011
    dc.w    $1100,$1101,$1110,$1111

    even
.csfx_copy_base_tbl:
    ; 4 entries, 8 bytes each: (base_vram .l, bias_word_as_long .l)
    ; Bias word sits in the low 16 bits of the long so `move.l (A2)+,D7`
    ; leaves the bias in D7.w for the .w AND in .csfx_apply_bias.
    ; T-CHR v9: sub-pal→CRAM slot mapping via pixel bias + Gen-pal bits (OAM).
    ;   copy 0 / shared bank A (sub-pal 0 + sub-pal 3): bias +$4
    ;   copy 1 / bank B (sub-pal 1): bias +$8
    ;   copy 2 / bank C (sub-pal 2): bias +$C
    ;   copy 3 reuses bank A because sub-pal 3 needs the same +$4 biased pixels
    ;   as sub-pal 0; only the SAT palette bits differ. This frees the old bank-C
    ;   overlap so 8x16 table-1 sprites like the item-roll heart can use upper-half
    ;   tile pairs without colliding with another sprite copy.
    dc.l    $00000000,$00004444
    dc.l    $00004000,$00008888
    dc.l    $00008000,$0000CCCC
    dc.l    $00000000,$00004444
.csfx_hi_copy_base_tbl:
    ; Upper-half CHR mirrored for NES 8x16 sprites. Only the safe banks used by
    ; sub-pal 1 (+8) and sub-pal 2 (+C) are populated here.
    dc.l    $00004000,$00008888
    dc.l    $00008000,$0000CCCC
    endc

;==============================================================================
; _compose_bg_tile_word — add the active BG pattern-table offset to a raw tile.
;
; Input:  D0.w = raw NES BG tile index (0..255)
; Output: D0.w = Genesis tile index with PPUCTRL bit 4 applied
; Uses no other registers.
;==============================================================================
_compose_bg_tile_word:
    andi.w  #$00FF,D0               ; raw tile index only
    btst    #4,(PPU_CTRL).l
    beq.s   .cbgtw_done
    ori.w   #$0100,D0               ; BG pattern table 1 → VRAM $1000
.cbgtw_done:
    rts

;==============================================================================
; _attr_write_2x2 — write palette bits into a 2x2 tile block.
;
; Input: D2.w = col (top-left tile), D3.w = row (top-left tile)
;        D5.w = palette << 13  (Genesis tile word palette bits [14:13])
; All inputs preserved.  Uses D0, D1, A0 as scratch.
;==============================================================================
_attr_write_2x2:
    bsr     _attr_write_one_tile        ; (row,   col)
    addq.w  #1,D2
    bsr     _attr_write_one_tile        ; (row,   col+1)
    addq.w  #1,D3
    bsr     _attr_write_one_tile        ; (row+1, col+1)
    subq.w  #1,D2
    bsr     _attr_write_one_tile        ; (row+1, col)
    subq.w  #1,D3
    rts

;==============================================================================
; _attr_write_one_tile — write one Plane A tile word with palette bits.
;
; Input: D2.w = col (0..31), D3.w = row (0..29), D5.w = palette << 13
; Reads tile index from NT_CACHE_BASE[row*32 + col].
; Writes tile word = (palette<<13) | tile_index to VDP Plane A.
; Inputs D2, D3, D5 preserved.  Uses D0, D1, A0.
;==============================================================================
_attr_write_one_tile:
    ; Bounds check (V64: NT0 rows 0-29, NT1 rows 30-59)
    cmpi.w  #60,D3
    bhs     .awt_skip           ; row >= 60 -> out of nametable
    cmpi.w  #32,D2
    bhs     .awt_skip           ; col >= 32 -> out of nametable

    ; Load cached tile index: NT_CACHE[row*32 + col]
    moveq   #0,D1
    move.w  D3,D1
    lsl.w   #5,D1               ; D1.w = row * 32
    add.w   D2,D1               ; D1.w = row*32 + col
    lea     (NT_CACHE_BASE).l,A0
    moveq   #0,D0
    move.b  (A0,D1.W),D0        ; D0.b = tile index

    bsr     _compose_bg_tile_word
    ; Build tile word: (palette<<13) | tile_index
    or.w    D5,D0               ; D0.w = tile word with palette bits

    ; Compute Genesis VDP address: $C000 + row*$80 + col*2
    moveq   #0,D1
    move.w  D3,D1
    lsl.l   #7,D1               ; D1.l = row * $80
    add.w   D2,D1
    add.w   D2,D1               ; D1.w += col * 2
    addi.w  #$C000,D1           ; D1.w = VDP address

    ; Issue VDP VRAM write command
    move.w  D0,-(SP)            ; save tile word
    move.l  D1,D0
    andi.l  #$00003FFF,D0
    swap    D0
    ori.l   #$40000003,D0       ; CD bits + A[15:14]=3
    move.l  D0,(VDP_CTRL).l
    move.w  (SP)+,D0            ; restore tile word
    move.w  D0,(VDP_DATA).l     ; write to Plane A

    ; Mirror top rows 0..3 into rows 60..63 during intro phase-1
    ; (all subphases) so the V64 dead zone always has valid content.
    tst.b   ($0012,A4)
    bne.s   .awt_skip
    cmpi.b  #$01,($042C,A4)
    bne.s   .awt_skip
    cmpi.w  #4,D3
    bhs.s   .awt_skip
    move.w  D0,-(SP)
    moveq   #0,D1
    move.w  D3,D1
    addi.w  #60,D1
    lsl.l   #7,D1
    moveq   #0,D0
    move.w  D2,D0
    add.w   D0,D1
    add.w   D0,D1
    addi.w  #$C000,D1
    move.l  D1,D0
    andi.l  #$00003FFF,D0
    swap    D0
    ori.l   #$40000003,D0
    move.l  D0,(VDP_CTRL).l
    move.w  (SP)+,D0
    move.w  D0,(VDP_DATA).l

.awt_skip:
    rts

;==============================================================================
; NES → Genesis palette lookup table
;
; 64 × 16-bit words: index = NES color byte (0–63).
; Genesis color format: $0BGR (bits [10:8]=Blue, [6:4]=Green, [2:0]=Red, 0–7 each).
; Source: title-calibrated NES palette approximations tuned against BizHawk
; frame-200 NES reference captures, quantized to Genesis 3-bit channels.
;==============================================================================
    even
nes_palette_to_genesis:
    ;       NES $00–$0F  (grays, blues, purples, reds, greens)
    ;       Genesis CRAM = (B<<9)|(G<<5)|(R<<1)  — NOT raw $0BGR nibbles
    dc.w    $0666   ; $00  rgb(84,84,84)     dark gray (universal BG)
    dc.w    $0E00   ; $01  rgb(0,0,252)     dark blue
    dc.w    $0A00   ; $02  rgb(0,0,188)     dark blue
    dc.w    $0A24   ; $03  rgb(68,40,188)   blue-violet
    dc.w    $0808   ; $04  rgb(148,0,132)   purple
    dc.w    $020A   ; $05  rgb(168,0,32)    dark red-magenta
    dc.w    $000A   ; $06  rgb(168,16,0)    dark red
    dc.w    $0028   ; $07  rgb(136,20,0)    dark red-brown
    dc.w    $0044   ; $08  dark olive-brown
    dc.w    $0060   ; $09  rgb(0,120,0)     dark green
    dc.w    $0060   ; $0A  rgb(0,104,0)     dark green
    dc.w    $0040   ; $0B  rgb(0,88,0)      very dark green
    dc.w    $0440   ; $0C  rgb(0,64,88)     dark teal
    dc.w    $0000   ; $0D  black (unused/invalid)
    dc.w    $0000   ; $0E  black (unused/invalid)
    dc.w    $0000   ; $0F  black (unused/invalid)

    ;       NES $10–$1F  (light grays, bright blues/reds, mid greens, teals)
    dc.w    $0AAA   ; $10  rgb(152,152,152)  light gray
    dc.w    $0E60   ; $11  rgb(0,120,248)   bright blue
    dc.w    $0E40   ; $12  rgb(0,88,248)    bright blue
    dc.w    $0E46   ; $13  rgb(104,68,252)  blue-violet
    dc.w    $0C0C   ; $14  rgb(216,0,204)   bright magenta
    dc.w    $040C   ; $15  rgb(228,0,88)    bright red
    dc.w    $004A   ; $16  orange-red
    dc.w    $004A   ; $17  orange
    dc.w    $006A   ; $18  rgb(172,124,0)   yellow-orange
    dc.w    $00A0   ; $19  rgb(0,184,0)     green
    dc.w    $0080   ; $1A  green
    dc.w    $04A0   ; $1B  rgb(0,168,68)    green-teal
    dc.w    $0880   ; $1C  rgb(0,136,136)   teal
    dc.w    $0000   ; $1D  black (unused/invalid)
    dc.w    $0000   ; $1E  black (unused/invalid)
    dc.w    $0000   ; $1F  black (unused/invalid)

    ;       NES $20–$2F  (near-white, light colors, pastels)
    dc.w    $0EEE   ; $20  rgb(248,248,248) near-white
    dc.w    $0EA4   ; $21  rgb(60,188,252)  light cyan-blue
    dc.w    $0E86   ; $22  light blue
    dc.w    $0E68   ; $23  rgb(152,120,248) light purple-blue
    dc.w    $0E6E   ; $24  rgb(248,120,248) light magenta
    dc.w    $084E   ; $25  rgb(248,88,152)  light pink-red
    dc.w    $046E   ; $26  rgb(248,120,88)  light orange
    dc.w    $048E   ; $27  rgb(252,160,68)  light yellow-orange
    dc.w    $00CC   ; $28  yellow
    dc.w    $02EA   ; $29  rgb(184,248,24)  yellow-green
    dc.w    $04C4   ; $2A  rgb(88,216,84)   light green
    dc.w    $08E4   ; $2B  rgb(88,248,152)  light green-teal
    dc.w    $0CC0   ; $2C  rgb(0,232,216)   light teal
    dc.w    $0666   ; $2D  rgb(120,120,120) medium gray
    dc.w    $0000   ; $2E  black (unused/invalid)
    dc.w    $0000   ; $2F  black (unused/invalid)

    ;       NES $30–$3F  (whites, very light pastels)
    dc.w    $0EEE   ; $30  rgb(252,252,252) white
    dc.w    $0ECA   ; $31  rgb(164,228,252) very light blue
    dc.w    $0EAA   ; $32  rgb(184,184,248) very light purple-blue
    dc.w    $0EAC   ; $33  rgb(216,184,248) very light purple
    dc.w    $0EAE   ; $34  rgb(248,184,248) very light magenta
    dc.w    $0AAE   ; $35  rgb(248,164,192) very light pink
    dc.w    $0CCE   ; $36  very light pink-beige
    dc.w    $0ACE   ; $37  rgb(252,224,168) very light yellow
    dc.w    $06CE   ; $38  rgb(248,216,120) light yellow
    dc.w    $06EC   ; $39  rgb(216,248,120) light yellow-green
    dc.w    $0AEA   ; $3A  rgb(184,248,184) light green
    dc.w    $0CEA   ; $3B  rgb(184,248,216) very light teal
    dc.w    $0EE0   ; $3C  rgb(0,252,252)   bright cyan
    dc.w    $0ECE   ; $3D  rgb(248,216,248) very light magenta
    dc.w    $0000   ; $3E  black (unused/invalid)
    dc.w    $0000   ; $3F  black (unused/invalid)

;==============================================================================
; Controller I/O
;==============================================================================

;------------------------------------------------------------------------------
; _ctrl_strobe — $4016 write (T27).
;
; On every call: read Genesis controller 1 via hardware I/O (TH two-phase),
; build an 8-bit NES button latch byte, and reset the serial read index.
;
; NES button order (bit0=A, bit1=B, bit2=Sel, bit3=Start,
;                   bit4=Up, bit5=Down, bit6=Left, bit7=Right).
; Genesis bits are active-low (0 = pressed).
;
; Latch storage (in Genesis work-RAM above NES address space):
;   CTL1_LATCH = ($1100,A4) = $FF1100 — latched NES button byte
;   CTL1_IDX   = ($1101,A4) = $FF1101 — serial read index (0–7)
;------------------------------------------------------------------------------
_ctrl_strobe:
    movem.l D1-D3,-(SP)
    ; Phase 1: set TH=1 → bits[5:4]=C,B  bits[3:0]=Right,Left,Down,Up (active low)
    move.b  #$40,($A10009).l    ; ctrl1: TH pin = output
    move.b  #$40,($A10001).l    ; assert TH=1
    nop
    nop
    move.b  ($A10001).l,D1      ; D1 = TH=1 data
    ; Phase 2: TH=0 → bits[5:4]=Start,A  bits[3:0]=Right,Left,Down,Up (active low)
    move.b  #$00,($A10001).l    ; assert TH=0
    nop
    nop
    move.b  ($A10001).l,D2      ; D2 = TH=0 data
    ; Build NES button byte
    moveq   #0,D3
    btst    #4,D2               ; A button: TH=0 bit4 (active low)
    bne.s   .cs_no_a
    bset    #0,D3
.cs_no_a:
    btst    #4,D1               ; B button: TH=1 bit4 (active low)
    bne.s   .cs_no_b
    bset    #1,D3
.cs_no_b:
    ; Select: no Genesis 3-button equivalent → bit2 stays 0
    btst    #5,D2               ; Start: TH=0 bit5 (active low)
    bne.s   .cs_no_start
    bset    #3,D3
.cs_no_start:
    btst    #0,D1               ; Up: TH=1 bit0 (active low)
    bne.s   .cs_no_up
    bset    #4,D3
.cs_no_up:
    btst    #1,D1               ; Down: TH=1 bit1 (active low)
    bne.s   .cs_no_down
    bset    #5,D3
.cs_no_down:
    btst    #2,D1               ; Left: TH=1 bit2 (active low)
    bne.s   .cs_no_left
    bset    #6,D3
.cs_no_left:
    btst    #3,D1               ; Right: TH=1 bit3 (active low)
    bne.s   .cs_no_right
    bset    #7,D3
.cs_no_right:
    move.b  D3,($1100,A4)       ; store latched NES button byte
    move.b  #0,($1101,A4)       ; reset serial index
    movem.l (SP)+,D1-D3
    rts

;------------------------------------------------------------------------------
; _ctrl_read_1 — $4016 read (T27).
;
; Returns the next button bit from the latch in D0.b (bit0 = button state,
; 1 = pressed).  Buttons are in NES order: A, B, Sel, Start, Up, Down, Left,
; Right (index 0–7).  Returns 0 when index overflows past 7.
;------------------------------------------------------------------------------
_ctrl_read_1:
    moveq   #0,D1
    move.b  ($1101,A4),D1       ; D1.l = current index (zero-extended)
    cmpi.b  #8,D1
    bge.s   .cr1_overflow
    addq.b  #1,($1101,A4)       ; advance index for next read
    moveq   #0,D0
    move.b  ($1100,A4),D0       ; D0 = latched button byte
    lsr.b   D1,D0               ; shift right by index → target bit in bit0
    andi.b  #1,D0               ; isolate bit0
    rts
.cr1_overflow:
    moveq   #0,D0
    rts

;------------------------------------------------------------------------------
; _ctrl_read_2 — $4017 read: controller 2 / frame counter.
; Return 0.
;------------------------------------------------------------------------------
_ctrl_read_2:
    moveq   #0,D0
    rts

;==============================================================================
; OAM DMA
;==============================================================================

;------------------------------------------------------------------------------
; _oam_dma — $4014 write: OAM DMA transfer.
;
; On NES, writing page number P to $4014 copies 256 bytes from CPU page P
; ($PP00–$PPFF) to OAM.  Zelda writes #$02, meaning copy from $0200–$02FF.
; NES $0200–$02FF = Genesis $FF0200–$FF02FF.
;
; T23: Convert 64 NES OAM entries → 64 Genesis SAT entries, write to VRAM $D800.
;
; NES OAM entry layout (4 bytes, address is OAM byte index):
;   [0] Y position (sprite top − 1; visible on scanline Y+1)
;   [1] Tile index (0–255, pattern table determined by PPUCTRL bit 3)
;   [2] Attribute: bit7=Vflip, bit6=Hflip, bit5=behind-BG, bits1:0=sprite palette
;   [3] X position (sprite left edge, 0–255)
;
; Genesis SAT entry layout (8 bytes at VRAM $D800 + sprite*8):
;   Word 0 [bits 8:0]: Y position (=NES_Y+129 for 240-line; 128=top of screen)
;   Word 1 [bits 11:8]: size (00=8×8 px); [bits 6:0]: link to next sprite index
;   Word 2: tile word → bit15=priority, bits14:13=palette, bit12=Vflip, bit11=Hflip,
;                        bits10:0=tile index
;   Word 3 [bits 8:0]: X position (=NES_X+128; 128=left of screen)
;
; Sprite palette mapping: NES sprite palette 0–3 → Genesis palette 0–3 directly.
;   (T25 will map NES sprite palettes to CRAM entries 32–63 = Genesis palettes 2–3.)
; Priority: bit15 = 1 (sprites always above background planes).
; Off-screen: NES Y+129 ≥ 368 means off-screen naturally; no special case needed.
;------------------------------------------------------------------------------
_oam_dma:
    ifne CHR_EXPANSION_ENABLED
    movem.l D0-D7/A0-A1,-(SP)
    else
    movem.l D0-D7/A0,-(SP)
    endc

    ; VSRAM scroll is now driven by _apply_genesis_scroll in IsrNmi.
    ; The old static 8px bias has been removed.

    ; Set VDP write address: VRAM $F800 (sprite attribute table)
    ; $F800 & $3FFF = $3800 → swap → $38000000 → | $40000003 = $78000003
    move.l  #$78000003,(VDP_CTRL).l

    lea     (NES_RAM_BASE+$0200).l,A0  ; A0 → NES OAM buffer ($FF0200)
    moveq   #63,D7                     ; loop: 64 sprites (dbra counts 63→0)
    moveq   #0,D6                      ; D6 = current sprite index (0..63)

.oam_loop:
    ; ── Read 4 NES OAM bytes ──────────────────────────────────────────────
    moveq   #0,D0
    move.b  (A0)+,D0            ; D0.w = NES Y (sprite top − 1)
    moveq   #0,D1
    move.b  (A0)+,D1            ; D1.w = tile index
    moveq   #0,D2
    move.b  (A0)+,D2            ; D2.w = attribute byte
    moveq   #0,D3
    move.b  (A0)+,D3            ; D3.w = NES X

    ; ── Word 0: Genesis Y ─────────────────────────────────────────────────
    ; NES sprite is visible on scanline (NES_Y + 1).
    ; Genesis 240-line: screen line 0 is at Y=128 → Genesis Y = 128 + screen_line
    ;   = 128 + (NES_Y + 1) = NES_Y + 129
    ; Sprites with NES_Y ≥ 239 produce Genesis Y ≥ 368 which is naturally off-screen.
    move.w  D0,D4
    addi.w  #129,D4
    tst.b   ($0012,A4)
    bne.s   .oam_write_y
    ; Apply the global attract-mode lift cleanly across all subphases without
    ; checking for top-edge continuity drops, as the VDP seamlessly processes Y < 128.
    subi.w  #8,D4
.oam_write_y:
    move.w  D4,(VDP_DATA).l

    ; ── Word 1: size | link ─────────────────────────────────────────────
    ; Link field: chain sprites 0→1→2→...→63→0
    move.w  D6,D4
    addq.w  #1,D4               ; D4 = this_sprite_index + 1
    cmpi.w  #64,D4              ; is this the last sprite?
    bne     .write_link
    moveq   #0,D4               ; yes → link = 0 (terminate list)
.write_link:
    ; Size: check PPUCTRL bit 5 for 8×16 sprite mode
    ; Genesis SAT word 1: [11:10]=H-size, [9:8]=V-size, [6:0]=link
    btst    #5,(PPU_CTRL).l
    beq.s   .oam_size_done
    ori.w   #$0100,D4           ; V-size = 2 (8×16: two 8×8 cells stacked)
.oam_size_done:
    move.w  D4,(VDP_DATA).l     ; write size | link

    ; ── Word 2: tile word (priority | palette | Vflip | Hflip | tile) ────
    ; Compute Genesis tile index based on sprite size mode
    btst    #5,(PPU_CTRL).l
    beq.s   .oam_8x8
    ; 8×16 mode: tile byte bit 0 = pattern table, bits 7:1 = tile pair
    move.w  D1,D5
    andi.w  #$0001,D5           ; pattern table bit
    lsl.w   #8,D5               ; $0000 or $0100
    move.w  D1,D4
    andi.w  #$00FE,D4           ; tile pair (even tile number)
    or.w    D4,D5               ; Genesis tile index
    bra.s   .oam_have_tile
.oam_8x8:
    ; 8×8 mode: check PPUCTRL bit 3 for sprite pattern table
    move.w  D1,D5
    andi.w  #$00FF,D5
    btst    #3,(PPU_CTRL).l
    beq.s   .oam_have_tile
    ori.w   #$0100,D5           ; pattern table $1000 → tile +$100
.oam_have_tile:
    ifne CHR_EXPANSION_ENABLED
    ; T-CHR S9 v8: NES sprite sub-palettes packed into UNUSED TAIL SLOTS of BG
    ; palettes — sub-pal 0/1/2 → PAL0 (biased to slots 4/8/12), sub-pal 3 → PAL1
    ; (biased to slot 4).  BG palettes themselves untouched.  CHR tiles live in
    ; copy N (0..3) at VRAM $0000/$4000/$6000/$8000.
    move.w  D2,D4
    andi.w  #$0003,D4           ; NES sub-palette (0..3)
    add.w   D4,D4               ; word index
    lea     (.oam_tile_bias_tbl,PC),A1
    add.w   (A1,D4.W),D5        ; apply per-copy tile bias
    andi.w  #$07FF,D5           ; keep bits 10:0 only
    ori.w   #$8000,D5           ; bit 15 = high priority
    lea     (.oam_pal_bits_tbl,PC),A1
    or.w    (A1,D4.W),D5        ; OR in palette bits (PAL0/PAL0/PAL0/PAL1)
    else
    andi.w  #$07FF,D5           ; keep bits 10:0 only
    ori.w   #$8000,D5           ; bit 15 = high priority (sprite over planes)
    ; Palette: NES sprite attr[1:0] → Genesis bits[14:13], offset +2
    move.w  D2,D4
    andi.w  #$0003,D4           ; isolate NES sprite palette (0–3)
    ori.w   #$0002,D4           ; offset: NES sprite pal 0,1→Genesis pal 2,3
    andi.w  #$0003,D4           ; mask (0→2, 1→3, 2→2, 3→3)
    lsl.w   #5,D4               ; shift left 5
    lsl.w   #8,D4               ; shift left 8 more → total shift 13 → bits[14:13]
    or.w    D4,D5               ; merge palette
    endc
    ; V-flip: NES attr bit 7 → Genesis tile word bit 12
    btst    #7,D2
    beq     .no_vflip
    ori.w   #$1000,D5           ; set bit 12
.no_vflip:
    ; H-flip: NES attr bit 6 → Genesis tile word bit 11
    btst    #6,D2
    beq     .no_hflip
    ori.w   #$0800,D5           ; set bit 11
.no_hflip:
    move.w  D5,(VDP_DATA).l     ; write tile word

    ; ── Word 3: Genesis X ─────────────────────────────────────────────────
    ; Genesis 40-cell: screen column 0 is at X=128 → Genesis X = NES_X + 128
    move.w  D3,D4
    addi.w  #128,D4
    move.w  D4,(VDP_DATA).l

    addq.w  #1,D6               ; advance sprite index
    dbra    D7,.oam_loop
    ifne CHR_EXPANSION_ENABLED
    movem.l (SP)+,D0-D7/A0-A1
    else
    movem.l (SP)+,D0-D7/A0
    endc
    rts

    ifne CHR_EXPANSION_ENABLED
.oam_tile_bias_tbl:
    dc.w    0                   ; NES sub-pal 0 → shared bank A @ VRAM $0000
    dc.w    512                 ; NES sub-pal 1 → bank B @ VRAM $4000 (tile 512)
    dc.w    1024                ; NES sub-pal 2 → bank C @ VRAM $8000 (tile 1024)
    dc.w    0                   ; NES sub-pal 3 → shared bank A @ VRAM $0000
.oam_pal_bits_tbl:
    dc.w    $0000               ; sub-pal 0 → PAL0 (bits 14:13 = 00)
    dc.w    $0000               ; sub-pal 1 → PAL0
    dc.w    $0000               ; sub-pal 2 → PAL0
    dc.w    $2000               ; sub-pal 3 → PAL1 (bits 14:13 = 01)
    endc

;==============================================================================
; MMC1 mapper writes ($8000 / $A000 / $C000 / $E000)
;==============================================================================
;
; T11b: real MMC1 shift-register decoder.
;
; Protocol: five consecutive writes to a register address.  Each write
; contributes bit 0 (LSB first) to the 5-bit shift accumulator.  Writing
; any byte with bit 7 set resets the shift register immediately.  On the
; 5th valid write the accumulated 5-bit value is stored in the corresponding
; MMC1 state register and the accumulator resets.
;
; MMC1 register map (Genesis RAM, $FF0812–$FF0815):
;   $8000 writes → MMC1_CTRL  (mirroring, PRG mode, CHR mode)
;   $A000 writes → MMC1_CHR0  (CHR bank 0)
;   $C000 writes → MMC1_CHR1  (CHR bank 1)
;   $E000 writes → MMC1_PRG   (PRG bank + RAM enable)
;
; Register contract:
;   D0.b = write value (NES accumulator, from transpiler)
;   D1-D3 saved/restored  (D3 = NES Y index — MUST be preserved)
;   D3 repurposed internally as target register offset (0-3 from MMC1_CTRL)
;   D1 = bit count (work), D2 = bit value (work)
;
; Expected state at LoopForever (T11b probe):
;   MMC1_CTRL = $0F  (IsrReset → SetMMC1Control($0F))
;   MMC1_PRG  = $05  (RunGame  → SwitchBank(5))
;   MMC1_SHIFT = $00, MMC1_COUNT = $00  (reset after each 5th write)
;==============================================================================

_mmc1_write_8000:
    movem.l D1-D3,-(SP)
    moveq   #0,D3                   ; CTRL is at offset 0 from MMC1_CTRL
    bra.s   _mmc1_common

_mmc1_write_a000:
    movem.l D1-D3,-(SP)
    moveq   #1,D3                   ; CHR0 is at offset 1
    bra.s   _mmc1_common

_mmc1_write_c000:
    movem.l D1-D3,-(SP)
    moveq   #2,D3                   ; CHR1 is at offset 2
    bra.s   _mmc1_common

_mmc1_write_e000:
    movem.l D1-D3,-(SP)
    moveq   #3,D3                   ; PRG is at offset 3
    ; fall through to _mmc1_common

_mmc1_common:
    ; Check bit 7 — reset strobe
    btst    #7,D0
    beq.s   .no_reset
    clr.b   (MMC1_SHIFT).l
    clr.b   (MMC1_COUNT).l
    movem.l (SP)+,D1-D3
    rts

.no_reset:
    ; Shift bit 0 of D0 into position MMC1_COUNT of the accumulator
    move.b  (MMC1_COUNT).l,D1      ; D1.b = current count (0–4)
    move.b  D0,D2
    andi.b  #1,D2                   ; D2.b = bit 0 of write value
    lsl.b   D1,D2                   ; D2.b = bit shifted to correct position
    or.b    D2,(MMC1_SHIFT).l       ; accumulate into shift register

    ; Increment count; check for completion
    addq.b  #1,(MMC1_COUNT).l
    cmpi.b  #5,(MMC1_COUNT).l
    bne.s   .mmc1_done              ; not yet 5 bits — wait for more writes

    ; 5th write: copy 5-bit shift value to the target state register
    move.b  (MMC1_SHIFT).l,D2
    andi.b  #$1F,D2                 ; mask to 5 bits
    lea     (MMC1_CTRL).l,A0        ; A0 = base of MMC1_CTRL ($FF0812)
    move.b  D2,(A0,D3.w)            ; store at MMC1_CTRL + D3 offset

    ; Reset accumulator
    clr.b   (MMC1_SHIFT).l
    clr.b   (MMC1_COUNT).l

.mmc1_done:
    movem.l (SP)+,D1-D3
    rts

;==============================================================================
; APU writes ($4000–$4017)  — T5: silent stubs, audio in T10+
;==============================================================================
_apu_write_4000:
_apu_write_4001:
_apu_write_4002:
_apu_write_4003:
_apu_write_4004:
_apu_write_4005:
_apu_write_4006:
_apu_write_4007:
_apu_write_4008:
_apu_write_400a:
_apu_write_400b:
_apu_write_400c:
_apu_write_400e:
_apu_write_400f:
_apu_write_4010:
_apu_write_4011:
_apu_write_4012:
_apu_write_4013:
_apu_write_4015:
_apu_write_4016:
_apu_write_4017:
    rts

;==============================================================================
; _indirect_stub — JMP (abs) indirect placeholder.
; Called when the transpiler can't resolve an indirect jump target at
; translate-time.  Halts via an infinite bra so BizHawk shows PC stuck here.
; In T9+ these will be replaced by computed dispatch tables.
;==============================================================================
_indirect_stub:
    bra.s   _indirect_stub          ; spin — caught as deliberate halt in T9+

;==============================================================================
; _m68k_tablejump — M68K-native replacement for the NES JSR-trick TableJump.
;
; On NES, "JSR TableJump" is a JSR-trick: the bytes after the JSR are a
; table of 16-bit vectors.  TableJump pops the return address from the 6502
; stack to find the table base, then jumps through it using the value in A.
;
; In M68K, BSR pushes the return address (= table base) onto A7 (M68K stack),
; not A5 (our NES stack).  The original TableJump pulled from A5 (zeros),
; constructing a bogus NES address and jumping into garbage.
;
; This replacement correctly pops the M68K return address as the dc.l table
; base, indexes by D0.b × 4, and dispatches.
;
; Calling convention:
;   D0.b = mode index
;   (A7)  = base address of the dc.l jump table (pushed by BSR)
;   Jumps directly to the selected target (does not RTS).
;==============================================================================
_m68k_tablejump:
    movea.l (SP)+,A0        ; pop M68K return address = dc.l table base
    and.w   #$00FF,D0       ; zero-extend mode byte → word
    lsl.w   #2,D0           ; D0.w = index × 4  (each dc.l = 4 bytes)
    movea.l (A0,D0.W),A0   ; load 32-bit target address from table
    jmp     (A0)            ; dispatch (no return)

;==============================================================================
; _clear_nametable_fast — Fast replacement for ClearNameTable.
;
; Fills Plane A with a tile word directly via VDP_DATA (bypassing _ppu_write_7)
; and clears NT_CACHE.  V64 plane: NT0 ($20) → rows 0-29, NT1 ($28) → rows 30-59.
;
; Input:
;   D0.b = hi byte of NES PPU address ($20 = nametable 0, $28 = nametable 1)
;   D2.b = tile index to fill with
;   D3.b = attribute byte (always 0 for Zelda clear; palette 0 used)
;
; Preserves all NES registers (D0, D2, D3, D7, A4, A5).
; Updates PPU_VADDR to the post-clear address (matching original behavior).
;==============================================================================
    even
_clear_nametable_fast:
    movem.l D0-D4/A0,-(SP)

    ; Save NT selection before D0 is clobbered
    move.b  D0,D4                   ; D4.b = NT hi byte ($20 or $28)

    ; Compute the end PPU_VADDR: start + 1024 tiles + 64 attributes = +$0440
    andi.w  #$00FF,D0
    lsl.w   #8,D0                   ; D0.w = PPU base ($2000 or $2800)
    addi.w  #$0440,D0
    move.w  D0,(PPU_VADDR).l        ; set PPU_VADDR to expected end value

    ; Build tile word from the current BG pattern-table selection
    moveq   #0,D0
    move.b  D2,D0                   ; D0.w = raw tile index
    bsr     _compose_bg_tile_word
    move.w  D0,D1                   ; D1.w = tile word to write

    ; Determine VRAM start address based on NT selection
    cmpi.b  #$28,D4
    beq.s   .cnf_nt1

    ; ---- NT0: Fill Plane A rows 0-29 starting at $C000 ----
    move.l  #$40000003,(VDP_CTRL).l ; VRAM write at $C000
    ; Clear NT_CACHE offsets 0-959 (NT0)
    lea     (NT_CACHE_BASE).l,A0
    bra.s   .cnf_fill

.cnf_nt1:
    ; ---- NT1: Fill Plane A rows 30-63 starting at $CF00 ----
    ; 34 rows = 30 NT1 rows + 4 gap rows (prevents garbage when scroll wraps).
    ; $CF00 = $C000 + 30*$80.  VDP command: ($CF00 & $3FFF)<<16 | $40000003
    move.l  #$4F000003,(VDP_CTRL).l ; VRAM write at $CF00
    ; Clear NT_CACHE offsets 960-1919 (NT1)
    lea     (NT_CACHE_BASE+960).l,A0

.cnf_fill:
    ; Write tiles to Plane A rows.  Plane A is 64 tiles wide,
    ; so after each 32-tile NES row we must skip 32 unused tiles.
    ; NT0: 30 rows (0-29).  NT1: 34 rows (30-63, includes 4 gap rows).
    cmpi.b  #$28,D4
    bne.s   .cnf_nt0_count
    moveq   #34-1,D3                ; NT1: 34 rows (fills gap rows 60-63)
    bra.s   .cnf_row
.cnf_nt0_count:
    moveq   #30-1,D3                ; NT0: 30 rows
.cnf_row:
    moveq   #32-1,D4                ; 32 cols per row
.cnf_col:
    move.w  D1,(VDP_DATA).l
    dbf     D4,.cnf_col

    ; Skip 32 unused tile slots (64 bytes) in Plane A row.
    moveq   #32-1,D4
.cnf_skip:
    move.w  D1,(VDP_DATA).l         ; write same tile to unused slots (harmless)
    dbf     D4,.cnf_skip

    dbf     D3,.cnf_row

    ; ---- Clear NT_CACHE (960 bytes for the selected NT) ----
    move.w  #960-1,D3
    move.b  D1,D0                   ; fill byte = tile index
.cnf_cache:
    move.b  D0,(A0)+
    dbf     D3,.cnf_cache

.cnf_done:
    movem.l (SP)+,D0-D4/A0
    rts

;==============================================================================
; _transfer_chr_block_fast — Bulk 2BPP→4BPP tile transfer to VDP VRAM.
;
; Bypasses _ppu_write_7 entirely.  Reads NES 2BPP tile data from a ROM source
; address, converts each 16-byte tile to 32-byte Genesis 4BPP, and writes
; directly to VDP VRAM.  Processes full tiles (16 bytes each).
;
; Input:
;   A0     = ROM source address (32-bit, points to NES 2BPP tile data)
;   D1.w   = NES PPU destination address (CHR range $0000–$1FFF)
;   D2.l   = byte count (must be multiple of 16)
;
; Output:
;   PPU_VADDR updated to D1 + D2 (post-transfer address)
;
; Preserves all NES registers (D0, D2, D3, D7, A4, A5).
;==============================================================================
    even
_transfer_chr_block_fast:
    ifne CHR_EXPANSION_ENABLED
    ; If destination is sprite half ($0000-$0FFF), stage each 16-byte tile
    ; through CHR_TILE_BUF and call _chr_upload_sprite_4x (emits 4 biased
    ; copies).  BG half ($1000-$1FFF) takes the legacy 1x fast path below.
    move.w  D1,D5
    andi.w  #$1000,D5
    bne.s   .tcbf_legacy_entry
    movem.l D0-D7/A0-A2,-(SP)
.tcbf_4x_loop:
    tst.l   D2
    ble.s   .tcbf_4x_done
    lea     (CHR_TILE_BUF).l,A1
    move.l  (A0)+,(A1)+
    move.l  (A0)+,(A1)+
    move.l  (A0)+,(A1)+
    move.l  (A0)+,(A1)+
    move.w  D1,(CHR_BUF_VADDR).l
    bsr     _chr_upload_sprite_4x
    addi.w  #16,D1
    subi.l  #16,D2
    bra.s   .tcbf_4x_loop
.tcbf_4x_done:
    move.w  D1,(PPU_VADDR).l
    movem.l (SP)+,D0-D7/A0-A2
    rts
.tcbf_legacy_entry:
    endc
    movem.l D0-D6/A0-A2,-(SP)

    ; Save byte count for PPU_VADDR update at end
    move.l  D2,D0                   ; D0.l = total byte count

    ; A2 = LUT base (kept across all tiles)
    lea     (.fast_expand_lut).l,A2

    ; A0 = ROM source (already set by caller)
    ; D1.w = NES PPU dest address

.ftcb_tile:
    tst.l   D2
    ble     .ftcb_done

    btst    #5,(PPU_CTRL).l
    beq.s   .ftcb_no_stage_hi_sprite
    cmpi.w  #$1F20,D1
    blo.s   .ftcb_no_stage_hi_sprite
    cmpi.w  #$1F40,D1
    bhs.s   .ftcb_no_stage_hi_sprite
    lea     (CHR_TILE_BUF).l,A1
    move.l  0(A0),(A1)
    move.l  4(A0),4(A1)
    move.l  8(A0),8(A1)
    move.l  12(A0),12(A1)
    move.w  D1,(CHR_BUF_VADDR).l
.ftcb_no_stage_hi_sprite:

    ; Set VDP write address: Genesis VRAM addr = NES CHR addr × 2
    move.w  D1,D3
    add.w   D3,D3                   ; D3.w = VDP VRAM address
    moveq   #0,D4
    move.w  D3,D4
    swap    D4                      ; D4 = addr << 16
    ori.l   #$40000000,D4           ; VDP VRAM-write command
    move.l  D4,(VDP_CTRL).l

    ; Convert 8 rows of this tile
    moveq   #7,D5                   ; row counter

.ftcb_row:
    ; plane0 = (A0), plane1 = 8(A0)
    moveq   #0,D3
    move.b  (A0),D3                 ; D3.b = plane 0 row byte
    moveq   #0,D4
    move.b  8(A0),D4                ; D4.b = plane 1 row byte

    ; ---- Pixels 0-3 (upper nibbles) ----
    move.b  D3,D6
    lsr.b   #4,D6
    andi.w  #$000F,D6
    add.w   D6,D6
    move.w  (A2,D6.W),D6           ; D6.w = plane0 upper expanded

    move.b  D4,D0
    lsr.b   #4,D0
    andi.w  #$000F,D0
    add.w   D0,D0
    move.w  (A2,D0.W),D0           ; D0.w = plane1 upper expanded
    lsl.w   #1,D0                   ; shift plane1 to bit 1
    or.w    D6,D0                   ; combine
    move.w  D0,(VDP_DATA).l         ; write pixels 0-3

    ; ---- Pixels 4-7 (lower nibbles) ----
    move.b  D3,D6
    andi.w  #$000F,D6
    add.w   D6,D6
    move.w  (A2,D6.W),D6           ; D6.w = plane0 lower expanded

    move.b  D4,D0
    andi.w  #$000F,D0
    add.w   D0,D0
    move.w  (A2,D0.W),D0           ; D0.w = plane1 lower expanded
    lsl.w   #1,D0
    or.w    D6,D0
    move.w  D0,(VDP_DATA).l         ; write pixels 4-7

    addq.l  #1,A0                   ; next plane-0 row
    subq.b  #1,D5
    bge.s   .ftcb_row

    ; Skip past plane-1 bytes (A0 is now at +8, plane1 starts at +8 from tile start)
    addq.l  #8,A0                   ; A0 now points to next tile

    btst    #5,(PPU_CTRL).l
    beq.s   .ftcb_no_hi_sprite_upload
    cmpi.w  #$1F20,D1
    blo.s   .ftcb_no_hi_sprite_upload
    cmpi.w  #$1F40,D1
    bhs.s   .ftcb_no_hi_sprite_upload
    bsr     _chr_upload_sprite_4x
.ftcb_no_hi_sprite_upload:

    addi.w  #16,D1                  ; advance NES PPU address by 16 (one tile)
    subi.l  #16,D2                  ; decrement remaining byte count
    bgt     .ftcb_tile

.ftcb_done:
    ; Update PPU_VADDR to expected post-transfer value
    move.w  D1,(PPU_VADDR).l

    movem.l (SP)+,D0-D6/A0-A2
    rts

    ;==========================================================================
    ; LUT for fast CHR conversion: 4-bit nibble → scattered 16-bit word.
    ; Same logic as .expand_nibble_lut but placed here for locality.
    ;==========================================================================
    even
.fast_expand_lut:
    dc.w    $0000,$0001,$0010,$0011,$0100,$0101,$0110,$0111
    dc.w    $1000,$1001,$1010,$1011,$1100,$1101,$1110,$1111

;==============================================================================
; _transfer_tilebuf_fast -- Native tile buffer interpreter.
;
; Replaces TransferTileBuf + ContinueTransferTileBuf.
; Parses tile buffer records and dispatches by PPU address range into
; tight inner loops, avoiding per-byte _ppu_write_7 overhead.
;
; Input:
;   ($0000,A4) / ($0001,A4) = 16-bit NES RAM pointer to buffer start
;   A4 = NES_RAM ($FF0000)
;
; Output:
;   ($0000,A4) / ($0001,A4) updated past last consumed record
;   PPU_VADDR, PPU_CTRL, NT_CACHE, CRAM updated per record contents
;
; Preserves: D0, D2, D3, D7, A4, A5 (6502 register convention)
;==============================================================================
    even
_transfer_tilebuf_fast:
    ; Caller passes buffer pointer in A0 (32-bit absolute address).
    movem.l D0-D6/A0-A3,-(SP)

    ; Reset PPU latch (matches _ppu_read_2 in original TransferTileBuf)
    clr.b   (PPU_LATCH).l

    ; A0 = buffer pointer (set by caller via TransferBufPtrs)
    ; A3 = safety limit: bail if buffer exceeds 2048 bytes (prevents runaway parsing)
    lea     (2048,A0),A3            ; largest buffer is ~1121 bytes

.ttf_next_record:
    cmpa.l  A3,A0                   ; safety limit: bail if past 128 records
    bge     .ttf_done
    move.b  (A0)+,D0                ; first byte of record
    bmi     .ttf_done               ; bit 7 set ($80-$FF) = sentinel -> done

    ; --- Parse record header ---
    ; D0.b = PPU addr hi byte
    moveq   #0,D5
    move.b  D0,D5
    lsl.w   #8,D5
    move.b  (A0)+,D5                ; D5.w = PPU address
    andi.w  #$3FFF,D5

    move.b  (A0)+,D6                ; D6.b = control byte

    ; Decode count (bits 5:0, 0 means 64)
    moveq   #0,D3
    move.b  D6,D3
    andi.w  #$003F,D3
    bne.s   .ttf_count_ok
    moveq   #64,D3
.ttf_count_ok:

    ; NES control byte layout (after two ASLs in original 6502):
    ;   Bit 7 = increment mode: 0 = horizontal (+1), 1 = vertical (+32)
    ;   Bit 6 = repeat mode:    0 = sequential,      1 = repeat single byte

    ; Decode increment (bit 7): 1 or 32
    moveq   #1,D1                   ; D1.w = increment
    btst    #7,D6
    beq.s   .ttf_inc_ok
    moveq   #32,D1
.ttf_inc_ok:

    ; Decode repeat mode (bit 6): prefetch single data byte
    moveq   #0,D4                   ; D4.b = 0 = sequential mode
    btst    #6,D6
    beq.s   .ttf_no_repeat
    move.b  (A0)+,D2                ; D2.b = repeat data byte
    moveq   #-1,D4                  ; D4.b = $FF = repeat mode
.ttf_no_repeat:

    ; Update PPU_CTRL bit 2 (increment mode) + NES RAM $00FF
    move.b  ($00FF,A4),D0
    btst    #7,D6
    beq.s   .ttf_ctrl_h
    ori.b   #$04,D0                 ; set bit 2 = +32 mode
    bra.s   .ttf_ctrl_s
.ttf_ctrl_h:
    andi.b  #$FB,D0                 ; clear bit 2 = +1 mode
.ttf_ctrl_s:
    move.b  D0,($00FF,A4)          ; update NES RAM CurPpuControl
    move.b  D0,(PPU_CTRL).l        ; update PPU_CTRL shadow
    move.w  D5,(PPU_VADDR).l       ; set PPU_VADDR to record start

    ; --- Dispatch by PPU address range ---
    cmpi.w  #$2000,D5
    blo     .ttf_chr_range          ; $0000-$1FFF = CHR
    cmpi.w  #$23C0,D5
    blo     .ttf_nt_range           ; $2000-$23BF = nametable 0 tiles
    cmpi.w  #$2400,D5
    blo     .ttf_attr_range         ; $23C0-$23FF = nametable 0 attributes
    cmpi.w  #$2800,D5
    blo     .ttf_skip_range         ; $2400-$27FF = NT mirror (unused w/ vert mirror)
    cmpi.w  #$2BC0,D5
    blo     .ttf_nt1_range          ; $2800-$2BBF = nametable 1 tiles
    cmpi.w  #$2C00,D5
    blo     .ttf_attr1_range        ; $2BC0-$2BFF = nametable 1 attributes
    cmpi.w  #$3F00,D5
    blo     .ttf_skip_range         ; $2C00-$3EFF = unhandled
    cmpi.w  #$3F20,D5
    blo     .ttf_palette_range      ; $3F00-$3F1F = palette
    bra     .ttf_skip_range         ; $3F20+ = unhandled

    ;==========================================================================
    ; CHR RANGE ($0000-$1FFF): 2BPP tile data -> VDP VRAM
    ;==========================================================================
.ttf_chr_range:
    ; Fast path: sequential + horizontal (+1) + tile-aligned
    cmp.w   #1,D1                   ; horizontal increment?
    bne.s   .ttf_chr_slow
    tst.b   D4                      ; sequential mode?
    bne.s   .ttf_chr_slow
    move.w  D5,D0
    andi.w  #$000F,D0               ; offset within tile
    tst.w   D0
    bne.s   .ttf_chr_slow           ; not tile-aligned

    ; Delegate to _transfer_chr_block_fast (A0=source, D1.w=dest, D2.l=count)
    movea.l A0,A1                   ; save source pointer
    move.w  D5,D1                   ; D1.w = PPU dest
    moveq   #0,D2
    move.w  D3,D2                   ; D2.l = byte count
    bsr     _transfer_chr_block_fast
    adda.l  D3,A1                   ; advance past consumed bytes
    movea.l A1,A0
    bra     .ttf_post_record

.ttf_chr_slow:
    ; Byte-by-byte CHR buffering (handles non-aligned, vertical, repeat)
    ; Use existing CHR_TILE_BUF accumulation logic
    lea     (CHR_TILE_BUF).l,A2

.ttf_chr_slow_loop:
    ; Get data byte
    tst.b   D4                      ; repeat mode?
    bne.s   .ttf_chr_have_byte
    move.b  (A0)+,D2                ; sequential: read next byte
.ttf_chr_have_byte:

    ; Store in CHR_TILE_BUF at (PPU_VADDR & $F)
    move.w  D5,D0
    andi.w  #$000F,D0
    move.b  D2,(A2,D0.W)           ; CHR_TILE_BUF[offset] = byte

    ; Check if first byte of tile: save base address
    tst.w   D0
    bne.s   .ttf_chr_no_base
    move.w  D5,D0
    andi.w  #$FFF0,D0
    move.w  D0,(CHR_BUF_VADDR).l
.ttf_chr_no_base:

    ; Advance PPU_VADDR
    add.w   D1,D5

    ; Check if we just completed a tile (16 bytes)
    move.w  D5,D0
    andi.w  #$000F,D0
    tst.w   D0
    bne.s   .ttf_chr_no_convert

    ; Convert and upload the completed tile
    ifne CHR_EXPANSION_ENABLED
    move.w  (CHR_BUF_VADDR).l,D0
    btst    #12,D0
    bne.s   .ttf_chr_bg_dispatch
    bsr     _chr_upload_sprite_4x
    bra.s   .ttf_chr_uploaded
.ttf_chr_bg_dispatch:
    bsr     _chr_convert_upload
    btst    #5,(PPU_CTRL).l
    beq.s   .ttf_chr_uploaded
    move.w  (CHR_BUF_VADDR).l,D0
    cmpi.w  #$1F20,D0
    blo.s   .ttf_chr_uploaded
    cmpi.w  #$1F40,D0
    bhs.s   .ttf_chr_uploaded
    bsr     _chr_upload_sprite_4x
.ttf_chr_uploaded:
    else
    bsr     _chr_convert_upload
    endc
.ttf_chr_no_convert:

    subq.w  #1,D3
    bne.s   .ttf_chr_slow_loop
    bra     .ttf_post_record

    ;==========================================================================
    ; NAMETABLE RANGE ($2000-$23BF): tile index -> Plane A word
    ;==========================================================================
.ttf_nt_range:
    lea     (NT_CACHE_BASE).l,A2

.ttf_nt_loop:
    ; Get data byte
    tst.b   D4                      ; repeat mode?
    bne.s   .ttf_nt_have_byte
    move.b  (A0)+,D2                ; sequential: read next byte
.ttf_nt_have_byte:

    ; Bounds check
    cmpi.w  #$23C0,D5
    bhs.s   .ttf_nt_skip

    ; Compute index = PPU_VADDR - $2000
    move.w  D5,D0
    subi.w  #$2000,D0               ; D0.w = index (0..$3BF)

    ; Cache tile index in NT_CACHE
    move.b  D2,(A2,D0.W)

    ; Compute VDP address: $C000 + row*$80 + col*2
    move.w  D0,D6                   ; save index
    andi.w  #$001F,D6               ; col = index & 31
    lsl.w   #1,D6                   ; col * 2
    lsr.w   #5,D0                   ; row = index >> 5
    mulu.w  #$0080,D0              ; row * $80
    add.w   D6,D0                   ; row*$80 + col*2
    addi.w  #$C000,D0              ; + Plane A base

    ; Issue VDP VRAM write command
    moveq   #0,D6
    move.w  D0,D6
    andi.l  #$00003FFF,D6
    swap    D6
    ori.l   #$40000003,D6          ; CD bits + A[15:14]=3 for $C000+
    move.l  D6,(VDP_CTRL).l

    ; Write tile word: tile index + BG pattern table offset
    moveq   #0,D0
    move.b  D2,D0
    bsr     _compose_bg_tile_word
    move.w  D0,(VDP_DATA).l

.ttf_nt_skip:
    add.w   D1,D5                   ; advance PPU_VADDR
    andi.w  #$3FFF,D5
    subq.w  #1,D3
    bne.s   .ttf_nt_loop
    bra     .ttf_post_record

    ;==========================================================================
    ; ATTRIBUTE RANGE ($23C0-$23FF): palette bits -> Plane A tile words
    ;==========================================================================
.ttf_attr_range:

.ttf_attr_loop:
    ; Get data byte
    tst.b   D4                      ; repeat mode?
    bne.s   .ttf_attr_have_byte
    move.b  (A0)+,D2                ; sequential: read next byte
.ttf_attr_have_byte:

    ; Bounds check
    cmpi.w  #$23C0,D5
    blo     .ttf_attr_skip
    cmpi.w  #$2400,D5
    bhs     .ttf_attr_skip

    ; Compute attr offset and tile base col/row
    move.w  D5,D0
    subi.w  #$23C0,D0               ; D0.w = attr offset (0..63)

    ; tile_base_col = (offset & 7) * 4, tile_base_row = (offset >> 3) * 4
    ; Save current regs (D1-D4 clobbered by attr helper, A0 clobbered by NT_CACHE read)
    move.l  A0,-(SP)                ; save buffer pointer (attr helper clobbers A0)
    movem.l D1-D4,-(SP)

    move.w  D0,D3
    lsr.w   #3,D3
    lsl.w   #2,D3                   ; D3.w = tile_base_row
    andi.w  #$0007,D0
    lsl.w   #2,D0
    move.w  D0,D2                   ; D2.w = tile_base_col

    ; Get attribute byte from saved D2 on stack
    ; movem.l D1-D4,-(SP) pushes: SP+0=D1, SP+4=D2, SP+8=D3, SP+12=D4
    move.l  (4,SP),D0              ; D0.l = old D2 (the attr data byte)
    move.b  D0,D4                  ; D4.b = attribute byte

    ; Quadrant 0: bits [1:0], row_off=0, col_off=0
    move.w  D4,D5
    andi.w  #$0003,D5
    lsl.w   #5,D5
    lsl.w   #8,D5                   ; D5.w = palette<<13
    bsr     _attr_write_2x2

    ; Quadrant 1: bits [3:2], col_off=+2
    move.w  D4,D5
    lsr.w   #2,D5
    andi.w  #$0003,D5
    lsl.w   #5,D5
    lsl.w   #8,D5
    addq.w  #2,D2
    bsr     _attr_write_2x2
    subq.w  #2,D2

    ; Quadrant 2: bits [5:4], row_off=+2
    move.w  D4,D5
    lsr.w   #4,D5
    andi.w  #$0003,D5
    lsl.w   #5,D5
    lsl.w   #8,D5
    addq.w  #2,D3
    bsr     _attr_write_2x2
    subq.w  #2,D3

    ; Quadrant 3: bits [7:6], row_off=+2, col_off=+2
    move.w  D4,D5
    lsr.w   #6,D5
    andi.w  #$0003,D5
    lsl.w   #5,D5
    lsl.w   #8,D5
    addq.w  #2,D2
    addq.w  #2,D3
    bsr     _attr_write_2x2
    subq.w  #2,D2
    subq.w  #2,D3

    movem.l (SP)+,D1-D4
    movea.l (SP)+,A0                ; restore buffer pointer
    ; Restore D5 = PPU_VADDR from PPU state (was clobbered by palette bits)
    move.w  (PPU_VADDR).l,D5

.ttf_attr_skip:
    add.w   D1,D5                   ; advance PPU_VADDR
    andi.w  #$3FFF,D5
    move.w  D5,(PPU_VADDR).l
    subq.w  #1,D3
    bne     .ttf_attr_loop
    bra     .ttf_post_record

    ;==========================================================================
    ; NAMETABLE 1 RANGE ($2800-$2BBF): tile index -> Plane A word
    ; Maps NT1 tiles to Plane A rows 30-59 (V64 plane, below NT0 rows 0-29).
    ;==========================================================================
.ttf_nt1_range:
    lea     (NT_CACHE_BASE).l,A2

.ttf_nt1_loop:
    ; Get data byte
    tst.b   D4                      ; repeat mode?
    bne.s   .ttf_nt1_have_byte
    move.b  (A0)+,D2                ; sequential: read next byte
.ttf_nt1_have_byte:

    ; Bounds check
    cmpi.w  #$2BC0,D5
    bhs     .ttf_nt1_skip

    ; Compute index = PPU_VADDR - $2800
    move.w  D5,D0
    subi.w  #$2800,D0               ; D0.w = index (0..$3BF)

    ; Cache tile index in NT_CACHE at NT1 offset (+960)
    move.w  D0,D6
    addi.w  #960,D6
    move.b  D2,(A2,D6.W)

    ; Compute VDP address: $C000 + (row+30)*$80 + col*2
    move.w  D0,D6                   ; save index
    andi.w  #$001F,D6               ; col = index & 31
    lsl.w   #1,D6                   ; col * 2
    lsr.w   #5,D0                   ; row = index >> 5
    addi.w  #30,D0                  ; +30: NT1 rows 30-59 in V64 plane
    mulu.w  #$0080,D0              ; (row+30) * $80
    add.w   D6,D0                   ; + col*2
    addi.w  #$C000,D0              ; + Plane A base

    ; Issue VDP VRAM write command
    moveq   #0,D6
    move.w  D0,D6
    andi.l  #$00003FFF,D6
    swap    D6
    ori.l   #$40000003,D6          ; CD bits + A[15:14]
    move.l  D6,(VDP_CTRL).l

    ; Write tile word: tile index + BG pattern table offset
    moveq   #0,D0
    move.b  D2,D0
    bsr     _compose_bg_tile_word
    ; Item-screen title flourish color fix:
    ; the ALL OF TREASURES side ornaments live on NT1 row $2900-$291F and use
    ; tiles $E4-$E6. On NES those blocks inherit palette 3; Genesis leaves them
    ; at palette 0 unless we force the same green palette here.
    cmpi.w  #$2900,D5
    blo.s   .ttf_nt1_write
    cmpi.w  #$2920,D5
    bhs.s   .ttf_nt1_write
    cmpi.b  #$E4,D2
    blo.s   .ttf_nt1_write
    cmpi.b  #$E6,D2
    bhi.s   .ttf_nt1_write
    ori.w   #$6000,D0
.ttf_nt1_write:
    move.w  D0,(VDP_DATA).l

.ttf_nt1_skip:
    add.w   D1,D5                   ; advance PPU_VADDR
    andi.w  #$3FFF,D5
    subq.w  #1,D3
    bne     .ttf_nt1_loop
    bra     .ttf_post_record

    ;==========================================================================
    ; ATTRIBUTE 1 RANGE ($2BC0-$2BFF): NT1 palette bits -> Plane A tile words
    ;==========================================================================
.ttf_attr1_range:

.ttf_attr1_loop:
    ; Get data byte
    tst.b   D4                      ; repeat mode?
    bne.s   .ttf_attr1_have_byte
    move.b  (A0)+,D2                ; sequential: read next byte
.ttf_attr1_have_byte:

    ; Bounds check
    cmpi.w  #$2BC0,D5
    blo     .ttf_attr1_skip
    cmpi.w  #$2C00,D5
    bhs     .ttf_attr1_skip

    ; Compute attr offset (same as NT0 but from $2BC0 base)
    move.w  D5,D0
    subi.w  #$2BC0,D0               ; D0.w = attr offset (0..63)

    ; Save regs (attr helper clobbers D1-D4 and A0)
    move.l  A0,-(SP)
    movem.l D1-D4,-(SP)

    move.w  D0,D3
    lsr.w   #3,D3
    lsl.w   #2,D3                   ; D3.w = tile_base_row (0-28)
    addi.w  #30,D3                  ; +30: NT1 rows 30-59 in V64 plane
    andi.w  #$0007,D0
    lsl.w   #2,D0
    move.w  D0,D2                   ; D2.w = tile_base_col

    ; Get attribute byte from saved D2 on stack
    move.l  (4,SP),D0
    move.b  D0,D4                  ; D4.b = attribute byte

    ; Quadrant 0: bits [1:0]
    move.w  D4,D5
    andi.w  #$0003,D5
    lsl.w   #5,D5
    lsl.w   #8,D5
    bsr     _attr_write_2x2

    ; Quadrant 1: bits [3:2], col_off=+2
    move.w  D4,D5
    lsr.w   #2,D5
    andi.w  #$0003,D5
    lsl.w   #5,D5
    lsl.w   #8,D5
    addq.w  #2,D2
    bsr     _attr_write_2x2
    subq.w  #2,D2

    ; Quadrant 2: bits [5:4], row_off=+2
    move.w  D4,D5
    lsr.w   #4,D5
    andi.w  #$0003,D5
    lsl.w   #5,D5
    lsl.w   #8,D5
    addq.w  #2,D3
    bsr     _attr_write_2x2
    subq.w  #2,D3

    ; Quadrant 3: bits [7:6], row_off=+2, col_off=+2
    move.w  D4,D5
    lsr.w   #6,D5
    andi.w  #$0003,D5
    lsl.w   #5,D5
    lsl.w   #8,D5
    addq.w  #2,D2
    addq.w  #2,D3
    bsr     _attr_write_2x2
    subq.w  #2,D2
    subq.w  #2,D3

    movem.l (SP)+,D1-D4
    movea.l (SP)+,A0
    move.w  (PPU_VADDR).l,D5

.ttf_attr1_skip:
    add.w   D1,D5                   ; advance PPU_VADDR
    andi.w  #$3FFF,D5
    move.w  D5,(PPU_VADDR).l
    subq.w  #1,D3
    bne     .ttf_attr1_loop
    bra     .ttf_post_record

    ;==========================================================================
    ; PALETTE RANGE ($3F00-$3F1F): NES color -> Genesis CRAM
    ;==========================================================================
.ttf_palette_range:
    move.l  A3,-(SP)                ; save safety limit
    lea     (nes_palette_to_genesis).l,A3

.ttf_pal_loop:
    ; Get data byte
    tst.b   D4                      ; repeat mode?
    bne.s   .ttf_pal_have_byte
    move.b  (A0)+,D2                ; sequential: read next byte
.ttf_pal_have_byte:

    ; Bounds check
    cmpi.w  #$3F20,D5
    bhs.s   .ttf_pal_skip

    ; Compute palette offset
    move.w  D5,D0
    subi.w  #$3F00,D0
    andi.w  #$001F,D0               ; offset 0..31

    ; NES palette mirroring & sprite palette remap
    ; Entry-0 offsets (16,20,24,28) mirror universal BG color → remap to BG
    ; Non-entry-0 sprite colors → remap to Genesis CRAM palettes 2-3
    cmpi.w  #$10,D0
    blo.s   .ttf_pal_bg
    move.w  D0,D6
    andi.w  #$0003,D6
    bne.s   .ttf_pal_spr            ; non-zero slot → sprite palette
    subi.w  #$10,D0                 ; entry-0: remap 16→0, 20→4, 24→8, 28→12
    bra.s   .ttf_pal_bg
.ttf_pal_spr:
    ifne CHR_EXPANSION_ENABLED
    ; T-CHR S8 v2: pack sprite sub-palettes into unused tail slots of BG
    ; palettes (PAL0[4..15] + PAL1[4..7]).  See .t19_spr_cram_base for the
    ; mapping table.  Using an inline table to avoid cross-scope lea.
    move.w  D0,D6
    subi.w  #$10,D6
    lsr.w   #2,D6                   ; D6 = sub-pal (0..3)
    add.w   D6,D6                   ; * 2 for word index
    lea     (.ttf_spr_cram_base,PC),A2
    move.w  (A2,D6.W),D6            ; D6 = CRAM base for this sub-pal
    andi.w  #$0003,D0               ; color slot (1..3)
    add.w   D0,D0                   ; * 2
    add.w   D0,D6                   ; D6 = CRAM address
    ; D2 preserved (holds palette data byte for later .ttf_pal_have_cram lookup)
    bra.s   .ttf_pal_have_cram_new
.ttf_spr_cram_base:
    dc.w    $08                     ; sub-pal 0 → PAL0[4]
    dc.w    $10                     ; sub-pal 1 → PAL0[8]
    dc.w    $18                     ; sub-pal 2 → PAL0[12]
    dc.w    $28                     ; sub-pal 3 → PAL1[4]
.ttf_pal_have_cram_new:
    else
    ; Legacy: remap NES sprite pal 0-3 → Genesis pal 2-3 (last-write-wins).
    move.w  D0,D6
    subi.w  #$10,D6
    lsr.w   #2,D6                   ; NES sprite pal (0-3)
    ori.w   #$0002,D6               ; Genesis pal = NES_pal | 2 (0→2, 1→3, 2→2, 3→3)
    andi.w  #$0003,D6
    lsl.w   #5,D6                   ; * $20
    andi.w  #$0003,D0               ; color slot
    lsl.w   #1,D0                   ; * 2
    add.w   D0,D6                   ; D6.w = CRAM address
    endc
    bra.s   .ttf_pal_have_cram
.ttf_pal_bg:

    ; Compute CRAM address: palette_idx*$20 + color_slot*2
    move.w  D0,D6
    lsr.w   #2,D6                   ; palette index (0..3)
    lsl.w   #5,D6                   ; * $20
    andi.w  #$0003,D0               ; color slot
    lsl.w   #1,D0                   ; * 2
    add.w   D0,D6                   ; D6.w = CRAM address
.ttf_pal_have_cram:

    ; VDP CRAM write command
    moveq   #0,D0
    move.w  D6,D0
    swap    D0
    ori.l   #$C0000000,D0
    move.l  D0,(VDP_CTRL).l

    ; Look up NES->Genesis color
    moveq   #0,D0
    move.b  D2,D0
    andi.w  #$003F,D0               ; mask to valid color index
    lsl.w   #1,D0                   ; word offset
    move.w  (A3,D0.W),D0           ; Genesis color word
    move.w  D0,(VDP_DATA).l

.ttf_pal_skip:
    add.w   D1,D5                   ; advance PPU_VADDR
    andi.w  #$3FFF,D5
    subq.w  #1,D3
    bne     .ttf_pal_loop

    ; Palette post-reset: set PPU_VADDR to $0000, clear latch
    move.w  #$0000,(PPU_VADDR).l
    clr.b   (PPU_LATCH).l
    movea.l (SP)+,A3                ; restore safety limit
    bra     .ttf_next_record        ; skip .ttf_post_record

    ;==========================================================================
    ; SKIP: unhandled PPU address range — consume payload and continue
    ;==========================================================================
.ttf_skip_range:
    tst.b   D4                      ; repeat mode?
    bne.s   .ttf_post_record        ; repeat: 1 byte already consumed
    adda.w  D3,A0                   ; sequential: skip D3 bytes
    bra     .ttf_post_record

    ;==========================================================================
    ; POST-RECORD: update PPU_VADDR and loop to next record
    ;==========================================================================
.ttf_post_record:
    move.w  D5,(PPU_VADDR).l
    bra     .ttf_next_record

    ;==========================================================================
    ; DONE: update ZP pointer and return
    ;==========================================================================
.ttf_done:
    ; Reset VDP to VRAM write mode so stale CRAM targeting doesn't
    ; corrupt palette on subsequent VDP_DATA writes.
    ; Target $FFFC (unused VRAM) to avoid corrupting tile 0 on stray writes.
    move.l  #$7FFC0003,(VDP_CTRL).l
    movem.l (SP)+,D0-D6/A0-A3
    rts
