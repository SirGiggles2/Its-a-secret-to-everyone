/* z_01.c — C port of z_01 leaf functions.
 * Data tables and remaining code stay in z_01.asm.
 */

#include "../nes_abi.h"

extern void z07_set_shove_info_with0(unsigned int val, unsigned int slot);

void z01_play_character_sfx(void) {
    RAM(0x0602) = 8;
}

unsigned char z01_reset_room_tile_obj_info(void) {
    RAM(0x052B) = 0;
    RAM(0x052C) = 0;
    RAM(0x052D) = 0;
    return 0;
}

void z01_play_key_taken_tune(void) {
    RAM(0x0602) = 0;
    RAM(0x0604) = 8;
}

void z01_take_power_triforce(void) {
    RAM(0x0509)++;
    RAM(0x0028) = 0xC0;
    RAM(0x00AC) = 64;
}

unsigned char z01_silence_all_sound(void) {
    RAM(0x0604) = 0x80;
    RAM(0x0603) = 0x80;
    RAM(0x0605) = 0;
    RAM(0x0607) = 0;
    return 0;
}

void z01_post_debit(unsigned int amount) {
    RAM(0x067E) = (unsigned char)(RAM(0x067E) + amount);
}

void z01_init_one_simple_object(unsigned int slot) {
    RAM(0x034F + slot) = RAM(0x00);
    RAM(0x0492 + slot) = 0;
    RAM(0x04BF + slot) = RAM(0x01);
}

void z01_destroy_object_wram(unsigned int val, unsigned int slot) {
    RAM(0x00C0 + slot) = val;
    RAM(0x00D3 + slot) = val;
    RAM(0x0028 + slot) = val;
    RAM(0x00AC + slot) = val;
    RAM(0x04F0 + slot) = val;
    RAM(0x0492 + slot) = 0xFF;
    RAM(0x0405 + slot) = 1;
}

void z01_destroy_whirlwind(unsigned int slot) {
    RAM(0x034F + slot) = 0;
    RAM(0x00C0 + slot) = 0;
    RAM(0x00D3 + slot) = 0;
    RAM(0x0028 + slot) = 0;
    RAM(0x00AC + slot) = 0;
    RAM(0x04F0 + slot) = 0;
    RAM(0x0492 + slot) = 0xFF;
    RAM(0x0405 + slot) = 1;
}

void z01_unhalt_link(void) {
    RAM(0x00AC) = 0;
}

void z01_inc_cave_state(void) {
    RAM(0x00AD)++;
}

void z01_set_up_whirlwind(unsigned int slot) {
    RAM(0x0084 + slot) = RAM(0x0084);
    RAM(0x0070 + slot) = 0;
    RAM(0x034F + slot) = 46;
}

void z01_uw_person_complex_state_delay_and_quit(void) {
    unsigned char timer = RAM(0x0029);
    if (timer == 0)
        RAM(0x0350) = 0;
}

void z01_set_boomerang_speed(unsigned int val, unsigned int slot) {
    RAM(0x03BC + slot) = val;
    unsigned char state = RAM(0x00AC + slot) & 0xF0;
    if (state == 0x40) {
        unsigned char spd = RAM(0x03BC + slot);
        RAM(0x03BC + slot) = spd >> 1;
        RAM(0x0380 + slot)--;
        if (RAM(0x0380 + slot) == 0)
            RAM(0x00AC + slot) = 80;
    }
}

void z01_set_up_common_cave_objects(unsigned int x, unsigned int slot, unsigned int y) {
    RAM(0x0070 + slot) = x;
    RAM(0x0084 + slot) = y;
    RAM(0x0485 + slot) = 0;
    RAM(0x04BF + slot) = 0x81;
    RAM(0x00AC) = 64;
    RAM(0x0351) = 64;
    RAM(0x0352) = 64;
    RAM(0x0071 + slot) = 72;
    RAM(0x0072 + slot) = 0xA8;
    RAM(0x0085 + slot) = y;
    RAM(0x0086 + slot) = y;
}

unsigned char z01_anim_set_sprite_desc_attrs(unsigned int val) {
    RAM(0x0004) = (unsigned char)val;
    RAM(0x0005) = (unsigned char)val;
    return (unsigned char)val;
}

void z01_post_credit(unsigned int val) {
    RAM(0x067D) = (unsigned char)(RAM(0x067D) + val);
}

unsigned char z01_add_to_int16_at_0(unsigned int val) {
    unsigned int sum = (unsigned char)val + RAM(0x0000);
    RAM(0x0000) = (unsigned char)sum;
    if (sum > 0xFF)
        RAM(0x0001)++;
    return (unsigned char)sum;
}

unsigned char z01_add_to_int16_at_2(unsigned int val) {
    unsigned int sum = (unsigned char)val + RAM(0x0002);
    RAM(0x0002) = (unsigned char)sum;
    if (sum > 0xFF)
        RAM(0x0003)++;
    return (unsigned char)sum;
}

unsigned char z01_add_to_int16_at_4(unsigned int val) {
    unsigned int sum = (unsigned char)val + RAM(0x0004);
    RAM(0x0004) = (unsigned char)sum;
    if (sum > 0xFF)
        RAM(0x0005)++;
    return (unsigned char)sum;
}

void z01_map_screen_pos_to_ppu_addr(void) {
    unsigned char y = RAM(0x0002);
    unsigned char x = RAM(0x0003);
    RAM(0x0000) = 0x20 | (y >> 6);
    RAM(0x0001) = ((y << 2) & 0xE0) | (x >> 3);
}

void z01_reset_shove_info_and_inv_timer(unsigned int slot) {
    z07_set_shove_info_with0(0, slot);
    RAM(0x04F0 + slot) = 0;
}

void z01_update_person_state_reset_char_offset(void) {
    RAM(0x0416) = 0;
    RAM(0x00AD)++;
}

void z01_begin_update_mode(void) {
    RAM(0x0013) = 0;
    RAM(0x0011)++;
}

void z01_cue_transfer_buf_and_advance_state(unsigned int val) {
    RAM(0x0014) = (unsigned char)val;
    z01_inc_cave_state();
}

void z01_take_one_rupee(void) {
    RAM(0x0602) = 1;
    RAM(0x067D)++;
}

void z01_set_item_value(unsigned int val, unsigned int slot3) {
    RAM(0x0657 + slot3) = (unsigned char)val;
}

void z01_init_whirlwind(unsigned int val, unsigned int slot) {
    RAM(0x0084) = (unsigned char)val;
    z01_set_up_whirlwind(slot);
}

unsigned char z01_add1_to_int16_at_2(void) {
    return z01_add_to_int16_at_2(1);
}

unsigned char z01_add1_to_int16_at_4(void) {
    return z01_add_to_int16_at_4(1);
}

void z01_cue_transfer_blank_person_wares(void) {
    z01_cue_transfer_buf_and_advance_state(42);
}

void z01_take_5_rupees(void) {
    for (signed char i = 4; i >= 0; i--)
        z01_take_one_rupee();
}

unsigned int z01_get_opposite_dir(unsigned int dir) {
    static const unsigned char opposite_dirs[] = {0x04, 0x08, 0x01, 0x02};
    unsigned char d = (unsigned char)dir;
    signed char idx = 3;
    while (idx >= 0) {
        if (d & 1) break;
        d >>= 1;
        idx--;
    }
    if (idx < 0) idx = 0;
    unsigned char result = opposite_dirs[idx];
    return ((unsigned int)(unsigned char)idx << 8) | result;
}

unsigned char z01_abs(unsigned int val) {
    unsigned char v = (unsigned char)val;
    if (v & 0x80)
        return (~v + 1) & 0xFF;
    return v;
}

unsigned char z01_negate(unsigned int val) {
    unsigned char v = (unsigned char)val;
    return (~v + 1) & 0xFF;
}

extern unsigned char z07_get_room_flags(void);

void z01_set_room_flag_uw_item_state(void) {
    unsigned char flags = z07_get_room_flags();
    flags |= 0x10;
    unsigned short ptr = ((unsigned short)RAM(0x01) << 8) | RAM(0x00);
    unsigned char room_id = RAM(0x00EB);
    nes_ram[ptr + room_id] = flags;
}

unsigned char z01_get_room_flag_uw_item_state(void) {
    unsigned char ptr_lo = nes_ram[0x6000u + 0x0BAF];
    unsigned char ptr_hi = nes_ram[0x6000u + 0x0BB0];
    RAM(0x08) = ptr_lo;
    RAM(0x09) = ptr_hi;
    unsigned short ptr = ((unsigned short)ptr_hi << 8) | ptr_lo;
    unsigned char room_id = RAM(0x00EB);
    return nes_ram[ptr + room_id] & 0x10;
}

void z01_play_effect(unsigned int val) {
    RAM(0x0603) |= (unsigned char)val;
}

void z01_play_sample(unsigned int val) {
    RAM(0x0601) |= (unsigned char)val;
}

void z01_play_parry_tune(void) {
    RAM(0x0604) = 1;
}

void z01_write_blank_priority_sprites(void) {
    static const unsigned char tmpl[] = {0x3D, 0x1C, 0x20, 0x00, 0xDD, 0x1C, 0x20, 0x00};
    for (unsigned char i = 0; i < 0x40; i++)
        RAM(0x0200 + i) = tmpl[i & 7];
}

void z01_init_underworld_person_b(unsigned int slot) {
    static const unsigned char text_selectors[] = {0x2A, 0x38, 0x3A, 0x2C, 0x40, 0x42, 0x42, 0x3C};
    z01_set_up_common_cave_objects(120, slot, 0x80);
    unsigned char obj_type = RAM(0x034F + slot);
    unsigned char idx = (unsigned char)(obj_type - 0x4B);
    RAM(0x0415) = text_selectors[idx];
    z01_play_character_sfx();
}

void z01_copy_price_list_template(void) {
    static const unsigned char tmpl[] = {
        0x22, 0xC8, 0x0D, 0x21, 0x24, 0x24, 0x24, 0x24,
        0x24, 0x24, 0x24, 0x24, 0x24, 0x24, 0x24, 0x24, 0xFF
    };
    for (signed char i = 16; i >= 0; i--)
        RAM(0x0302 + (unsigned char)i) = tmpl[(unsigned char)i];
}

unsigned char z01_compare_hearts_to_containers(void) {
    unsigned char hearts = RAM(0x066F);
    unsigned char filled = hearts & 0x0F;
    RAM(0x0000) = filled;
    unsigned char containers = hearts >> 4;
    return containers;
}

void z01_uw_person_complex_state_begin(void) {
    unsigned char obj = RAM(0x0350);
    if (obj == 0x4F)
        RAM(0x0014) = 108;
    RAM(0x0029) = 10;
    RAM(0x00AD)++;
}

void z01_format_char_doublet(unsigned int val) {
    RAM(0x0002) = (unsigned char)val;
    RAM(0x0003) = 36;
}

unsigned char z01_reset_cur_sprite_index(void) {
    RAM(0x0341) = 0;
    return 0;
}

void z01_play_boomerang_sfx(unsigned int sfx_id) {
    if (RAM(0x003B) != 0)
        return;
    z01_play_effect(sfx_id);
    RAM(0x003B) = 10;
}

void z01_take_hearts_no_sound(void) {
    RAM(0x0001) = RAM(0x000A);
    for (;;) {
        unsigned char containers = z01_compare_hearts_to_containers();
        unsigned char filled = RAM(0x0000);
        if (containers == filled) {
            unsigned char partial = RAM(0x0670);
            partial++;
            if (partial == 0)
                return;
            RAM(0x0670) = 0xFF;
            return;
        }
        RAM(0x066F)++;
        RAM(0x0001)--;
        if ((signed char)RAM(0x0001) < 0)
            return;
    }
}

unsigned char z01_do_objects_collide_with_thresholds(void) {
    RAM(0x0006) = 0;
    unsigned char dx = (unsigned char)(RAM(0x0002) - RAM(0x0004));
    unsigned char abs_dx = z01_abs(dx);
    RAM(0x000A) = abs_dx;
    if (abs_dx >= RAM(0x000D))
        return RAM(0x0006);
    unsigned char dy = (unsigned char)(RAM(0x0003) - RAM(0x0005));
    unsigned char abs_dy = z01_abs(dy);
    RAM(0x000B) = abs_dy;
    if (abs_dy >= RAM(0x000E))
        return RAM(0x0006);
    RAM(0x0006)++;
    return RAM(0x0006);
}

extern void z07_destroy_monster(unsigned int slot);
extern const unsigned char UnderworldPersonTextSelectorsC[];

void z01_init_underworld_person_c(unsigned int slot) {
    z01_set_up_common_cave_objects(120, slot, 0x80);
    z01_play_character_sfx();
    unsigned char obj_type = RAM(0x034F + slot);
    unsigned char idx = (unsigned char)(obj_type - 0x4B);
    RAM(0x0415) = UnderworldPersonTextSelectorsC[idx];
    if (obj_type != 0x4B)
        return;
    if (RAM(0x0671) != 0xFF)
        return;
    RAM(0x04CE) = 1;
    RAM(0x00AC) = 0;
    z07_destroy_monster(slot);
}

extern const unsigned char TextboxLineAddrsLo[];

void z01_init_grumble_full(unsigned int slot) {
    z01_set_up_common_cave_objects(120, slot, 0x80);
    RAM(0x0415) = 36;
    RAM(0x045F) = TextboxLineAddrsLo[2];
    unsigned char item_state = z01_get_room_flag_uw_item_state();
    if (item_state == 0) {
        z01_play_character_sfx();
        return;
    }
    RAM(0x00AC) = 0;
    RAM(0x0350) = 0;
}

extern const unsigned char RupeeStashXs[];
extern const unsigned char RupeeStashYs[];

void z01_init_rupee_stash_full(unsigned int slot) {
    RAM(0x0001) = RAM(0x04BF + slot);
    RAM(0x0000) = 53;
    for (unsigned char i = 10; i >= 1; i--) {
        z01_init_one_simple_object(i);
        RAM(0x0070 + i) = RupeeStashXs[i - 1];
        RAM(0x0084 + i) = RupeeStashYs[i - 1];
    }
}
