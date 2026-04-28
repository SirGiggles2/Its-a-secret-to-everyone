/*
 * Render API public surface (S1 Phase D, Task D1).
 *
 * Owned C in src/frontend/ and src/game/ calls render_* functions
 * here instead of writing raw VDP control words. The implementation
 * (src/sgdk_adapter/render_adapter.c) initially forwards to existing
 * vdp_* helpers in src/frontend/intro/intro_common.c; Phase F migrates
 * those forwarders onto SGDK API (VDP_*, DMA_*, PAL_*) per call site.
 *
 * Spec ref: 2026-04-27-native-genesis-rewrite-design.md Section 4.1, 4.5
 */

#ifndef RENDER_ABI_H
#define RENDER_ABI_H

/* ---- Plane A tilemap write ----
 * (col, row) in tile units. Plane A is 64x32 in current H32 mode;
 *   col in [0, 63], row in [0, 31].
 * word is the VDP nametable entry: priority<<15 | palette<<13 |
 *   vflip<<12 | hflip<<11 | tile_index. */
void render_set_plane_a_word(unsigned short col, unsigned short row,
                             unsigned short word);

/* ---- Palette load (full 16-color palette) ----
 * idx in [0, 3] selects which CRAM palette slot.
 * src points to 16 little-endian VDP color words (BGR-444 in CRAM order). */
void render_load_palette(unsigned short idx, const unsigned short *src);

/* ---- CHR (tile pattern) upload to VRAM ----
 * vram_addr is the byte address within VRAM (0..0xFFFF).
 * src points to packed 4bpp tile data; byte_count is the source size. */
void render_chr_upload(unsigned short vram_addr,
                       const unsigned char *src,
                       unsigned short byte_count);

/* ---- Raw VRAM streaming (F3: title cutover) ----
 *
 * These calls give callers a write cursor into VRAM without touching
 * VDP registers themselves.  The adapter owns the MMIO.
 *
 * render_vram_open_write  -- set VRAM write address; leaves port open.
 * render_vram_write_word  -- stream one word at the current VRAM cursor.
 * render_vram_write_words -- stream count words from src[] at the cursor.
 */
void render_vram_open_write(unsigned short vram_addr);
void render_vram_write_word(unsigned short word);
void render_vram_write_words(const unsigned short *src, unsigned short count);

/* ---- CRAM single-slot write (F3: title cutover) ----
 *
 * render_cram_open_write   -- set CRAM write cursor to byte-offset slot*2.
 * render_cram_write_color  -- open slot and write one color word (combined).
 * render_cram_upload       -- open CRAM at offset 0 and stream count words.
 */
void render_cram_open_write(unsigned short slot);
void render_cram_write_color(unsigned short slot, unsigned short value);
void render_cram_upload(const unsigned short *src, unsigned short count);

/* ---- VSRAM write (F3: title cutover) ----
 *
 * render_vsram_open_write -- set VSRAM write cursor to byte-offset slot*2.
 * render_vsram_write_word -- write one word at the open VSRAM cursor.
 */
void render_vsram_open_write(unsigned short slot);
void render_vsram_write_word(unsigned short value);

/* ---- Plane bulk helpers (F3: title cutover) ----
 *
 * render_plane_fill          -- fill tile_count nametable words starting at
 *                               plane_base with fill_word.
 * render_plane_a_write_row   -- write count cells to row of Plane A.
 *                               Plane A nametable base is fixed at $C000.
 */
void render_plane_fill(unsigned short plane_base, unsigned short fill_word,
                       unsigned short tile_count);
void render_plane_a_write_row(unsigned short row, const unsigned short *cells,
                              unsigned short count);

/* ---- F4 additions: IO primitives consolidated from intro_common.c ----
 *
 * render_display_enable    -- write VDP Reg 1: 1=display on, 0=display off.
 * render_vscroll_set       -- write value to VSRAM slot 0 (plane A vscroll).
 * render_plane_write_row   -- write 32 cells to row of any plane (A or B).
 *                             plane_base = $C000 (A) or $E000 (B).
 * render_mode_set_v32      -- set VDP Reg 16 to H32xV32 ($9000).
 * render_mode_set_v64      -- set VDP Reg 16 to H64xV64 ($9011).
 * render_z80_bus_grab      -- assert Z80 bus request; spin until ACKed.
 * render_z80_bus_release   -- release Z80 bus request.
 * render_irq_mask          -- raise SR IPL to 7 (mask all interrupts).
 * render_irq_unmask        -- lower SR IPL to 0 (unmask all interrupts).
 */
void render_display_enable(unsigned char on);
void render_vscroll_set(unsigned short value);
void render_plane_write_row(unsigned short plane_base, unsigned short row,
                            const unsigned short *cells, unsigned short count);
void render_mode_set_v32(void);
void render_mode_set_v64(void);
void render_z80_bus_grab(void);
void render_z80_bus_release(void);
void render_irq_mask(void);
void render_irq_unmask(void);

/* ---- F5 additions: FS frontend cutover primitives ----
 *
 * render_cram_open_write_byte -- open CRAM write cursor at a raw byte address
 *                                (0, 32, 64, 96 for palettes 0..3).  Honest
 *                                about CRAM's byte-addressable nature; avoids
 *                                the /2 conversion at call sites that already
 *                                work in byte space.
 * render_sat_write            -- write one complete SAT entry (8 bytes = 4 words)
 *                                at SAT slot entry.  Computes the VRAM address
 *                                from sat_base + entry*8 and streams the four
 *                                words: y, size_link, tile_attr, x.
 *                                sat_base is the VRAM byte address of the SAT
 *                                (typically $F800 in our boot config).
 * render_vram_write_zero_tile -- zero 16 words (32 bytes = one tile) at
 *                                VRAM address vram_addr.  Used to blank tile 0
 *                                so default nametable cells render transparent.
 */
void render_cram_open_write_byte(unsigned short byte_addr);
void render_sat_write(unsigned short sat_base, unsigned char entry,
                      unsigned short y, unsigned short size_link,
                      unsigned short tile_attr, unsigned short x);
void render_vram_write_zero_tile(unsigned short vram_addr);

#endif /* RENDER_ABI_H */
