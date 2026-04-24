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
}
