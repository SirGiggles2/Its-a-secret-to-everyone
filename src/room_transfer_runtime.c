#include "room_transfer_runtime.h"

#define PLAY_AREA_BASE  0x6530u
#define COL_STRIDE      0x16u

void roomxf_copy_column_to_tilebuf(void) {
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

void roomxf_copy_row_to_tilebuf(void) {
    unsigned char row = RAM(0x00E9);

    unsigned short ptr = 0x6530u + row;
    RAM(0x0000) = ptr & 0xFF;
    RAM(0x0001) = (ptr >> 8) & 0xFF;

    unsigned short vram = 0x20E0u;
    for (signed char r = (signed char)row; r >= 0; r--)
        vram += 0x20;
    RAM(0x0302) = (vram >> 8) & 0xFF;
    RAM(0x0303) = vram & 0xFF;

    RAM(0x0304) = 32;
    RAM(0x0325) = 0xFF;

    unsigned short s = PLAY_AREA_BASE + row;
    for (unsigned char i = 0; i < 32; i++) {
        RAM(0x0305 + i) = nes_ram[s];
        s += COL_STRIDE;
    }

    RAM(0x0301) = 35;

    RAM(0x0000) = s & 0xFF;
    RAM(0x0001) = (s >> 8) & 0xFF;
}

unsigned int roomxf_cycle9_in_direction(unsigned int d3_in) {
    unsigned char d3 = (unsigned char)d3_in;
    unsigned char dir = ROOM_CYCLE_DIR & 0x03;
    if (dir == 0)
        return d3;
    if (dir & 1)
        d3++;
    else
        d3--;
    if (d3 == 0xFF)
        d3 = 8;
    else if (d3 == 9)
        d3 = 0;
    return d3;
}

void roomxf_copy_column_or_row_to_tilebuf(void) {
    unsigned char row = ROOM_ROW_INDEX;
    if (row < 0x16) {
        if (row == ROOM_LAST_ROW_INDEX)
            return;
        ROOM_LAST_ROW_INDEX = row;
        roomxf_copy_row_to_tilebuf();
        return;
    }
    if (CUR_ROOM_FLAGS_PTR == 0 || CUR_ROOM_FLAGS_PTR >= 0x21)
        return;
    roomxf_copy_column_to_tilebuf();
}

void roomxf_fetch_tile_map_addr(void) {
    SAVEFILE_PTR_LO = 48;
    SAVEFILE_PTR_HI = 101;
}

void roomxf_copy_play_area_attrs_half(unsigned int ppu_hi, unsigned int ppu_lo, unsigned int end_off) {
    unsigned char src = (unsigned char)end_off;
    unsigned char dst;
    TRANSFER_BUF_BYTE(0) = (unsigned char)ppu_hi;
    TRANSFER_BUF_BYTE(1) = (unsigned char)ppu_lo;
    TRANSFER_BUF_BYTE(2) = 24;
    TRANSFER_BUF_BYTE(27) = 0xFF;
    for (dst = 24; dst > 0; dst--) {
        TRANSFER_BUF_BYTE((unsigned char)(2 + dst)) = ROOM_PALETTE_ATTR(src);
        src--;
    }
}
