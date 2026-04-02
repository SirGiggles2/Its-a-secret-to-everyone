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
; 32 × 30 = 960 bytes.  NT_CACHE[row*32 + col] = tile index written by T18.
; Read by T20 attribute handler to re-write tile words with correct palette bits.
;------------------------------------------------------------------------------
NT_CACHE_BASE   equ CHR_STATE_BASE+$20  ; $FF0840  (32×30 = 960 bytes)

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
    move.b  D0,(PPU_CTRL).l
    rts

;------------------------------------------------------------------------------
; _ppu_write_1 — PPUMASK ($2001)
; Store shadow for potential video-enable logic in T6+.
;------------------------------------------------------------------------------
_ppu_write_1:
    move.b  D0,(PPU_MASK).l
    ; Translate PPUMASK bits 3,4 (BG enable, sprite enable) → VDP Reg 1 display bit.
    ; D0 is not modified (btst is non-destructive; move.w #imm,addr doesn't use D0).
    btst    #3,D0                   ; bit 3 = show background
    bne.s   .ppumask_display_on
    btst    #4,D0                   ; bit 4 = show sprites
    bne.s   .ppumask_display_on
    move.w  #$8134,(VDP_CTRL).l     ; Reg 1: display OFF (VBlank IRQ + DMA + M5)
    rts
.ppumask_display_on:
    move.w  #$8174,(VDP_CTRL).l     ; Reg 1: display ON  (bit 6 set)
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
; Preserves: D0–D5, A0–A6 (all saved/restored).
;------------------------------------------------------------------------------
_ppu_write_7:
    movem.l D0-D5/A0,-(SP)          ; save all working registers (D0 = NES acc)

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

    ; Complete tile — convert 2BPP → 4BPP and upload to VDP VRAM
    bsr     .chr_convert_upload
    clr.b   (CHR_BUF_CNT).l

.chr_ret:
    movem.l (SP)+,D0-D5/A0
    rts

    ;==========================================================================
    ; NAMETABLE / PALETTE PATH  (PPU_VADDR $2000–$3FFF)
    ;==========================================================================
    ; Word-pair buffering: buffer even-address byte, flush word on odd address.
    ;==========================================================================
.nt_write:
    ;======================================================================
    ; T18: Nametable 0 tile area ($2000–$23BF) → Genesis Plane A @ $C000.
    ;
    ; Each NES byte is one tile index.  Convert to a Genesis tile word and
    ; write to Plane A at the correct col/row position.
    ;
    ; Plane A is at VDP VRAM $C000 (Reg 2 = $8230), 64H × 32V (Reg 16=$9001),
    ; so each row is 64 tiles × 2 bytes = $80 bytes wide.
    ;
    ;   index    = PPU_VADDR − $2000           (0 … $3BF)
    ;   col      = index & 31                  (0 … 31)
    ;   row      = index >> 5                  (0 … 29)
    ;   vdp_addr = $C000 + row * $80 + col * 2
    ;   tile word = 0x0000 | tile_index        (palette 0, no flip, no priority)
    ;
    ; Attribute bytes ($23C0–$23FF) and all higher addresses: no-op (skip write).
    ;======================================================================
    cmpi.w  #$23C0,D1
    bhs.s   .nt_noop                ; ≥$23C0: attribute / palette / overflow — no-op

    move.w  D1,D2
    subi.w  #$2000,D2               ; D2.w = index (0…$3BF)

    move.w  D2,D3
    andi.w  #$001F,D3               ; D3.w = col (0…31)
    lsl.w   #1,D3                   ; D3.w = col * 2

    lsr.w   #5,D2                   ; D2.w = row (0…29)
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

    ; Write Genesis tile word: tile index only (palette 0, no flip, no priority)
    andi.w  #$00FF,D0               ; D0.w = tile index (0…255)
    move.w  D0,(VDP_DATA).l         ; write tile word to Plane A

    ; T20: cache tile index for attribute palette updates
    ; Cache offset = PPU_VADDR - $2000 = row*32 + col  (NES nametable is 32 wide)
    move.w  D1,D3
    subi.w  #$2000,D3               ; D3.w = cache offset (0…$3BF)
    lea     (NT_CACHE_BASE).l,A0
    move.b  D0,(A0,D3.W)            ; NT_CACHE[offset] = tile index

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
    bsr     .attr_write_2x2

    ; Quadrant 1: bits [3:2], row_off=0, col_off=+2
    move.w  D4,D5
    lsr.w   #2,D5
    andi.w  #$0003,D5
    lsl.w   #5,D5
    lsl.w   #8,D5
    addq.w  #2,D2
    bsr     .attr_write_2x2
    subq.w  #2,D2

    ; Quadrant 2: bits [5:4], row_off=+2, col_off=0
    move.w  D4,D5
    lsr.w   #4,D5
    andi.w  #$0003,D5
    lsl.w   #5,D5
    lsl.w   #8,D5
    addq.w  #2,D3
    bsr     .attr_write_2x2
    subq.w  #2,D3

    ; Quadrant 3: bits [7:6], row_off=+2, col_off=+2
    move.w  D4,D5
    lsr.w   #6,D5
    andi.w  #$0003,D5
    lsl.w   #5,D5
    lsl.w   #8,D5
    addq.w  #2,D2
    addq.w  #2,D3
    bsr     .attr_write_2x2
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

    ; Sprite palettes ($3F10-$3F1F = offset 16-31): BG pals 2,3 already have
    ; the same colors as sprite pals 2,3 for Zelda; sprite pal 0,1 would
    ; overwrite BG pal 0,1 slots with wrong colors.  Skip all sprite pal writes.
    cmpi.w  #$10,D2
    bhs.s   .nt_skip_write          ; sprite palette → skip

    move.w  D2,D3
    lsr.w   #2,D3                   ; D3.w = palette index (0..3)
    lsl.w   #5,D3                   ; D3.w = palette * $20

    andi.w  #$0003,D2               ; D2.w = color slot (0..3)
    lsl.w   #1,D2                   ; D2.w = color * 2
    add.w   D2,D3                   ; D3.w = CRAM address (0..$66)

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
    movem.l (SP)+,D0-D5/A0
    rts

    ;==========================================================================
    ; .attr_write_2x2 — write palette bits into a 2×2 tile block.
    ;
    ; Input: D2.w = col (top-left tile), D3.w = row (top-left tile)
    ;        D5.w = palette << 11  (Genesis tile word palette bits)
    ; All inputs preserved.  Uses D0, D1, A0 as scratch.
    ;==========================================================================
.attr_write_2x2:
    bsr     .attr_write_one_tile        ; (row,   col)
    addq.w  #1,D2
    bsr     .attr_write_one_tile        ; (row,   col+1)
    addq.w  #1,D3
    bsr     .attr_write_one_tile        ; (row+1, col+1)
    subq.w  #1,D2
    bsr     .attr_write_one_tile        ; (row+1, col)
    subq.w  #1,D3
    rts

    ;==========================================================================
    ; .attr_write_one_tile — write one Plane A tile word with palette bits.
    ;
    ; Input: D2.w = col (0..31), D3.w = row (0..29), D5.w = palette << 11
    ; Reads tile index from NT_CACHE_BASE[row*32 + col].
    ; Writes tile word = (palette<<11) | tile_index to VDP Plane A.
    ; Inputs D2, D3, D5 preserved.  Uses D0, D1, A0.
    ;==========================================================================
.attr_write_one_tile:
    ; Bounds check
    cmpi.w  #30,D3
    bhs.s   .awt_skip           ; row ≥ 30 → out of nametable
    cmpi.w  #32,D2
    bhs.s   .awt_skip           ; col ≥ 32 → out of nametable

    ; Load cached tile index: NT_CACHE[row*32 + col]
    moveq   #0,D1
    move.w  D3,D1
    lsl.w   #5,D1               ; D1.w = row * 32
    add.w   D2,D1               ; D1.w = row*32 + col
    lea     (NT_CACHE_BASE).l,A0
    moveq   #0,D0
    move.b  (A0,D1.W),D0        ; D0.b = tile index

    ; Build tile word: (palette<<13) | tile_index   [palette at Genesis bits 14:13]
    or.w    D5,D0               ; D0.w = tile word with palette bits

    ; Compute Genesis VDP address: $C000 + row*$80 + col*2
    moveq   #0,D1
    move.w  D3,D1
    lsl.l   #7,D1               ; D1.l = row * $80  (lsl.l preserves zero-extended upper)
    add.w   D2,D1
    add.w   D2,D1               ; D1.w += col * 2
    addi.w  #$C000,D1           ; D1.w = VDP address (Plane A base $C000)

    ; Issue VDP VRAM write command, then write tile word
    ; Plane A addresses have A[15:14]=11=3. Full command: $40000000|((addr&$3FFF)<<16)|3
    move.w  D0,-(SP)            ; save tile word
    move.l  D1,D0               ; copy addr
    andi.l  #$00003FFF,D0       ; D0.l = addr & $3FFF
    swap    D0                  ; D0.l = (addr & $3FFF) << 16
    ori.l   #$40000003,D0       ; add CD bits + A[15:14]=3
    move.l  D0,(VDP_CTRL).l
    move.w  (SP)+,D0            ; restore tile word into D0.w
    move.w  D0,(VDP_DATA).l     ; write tile word to Plane A

.awt_skip:
    rts

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
.chr_convert_upload:
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
    ;         Represents the plane-0 (or plane-1) contribution to 4 pixels.
    ;         Caller left-shifts by 1 for plane-1 (bit-1 contribution).
    ;
    ; Example: n = 0b1010 (pixels 0,2 set; pixels 1,3 clear)
    ;   output = $1010  ($1000 | $0010)
    ;   Meaning: pixel 0 nibble = 1, pixel 1 = 0, pixel 2 = 1, pixel 3 = 0.
    ;
    ; Uses: D0 as scratch (lsl.w residue in D0 cleared by andi.w).
    ; Caller (.ccu_row) saves plane0 expansion in D6, not D0.
    ;==========================================================================
.expand_nibble:
    moveq   #0,D2

    ; bit 3 of D1 → bit 12 of D2  (shift: 3→12, i.e. ×(4096/8) = ×512 = <<9)
    move.b  D1,D0
    andi.w  #$0008,D0               ; isolate bit 3, clear D0 high byte residue
    lsl.w   #8,D0                   ; shift 8: $08 → $0800
    lsl.w   #1,D0                   ; shift 1 more: $0800 → $1000  (bit 12)
    or.w    D0,D2

    ; bit 2 of D1 → bit 8 of D2  (<<6: $04 → $0100)
    move.b  D1,D0
    andi.w  #$0004,D0               ; isolate bit 2, clear D0 high byte residue
    lsl.w   #6,D0
    or.w    D0,D2

    ; bit 1 of D1 → bit 4 of D2  (<<3: $02 → $0010)
    move.b  D1,D0
    andi.w  #$0002,D0               ; isolate bit 1, clear D0 high byte residue
    lsl.w   #3,D0
    or.w    D0,D2

    ; bit 0 of D1 → bit 0 of D2  (no shift: $01 → $0001)
    move.b  D1,D0
    andi.w  #$0001,D0               ; isolate bit 0, clear D0 high byte residue
    or.w    D0,D2

    rts

;==============================================================================
; NES → Genesis palette lookup table
;
; 64 × 16-bit words: index = NES color byte (0–63).
; Genesis color format: $0BGR (bits [10:8]=Blue, [6:4]=Green, [2:0]=Red, 0–7 each).
; Source: standard NES NTSC palette (NESdev wiki) converted to Genesis 3-bit channels.
;   genesis_ch = round(nes_ch * 7 / 255)  clamped to 0..7
;   word = (gb << 8) | (gg << 4) | gr
;==============================================================================
    even
nes_palette_to_genesis:
    ;       NES $00–$0F  (grays, blues, purples, reds, greens)
    dc.w    $0333   ; $00  rgb(84,84,84)     dark gray (universal BG)
    dc.w    $0700   ; $01  rgb(0,0,252)     dark blue
    dc.w    $0500   ; $02  rgb(0,0,188)     dark blue
    dc.w    $0512   ; $03  rgb(68,40,188)   blue-violet
    dc.w    $0404   ; $04  rgb(148,0,132)   purple
    dc.w    $0105   ; $05  rgb(168,0,32)    dark red-magenta
    dc.w    $0005   ; $06  rgb(168,16,0)    dark red
    dc.w    $0014   ; $07  rgb(136,20,0)    dark red-brown
    dc.w    $0012   ; $08  rgb(80,48,0)     dark brown
    dc.w    $0030   ; $09  rgb(0,120,0)     dark green
    dc.w    $0030   ; $0A  rgb(0,104,0)     dark green
    dc.w    $0020   ; $0B  rgb(0,88,0)      very dark green
    dc.w    $0220   ; $0C  rgb(0,64,88)     dark teal
    dc.w    $0000   ; $0D  black (unused/invalid)
    dc.w    $0000   ; $0E  black (unused/invalid)
    dc.w    $0000   ; $0F  black (unused/invalid)

    ;       NES $10–$1F  (light grays, bright blues/reds, mid greens, teals)
    dc.w    $0555   ; $10  rgb(152,152,152)  light gray
    dc.w    $0730   ; $11  rgb(0,120,248)   bright blue
    dc.w    $0720   ; $12  rgb(0,88,248)    bright blue
    dc.w    $0723   ; $13  rgb(104,68,252)  blue-violet
    dc.w    $0606   ; $14  rgb(216,0,204)   bright magenta
    dc.w    $0206   ; $15  rgb(228,0,88)    bright red
    dc.w    $0027   ; $16  rgb(248,56,0)    bright orange-red
    dc.w    $0036   ; $17  rgb(228,92,16)   orange
    dc.w    $0035   ; $18  rgb(172,124,0)   yellow-orange
    dc.w    $0050   ; $19  rgb(0,184,0)     green
    dc.w    $0050   ; $1A  rgb(0,168,0)     green
    dc.w    $0250   ; $1B  rgb(0,168,68)    green-teal
    dc.w    $0440   ; $1C  rgb(0,136,136)   teal
    dc.w    $0000   ; $1D  black (unused/invalid)
    dc.w    $0000   ; $1E  black (unused/invalid)
    dc.w    $0000   ; $1F  black (unused/invalid)

    ;       NES $20–$2F  (near-white, light colors, pastels)
    dc.w    $0777   ; $20  rgb(248,248,248) near-white
    dc.w    $0752   ; $21  rgb(60,188,252)  light cyan-blue
    dc.w    $0743   ; $22  rgb(104,136,252) light blue
    dc.w    $0734   ; $23  rgb(152,120,248) light purple-blue
    dc.w    $0737   ; $24  rgb(248,120,248) light magenta
    dc.w    $0427   ; $25  rgb(248,88,152)  light pink-red
    dc.w    $0237   ; $26  rgb(248,120,88)  light orange
    dc.w    $0247   ; $27  rgb(252,160,68)  light yellow-orange
    dc.w    $0057   ; $28  rgb(248,184,0)   yellow
    dc.w    $0175   ; $29  rgb(184,248,24)  yellow-green
    dc.w    $0262   ; $2A  rgb(88,216,84)   light green
    dc.w    $0472   ; $2B  rgb(88,248,152)  light green-teal
    dc.w    $0660   ; $2C  rgb(0,232,216)   light teal
    dc.w    $0333   ; $2D  rgb(120,120,120) medium gray
    dc.w    $0000   ; $2E  black (unused/invalid)
    dc.w    $0000   ; $2F  black (unused/invalid)

    ;       NES $30–$3F  (whites, very light pastels)
    dc.w    $0777   ; $30  rgb(252,252,252) white
    dc.w    $0765   ; $31  rgb(164,228,252) very light blue
    dc.w    $0755   ; $32  rgb(184,184,248) very light purple-blue
    dc.w    $0756   ; $33  rgb(216,184,248) very light purple
    dc.w    $0757   ; $34  rgb(248,184,248) very light magenta
    dc.w    $0557   ; $35  rgb(248,164,192) very light pink
    dc.w    $0567   ; $36  rgb(252,204,112)  very light orange-yellow
    dc.w    $0567   ; $37  rgb(252,224,168) very light yellow
    dc.w    $0367   ; $38  rgb(248,216,120) light yellow
    dc.w    $0376   ; $39  rgb(216,248,120) light yellow-green
    dc.w    $0575   ; $3A  rgb(184,248,184) light green
    dc.w    $0675   ; $3B  rgb(184,248,216) very light teal
    dc.w    $0770   ; $3C  rgb(0,252,252)   bright cyan
    dc.w    $0767   ; $3D  rgb(248,216,248) very light magenta
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
    movem.l D0-D7/A0,-(SP)

    ; Set VDP write address: VRAM $D800 (sprite attribute table)
    ; $D800 & $3FFF = $1800 → swap → $18000000 → | $40000003 = $58000003
    ; (CD[5:4]=01 = VRAM write; A[15:14]=11 from $D800's top bits)
    move.l  #$58000003,(VDP_CTRL).l

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
    move.w  D4,(VDP_DATA).l

    ; ── Word 1: size (8×8 = 0) | link (index of next sprite; 0 = end) ────
    move.w  D6,D4
    addq.w  #1,D4               ; D4 = this_sprite_index + 1
    cmpi.w  #64,D4              ; is this the last sprite?
    bne     .write_link
    moveq   #0,D4               ; yes → link = 0 (terminate list)
.write_link:
    move.w  D4,(VDP_DATA).l     ; write 0000 | link[6:0]

    ; ── Word 2: tile word (priority | palette | Vflip | Hflip | tile) ────
    move.w  D1,D5               ; start with tile index
    andi.w  #$07FF,D5           ; keep bits 10:0 only
    ori.w   #$8000,D5           ; bit 15 = high priority (sprite over planes)
    ; Palette: NES attr[1:0] → Genesis bits[14:13]
    move.w  D2,D4
    andi.w  #$0003,D4           ; isolate palette (0–3)
    lsl.w   #5,D4               ; shift left 5
    lsl.w   #8,D4               ; shift left 8 more → total shift 13 → bits[14:13]
    or.w    D4,D5               ; merge palette
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

    movem.l (SP)+,D0-D7/A0
    rts

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
