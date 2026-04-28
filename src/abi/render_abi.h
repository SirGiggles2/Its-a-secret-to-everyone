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

#endif /* RENDER_ABI_H */
