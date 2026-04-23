#include "sprite_runtime.h"

extern unsigned char z01_reset_cur_sprite_index(void);

void sprrt_cycle_cur_sprite_index(void) {
    unsigned char idx = (unsigned char)(RAM(0x0341) + 1u);
    if (idx == 0x28) {
        z01_reset_cur_sprite_index();
    } else {
        RAM(0x0341) = idx;
    }
}

unsigned char sprrt_cycle_sprite_index_in_a(unsigned char idx) {
    idx = (unsigned char)(idx + 1u);
    if (idx == 0x28) {
        z01_reset_cur_sprite_index();
        return 0;
    }
    RAM(0x0341) = idx;
    return idx;
}

void sprrt_hide_object_sprites(void) {
    unsigned char d2 = 96;
    do {
        RAM(0x0200 + d2) = 0xF8;
        d2 = (unsigned char)(d2 + 4u);
    } while (d2 != 0);
    RAM(0x0342) = sprrt_cycle_sprite_index_in_a(RAM(0x0342));
}

void sprrt_show_link_sprites_behind_horizontal_doors(void) {
    static const unsigned char extents[2] = {0x08, 0x00};
    unsigned int d3 = 10;
    int d2 = 1;
    RAM(0x0000) = RAM(0x0070);
    do {
        unsigned char x = (unsigned char)(RAM(0x0000) + extents[d2]);
        if (x >= 0xE9u || x < 0x10u) {
            RAM(0x0240 + d3) = RAM(0x0240 + d3) | 0x20u;
        }
        d3 = (d3 + 4u) & 0xFFu;
        if (d3 == 0) {
            d3 = 32;
        }
        d2--;
    } while (d2 >= 0);
}
