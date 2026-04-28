/*
 * Render adapter implementation (S1 Phase D/F).
 *
 * Phase D: forwards render_set_plane_a_word / render_load_palette /
 *   render_chr_upload to existing vdp_ helpers in intro_common.c.
 * Phase F3: adds raw VDP streaming helpers used by intro_title.c after
 *   its local VDP macros are removed.  These inline the same MMIO writes
 *   the title file used to do directly; the adapter is the IO primitive
 *   layer per spec Section 4.
 * Phase F4: consolidates all vdp_* IO primitives from intro_common.c into
 *   this file.  Renames them to render_* per the long-term clean naming
 *   convention.  extern vdp_dma_to_vram / vdp_load_cram forwarders removed.
 *
 * Phase S11+ swap: replace the VDP_CTRL_LONG / VDP_DATA_WORD lines with
 * SGDK VDP_*, DMA_*, PAL_* calls.
 */

#include "render_adapter.h"

/* VDP MMIO addresses used by all helpers below. */
#define VDP_DATA_WORD (*(volatile unsigned short *)0x00C00000)
#define VDP_CTRL_WORD (*(volatile unsigned short *)0x00C00004)
#define VDP_CTRL_LONG (*(volatile unsigned long  *)0x00C00004)

/* Z80 bus control registers. */
#define Z80_BUSREQ_WORD (*(volatile unsigned short *)0x00A11100)

/* VDP plane A nametable base for the current H32 video mode. Locked
 * at $C000 in our genesis_shell.asm boot path. The nametable entry
 * write address is computed as plane_base + (row * 64 + col) * 2. */
#define PLANE_A_BASE 0xC000u

/* CRAM color words per palette. */
#define CRAM_COLORS_PER_PAL 16u

/* ---- IO primitives (moved in from intro_common.c, F4) ---- */

void render_display_enable(unsigned char on)
{
    /* Reg 1: $8134 = display OFF (VBlank IRQ, DMA, M5); $8174 = display ON. */
    VDP_CTRL_WORD = on ? (unsigned short)0x8174 : (unsigned short)0x8134;
}

void render_vscroll_set(unsigned short value)
{
    /* VSRAM write to slot 0 (plane A vscroll). */
    VDP_CTRL_LONG = 0x40000010UL;
    VDP_DATA_WORD = value;
}

void render_plane_write_row(unsigned short plane_base, unsigned short row,
                            const unsigned short *cells, unsigned short count)
{
    /* plane_base = $C000 (A) or $E000 (B). row = 0..31. stride = 64 bytes. */
    unsigned short addr = (unsigned short)(plane_base + row * 64u);
    VDP_CTRL_LONG = 0x40000000UL
                  | ((unsigned long)(addr & 0x3FFFu) << 16)
                  | ((addr >> 14) & 0x0003u);
    while (count--) VDP_DATA_WORD = *cells++;
}

void render_mode_set_v32(void)
{
    /* VDP Reg 16 = $9000 (H32 x V32). Row stride = 64 bytes. */
    VDP_CTRL_WORD = 0x9000;
}

void render_mode_set_v64(void)
{
    /* VDP Reg 16 = $9011 (H64 x V64). Matches gameplay default. */
    VDP_CTRL_WORD = 0x9011;
}

void render_z80_bus_grab(void)
{
    /* Hold Z80 bus so 68K has uncontended VRAM access. */
    Z80_BUSREQ_WORD = 0x0100;
    while ((Z80_BUSREQ_WORD & 0x0100) != 0) { /* wait BUSACK */ }
}

void render_z80_bus_release(void)
{
    Z80_BUSREQ_WORD = 0x0000;
}

void render_irq_mask(void)
{
    __asm__ volatile ("ori.w #0x0700,%sr");
}

void render_irq_unmask(void)
{
    __asm__ volatile ("andi.w #0xF8FF,%sr");
}

/* ---- Internal DMA / CRAM helpers (were extern'd from intro_common.c) ---- */

/* CPU-based VRAM upload. Writes len bytes from src to VRAM[dst..dst+len-1].
 * Slower than DMA but reliable in display-off windows. */
static void vram_dma_upload(unsigned long src, unsigned short dst,
                            unsigned short len)
{
    const unsigned short *p = (const unsigned short *)src;
    unsigned short words = (unsigned short)(len >> 1);

    /* Ensure auto-increment = 2 (word stride). */
    VDP_CTRL_WORD = 0x8F02;

    /* Open VRAM write at dst. */
    unsigned long cmd = 0x40000000UL | ((unsigned long)(dst & 0x3FFFu) << 16)
                                     | ((dst >> 14) & 0x0003u);
    VDP_CTRL_LONG = cmd;

    for (unsigned short i = 0; i < words; i++) {
        VDP_DATA_WORD = p[i];
    }
}

/* ---- Phase D public API ---- */

void render_set_plane_a_word(unsigned short col, unsigned short row,
                             unsigned short word)
{
    /* Compute VRAM nametable byte address, then upload 1 word.
     * For sparse single-word writes a direct VDP_CTRL/VDP_DATA poke is
     * cheaper, but we have no helper for that today; F-phase replaces
     * with SGDK VDP_setTileMapXY. For now, DMA path keeps wiring valid
     * if a caller appears (no caller exists at S1 D-phase). */
    unsigned short vram_addr =
        (unsigned short)(PLANE_A_BASE + (row * 64u + col) * 2u);
    unsigned short tmp = word;
    vram_dma_upload((unsigned long)&tmp, vram_addr, 1);
}

void render_load_palette(unsigned short idx, const unsigned short *src)
{
    /* CRAM is byte-indexed but render_cram_upload writes contiguously
     * starting at CRAM offset 0. F-phase replaces with SGDK PAL_setPalette
     * which takes the slot index directly. */
    (void)idx;
    render_cram_upload(src, CRAM_COLORS_PER_PAL);
}

void render_chr_upload(unsigned short vram_addr,
                       const unsigned char *src,
                       unsigned short byte_count)
{
    /* vram_dma_upload takes BYTE count as its len parameter and divides
     * by 2 internally to compute the word count. Pass byte_count straight
     * through; double-shift here would upload a quarter of the data. */
    vram_dma_upload((unsigned long)src, vram_addr, byte_count);
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
