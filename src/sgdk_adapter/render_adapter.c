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

void render_wait_vblank(void)
{
    /* Wait for VBlank rising edge: drain through any in-progress vblank,
     * then spin until status bit 3 is set again. Used by frontends that
     * do not run from VBlankISR. */
    while ( (VDP_CTRL_WORD & 0x0008));
    while (!(VDP_CTRL_WORD & 0x0008));
}

void render_window_v_set(unsigned char value)
{
    /* VDP Reg 18: window vertical position byte. value=0 disables the
     * Window plane vertically; non-zero sets row count (high bit chooses
     * up vs down direction). genesis_shell.asm uses 0x9208 for 8-row top
     * window during transpiled gameplay HUD; intro_main resets to 0x9200. */
    VDP_CTRL_WORD = (unsigned short)(0x9200u | value);
}

void render_sat_clear(void)
{
    /* SAT lives at VRAM $FC00 in our genesis_shell.asm boot (VDP reg 5 =
     * $7E for H32 mode, 80 sprite slots * 8 bytes each = 640 bytes).
     * Zero every slot. Slot 0 with y=0 link=0 attr=0 x=0 is the standard
     * "end of sprite list" terminator and produces an off-screen sprite. */
    render_vram_open_write(0xFC00u);
    /* 640 bytes = 320 words. */
    unsigned short i;
    for (i = 0; i < 320u; i++) {
        VDP_DATA_WORD = 0;
    }
}

/* CRAM read access:
 *   VDP control word $00000020 = CD bits for CRAM read at byte addr 0.
 *   Auto-increment (VDP reg 15 = 2) drives sequential reads. After
 *   genesis_shell.asm boot, auto-inc is locked at 2.
 * CRAM write access:
 *   $C0000000 base for CRAM write at offset 0 (existing render_cram_open
 *   formula). */

static unsigned short s_fade_snapshot[64];

void render_cram_fade_capture(void)
{
    VDP_CTRL_LONG = 0x00000020UL;
    unsigned char i;
    for (i = 0; i < 64u; i++) {
        s_fade_snapshot[i] = VDP_DATA_WORD;
    }
}

void render_cram_fade_apply(unsigned char step, unsigned char total)
{
    if (total == 0u) return;
    if (step > total) step = total;
    unsigned short remaining = (unsigned short)(total - step);

    VDP_CTRL_LONG = 0xC0000000UL;
    unsigned char i;
    for (i = 0; i < 64u; i++) {
        unsigned short c = s_fade_snapshot[i];
        /* Each channel: 4-bit value in low 4 of nibble, even-step encoded
         * (0, 2, 4, 6, 8, 10, 12, 14). Mask off the high bit of each nibble
         * since CRAM ignores it on read but the snapshot may carry junk. */
        unsigned short b = (c >> 8) & 0x000Eu;
        unsigned short g = (c >> 4) & 0x000Eu;
        unsigned short r = (c >> 0) & 0x000Eu;
        b = (unsigned short)((b * remaining) / total) & 0x000Eu;
        g = (unsigned short)((g * remaining) / total) & 0x000Eu;
        r = (unsigned short)((r * remaining) / total) & 0x000Eu;
        VDP_DATA_WORD = (unsigned short)((b << 8) | (g << 4) | r);
    }
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
    unsigned short addr = (unsigned short)(PLANE_A_BASE + (row * 64u + col) * 2u);
    VDP_CTRL_LONG = 0x40000000UL
                  | ((unsigned long)(addr & 0x3FFFu) << 16)
                  | ((addr >> 14) & 0x0003u);
    VDP_DATA_WORD = word;
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

/* ---- Phase F5 FS frontend cutover primitives ---- */

/* Open CRAM write cursor at a raw byte address.
 * Genesis CRAM is byte-addressed; palette N starts at byte N*32.
 * Caller passes byte_addr directly (0, 32, 64, 96 for palettes 0..3).
 * Same CD encoding as render_cram_open_write but skips the *2 step. */
void render_cram_open_write_byte(unsigned short byte_addr)
{
    unsigned long addr = (unsigned long)byte_addr;
    VDP_CTRL_LONG = 0xC0000000UL
                  | ((addr & 0x3FFFu) << 16)
                  | ((addr >> 14) & 0x0003u);
}

/* Write one complete SAT entry at slot entry.
 * SAT VRAM address = sat_base + entry * 8.
 * Streams 4 words: y, size_link, tile_attr, x (Genesis SAT layout). */
void render_sat_write(unsigned short sat_base, unsigned char entry,
                      unsigned short y, unsigned short size_link,
                      unsigned short tile_attr, unsigned short x)
{
    unsigned short addr = (unsigned short)(sat_base + (unsigned short)entry * 8u);
    VDP_CTRL_LONG = 0x40000000UL
                  | ((unsigned long)(addr & 0x3FFFu) << 16)
                  | ((addr >> 14) & 0x0003u);
    VDP_DATA_WORD = y;
    VDP_DATA_WORD = size_link;
    VDP_DATA_WORD = tile_attr;
    VDP_DATA_WORD = x;
}

/* Zero 16 words (one 4bpp tile = 32 bytes) at vram_addr.
 * Used to blank VRAM tile 0 so cells referencing it render transparent. */
void render_vram_write_zero_tile(unsigned short vram_addr)
{
    render_vram_open_write(vram_addr);
    unsigned short i;
    for (i = 0; i < 16u; i++) VDP_DATA_WORD = 0;
}

/* Genesis ROM bank-window load. Wraps the asm primitive
 * `c_copy_bank_to_window` (which itself wraps `_copy_bank_to_window`
 * with the C calling convention).
 *
 * Why this exists: src/game/ native code can't call c_-prefixed
 * shims per CLAUDE.md rule "no transpile-bridge shims (z01_/z07_/c_/
 * ...) in src/game/". This wrapper is in src/sgdk_adapter/ — the
 * Genesis platform layer — so callers in src/game/ get a clean
 * `render_bank_window_load(bank)` API without naming a c_ shim.
 *
 * Per debate 007 synthesis option D resolution: bank-window cache
 * is Genesis-native ROM access (NOT NES MMC1 emulation). The c_
 * prefix on c_copy_bank_to_window is misleading nomenclature —
 * functional reality is "Genesis cartridge ROM bank reader." */
extern void c_copy_bank_to_window(unsigned int bank);

void render_bank_window_load(unsigned char bank)
{
    c_copy_bank_to_window((unsigned int)bank);
}
