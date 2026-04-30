#include <genesis.h>
#include "roomrom_sprites.h"
#include "render_abi.h"

/* Sprite CHR block from data/chr/sprites.c. Note: the extractor pulls this
 * from the wrong PRG bank (intro/title sprite seam, not gameplay), so it does
 * NOT contain Link's gameplay tiles. We embed Link's 4 tiles below as a fix.
 * Long-term: tools/extract_chr.py needs its sprite seam corrected from
 * PRG $D15B to PRG $807F (verified via /spritefix probe). */
extern const unsigned char sprites_chr[7424];
extern const unsigned char misc_palettes[1208];

#define SPRITE_VRAM_TILE_BASE  512u
#define SPRITE_CHR_BYTES       7424u

#define SPRITE_BLOCK_TILE_COUNT 232u
#define LINK_VRAM_TILE         (SPRITE_VRAM_TILE_BASE + SPRITE_BLOCK_TILE_COUNT)

/* Link facing-down standstill, 4 tiles in Genesis 2x2 column-major order
 * (TL, BL, TR, BR). Sourced from NES gameplay CHR-RAM at NES tile IDs
 * $58, $59, $0A, $0B (verified via OAM dump in BizHawk: spr18 tile=$58,
 * spr19 tile=$0A, palette 0). NES 2bpp -> Genesis 4bpp converted offline. */
static const unsigned char link_down_chr[128] = {
    /* tile $58 (TL) */
    0x00, 0x00, 0x01, 0x11, 0x00, 0x00, 0x11, 0x11, 0x00, 0x20, 0x13, 0x33,
    0x00, 0x20, 0x33, 0x33, 0x00, 0x22, 0x32, 0x12, 0x00, 0x22, 0x32, 0x32,
    0x00, 0x02, 0x22, 0x22, 0x00, 0x01, 0x12, 0x23,
    /* tile $59 (BL) */
    0x03, 0x33, 0x33, 0x22, 0x33, 0x23, 0x33, 0x31, 0x32, 0x22, 0x33, 0x23,
    0x33, 0x23, 0x33, 0x21, 0x33, 0x23, 0x33, 0x23, 0x33, 0x33, 0x33, 0x21,
    0x02, 0x22, 0x22, 0x30, 0x00, 0x00, 0x33, 0x30,
    /* tile $0A (TR) */
    0x11, 0x10, 0x00, 0x00, 0x11, 0x11, 0x00, 0x00, 0x33, 0x31, 0x02, 0x00,
    0x33, 0x33, 0x02, 0x00, 0x21, 0x23, 0x22, 0x00, 0x23, 0x23, 0x22, 0x00,
    0x22, 0x22, 0x23, 0x00, 0x32, 0x21, 0x13, 0x00,
    /* tile $0B (BR) */
    0x22, 0x11, 0x33, 0x30, 0x11, 0x11, 0x23, 0x30, 0x31, 0x12, 0x22, 0x30,
    0x33, 0x33, 0x22, 0x20, 0x31, 0x11, 0x12, 0x00, 0x11, 0x11, 0x00, 0x00,
    0x03, 0x33, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
};

static unsigned short nes_to_cram(unsigned char nes_idx)
{
    unsigned short off = (unsigned short)(nes_idx & 0x3Fu) * 2u;
    return (unsigned short)misc_palettes[off]
         | ((unsigned short)misc_palettes[off + 1] << 8);
}

void roomrom_sprites_upload_chr(void)
{
    /* Main extracted sprite block (kept for future S2+ tiles even though it
     * doesn't contain gameplay Link). */
    render_chr_upload((unsigned short)(SPRITE_VRAM_TILE_BASE * 32u),
                      sprites_chr, SPRITE_CHR_BYTES);

    /* Link's actual gameplay tiles, ground-truth from live NES CHR. */
    render_chr_upload((unsigned short)(LINK_VRAM_TILE * 32u),
                      link_down_chr, sizeof(link_down_chr));
}

void roomrom_sprites_load_palette(void)
{
    unsigned short pal16[16];
    unsigned char i;

    for (i = 0; i < 16; i++) pal16[i] = 0;

    /* Sprite sub-pal 0 = Link's gameplay palette. Verified live PALRAM dump
     * ($3F11..$3F13) returns $29, $27, $17 for color indices 1..3 — green
     * tunic, peach skin, brown shadow. */
    pal16[0] = nes_to_cram(0x0Fu);  /* transparent (NES uses $00 here, $0F == universal black) */
    pal16[1] = nes_to_cram(0x29u);  /* green tunic */
    pal16[2] = nes_to_cram(0x27u);  /* peach skin */
    pal16[3] = nes_to_cram(0x17u);  /* brown shadow / boots */

    render_load_palette(3 /* PAL3 */, pal16);
}

void roomrom_sprites_spawn_link(short x, short y)
{
    VDP_setSpriteFull(0,
                      (s16)x,
                      (s16)y,
                      SPRITE_SIZE(2, 2),
                      TILE_ATTR_FULL(PAL3, 1 /*pri*/, 0 /*vflip*/, 0 /*hflip*/,
                                     LINK_VRAM_TILE),
                      0 /*link terminator*/);
    VDP_updateSprites(1, DMA);
}
