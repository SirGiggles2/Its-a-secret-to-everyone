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
; Layout (19 bytes):
;   +0…+15  CHR_TILE_BUF  (16 bytes) raw NES 2BPP tile data
;              bytes 0–7  = plane 0 (bit 0 of each pixel, row 0 first)
;              bytes 8–15 = plane 1 (bit 1 of each pixel, row 0 first)
;   +16     CHR_BUF_CNT   (byte) number of bytes accumulated (0–15)
;   +17–18  CHR_BUF_VADDR (word) NES PPU address at start of this tile
;------------------------------------------------------------------------------
CHR_STATE_BASE  equ PPU_STATE_BASE+$20  ; $FF0820

CHR_TILE_BUF    equ CHR_STATE_BASE+0    ; 16 bytes: raw NES tile bytes
CHR_BUF_CNT     equ CHR_STATE_BASE+16   ; byte: bytes accumulated
CHR_BUF_VADDR   equ CHR_STATE_BASE+17   ; word: tile's NES base address
CHR_HIT_COUNT   equ CHR_STATE_BASE+19   ; byte: total CHR write calls (debug counter)

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
    btst    #0,D1
    bne.s   .nt_odd_byte            ; odd address → flush word

    ; ---- Even address: buffer the byte ----
    move.b  D0,(PPU_DBUF).l
    move.b  #1,(PPU_DHALF).l
    bsr     .inc_ppuaddr
    movem.l (SP)+,D0-D5/A0
    rts

.nt_odd_byte:
    ; ---- Odd address: assemble word and write to VDP VRAM ----
    ; VDP VRAM write command for word-aligned address (D1–1):
    moveq   #0,D2
    move.w  D1,D2                   ; D2.w = odd VRAM address
    subq.w  #1,D2                   ; D2.w = even (word-aligned)
    swap    D2                      ; D2   = word_addr << 16
    ori.l   #$40000000,D2           ; D2   = VDP VRAM-write command long
    move.l  D2,(VDP_CTRL).l

    ; Build word: high byte = PPU_DBUF (even), low byte = D0 (odd)
    moveq   #0,D2
    move.b  (PPU_DBUF).l,D2        ; D2.b = buffered even byte
    lsl.w   #8,D2                  ; shift to high byte of word
    andi.w  #$00FF,D0              ; mask to byte
    or.w    D0,D2                  ; D2.w = complete word
    move.w  D2,(VDP_DATA).l        ; commit to VDP VRAM

    clr.b   (PPU_DHALF).l
    bsr     .inc_ppuaddr
    movem.l (SP)+,D0-D5/A0
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
    add.w   D1,D1                   ; D1 = NES_addr × 2  (lsl #1)
    ; VDP VRAM write command for D1.w (< $4000, so upper word = 0):
    move.l  D1,D2
    swap    D2                      ; D2 = D1.w << 16 (high word = addr)
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
    move.w  D2,D0                   ; save plane0 expansion

    move.b  D4,D1
    lsr.b   #4,D1                   ; D1.b = upper nibble of plane1 (pix 0-3)
    andi.b  #$0F,D1
    bsr     .expand_nibble          ; D2.w = plane1 expansion
    lsl.w   #1,D2                   ; ×2 → puts plane1 bits in bit1 of each nibble
    or.w    D0,D2                   ; combine: each nibble = (p1_bit<<1)|p0_bit
    move.w  D2,(VDP_DATA).l         ; write pixels 0-3 (2 VDP bytes via auto-incr)

    ; ---- Pixels 4-7 (lower nibbles of D3 and D4) ----
    move.b  D3,D1
    andi.b  #$0F,D1                 ; D1.b = lower nibble of plane0 (pix 4-7)
    bsr     .expand_nibble
    move.w  D2,D0                   ; save plane0 expansion

    move.b  D4,D1
    andi.b  #$0F,D1                 ; D1.b = lower nibble of plane1 (pix 4-7)
    bsr     .expand_nibble
    lsl.w   #1,D2                   ; ×2 for plane1
    or.w    D0,D2
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
    ; Uses: D0 (caller's D0 is saved on stack by _ppu_write_7).
    ;==========================================================================
.expand_nibble:
    moveq   #0,D2

    ; bit 3 of D1 → bit 12 of D2  (shift: 3→12, i.e. ×(4096/8) = ×512 = <<9)
    move.b  D1,D0
    andi.b  #$08,D0                 ; isolate bit 3 ($08)
    lsl.w   #8,D0                   ; shift 8: $08 → $0800
    lsl.w   #1,D0                   ; shift 1 more: $0800 → $1000  (bit 12)
    or.w    D0,D2

    ; bit 2 of D1 → bit 8 of D2  (<<6: $04 → $0100)
    move.b  D1,D0
    andi.b  #$04,D0
    lsl.w   #6,D0
    or.w    D0,D2

    ; bit 1 of D1 → bit 4 of D2  (<<3: $02 → $0010)
    move.b  D1,D0
    andi.b  #$02,D0
    lsl.w   #3,D0
    or.w    D0,D2

    ; bit 0 of D1 → bit 0 of D2  (no shift: $01 → $0001)
    move.b  D1,D0
    andi.b  #$01,D0
    or.w    D0,D2

    rts

;==============================================================================
; Controller I/O
;==============================================================================

;------------------------------------------------------------------------------
; _ctrl_strobe — $4016 write: strobe the controller latch.
; T5: stub — no input yet.
;------------------------------------------------------------------------------
_ctrl_strobe:
    rts

;------------------------------------------------------------------------------
; _ctrl_read_1 — $4016 read: read one bit from controller 1.
; T5: return 0 (no buttons pressed) — no input yet.
;------------------------------------------------------------------------------
_ctrl_read_1:
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
; NES $0200–$02FF maps to Genesis RAM $FF0200–$FF02FF (NES_RAM_BASE + $0200).
;
; T5: Stub — no sprite output yet.  In T7 we'll DMA the data into VDP OAM
; via the sprite attribute table at VRAM $D800.
;------------------------------------------------------------------------------
_oam_dma:
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
