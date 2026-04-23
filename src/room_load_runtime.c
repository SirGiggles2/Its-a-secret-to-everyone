#include "room_load_runtime.h"

#define NES_SRAM_BASE 0x6000u

static const unsigned char roomld_sprite0_descriptor[] = { 0x27, 0x61, 0x20, 0x58 };
static const unsigned char roomld_palette_to_nt_attr[] = { 0x00, 0x55, 0xAA, 0xFF };
static const unsigned char roomld_obj_room_bounds[] = {
    0x11, 0xE0, 0x4E, 0xCD, 0x89,
    0x21, 0xD0, 0x5E, 0xBD, 0x78
};

void roomld_write_and_enable_sprite0(void) {
    signed char i;
    ROOM_SPRITE0_ENABLED = 1;
    for (i = 3; i >= 0; i--)
        ROOM_OAM_BYTE((unsigned char)i) = roomld_sprite0_descriptor[(unsigned char)i];
}

void roomld_put_link_behind_background(void) {
    ROOM_LINK_BG_ATTR_A |= 0x20;
    ROOM_LINK_BG_ATTR_B |= 0x20;
}

void roomld_reset_inv_obj_state(void) {
    signed char i;
    ROOM_INV_OBJ_ACTIVE = 0;
    for (i = 5; i >= 0; i--)
        ROOM_INV_OBJ_STATE((unsigned char)i) = 0;
}

void roomld_fill_play_area_attrs(unsigned int room_id) {
    unsigned char outer_sel = nes_ram[NES_SRAM_BASE + 0x087E + room_id] & 0x03;
    unsigned char outer_attr = roomld_palette_to_nt_attr[outer_sel];
    unsigned char inner_sel;
    unsigned char inner_attr;
    unsigned char d3;

    for (d3 = 0; d3 < 48; d3++)
        ROOM_PALETTE_ATTR(d3) = outer_attr;

    inner_sel = nes_ram[NES_SRAM_BASE + 0x08FE + room_id] & 0x03;
    inner_attr = roomld_palette_to_nt_attr[inner_sel];

    for (d3 = 9; d3 < 0x27; d3++) {
        unsigned char mod = d3 & 0x07;
        if (mod == 0 || mod == 7)
            continue;
        if (d3 >= 0x21) {
            unsigned char combined = (inner_attr & 0x0F) | (ROOM_PALETTE_ATTR(d3) & 0xF0);
            ROOM_PALETTE_ATTR(d3) = combined;
        } else {
            ROOM_PALETTE_ATTR(d3) = inner_attr;
        }
    }
}

void roomld_setup_obj_room_bounds(void) {
    unsigned char base = 5;
    unsigned char i;
    if (CUR_LEVEL == 0) {
        base = 0;
        ROOM_IN_DOORWAY_FLAG = 0;
    }
    for (i = 0; i < 5; i++)
        ROOM_BOUNDS(i) = roomld_obj_room_bounds[(unsigned char)(base + i)];
}

void roomld_init_link_speed(void) {
    WORLD_TMP0 = 96;
    if (CUR_LEVEL != 0) {
        ROOM_LINK_SPEED = WORLD_TMP0;
        return;
    }
    if (ROOM_COLLIDABLE_TILE == 0x74 || ROOM_COLLIDABLE_TILE == 0x75) {
        WORLD_TMP0 = 48;
        if (ROOM_LINK_SPEED != 48)
            ROOM_LINK_SPEED_FRAC = 0;
    }
    ROOM_LINK_SPEED = WORLD_TMP0;
}
