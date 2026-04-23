#include "hud_runtime.h"

extern void z01_format_decimal_byte(unsigned char val);
extern void c_format_char_doublet(unsigned char ch);
extern const unsigned char StatusBarTransferBufTemplate[];

void hudrt_format_hearts_in_text_buf(unsigned char start_off) {
    unsigned char hearts;
    unsigned char full;
    unsigned char threshold_empty;
    unsigned char containers;
    unsigned char threshold_space;
    unsigned char row_pos;
    unsigned char slot;
    RAM(0x000D) = start_off;
    hearts = RAM(0x000E);
    full = hearts & 0x0F;
    threshold_empty = (unsigned char)(15 - full);
    containers = hearts >> 4;
    threshold_space = (unsigned char)(15 - containers);
    RAM(0x000B) = start_off + 7;
    row_pos = 7;
    for (slot = 0; slot < 16; ++slot) {
        unsigned char tile;
        if (row_pos == 0xFF) {
            RAM(0x000B) = RAM(0x000D) + 0x12;
            row_pos = 18;
        }
        if (hearts == 0 || slot < threshold_space) {
            tile = 36;
        } else if (slot > threshold_empty) {
            tile = 0xF2;
        } else if (slot < threshold_empty) {
            tile = 102;
        } else {
            unsigned char partial = RAM(0x000F);
            if (partial == 0) {
                tile = 102;
            } else if (partial >= 0x80) {
                tile = 0xF2;
            } else {
                RAM(0x0529) = 0;
                tile = 101;
            }
        }
        RAM(0x000C) = row_pos;
        RAM(0x0302 + RAM(0x000B)) = tile;
        RAM(0x000B)--;
        row_pos = (unsigned char)(RAM(0x000C) - 1);
    }
}

void hudrt_copy_triplet_to_text_buf(void) {
    unsigned char base_off = RAM(0x0000);
    RAM(0x0302 + base_off) = RAM(0x0003);
    RAM(0x0302 + base_off - 1) = RAM(0x0002);
    RAM(0x0302 + base_off - 2) = RAM(0x0001);
}

void hudrt_format_decimal_count_byte(unsigned char val) {
    unsigned char hundreds;
    z01_format_decimal_byte(val);
    hundreds = RAM(0x0001);
    if (hundreds == 0x24)
        hundreds = 33;
    RAM(0x0001) = hundreds;
    if (RAM(0x0002) == 0x24)
        c_format_char_doublet(RAM(0x0003));
}

void hudrt_format_decimal_count_byte_in_text_buf(unsigned char val, unsigned char buf_offset) {
    RAM(0x0000) = buf_offset;
    hudrt_format_decimal_count_byte(val);
    hudrt_copy_triplet_to_text_buf();
}

void hudrt_format_status_bar_text(void) {
    unsigned char i;
    for (i = 0; i <= 40; ++i)
        RAM(0x0302 + i) = StatusBarTransferBufTemplate[i];
    RAM(0x000E) = RAM(0x066F);
    RAM(0x000F) = RAM(0x0670);
    hudrt_format_hearts_in_text_buf(3);
    hudrt_format_decimal_count_byte_in_text_buf(RAM(0x066D), 27);
    if (RAM(0x0664) != 0) {
        RAM(0x0000) = 33;
        RAM(0x0001) = 33;
        c_format_char_doublet(10);
        hudrt_copy_triplet_to_text_buf();
    } else {
        hudrt_format_decimal_count_byte_in_text_buf(RAM(0x066E), 33);
    }
    hudrt_format_decimal_count_byte_in_text_buf(RAM(0x0658), 39);
}

void hudrt_world_change_rupees(void) {
    unsigned char rupees;
    if (RAM(0x0014) != 0)
        return;
    if (!(RAM(0x0302) & 0x80))
        return;
    rupees = RAM(0x066D);
    if (rupees == 0) {
        RAM(0x0657 + 39) = 0;
    } else if (rupees == 0xFF) {
        RAM(0x0657 + 38) = 0;
    }
    if (RAM(0x0015) & 1)
        return;
    if (RAM(0x067D) != 0) {
        RAM(0x067D)--;
        RAM(0x066D)++;
        RAM(0x0604) = 16;
    }
    if (RAM(0x067E) == 0) {
        hudrt_format_status_bar_text();
        return;
    }
    RAM(0x067E)--;
    RAM(0x066D)--;
    RAM(0x0604) = 16;
    hudrt_format_status_bar_text();
}
