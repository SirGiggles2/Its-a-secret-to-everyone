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

/* --- Stage 4a functions --- */

static const unsigned char level_masks[] = {
    0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80
};

#define NES_SRAM_BASE  0x6000u

static unsigned char get_room_flags(void) {
    unsigned char ptr_lo = nes_ram[NES_SRAM_BASE + 0x0BAF];
    unsigned char ptr_hi = nes_ram[NES_SRAM_BASE + 0x0BB0];
    RAM(0x00) = ptr_lo;
    RAM(0x01) = ptr_hi;
    unsigned short ptr = ((unsigned short)ptr_hi << 8) | ptr_lo;
    unsigned char room_id = RAM(0x00EB);
    return nes_ram[ptr + room_id];
}

static unsigned char has_item_by_level(unsigned char base_offset) {
    unsigned char level = RAM(0x0010);
    if (level == 0) return 0;
    unsigned char idx = level - 1;
    unsigned char offset = base_offset;
    if (idx >= 8) offset += 2;
    unsigned char bit_idx = idx & 7;
    return RAM(0x0657 + offset) & level_masks[bit_idx];
}

unsigned char z05_has_compass(void) {
    return has_item_by_level(16);
}

unsigned char z05_has_map(void) {
    return has_item_by_level(17);
}

void z05_calc_open_doorway_mask(unsigned int attr, unsigned int dir_idx) {
    unsigned char is_open;
    if (attr < 4) {
        is_open = 1;
    } else {
        unsigned char flags = get_room_flags();
        is_open = (flags & level_masks[dir_idx]) ? 1 : 0;
    }
    unsigned char mask = RAM(0x033F);
    mask = ((mask << 1) | is_open) & 0x0F;
    RAM(0x033F) = mask;
}

void z05_add_door_flags(void) {
    get_room_flags();
    unsigned char room_id = RAM(0x00EB);
    unsigned short ptr = ((unsigned short)RAM(0x01) << 8) | RAM(0x00);
    unsigned char flags = nes_ram[ptr + room_id];
    for (signed char d = 3; d >= 0; d--) {
        unsigned char masked = flags & level_masks[(unsigned char)d];
        if (masked)
            RAM(0x00EE) |= masked;
    }
}

/* --- Stage 4b functions --- */

unsigned int z05_split_room_id(void) {
    unsigned char room = RAM(0x00EB);
    unsigned char col = room & 0x0F;
    unsigned char row = room >> 4;
    return ((unsigned int)row << 8) | col;
}

unsigned char z05_is_dark_room(unsigned int col) {
    unsigned char level = RAM(0x0010);
    if (level == 0) return 0;
    return nes_ram[NES_SRAM_BASE + 0x0A7E + col] & 0x80;
}

void z05_set_door_flag(unsigned int dir_idx) {
    unsigned char flags = get_room_flags();
    flags |= level_masks[dir_idx];
    unsigned short ptr = ((unsigned short)RAM(0x01) << 8) | RAM(0x00);
    unsigned char room_id = RAM(0x00EB);
    nes_ram[ptr + room_id] = flags;
}

void z05_reset_door_flag(unsigned int dir_idx) {
    get_room_flags();
    unsigned char mask = level_masks[dir_idx] ^ 0xFF;
    unsigned short ptr = ((unsigned short)RAM(0x01) << 8) | RAM(0x00);
    unsigned char room_id = RAM(0x00EB);
    unsigned char flags = nes_ram[ptr + room_id];
    nes_ram[ptr + room_id] = flags & mask;
}

void z05_check_has_living_monsters(void) {
    unsigned char max_slot = RAM(0x0340);
    for (signed char i = (signed char)max_slot; i >= 0; i--) {
        unsigned char obj = RAM(0x0350 + (unsigned char)i);
        if (obj == 0) continue;
        if (obj < 0x2B) return;
        if (obj < 0x2E) continue;
        if (obj < 0x49) return;
    }
    RAM(0x0512) = 0;
    RAM(0x034D)++;
}

void z05_silence_sound(void) {
    RAM(0x0604) = 0x80;
    RAM(0x0603) = 0x80;
}

void z05_set_entering_doorway(void) {
    unsigned char scroll_dir = RAM(0x0098);
    unsigned char a = (scroll_dir >> 1) & 0x05;
    unsigned char b = (scroll_dir << 1) & 0x0A;
    RAM(0x00EE) = a | b;
}

/* --- Stage 4b batch 3 functions --- */

static const unsigned char sprite0_descriptor[] = { 0x27, 0x61, 0x20, 0x58 };

void z05_write_and_enable_sprite0(void) {
    RAM(0x00E3) = 1;
    for (signed char i = 3; i >= 0; i--)
        RAM(0x0200 + (unsigned char)i) = sprite0_descriptor[(unsigned char)i];
}

void z05_put_link_behind_background(void) {
    RAM(0x024A) |= 0x20;
    RAM(0x024E) |= 0x20;
}

extern void z05_reset_inv_obj_state(void);
extern void z05_copy_row_to_tilebuf(void);
extern void z05_copy_column_to_tilebuf(void);

unsigned int z05_cycle9_in_direction(unsigned int d3_in) {
    unsigned char d3 = (unsigned char)d3_in;
    unsigned char dir = RAM(0x00EF) & 0x03;
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

void z05_copy_column_or_row_to_tilebuf(void) {
    unsigned char row = RAM(0x00E9);
    if (row < 0x16) {
        if (row == RAM(0x00ED))
            return;
        RAM(0x00ED) = row;
        z05_copy_row_to_tilebuf();
        return;
    }
    unsigned char col = RAM(0x00E8);
    if (col == 0 || col >= 0x21)
        return;
    z05_copy_column_to_tilebuf();
}

void z05_init_mode_a_sub_a_go_to_mode4(void) {
    z05_reset_inv_obj_state();
    RAM(0x0013) = 0;
    RAM(0x0012) = 4;
}

void z05_reset_inv_obj_state(void) {
    RAM(0x0064) = 0;
    for (signed char i = 5; i >= 0; i--)
        RAM(0x00B9 + (unsigned char)i) = 0;
}

void z05_mask_cur_ppu_mask_grayscale(void) {
    RAM(0x00FE) &= 0xFE;
}

static const unsigned char room_palette_to_nt_attr[] = { 0x00, 0x55, 0xAA, 0xFF };

void z05_fill_play_area_attrs(unsigned int room_id) {
    unsigned char outer_sel = nes_ram[NES_SRAM_BASE + 0x087E + room_id] & 0x03;
    unsigned char outer_attr = room_palette_to_nt_attr[outer_sel];

    for (unsigned char i = 0; i < 48; i++)
        RAM(0x0530 + i) = outer_attr;

    unsigned char inner_sel = nes_ram[NES_SRAM_BASE + 0x08FE + room_id] & 0x03;
    unsigned char inner_attr = room_palette_to_nt_attr[inner_sel];

    for (unsigned char d3 = 9; d3 < 0x27; d3++) {
        unsigned char mod = d3 & 0x07;
        if (mod == 0 || mod == 7) continue;
        if (d3 >= 0x21) {
            unsigned char combined = (inner_attr & 0x0F) | (RAM(0x0530 + d3) & 0xF0);
            RAM(0x0530 + d3) = combined;
        } else {
            RAM(0x0530 + d3) = inner_attr;
        }
    }
}

static const unsigned char obj_room_bounds[] = {
    0x11, 0xE0, 0x4E, 0xCD, 0x89,
    0x21, 0xD0, 0x5E, 0xBD, 0x78
};

void z05_setup_obj_room_bounds(void) {
    unsigned char base = 5;
    if (RAM(0x0010) == 0) {
        base = 0;
        RAM(0x0053) = 0;
    }
    for (unsigned char i = 0; i < 5; i++)
        RAM(0x0346 + i) = obj_room_bounds[base + i];
}

void z05_init_link_speed(void) {
    RAM(0x0000) = 96;
    unsigned char level = RAM(0x0010);
    if (level != 0) {
        RAM(0x03BC) = RAM(0x0000);
        return;
    }
    unsigned char tile = RAM(0x049E);
    if (tile == 0x74 || tile == 0x75) {
        RAM(0x0000) = 48;
        if (RAM(0x03BC) != 48)
            RAM(0x03A8) = 0;
    }
    RAM(0x03BC) = RAM(0x0000);
}

void z05_update_mode7_scroll_sub2(void) {
    RAM(0x0013)++;
    unsigned char frame = (unsigned char)(RAM(0x0015) + 1);
    frame &= 0x03;
    if (RAM(0x0010) == 0)
        frame &= 0x01;
    RAM(0x00E6) = frame;
}

void z05_update_mode7_scroll_sub7(void) {
    RAM(0x0013) = 1;
    RAM(0x0011) = 0;
    RAM(0x010C) = 0;
    RAM(0x00E7) = 0;
    RAM(0x00E3) = 0;
    RAM(0x0012) = 4;
}

void z05_fetch_tile_map_addr(void) {
    RAM(0x00) = 48;
    RAM(0x01) = 101;
}

void z05_copy_play_area_attrs_half(unsigned int ppu_hi, unsigned int ppu_lo, unsigned int end_off) {
    RAM(0x0302) = ppu_hi;
    RAM(0x0303) = ppu_lo;
    RAM(0x0304) = 24;
    RAM(0x0305 + 24) = 0xFF;
    unsigned char src = end_off;
    for (unsigned char dst = 24; dst > 0; dst--) {
        RAM(0x0304 + dst) = RAM(0x0530 + src);
        src--;
    }
}

void z05_inc_submode(void) {
    RAM(0x0013)++;
}

void z05_inc_2_submodes(void) {
    RAM(0x0013)++;
    RAM(0x0013)++;
}

void z05_init_mode4_go_to_sub0(void) {
    RAM(0x0013) = 0;
    RAM(0x051F) = 0;
}

void z05_trigger_open_door(unsigned int val) {
    RAM(0x0055) = (unsigned char)val;
    RAM(0x0054) = 6;
}

void z05_update_mode11_death_sub6(void) {
    RAM(0x00FF) = RAM(0x00FF) & 0xFE;
    z05_inc_submode();
}

void z05_reset_vscroll_lo(void) {
    RAM(0x00E2) = 0;
    z05_inc_submode();
}

void z05_select_transfer_buf(unsigned int val) {
    RAM(0x0014) = (unsigned char)val;
    z05_inc_submode();
}

void z05_touch_door_wall(void) {
    RAM(0x000E) = 0xFF;
}

void z05_select_transfer_buf_and_inc_state(unsigned int val) {
    RAM(0x0014) = (unsigned char)val;
    RAM(0x00E1)++;
}

void z05_block_at_wall(void) {
    RAM(0x000E) = 0xFF;
}

void z05_get_player_coords_for_direction(unsigned int dir) {
    unsigned char x = RAM(0x0070);
    unsigned char y = RAM(0x0084);
    if ((unsigned char)dir & 0x03) {
        RAM(0x0000) = y;
        RAM(0x0001) = x;
    } else {
        RAM(0x0000) = x;
        RAM(0x0001) = y;
    }
}

/* --- Carry-flag returning functions --- */

extern void z05_copy_row_to_tilebuf(void);

unsigned int z05_copy_next_row_to_transfer_buf(void) {
    z05_copy_row_to_tilebuf();
    RAM(0x00E9)++;
    unsigned char row = RAM(0x00E9);
    unsigned int result = row;
    if (row < 0x16)
        result |= CARRY_SET;
    return result;
}

unsigned int z05_copy_next_row_advance_submode(void) {
    unsigned int result = z05_copy_next_row_to_transfer_buf();
    if (!(result & CARRY_SET)) {
        RAM(0x0013)++;
    }
    return result;
}

extern unsigned char z01_abs(unsigned int val);

unsigned int z05_is_distance_safe_to_spawn(unsigned int slot) {
    unsigned char link_x = RAM(0x0070);
    unsigned char obj_x = RAM(0x0070 + slot);
    unsigned char dx = z01_abs((unsigned char)(link_x - obj_x));
    if (dx < 0x22) {
        unsigned char link_y = RAM(0x0084);
        unsigned char obj_y = RAM(0x0084 + slot);
        unsigned char dy = z01_abs((unsigned char)(link_y - obj_y));
        if (dy < 0x22)
            return CARRY_SET;
    }
    return 0;
}

void z05_set_fade_cycle_and_advance_submode(unsigned int val) {
    RAM(0x051C) = (unsigned char)val;
    RAM(0x0013)++;
}

void z05_set_moving_dir_and_switch_to_player_slot(unsigned int dir) {
    RAM(0x000F) = (unsigned char)dir;
    /* Shim must also set D2=0 (switch to player slot) */
}

extern unsigned int z01_get_opposite_dir(unsigned int dir);

void z05_link_modify_dir_in_doorway(void) {
    if (RAM(0x0053) == 0) return;
    unsigned char input_dir = RAM(0x03F8);
    if (input_dir == 0) return;
    unsigned char facing = RAM(0x0098);
    if (facing & input_dir) {
        RAM(0x03F8) = facing;
        return;
    }
    unsigned char opp = (unsigned char)z01_get_opposite_dir(facing);
    if (opp & input_dir) {
        RAM(0x03F8) = opp;
        return;
    }
    RAM(0x03F8) = facing;
}

extern unsigned char z07_end_game_mode(void);

void z05_update_mode11_death_sub_c(void) {
    if (RAM(0x0033) != 0) return;
    z07_end_game_mode();
    RAM(0x0012) = 8;
    RAM(0x0602) = 64;
    unsigned char slot = RAM(0x0016);
    unsigned char continue_count = RAM(0x0630 + slot);
    if (continue_count != 0xFF)
        RAM(0x0630 + slot) = continue_count + 1;
}

void z05_update_mode7_scroll_sub6(void) {
    if (RAM(0x0010) == 0) {
        z05_update_mode7_scroll_sub7();
        return;
    }
    unsigned char room = RAM(0x00EB);
    unsigned char dark = z05_is_dark_room(room);
    if (dark == 0) {
        z05_update_mode7_scroll_sub7();
        return;
    }
    RAM(0x00E9) = 0;
    RAM(0x0013)++;
}

extern unsigned char z07_get_collidable_tile_still(unsigned int slot);
extern unsigned char z01_compare_hearts_to_containers(void);
extern unsigned char z01_reset_room_tile_obj_info(void);

void z05_cue_transfer_play_area_attrs_half_and_advance_submode(
        unsigned int ppu_hi, unsigned int ppu_lo, unsigned int end_off) {
    z05_copy_play_area_attrs_half(ppu_hi, ppu_lo, end_off);
    RAM(0x0013)++;
}

void z05_update_mode11_death_sub2(void) {
    unsigned int result = z05_copy_next_row_advance_submode();
    if (result & CARRY_SET) {
        z05_write_and_enable_sprite0();
    }
    unsigned char val = RAM(0x0302);
    val = (unsigned char)(val + 0x08);
    RAM(0x0302) = val;
}

void z05_init_mode10(void) {
    z07_get_collidable_tile_still(0);
    if (RAM(0x049E) != 0x24)
        goto done;
    RAM(0x0619) = 0;
    RAM(0x0603) = 8;
    unsigned char y = (unsigned char)(RAM(0x0084) + 0x10);
    RAM(0x0412) = y;
done:
    RAM(0x0011)++;
}

void z05_setup_tile_object_ow(void) {
    unsigned char room = RAM(0x00EB);
    unsigned char type;
    if (room == 0x3F || room == 0x55) {
        type = 97;
    } else {
        RAM(0x007B) = RAM(0x052C);
        RAM(0x008F) = RAM(0x052D);
        type = RAM(0x052B);
    }
    RAM(0x035A) = type;
    z01_reset_room_tile_obj_info();
    RAM(0x00B7) = 0;
}

void z05_world_fill_hearts(void) {
    if (RAM(0x0063) == 0)
        return;
    RAM(0x0604) = 16;
    unsigned char partial = RAM(0x0670);
    if (partial >= 0xF8) {
        RAM(0x0670) = 0;
        unsigned char containers = z01_compare_hearts_to_containers();
        unsigned char filled = RAM(0x0000);
        if (containers == filled) {
            RAM(0x0670)--;
            RAM(0x052E) = 0;
            RAM(0x0063) = 0;
            RAM(0x00E0) = 0;
            return;
        }
        RAM(0x066F)++;
        return;
    }
    RAM(0x0670) = (unsigned char)(partial + 0x06);
}

