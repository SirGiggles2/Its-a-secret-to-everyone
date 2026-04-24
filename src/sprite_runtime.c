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

/* ---- Plan C: drained from z_07 (animation cluster) --------------------- */

static void sprrt_animate_link_obj_state(void) {
    unsigned char state = RAM(0x00AC);
    unsigned char major = state & 0x30;
    if (major == 0x10 || major == 0x20) {
        if (state & 0x0F)
            RAM(0x00AC) = state | 0x30;
        else
            RAM(0x00AC) = state + 1;
        RAM(0x03E4) = 1;
    } else if (major == 0x30) {
        RAM(0x00AC) = state & 0xC0;
    }
}

void sprrt_roll_over_anim_counter(unsigned int slot) {
    RAM(0x03D0 + slot) = RAM(0x00);
    RAM(0x03E4 + slot) ^= 0x01;
}

unsigned char sprrt_anim_fetch_obj_pos(unsigned int slot) {
    RAM(0x0000) = RAM(0x0070 + slot);
    RAM(0x0001) = RAM(0x0084 + slot);
    RAM(0x000F) = 0;
    return 0;
}

void sprrt_anim_set_obj_hflip(unsigned int slot) {
    RAM(0x000F) = RAM(0x03E4 + slot);
}

void sprrt_anim_advance_and_fetch(unsigned int val, unsigned int slot) {
    RAM(0x0000) = (unsigned char)val;
    RAM(0x03D0 + slot)--;
    if (RAM(0x03D0 + slot) == 0) {
        sprrt_roll_over_anim_counter(slot);
    }
    sprrt_anim_fetch_obj_pos(slot);
}

void sprrt_animate_object_walking(unsigned int slot) {
    if (--RAM(0x03D0 + slot) == 0) {
        if (slot == 0) sprrt_animate_link_obj_state();
        RAM(0x0000) = 6;
        sprrt_roll_over_anim_counter(slot);
    }
    sprrt_anim_fetch_obj_pos(slot);
    unsigned char dir = RAM(0x0098 + slot) & 0x0C;
    if (dir != 0) {
        sprrt_anim_set_obj_hflip(slot);
    } else {
        if (!(RAM(0x0098 + slot) & 1)) RAM(0x000F)++;
    }
}
