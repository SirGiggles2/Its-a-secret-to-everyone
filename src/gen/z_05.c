/* z_05.c — Stage 3b: C port of z_05 tile buffer copy functions.
 * Data tables and remaining code stay in z_05.asm.
 */

#include "../nes_abi.h"

#define PLAY_AREA_BASE  0x6530u
#define COL_STRIDE      0x16u

/* CopyColumnToTileBuf — builds a tile transfer record for one column
 * of the play area.  NES RAM[$00E8] = target column + 1.
 * Writes header + 22 column bytes into the tile buffer at RAM[$0302+]. */
void z05_copy_column_to_tilebuf(void) {
    RAM(0x0000) = 0x1A;
    RAM(0x0001) = 0x65;

    unsigned char col = RAM(0x00E8) - 1;
    unsigned char buf = RAM(0x0301);

    RAM(0x0302 + buf) = 33;
    RAM(0x0303 + buf) = col;

    unsigned short src = PLAY_AREA_BASE + (unsigned short)col * COL_STRIDE;

    RAM(0x0304 + buf) = 0x96;
    RAM(0x031B + buf) = 0xFF;

    unsigned char dst = buf;
    for (unsigned char i = 0; i < 22; i++) {
        RAM(0x0305 + dst) = nes_ram[src + i];
        dst++;
    }
    src += 22;
    dst += 3;
    RAM(0x0301) = dst;

    RAM(0x0000) = src & 0xFF;
    RAM(0x0001) = (src >> 8) & 0xFF;
}

/* CopyRowToTileBuf — builds a tile transfer record for one row
 * of the play area.  NES RAM[$00E9] = target row.
 * Reads 32 tiles (one per column, stride $16) into tile buffer. */
void z05_copy_row_to_tilebuf(void) {
    unsigned char row = RAM(0x00E9);

    /* Set pointer 00:01 = $6530 + row (8-bit add with carry) */
    unsigned short ptr = 0x6530u + row;
    RAM(0x0000) = ptr & 0xFF;
    RAM(0x0001) = (ptr >> 8) & 0xFF;

    /* Compute VRAM dest address: $20E0 + (row+1)*$20
     * The NES loop adds $20 to $E0 for (row+1) iterations.
     * Row 0: $20E0 + $20 = $2100.  Row 1: $2100 + $20 = $2120.  etc. */
    unsigned short vram = 0x20E0u;
    for (signed char r = (signed char)row; r >= 0; r--)
        vram += 0x20;
    RAM(0x0302) = (vram >> 8) & 0xFF;
    RAM(0x0303) = vram & 0xFF;

    RAM(0x0304) = 32;
    RAM(0x0325) = 0xFF;

    /* Copy 32 tiles: one per column, stride $16 */
    unsigned short s = PLAY_AREA_BASE + row;
    for (unsigned char i = 0; i < 32; i++) {
        RAM(0x0305 + i) = nes_ram[s];
        s += COL_STRIDE;
    }

    RAM(0x0301) = 35;

    RAM(0x0000) = s & 0xFF;
    RAM(0x0001) = (s >> 8) & 0xFF;
}
