#include "roomrom_bg_palette.h"
#include "render_abi.h"

/* Reuse the existing misc_palettes NES-color-index -> Gen-CRAM-word LUT.
 * Same table consumed by ow_room_render_roomrom.c, uw_room_render_roomrom.c,
 * and roomrom_sprites.c -- single source of truth for color conversion.
 */
extern const unsigned char misc_palettes[1208];

unsigned short roomrom_bg_palette_nes_to_cram(unsigned char nes_color)
{
    unsigned short off = (unsigned short)(nes_color & 0x3Fu) * 2u;
    return (unsigned short)misc_palettes[off]
         | ((unsigned short)misc_palettes[off + 1] << 8);
}

static void load_slot16(unsigned char gen_slot, const unsigned char *nes16)
{
    unsigned short pal16[16];
    unsigned char i;
    for (i = 0; i < 16; i++) {
        pal16[i] = roomrom_bg_palette_nes_to_cram(nes16[i]);
    }
    render_load_palette((unsigned short)gen_slot, pal16);
}

void roomrom_bg_palette_load_palram_full(const unsigned char *palram32)
{
    /* PAL0 <- NES BG palram bytes ($3F00..$3F0F).
     * PAL1 <- NES SPR palram bytes ($3F10..$3F1F).
     * PAL2/PAL3 untouched (caller-managed). */
    load_slot16(0, palram32 + 0);
    load_slot16(1, palram32 + 16);
}

void roomrom_bg_palette_load_bg_only(const unsigned char *palram16)
{
    load_slot16(0, palram16);
}
