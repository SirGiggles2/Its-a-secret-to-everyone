/* tools/intro_demo/intro_title.c
 *
 * Title runtime: load assets, per-vblank step (glow only for now;
 * waterfall added in Task 12), fade-out driver.
 */
#include "intro_title.h"

#define VDP_DATA_WORD (*(volatile unsigned short *)0x00C00000)
#define VDP_CTRL_WORD (*(volatile unsigned short *)0x00C00004)
#define VDP_CTRL_LONG (*(volatile unsigned long  *)0x00C00004)

extern const unsigned char  intro_title_bg_chr[];
extern const unsigned long  intro_title_bg_chr_size;
extern const unsigned char  intro_title_sprite_chr[];
extern const unsigned long  intro_title_sprite_chr_size;
extern const unsigned short intro_title_tilemap_rows;
extern const unsigned short intro_title_tilemap[];
extern const unsigned short intro_title_palette[64];
extern const unsigned short intro_title_fade_cycles[14][64];
extern const unsigned short intro_title_fade_delays[14];
extern const unsigned short intro_title_glow_colors[8];
extern const unsigned char  intro_title_glow_delays[8];

#define PLANE_A_BASE 0xC000u

static void vram_write_open(unsigned short dst) {
    VDP_CTRL_LONG = 0x40000000UL
                  | ((unsigned long)(dst & 0x3FFF) << 16)
                  | ((dst >> 14) & 0x0003);
}

static void vram_upload(const unsigned char *src, unsigned long bytes,
                        unsigned short dst) {
    const unsigned short *p = (const unsigned short *)src;
    unsigned long words = bytes >> 1;
    vram_write_open(dst);
    while (words--) VDP_DATA_WORD = *p++;
}

static void cram_upload(const unsigned short *src, unsigned short count) {
    VDP_CTRL_LONG = 0xC0000000UL;
    while (count--) VDP_DATA_WORD = *src++;
}

static void cram_write_one(unsigned short slot, unsigned short value) {
    unsigned long addr = (unsigned long)slot * 2u;
    VDP_CTRL_LONG = 0xC0000000UL
                  | ((addr & 0x3FFFu) << 16)
                  | ((addr >> 14) & 0x0003u);
    VDP_DATA_WORD = value;
}

static void plane_fill_blank(unsigned short base) {
    vram_write_open(base);
    for (unsigned short i = 0; i < 32 * 32; i++) VDP_DATA_WORD = 0x0024;
}

static void write_row(unsigned short row, const unsigned short *cells) {
    unsigned short addr = (unsigned short)(PLANE_A_BASE + row * 64);
    vram_write_open(addr);
    for (int i = 0; i < 32; i++) VDP_DATA_WORD = cells[i];
}

static void vsram_set0(unsigned short value) {
    VDP_CTRL_LONG = 0x40000010UL;
    VDP_DATA_WORD = value;
}

static unsigned char s_glow_cycle = 0;
static unsigned char s_glow_timer = 0;
static unsigned char s_fade_cycle = 0;
static unsigned short s_fade_delay = 0;

void intro_title_setup(void) {
    /* Display off during upload (display will be all-black on enable
     * because CRAM is rewritten before the display flips on). */
    VDP_CTRL_WORD = 0x8134;

    /* CHR uploads. */
    vram_upload(intro_title_bg_chr,     intro_title_bg_chr_size,     0x0000);
    vram_upload(intro_title_sprite_chr, intro_title_sprite_chr_size, 0x2000);

    /* Plane A: title rows. Plane B blank. */
    plane_fill_blank(PLANE_A_BASE);
    plane_fill_blank(0xE000);
    for (unsigned short r = 0; r < intro_title_tilemap_rows; r++) {
        write_row(r, &intro_title_tilemap[r * 32]);
    }

    /* CRAM: title palette. */
    cram_upload(intro_title_palette, 64);

    vsram_set0(0);

    /* Reset title state. */
    s_glow_cycle = 0;
    s_glow_timer = intro_title_glow_delays[0];
    s_fade_cycle = 0;
    s_fade_delay = 0;

    /* Display on. */
    VDP_CTRL_WORD = 0x8174;
}

void intro_title_step(void) {
    /* Triforce glow: every 6 frames (16 at end), advance cycle and
     * patch Gen pal 1 slot 2 (= NES BG pal 1 color 2 = PALRAM $3F06). */
    if (s_glow_timer == 0) {
        s_glow_cycle++;
        if (s_glow_cycle >= 8u) s_glow_cycle = 0;
        s_glow_timer = intro_title_glow_delays[s_glow_cycle];
        cram_write_one((unsigned short)(1*16 + 2), intro_title_glow_colors[s_glow_cycle]);
    } else {
        s_glow_timer--;
    }
    /* Waterfall: added in Task 12. */
}

void intro_title_fade_apply(unsigned char idx) {
    if (idx >= 14u) return;
    VDP_CTRL_LONG = 0xC0000000UL;
    const unsigned short *src = intro_title_fade_cycles[idx];
    for (unsigned short i = 0; i < 64; i++) VDP_DATA_WORD = src[i];
    s_fade_delay = intro_title_fade_delays[idx];
    s_fade_cycle = idx;
}

void intro_title_fade_step(void) {
    if (s_fade_delay > 0) {
        s_fade_delay--;
        return;
    }
    if (s_fade_cycle + 1u >= 14u) {
        /* Last cycle's delay just expired — fade is done. */
        s_fade_cycle = 14u;
        return;
    }
    intro_title_fade_apply((unsigned char)(s_fade_cycle + 1u));
}

unsigned char intro_title_fade_done(void) {
    return (s_fade_cycle >= 14u) ? 1u : 0u;
}

void intro_title_fade_reset(void) {
    s_fade_cycle = 0;
    s_fade_delay = 0;
}

void intro_title_blackout(void) {
    /* CRAM all black, holding the plane content but invisible. */
    VDP_CTRL_LONG = 0xC0000000UL;
    for (unsigned short i = 0; i < 64; i++) VDP_DATA_WORD = 0x0000;
}
