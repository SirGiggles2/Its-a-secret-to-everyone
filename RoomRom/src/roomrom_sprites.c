#include <genesis.h>
#include "roomrom_sprites.h"
#include "render_abi.h"

/* Sprite CHR exported from data/chr/sprites.c (already in Genesis 4bpp).
 * Per data/chr/MANIFEST.json the sprite block lives at VRAM tile 512. */
extern const unsigned char sprites_chr[7424];

#define SPRITE_VRAM_TILE_BASE  512u
#define SPRITE_CHR_BYTES       7424u

void roomrom_sprites_upload_chr(void)
{
    render_chr_upload((unsigned short)(SPRITE_VRAM_TILE_BASE * 32u),
                      sprites_chr, SPRITE_CHR_BYTES);
}

void roomrom_sprites_load_palette(void)
{
    /* implemented in next commit */
}

void roomrom_sprites_spawn_link(short x, short y)
{
    (void)x; (void)y;
    /* implemented in next commit */
}
