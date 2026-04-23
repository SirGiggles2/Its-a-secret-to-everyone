#include "room_transfer_runtime.h"

extern void z05_copy_row_to_tilebuf(void);
extern void z05_copy_column_to_tilebuf(void);

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
        z05_copy_row_to_tilebuf();
        return;
    }
    if (CUR_ROOM_FLAGS_PTR == 0 || CUR_ROOM_FLAGS_PTR >= 0x21)
        return;
    z05_copy_column_to_tilebuf();
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
