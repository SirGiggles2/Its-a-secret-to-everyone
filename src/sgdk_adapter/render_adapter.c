/*
 * Render adapter implementation (S1 Phase D/F).
 *
 * Phase D: forwards render_set_plane_a_word / render_load_palette /
 *   render_chr_upload to existing vdp_ helpers in intro_common.c.
 * Phase F3: adds raw VDP streaming helpers used by intro_title.c after
 *   its local VDP macros are removed.  These inline the same MMIO writes
 *   the title file used to do directly; the adapter is the IO primitive
 *   layer per spec Section 4.
 *
 * Phase S11+ swap: replace the VDP_CTRL_LONG / VDP_DATA_WORD lines with
 * SGDK VDP_*, DMA_*, PAL_* calls.
 */

#include "render_adapter.h"

/* Forward declarations of existing helpers we wrap. Definitions live
 * in src/frontend/intro/intro_common.c. Re-declared here to avoid
 * pulling intro_common.h (which includes intro-specific decls we
 * don't need at the adapter layer). */

extern void vdp_dma_to_vram(unsigned long src, unsigned short dst,
                            unsigned short len);
extern void vdp_load_cram(const unsigned short *src, unsigned short count);

/* VDP MMIO addresses used by the streaming helpers below.
 * These are the same constants intro_title.c used to define locally. */
#define VDP_DATA_WORD (*(volatile unsigned short *)0x00C00000)
#define VDP_CTRL_LONG (*(volatile unsigned long  *)0x00C00004)

/* VDP plane A nametable base for the current H32 video mode. Locked
 * at $C000 in our genesis_shell.asm boot path. The nametable entry
 * write address is computed as plane_base + (row * 64 + col) * 2. */
#define PLANE_A_BASE 0xC000u

/* CRAM color words per palette. */
#define CRAM_COLORS_PER_PAL 16u

/* ---- Phase D public API ---- */

void render_set_plane_a_word(unsigned short col, unsigned short row,
                             unsigned short word)
{
    /* Compute VRAM nametable byte address, then DMA 1 word.
     * For sparse single-word writes a direct VDP_CTRL/VDP_DATA poke is
     * cheaper, but we have no helper for that today; F-phase replaces
     * with SGDK VDP_setTileMapXY. For now, DMA path keeps wiring valid
     * if a caller appears (no caller exists at S1 D-phase). */
    unsigned short vram_addr =
        (unsigned short)(PLANE_A_BASE + (row * 64u + col) * 2u);
    unsigned short tmp = word;
    vdp_dma_to_vram((unsigned long)&tmp, vram_addr, 1);
}

void render_load_palette(unsigned short idx, const unsigned short *src)
{
    /* CRAM is byte-indexed but vdp_load_cram writes contiguously
     * starting at the CRAM cursor set by the caller - until we own a
     * cursor-set helper, this forwarder loads from idx*16 worth into
     * the cursor. F-phase replaces with SGDK PAL_setPalette which
     * takes the slot index directly. */
    (void)idx;
    vdp_load_cram(src, CRAM_COLORS_PER_PAL);
}

void render_chr_upload(unsigned short vram_addr,
                       const unsigned char *src,
                       unsigned short byte_count)
{
    /* vdp_dma_to_vram takes BYTE count as its len parameter and divides
     * by 2 internally to compute the word count. Pass byte_count straight
     * through; double-shift here would upload a quarter of the data. */
    vdp_dma_to_vram((unsigned long)src, vram_addr, byte_count);
}

/* ---- Phase F3 raw streaming helpers ---- */

/* Open a VRAM write port at the given byte address.
 * Control word format: 0x40000000 | (addr[13:0] << 16) | addr[15:14]
 * (same formula intro_title.c used in its local vram_write_open). */
void render_vram_open_write(unsigned short vram_addr)
{
    VDP_CTRL_LONG = 0x40000000UL
                  | ((unsigned long)(vram_addr & 0x3FFFu) << 16)
                  | ((vram_addr >> 14) & 0x0003u);
}

/* Stream one word to the currently open VRAM target. */
void render_vram_write_word(unsigned short word)
{
    VDP_DATA_WORD = word;
}

/* Stream count words from src[] to the currently open VRAM target. */
void render_vram_write_words(const unsigned short *src, unsigned short count)
{
    while (count--) VDP_DATA_WORD = *src++;
}

/* Open CRAM write cursor at byte-offset slot*2.
 * Control word format: 0xC0000000 | (byteaddr[13:0] << 16) | byteaddr[15:14].
 * slot is the palette-color index (0..63). */
void render_cram_open_write(unsigned short slot)
{
    unsigned long addr = (unsigned long)slot * 2u;
    VDP_CTRL_LONG = 0xC0000000UL
                  | ((addr & 0x3FFFu) << 16)
                  | ((addr >> 14) & 0x0003u);
}

/* Open CRAM at slot and write one color word. */
void render_cram_write_color(unsigned short slot, unsigned short value)
{
    render_cram_open_write(slot);
    VDP_DATA_WORD = value;
}

/* Open CRAM at offset 0 and stream count color words. */
void render_cram_upload(const unsigned short *src, unsigned short count)
{
    VDP_CTRL_LONG = 0xC0000000UL;
    while (count--) VDP_DATA_WORD = *src++;
}

/* Open VSRAM write cursor at byte-offset slot*2.
 * Control word: 0x40000010 for slot 0; general form uses the same
 * slot*2 formula as CRAM but with VSRAM CD bits (0x40000010 base).
 * slot is the VSRAM word index (0..39). */
void render_vsram_open_write(unsigned short slot)
{
    unsigned long addr = (unsigned long)slot * 2u;
    VDP_CTRL_LONG = 0x40000010UL
                  | ((addr & 0x3FFFu) << 16)
                  | ((addr >> 14) & 0x0003u);
}

/* Write one word at the open VSRAM cursor. */
void render_vsram_write_word(unsigned short value)
{
    VDP_DATA_WORD = value;
}

/* Fill tile_count nametable words at plane_base with fill_word.
 * Opens VRAM at plane_base then streams fill_word tile_count times. */
void render_plane_fill(unsigned short plane_base, unsigned short fill_word,
                       unsigned short tile_count)
{
    render_vram_open_write(plane_base);
    while (tile_count--) VDP_DATA_WORD = fill_word;
}

/* Write count cells into row of Plane A (base $C000, row stride = 64 bytes). */
void render_plane_a_write_row(unsigned short row, const unsigned short *cells,
                              unsigned short count)
{
    unsigned short addr = (unsigned short)(PLANE_A_BASE + row * 64u);
    render_vram_open_write(addr);
    while (count--) VDP_DATA_WORD = *cells++;
}
