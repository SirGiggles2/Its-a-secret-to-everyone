#include "intro_story.h"
#include "intro_common.h"

extern const unsigned char  intro_font_chr[];
extern const unsigned char  intro_art_chr[];
extern const unsigned short intro_palette[64];
extern const unsigned short intro_story_tilemap_rows;
extern const unsigned short intro_story_tilemap[];

extern const unsigned long intro_font_chr_size;
extern const unsigned long intro_art_chr_size;

#define PLANE_A_BASE  0x4000u
#define SCROLL_SPEED  1u

static unsigned long s_scroll_pixel;
static unsigned short s_next_source_row;
static unsigned short s_last_row;
static unsigned short s_done;

void intro_story_enter(void) {
    vdp_set_mode_v32();

    vdp_dma_to_vram((unsigned long)intro_font_chr, 0x0000, (unsigned short)intro_font_chr_size);
    vdp_dma_to_vram((unsigned long)intro_art_chr,  (unsigned short)intro_font_chr_size,
                    (unsigned short)intro_art_chr_size);

    vdp_load_cram(intro_palette, 64);

    unsigned short first_rows = intro_story_tilemap_rows < 32
                                 ? intro_story_tilemap_rows : 32;
    for (unsigned short r = 0; r < first_rows; r++) {
        vdp_write_nametable_row(PLANE_A_BASE, r, &intro_story_tilemap[r * 32]);
    }

    vdp_set_vscroll(0);
    s_scroll_pixel = 0;
    s_next_source_row = (unsigned short)first_rows;

    s_last_row = 0;
    s_done = 0;
}

unsigned int intro_story_update(void) {
    if (s_done) return 1;

    s_scroll_pixel += SCROLL_SPEED;
    vdp_set_vscroll((unsigned short)(s_scroll_pixel & 0xFFFF));

    unsigned short new_row = (unsigned short)(s_scroll_pixel >> 3);
    if (new_row > s_last_row) {
        unsigned short plane_row = (unsigned short)(s_last_row & 31u);
        if (s_next_source_row < intro_story_tilemap_rows) {
            vdp_write_nametable_row(PLANE_A_BASE, plane_row,
                &intro_story_tilemap[s_next_source_row * 32]);
            s_next_source_row++;
        }
        s_last_row = new_row;
    }

    unsigned long end_pixel = (unsigned long)intro_story_tilemap_rows * 8u
                            + 32u * 8u;
    if (s_scroll_pixel >= end_pixel) {
        s_done = 1;
        return 1;
    }
    return 0;
}
