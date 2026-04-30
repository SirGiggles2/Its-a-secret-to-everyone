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

/* Dedicated VRAM region for Link's facing-down frame, laid out in Genesis
 * sprite column-major order (TL, BL, TR, BR). Sits just past the main 232-tile
 * sprite block to avoid colliding with anything else. */
#define SPRITE_BLOCK_TILE_COUNT 232u
#define LINK_VRAM_TILE         (SPRITE_VRAM_TILE_BASE + SPRITE_BLOCK_TILE_COUNT)

static unsigned short nes_to_cram(unsigned char nes_idx)
{
    unsigned short off = (unsigned short)(nes_idx & 0x3Fu) * 2u;
    return (unsigned short)misc_palettes[off]
         | ((unsigned short)misc_palettes[off + 1] << 8);
}

void roomrom_sprites_upload_chr(void)
{
    /* Main sprite block (NES tile order, contiguous). */
    render_chr_upload((unsigned short)(SPRITE_VRAM_TILE_BASE * 32u),
                      sprites_chr, SPRITE_CHR_BYTES);

    /* Link facing-down standstill: 4 tiles laid out for Genesis 2x2 sprite
     * (column-major). NES sprite-mode-8x16 pairs $60/$61 (left col) and
     * $70/$71 (right col); copy them into LINK_VRAM_TILE..+3 in that order. */
    {
        static const unsigned char nes_link_down_ids[4] = {
            0x60u,  /* TL */
            0x61u,  /* BL */
            0x70u,  /* TR */
            0x71u   /* BR */
        };
        unsigned char i;
        for (i = 0; i < 4; i++) {
            unsigned short src_off = (unsigned short)nes_link_down_ids[i] * 32u;
            render_chr_upload((unsigned short)((LINK_VRAM_TILE + i) * 32u),
                              sprites_chr + src_off, 32u);
        }
    }
}

void roomrom_sprites_load_palette(void)
{
    unsigned short pal16[16];
    unsigned char i;

    for (i = 0; i < 16; i++) pal16[i] = 0;

    /* Sprite pal 0 used for Link. $0F transparent, $30 white, $16 red detail,
     * $27 green tunic. $27 chosen empirically (visual verify); spec said $06
     * but $06 is a skin shadow, wrong for the tunic. A NES PALRAM probe in
     * S2 will pin the canonical gameplay values. */
    pal16[0] = nes_to_cram(0x0Fu);
    pal16[1] = nes_to_cram(0x30u);
    pal16[2] = nes_to_cram(0x16u);
    pal16[3] = nes_to_cram(0x27u);

    /* sub-pals 1..3 left zero - populated in later slices for enemy colors. */

    render_load_palette(3 /* PAL3 */, pal16);
}

void roomrom_sprites_spawn_link(short x, short y)
{
    /* SGDK adds the 0x80 sprite-table origin internally; pass screen coords. */
    VDP_setSpriteFull(0,
                      (s16)x,
                      (s16)y,
                      SPRITE_SIZE(2, 2),
                      TILE_ATTR_FULL(PAL3, 1 /*pri*/, 0 /*vflip*/, 0 /*hflip*/,
                                     LINK_VRAM_TILE),
                      0 /*link terminator*/);
    VDP_updateSprites(1, DMA);
}
