#include <genesis.h>
#include "roomrom_sprites.h"
#include "render_abi.h"

/* Sprite CHR exported from data/chr/sprites.c (already in Genesis 4bpp).
 * Per data/chr/MANIFEST.json the sprite block lives at VRAM tile 512. */
extern const unsigned char sprites_chr[7424];

/* Inline NES->CRAM conversion (also used by ow_/uw_room_render).
 * misc_palettes is the canonical NES->CRAM lookup populated at build. */
extern const unsigned char misc_palettes[1208];

#define SPRITE_VRAM_TILE_BASE  512u
#define SPRITE_CHR_BYTES       7424u
#define LINK_TILE_NES_BASE     0x60u   /* facing-down standstill, top-left tile */
#define LINK_VRAM_TILE         (SPRITE_VRAM_TILE_BASE + LINK_TILE_NES_BASE)

static unsigned short nes_to_cram(unsigned char nes_idx)
{
    unsigned short off = (unsigned short)(nes_idx & 0x3Fu) * 2u;
    return (unsigned short)misc_palettes[off]
         | ((unsigned short)misc_palettes[off + 1] << 8);
}

void roomrom_sprites_upload_chr(void)
{
    render_chr_upload((unsigned short)(SPRITE_VRAM_TILE_BASE * 32u),
                      sprites_chr, SPRITE_CHR_BYTES);
}

void roomrom_sprites_load_palette(void)
{
    unsigned short pal16[16];
    unsigned char i;

    for (i = 0; i < 16; i++) pal16[i] = 0;

    /* NES sprite sub-palette 0 = Link's gameplay palette ($3F10..$3F13). */
    pal16[0] = nes_to_cram(0x0F);  /* transparent / black */
    pal16[1] = nes_to_cram(0x30);  /* white  (shield highlights) */
    pal16[2] = nes_to_cram(0x16);  /* tan    (skin) */
    pal16[3] = nes_to_cram(0x06);  /* dark red / brown */

    /* sub-pals 1..3 left zero - populated in later slices for enemy colors. */

    render_load_palette(3 /* PAL3 */, pal16);
}

void roomrom_sprites_spawn_link(short x, short y)
{
    /* SGDK sprite-table coords: screen + 0x80 origin. */
    unsigned short sx = (unsigned short)(x + 0x80);
    unsigned short sy = (unsigned short)(y + 0x80);

    VDP_setSprite(0,
                  sy,
                  sx,
                  SPRITE_SIZE(2, 2),
                  TILE_ATTR_FULL(PAL3, 1 /*pri*/, 0 /*vflip*/, 0 /*hflip*/,
                                 LINK_VRAM_TILE),
                  0 /*link terminator*/);
    VDP_updateSprites(1, DMA);
}
