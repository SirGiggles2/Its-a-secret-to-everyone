/* SGDK-backed render_abi.h implementation for RoomRom.
 * Maps render_set_plane_a_word and render_chr_upload onto SGDK VDP API.
 * Only the two functions called by ow_room_render.c are implemented here.
 */
#include <genesis.h>
#include "render_abi.h"

void render_set_plane_a_word(unsigned short col, unsigned short row,
                             unsigned short word)
{
    VDP_setTileMapXY(BG_A, word, col, row);
}

void render_load_palette(unsigned short idx, const unsigned short *src)
{
    PAL_setColors((u16)(idx * 16), (const u16 *)src, 16, CPU);
}

void render_chr_upload(unsigned short vram_addr,
                       const unsigned char *src,
                       unsigned short byte_count)
{
    /* vram_addr and byte_count are in bytes; SGDK counts in tiles (32 bytes). */
    VDP_loadTileData((const u32 *)src,
                     (u16)(vram_addr >> 5),
                     (u16)(byte_count >> 5),
                     CPU);
}
