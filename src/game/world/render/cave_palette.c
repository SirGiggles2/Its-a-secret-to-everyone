#include "cave_palette.h"
#include "bg_palette.h"
#include "render_abi.h"

/* NES PPU bytes for cave BG subpal 2+3 (Z_06.asm:714). */
static const unsigned char k_cave_subpal_2_3_nes[8] = {
    0x0F, 0x30, 0x00, 0x12,   /* subpal 2: black, white, gray, blue   */
    0x0F, 0x07, 0x0F, 0x17    /* subpal 3: black, brown, black, orange */
};

void cave_palette_apply(void)
{
    unsigned short cram[8];
    unsigned char i;
    for (i = 0u; i < 8u; i++) {
        cram[i] = roomrom_bg_palette_nes_to_cram(k_cave_subpal_2_3_nes[i]);
    }
    /* PAL0 starts at CRAM slot 0; subpal 2+3 occupy slots 8..15. */
    render_cram_subrange_upload(8u, cram, 8u);
}
