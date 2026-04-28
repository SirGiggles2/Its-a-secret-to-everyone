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

#endif /* RENDER_ABI_H */
