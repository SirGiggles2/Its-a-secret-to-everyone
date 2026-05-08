/* SGDK-backed render_abi.h implementation for RoomRom.
 * Maps the room renderer's plane, palette, and CHR calls onto SGDK VDP API.
 */
#include <genesis.h>
#include "render_abi.h"

void render_set_plane_a_word(unsigned short col, unsigned short row,
                             unsigned short word)
{
    VDP_setTileMapXY(BG_A, word,
                     (unsigned short)(col & 0x3Fu),
                     (unsigned short)(row & 0x3Fu));
}

void render_set_plane_b_word(unsigned short col, unsigned short row,
                             unsigned short word)
{
    VDP_setTileMapXY(BG_B, word,
                     (unsigned short)(col & 0x3Fu),
                     (unsigned short)(row & 0x3Fu));
}

void render_load_palette(unsigned short idx, const unsigned short *src)
{
    PAL_setColors((u16)(idx * 16), (const u16 *)src, 16, CPU);
}

void render_chr_upload(unsigned short vram_addr,
                       const unsigned char *src,
                       unsigned short byte_count)
{
    u16 tile = (u16)(vram_addr >> 5);
    u16 count = (u16)(byte_count >> 5);
    u16 i;

    /* Generated C byte arrays are not guaranteed to be long-aligned after
     * linking. SGDK's CPU tile upload reads u32s, so copy through an aligned
     * tile buffer instead of casting the source pointer directly. */
    for (i = 0; i < count; i++) {
        u32 buf[8];
        u16 j;
        const unsigned char *tile_src = src + ((unsigned short)i << 5);
        for (j = 0; j < 8; j++) {
            u16 off = (u16)(j << 2);
            buf[j] = ((u32)tile_src[off] << 24) |
                     ((u32)tile_src[off + 1] << 16) |
                     ((u32)tile_src[off + 2] << 8) |
                     (u32)tile_src[off + 3];
        }
        VDP_loadTileData(buf, (u16)(tile + i), 1, CPU);
    }
}

void render_mode_set_v64(void)
{
    VDP_setPlaneSize(64, 64, TRUE);
}

void render_mode_set_h64v32(void)
{
    /* PR-2: 64x32 plane mode. SGDK case 11 default puts BGB@$C000,
     * Window@$D000, BGA@$E000, HScroll@$F000, SAT@$F400. Caller must
     * override BGA/BGB addresses if a different layout is needed. */
    VDP_setPlaneSize(64, 32, TRUE);
}
