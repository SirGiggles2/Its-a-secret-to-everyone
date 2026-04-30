#include <genesis.h>
#include "roomrom_sprites.h"
#include "render_abi.h"

/* Sprite CHR sources.
 * sprites_chr (data/chr/sprites.c) holds OW enemy tiles (Octorok / Leever /
 * Tektite). common_chr (data/chr/common.c) holds the always-loaded sprites
 * including Link, sword, heart. NES tile IDs in common_chr are 1:1 (NES
 * tile $58 = common_chr + 0x58*32). */
extern const unsigned char sprites_chr[7424];
extern const unsigned char common_chr[7616];
extern const unsigned char misc_palettes[1208];

#define SPRITE_VRAM_TILE_BASE   512u
#define SPRITE_CHR_BYTES        7424u
#define SPRITE_BLOCK_TILE_COUNT 232u

/* Per data/chr/MANIFEST.json: common block lives at VRAM tile 936. Plus 238
 * tiles to land just past it for our Link slot. */
#define COMMON_VRAM_TILE_BASE   936u
#define COMMON_CHR_BYTES        7616u
#define COMMON_BLOCK_TILE_COUNT 238u

#define LINK_VRAM_TILE          (COMMON_VRAM_TILE_BASE + COMMON_BLOCK_TILE_COUNT)

static unsigned short nes_to_cram(unsigned char nes_idx)
{
    unsigned short off = (unsigned short)(nes_idx & 0x3Fu) * 2u;
    return (unsigned short)misc_palettes[off]
         | ((unsigned short)misc_palettes[off + 1] << 8);
}

void roomrom_sprites_upload_chr(void)
{
    /* Main sprite block (OW enemies — kept for S3+). */
    render_chr_upload((unsigned short)(SPRITE_VRAM_TILE_BASE * 32u),
                      sprites_chr, SPRITE_CHR_BYTES);

    /* Common sprite block (always-loaded gameplay sprites including Link). */
    render_chr_upload((unsigned short)(COMMON_VRAM_TILE_BASE * 32u),
                      common_chr, COMMON_CHR_BYTES);

    /* Link facing-down standstill — copy 4 tiles from common_chr into the
     * dedicated LINK_VRAM_TILE region in Genesis 2x2 column-major order
     * (TL, BL, TR, BR). NES tile IDs: $58, $59, $0A, $0B. */
    {
        static const unsigned char link_down_nes_ids[4] = {
            0x58u, 0x59u, 0x0Au, 0x0Bu
        };
        unsigned char i;
        for (i = 0; i < 4; i++) {
            unsigned short src_off = (unsigned short)link_down_nes_ids[i] * 32u;
            render_chr_upload((unsigned short)((LINK_VRAM_TILE + i) * 32u),
                              common_chr + src_off, 32u);
        }
    }
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

void roomrom_sprites_set_link_pos(short x, short y)
{
    VDP_setSpriteFull(0,
                      (s16)x,
                      (s16)y,
                      SPRITE_SIZE(2, 2),
                      TILE_ATTR_FULL(PAL3, 1, 0, 0, LINK_VRAM_TILE),
                      0);
    VDP_updateSprites(1, DMA);
}
