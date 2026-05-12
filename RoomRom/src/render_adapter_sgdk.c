/* SGDK-backed render_abi.h implementation for RoomRom.
 * Maps the room renderer's plane, palette, and CHR calls onto SGDK VDP API.
 */
#include <genesis.h>
#include "render_abi.h"

#define ROOMROM_PLANE_SHARED_BASE 0xC000u
#define ROOMROM_PLANE_ROW_TILES   64u
#define VDP_DATA_WORD (*(volatile u16 *)VDP_DATA_PORT)
#define VDP_CTRL_LONG (*(volatile u32 *)VDP_CTRL_PORT)

static void render_set_roomrom_plane_word(u16 base, unsigned short col,
                                          unsigned short row,
                                          unsigned short word)
{
    const u16 addr = (u16)(base +
        ((((row & 0x3Fu) * ROOMROM_PLANE_ROW_TILES) + (col & 0x3Fu)) << 1));
    VDP_setAutoInc(2);
    VDP_CTRL_LONG = VDP_WRITE_VRAM_ADDR(addr);
    VDP_DATA_WORD = word;
}

void render_set_plane_a_word(unsigned short col, unsigned short row,
                             unsigned short word)
{
    render_set_roomrom_plane_word(ROOMROM_PLANE_SHARED_BASE, col, row, word);
}

void render_set_plane_b_word(unsigned short col, unsigned short row,
                             unsigned short word)
{
    render_set_roomrom_plane_word(ROOMROM_PLANE_SHARED_BASE, col, row, word);
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

    if ((((unsigned long)src | (unsigned long)byte_count | (unsigned long)vram_addr) & 3u) == 0u) {
        VDP_loadTileData((const u32 *)src, tile, count, CPU);
        return;
    }

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
