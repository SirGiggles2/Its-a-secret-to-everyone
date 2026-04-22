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

extern void z07_reset_moving_dir(void);

void z01_update_uw_person_life_or_money_state_0(void) {
    RAM(0x0029) = 10;
    z01_cue_transfer_buf_and_advance_state(118);
}

void z01_underworld_person_destroy_if_taken(unsigned int slot) {
    unsigned char item_state = z01_get_room_flag_uw_item_state();
    if (item_state == 0) {
        z01_play_character_sfx();
        return;
    }
    RAM(0x00AC) = 0;
    z07_destroy_monster(slot);
}

void z01_init_uw_person_life_or_money_full(unsigned int slot) {
    z01_set_up_common_cave_objects(120, slot, 0x80);
    RAM(0x0415) = 54;
    RAM(0x045F) = TextboxLineAddrsLo[2];
    z01_underworld_person_destroy_if_taken(slot);
}

void z01_person_flag_item_taken_and_advance_state(void) {
    z01_set_room_flag_uw_item_state();
    RAM(0x0029) = 64;
    z01_cue_transfer_buf_and_advance_state(30);
}

void z01_check_person_blocking(void) {
    if (RAM(0x0084) >= 0x8E)
        return;
    if ((RAM(0x000F) & 0x08) == 0)
        return;
    z07_reset_moving_dir();
}

void z01_clear_prices_cave_flag(void) {
    RAM(0x0413) = RAM(0x0413) & 0xF7;
}

void z01_update_person_state_delay_then_hide(void) {
    if (RAM(0x0029) == 0)
        RAM(0x0350) = 0;
}

/* --- batch 40 --- */

void z01_update_person_state_do_nothing(void) {
}

void z01_update_cave_person_state_do_nothing(void) {
}

void z01_init_underworld_person_do_nothing(void) {
}

void z01_update_grumble1(void) {
    unsigned char val = RAM(0x00AC + 15);
    if ((val & 0x80) == 0)
        return;
    RAM(0x00AC) = 64;
    RAM(0x0602) = 4;
    z01_person_flag_item_taken_and_advance_state();
}

/* --- batch 43 --- */

unsigned char z01_add1_to_int16_at_0(void) {
    return z01_add_to_int16_at_0(1);
}

/* --- batch 49 --- */

extern void z01_play_key_taken_tune(void);
extern void z01_take_hearts_no_sound(void);

void z01_take_hearts(void) {
    z01_play_key_taken_tune();
    z01_take_hearts_no_sound();
}

/* --- batch 53 --- */

extern const unsigned char TeleportYs[];

void z01_check_init_whirlwind_and_begin_update(void) {
    if (RAM(0x0522) != 0) {
        RAM(0x0522)++;
        RAM(0x00AC) = 64;
        unsigned char y = TeleportYs[RAM(0x0523) & 7];
        z01_init_whirlwind((unsigned int)y, 9);
    }
    z01_begin_update_mode();
}

/* --- batch 55 --- */

extern const unsigned char PaletteRow7TransferRecord[];
extern const unsigned char GanonColorTriples[];

void z01_advance_teleporting_level_index(void) {
    RAM(0x0523)++;
    if ((RAM(0x0098) & 0x09) == 0)
        RAM(0x0523) -= 2;
}

static void replace_palette_row_common(unsigned char color_index)
{
    unsigned char len = RAM(0x0301);
    for (unsigned char i = 0; i < 8; i++)
        RAM(0x0302 + len++) = PaletteRow7TransferRecord[i];
    RAM(0x0301) = len;
    for (int j = 0; j < 3; j++)
        RAM(0x0306 + j) = GanonColorTriples[color_index - 2 + j];
}

void z01_replace_ganon_brown_palette_row(void) { replace_palette_row_common(2); }
void z01_replace_ganon_blue_palette_row(void) { replace_palette_row_common(5); }
void z01_replace_ashes_palette_row(void) { replace_palette_row_common(8); }

/* --- batch 56 --- */

extern const unsigned char UnderworldPersonTextSelectorsA[];
extern const unsigned char LifeOrMoneyItemXs[];

void z01_init_underworld_person_a(unsigned int slot) {
    z01_set_up_common_cave_objects(120, slot, 0x80);
    unsigned char idx = (unsigned char)(RAM(0x034F + slot) - 0x4B);
    RAM(0x0415) = UnderworldPersonTextSelectorsA[idx];
    if (RAM(0x0350) == 0x4F) {
        z01_underworld_person_destroy_if_taken(slot);
        return;
    }
    z01_play_character_sfx();
}

void z01_update_uw_person_complex_state_sense_link(void) {
    if (RAM(0x0350) != 0x4F) return;
    if (RAM(0x0070) != 0x78) return;
    unsigned char ydiff = (unsigned char)(RAM(0x0084) - 0x98);
    if (z01_abs((unsigned int)ydiff) >= 6) return;
    if (RAM(0x066D) < 100) return;
    RAM(0x067E) = (unsigned char)(100 + RAM(0x067E));
    RAM(0x0604) = 8;
    unsigned char max_bombs = (unsigned char)(RAM(0x067C) + 4);
    RAM(0x067C) = max_bombs;
    RAM(0x0658) = max_bombs;
    z01_person_flag_item_taken_and_advance_state();
}

void z01_update_uw_person_life_or_money_state_2(void) {
    for (int i = 1; i >= 0; i--) {
        if (RAM(0x0070) != LifeOrMoneyItemXs[i])
            continue;
        unsigned char ydiff = (unsigned char)(RAM(0x0084) - 0x98);
        if (z01_abs((unsigned int)ydiff) >= 6)
            continue;
        if (i != 0) {
            if (RAM(0x066D) < 50) return;
            RAM(0x067E) = (unsigned char)(50 + RAM(0x067E));
        } else {
            unsigned char hearts = RAM(0x066F);
            unsigned char containers = hearts & 0xF0;
            if (containers >= 0x30) {
                unsigned char new_cont = (unsigned char)(containers - 0x10);
                RAM(0x0000) = new_cont;
                int partial = (int)(hearts & 0x0F) - 1;
                if (partial < 0) partial = 0;
                RAM(0x066F) = new_cont | (unsigned char)partial;
            } else {
                RAM(0x066F) = containers;
                RAM(0x0670) = 0;
            }
        }
        RAM(0x0604) = 8;
        RAM(0x04CE) = 1;
        z01_person_flag_item_taken_and_advance_state();
        return;
    }
}

/* --- batch 57 --- */

extern unsigned char z07_anim_fetch_obj_pos(unsigned int slot);
extern void c_check_monster_collisions(unsigned int slot);
extern void c_animate_item_object(unsigned char item_type, unsigned int slot);
extern void c_draw_object_mirrored(unsigned int slot);
extern void c_draw_object_not_mirrored(unsigned int slot);
extern void c_link_end_move_and_animate_bank1(void);
extern void c_update_person_state_textbox(void);
extern const unsigned char LifeOrMoneyItemTypes[];

void z01_person_check_collisions(unsigned int slot) {
    c_check_monster_collisions(slot);
    unsigned char killed = RAM(0x0406);
    if (killed) {
        RAM(0x04CC) = killed;
        RAM(0x0406) = 0;
    }
}

static void person_draw_and_check_collisions(unsigned int slot) {
    z01_person_check_collisions(slot);
    z07_anim_fetch_obj_pos(slot);
    c_draw_object_mirrored(slot);
}

void z01_person_draw_and_check_collisions(unsigned int slot) {
    person_draw_and_check_collisions(slot);
}

void z01_draw_life_or_money_items(void) {
    for (int i = 1; i >= 0; i--) {
        RAM(0x0083) = LifeOrMoneyItemXs[i];
        RAM(0x0097) = 0x98;
        c_animate_item_object(LifeOrMoneyItemTypes[i], 19);
    }
}

void z01_update_grumble3(void) {
    c_link_end_move_and_animate_bank1();
    if (RAM(0x0029) != 0) {
        z01_init_underworld_person_do_nothing();
        return;
    }
    RAM(0x00AC + 15) = 0;
    RAM(0x065D) = 0;
    RAM(0x00AC) = 0;
    RAM(0x0350) = 0;
    z01_init_underworld_person_do_nothing();
}

void z01_update_uw_person_complex(unsigned int slot) {
    unsigned char state = RAM(0x00AD);
    if (state != 4 || (RAM(0x0015) & 1) == 0) {
        person_draw_and_check_collisions(slot);
        if (RAM(0x0350) == 0x4F) {
            RAM(0x0083) = 120;
            RAM(0x0097) = 0x98;
            c_animate_item_object(24, 19);
        }
    }
    state = RAM(0x00AD);
    switch (state) {
        case 0: z01_uw_person_complex_state_begin(); break;
        case 1: c_update_person_state_textbox(); break;
        case 2: z01_update_uw_person_complex_state_sense_link(); break;
        case 3: z01_cue_transfer_blank_person_wares(); break;
        case 4: z01_uw_person_complex_state_delay_and_quit(); break;
    }
}

void z01_update_uw_person_full(unsigned int slot) {
    unsigned char level = RAM(0x0010);
    if ((unsigned char)level < 3 || level == 5 || level == 7) {
        z01_update_uw_person_complex(slot);
        return;
    }
    person_draw_and_check_collisions(slot);
    switch (RAM(0x00AD)) {
        case 0: z01_update_person_state_reset_char_offset(); break;
        case 1: c_update_person_state_textbox(); break;
        case 2: z01_update_person_state_do_nothing(); break;
    }
}

void z01_update_grumble_full(unsigned int slot) {
    unsigned char state = RAM(0x00AD);
    if (state != 3 || (RAM(0x0015) & 1) == 0) {
        z01_person_check_collisions(slot);
        z07_anim_fetch_obj_pos(slot);
        c_draw_object_not_mirrored(slot);
    }
    state = RAM(0x00AD);
    switch (state) {
        case 0: c_update_person_state_textbox(); break;
        case 1: z01_update_grumble1(); break;
        case 2: z01_cue_transfer_blank_person_wares(); break;
        case 3: z01_update_grumble3(); break;
    }
}

void z01_update_uw_person_life_or_money_full(unsigned int slot) {
    unsigned char state = RAM(0x00AD);
    if (state != 4 || (RAM(0x0015) & 1) == 0) {
        person_draw_and_check_collisions(slot);
        z01_draw_life_or_money_items();
    }
    state = RAM(0x00AD);
    switch (state) {
        case 0: z01_update_uw_person_life_or_money_state_0(); break;
        case 1: c_update_person_state_textbox(); break;
        case 2: z01_update_uw_person_life_or_money_state_2(); break;
        case 3: z01_cue_transfer_blank_person_wares(); break;
        case 4: z01_uw_person_complex_state_delay_and_quit(); break;
    }
}

/* --- batch 58 --- */

extern void c_link_end_move_and_draw_bank1(void);
extern const unsigned char CaveWareXs[];
extern const unsigned char PersonTextAddrs[];
extern const unsigned char TextboxCharTransferRecTemplate[];
extern const unsigned char TextboxLineAddrsLo[];

static void draw_cave_person(unsigned int slot) {
    z07_anim_fetch_obj_pos(slot);
    if ((unsigned char)RAM(0x0350) < 0x7B)
        c_draw_object_mirrored(slot);
    else
        c_draw_object_not_mirrored(slot);
}

void z01_draw_cave_person(unsigned int slot) {
    draw_cave_person(slot);
}

void z01_draw_cave_items(void) {
    if (RAM(0x0413) & 4) {
        RAM(0x0421) = 2;
        do {
            unsigned char i = RAM(0x0421);
            RAM(0x0083) = CaveWareXs[i];
            RAM(0x0097) = 0x98;
            unsigned char item = RAM(0x0422 + i) & 0x3F;
            if (item != 0x3F)
                c_animate_item_object(item, 19);
            RAM(0x0421)--;
        } while ((signed char)RAM(0x0421) >= 0);
    }
    if (RAM(0x0413) & 8) {
        RAM(0x0083) = 48;
        RAM(0x0097) = 0xAB;
        c_animate_item_object(24, 19);
    }
}

static unsigned char swap_space_and_sign(unsigned char d0) {
    if (d0 == 0x24) {
        unsigned char tmp = RAM(0x0004);
        RAM(0x0004) = d0;
        d0 = tmp;
    }
    return d0;
}

void z01_format_decimal_byte(unsigned char val) {
    unsigned char units = val % 10;
    unsigned char rest  = val / 10;
    unsigned char tens  = rest % 10;
    unsigned char hundreds = rest / 10;
    RAM(0x0003) = units;
    if (hundreds == 0) {
        hundreds = 0x24;
        if (tens == 0)
            tens = 0x24;
    }
    RAM(0x0002) = tens;
    RAM(0x0001) = hundreds;
}

void z01_write_prices_to_dynamic_transfer_buf(unsigned char price_char) {
    RAM(0x0305) = price_char;
    RAM(0x042E) = 0;
    RAM(0x042F) = 0;
    unsigned char price_index = 0;
    do {
        unsigned char price = RAM(0x0430 + price_index);
        if (price == 0) {
            RAM(0x0001) = 0x24;
            RAM(0x0002) = 0x24;
            RAM(0x0003) = 0x24;
        } else {
            z01_format_decimal_byte(price);
        }
        unsigned char dash = (RAM(0x0413) & 0x80) ? 98 : 0x24;
        RAM(0x0004) = dash;
        unsigned char off = RAM(0x042F);
        RAM(0x0308 + off) = swap_space_and_sign(RAM(0x0002));
        RAM(0x0307 + off) = swap_space_and_sign(RAM(0x0001));
        RAM(0x0309 + off) = RAM(0x0003);
        RAM(0x042F) = off + 4;
        price_index++;
        RAM(0x042E) = price_index;
    } while (price_index < 3);
    RAM(0x0029) = 10;
    z01_cue_transfer_buf_and_advance_state(10);
}

void z01_write_prices_transfer_buf(void) {
    z01_copy_price_list_template();
    z01_write_prices_to_dynamic_transfer_buf(33);
}

void z01_update_cave_person_state_transfer_prices(void) {
    if (!(RAM(0x0413) & 8)) {
        z01_inc_cave_state();
        return;
    }
    z01_write_prices_transfer_buf();
}

void z01_update_person_state_textbox(void) {
    c_link_end_move_and_draw_bank1();
    if (RAM(0x0029) != 0)
        return;
    RAM(0x0029) = 6;
    for (signed int i = 4; i >= 0; i--)
        RAM(0x0302 + (unsigned char)i) = TextboxCharTransferRecTemplate[(unsigned char)i];
    unsigned char ch;
    unsigned char char_idx;
    unsigned short ptr;
    do {
        RAM(0x0303) = RAM(0x045F);
        RAM(0x045F)++;
        unsigned char sel = RAM(0x0415);
        RAM(0x0000) = PersonTextAddrs[sel];
        RAM(0x0001) = PersonTextAddrs[sel + 1];
        char_idx = RAM(0x0416);
        RAM(0x0416)++;
        ptr = ((unsigned short)RAM(0x0001) << 8) | RAM(0x0000);
        ch = nes_ram[ptr + char_idx] & 0x3F;
    } while (ch == 0x25);
    RAM(0x0305) = ch;
    RAM(0x0604) = 16;
    unsigned char line_flags = nes_ram[ptr + char_idx] & 0xC0;
    if (line_flags == 0)
        return;
    unsigned char line_index;
    if (line_flags == 0xC0)
        line_index = 2;
    else if (line_flags == 0x40)
        line_index = 1;
    else
        line_index = 0;
    RAM(0x045F) = TextboxLineAddrsLo[line_index];
    if (line_index == 2) {
        RAM(0x00AD)++;
        z01_unhalt_link();
    }
}

/* --- batch 59 --- */

extern void c_take_item(unsigned char item_type);
extern const unsigned char HintCaveTextSelectors0[];

static void prepend_sign_to_price(unsigned char val, unsigned char off) {
    unsigned char sign = (val == 0x14 || val == 0x32) ? 100 : 98;
    RAM(0x0306 + off) = sign;
}

void z01_update_cave_person_state_talk_or_shop_or_door_charge(void) {
    if (!(RAM(0x0413) & 1)) {
        RAM(0x00AD) = 8;
        if (RAM(0x0350) == 0x71) {
            RAM(0x067E) += 20;
            z01_set_room_flag_uw_item_state();
        }
        return;
    }
    if (RAM(0x067E) != 0)
        return;
    for (signed int i = 2; i >= 0; i--) {
        unsigned char item = RAM(0x0422 + i) & 0x3F;
        if (item == 0x3F) continue;
        if (RAM(0x0070) != CaveWareXs[i]) continue;
        unsigned char dist = z01_abs((unsigned int)(unsigned char)(RAM(0x0084) - 0x98));
        if (dist >= 6) continue;
        RAM(0x0438) = (unsigned char)i;
        unsigned char flags30 = RAM(0x0413) & 0x30;
        if (flags30) {
            if (!(flags30 & 0x10)) {
                RAM(0x00AD) = 5;
                return;
            }
            if (RAM(0x066D) < RAM(0x0430 + i))
                return;
            z01_post_debit(RAM(0x0430 + i));
            RAM(0x00AD) = 5;
            return;
        }
        if (RAM(0x0413) & 2) {
            if (RAM(0x066D) < RAM(0x0430 + i))
                return;
            z01_post_debit(RAM(0x0430 + i));
        }
        if (RAM(0x0413) & 0x40) {
            unsigned char min_hearts = (RAM(0x0350) == 0x6C) ? 64 : 0xB0;
            if (min_hearts < RAM(0x066F))
                return;
        }
        z01_set_room_flag_uw_item_state();
        unsigned char taken_item = RAM(0x0422 + i) & 0x3F;
        RAM(0x0422 + i) = 0xFF;
        c_take_item(taken_item);
        z01_cue_transfer_buf_and_advance_state(30);
        RAM(0x0029) = 64;
        z01_clear_prices_cave_flag();
        return;
    }
}

void z01_update_cave_person_state_hint_or_money_game(void) {
    if (RAM(0x0413) & 0x10) {
        unsigned char base_off = (RAM(0x0350) == 0x75) ? 0 : 3;
        unsigned char sel_idx = base_off + RAM(0x0438);
        RAM(0x0415) = HintCaveTextSelectors0[sel_idx];
        RAM(0x045F) = TextboxLineAddrsLo[2];
        RAM(0x0416) = 0;
        z01_clear_prices_cave_flag();
        z01_cue_transfer_buf_and_advance_state(30);
        return;
    }
    if ((unsigned char)RAM(0x0350) >= 0x7B) {
        z01_copy_price_list_template();
        z01_write_prices_to_dynamic_transfer_buf(36);
        RAM(0x0604) = 8;
        z01_set_room_flag_uw_item_state();
        RAM(0x00AD) = 8;
        z01_post_credit(RAM(0x0431));
        return;
    }
    if ((unsigned char)RAM(0x066D) < 0x0A)
        return;
    RAM(0x0604) = 8;
    for (signed int j = 2; j >= 0; j--)
        RAM(0x0430 + j) = RAM(0x0448 + j);
    z01_write_prices_transfer_buf();
    RAM(0x00AD) = 8;
    prepend_sign_to_price(RAM(0x0448), 1);
    prepend_sign_to_price(RAM(0x0449), 5);
    prepend_sign_to_price(RAM(0x044A), 9);
    unsigned char chosen = RAM(0x0438);
    unsigned char amount = RAM(0x0448 + chosen);
    if (amount == 0x14 || amount == 0x32)
        z01_post_credit(amount);
    else
        z01_post_debit(amount);
}

void z01_update_cave_person(unsigned int slot) {
    unsigned char state = RAM(0x00AD);
    if (!(state == 4 && (RAM(0x0015) & 1))) {
        draw_cave_person(slot);
        if (RAM(0x0350) == 0x74 && RAM(0x0666) != 2) {
            if (RAM(0x0656) == 0x0F && (RAM(0x00F8) & 0x40)) {
                RAM(0x0602) = 4;
                RAM(0x0666)++;
                RAM(0x0656) = 7;
            } else {
                if (RAM(0x00AC) == 0x40)
                    z01_unhalt_link();
                return;
            }
        }
        z01_draw_cave_items();
    }
    state = RAM(0x00AD);
    switch (state) {
        case 0: z01_update_cave_person_state_transfer_prices(); break;
        case 1: z01_update_person_state_textbox(); break;
        case 2: z01_update_cave_person_state_talk_or_shop_or_door_charge(); break;
        case 3: z01_cue_transfer_blank_person_wares(); break;
        case 4: z01_update_person_state_delay_then_hide(); break;
        case 5: z01_update_cave_person_state_hint_or_money_game(); break;
        case 6: z01_cue_transfer_blank_person_wares(); break;
        case 7: z01_update_person_state_textbox(); break;
        case 8: z01_update_cave_person_state_do_nothing(); break;
    }
}

/* --- batch 60 --- */

extern const unsigned char StatusBarTransferBufTemplate[];
extern void c_format_char_doublet(unsigned char ch);

void z01_format_hearts_in_text_buf(unsigned char start_off) {
    RAM(0x000D) = start_off;
    unsigned char hearts = RAM(0x000E);
    unsigned char full = hearts & 0x0F;
    unsigned char threshold_empty = (unsigned char)(15 - full);
    unsigned char containers = hearts >> 4;
    unsigned char threshold_space = (unsigned char)(15 - containers);
    RAM(0x000B) = start_off + 7;
    unsigned char row_pos = 7;
    for (unsigned char slot = 0; slot < 16; slot++) {
        if (row_pos == 0xFF) {
            RAM(0x000B) = RAM(0x000D) + 0x12;
            row_pos = 18;
        }
        unsigned char tile;
        if (hearts == 0 || slot < threshold_space) {
            tile = 36;
        } else if (slot > threshold_empty) {
            tile = 0xF2;
        } else if (slot < threshold_empty) {
            tile = 102;
        } else { /* slot == threshold_empty */
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

void z01_copy_triplet_to_text_buf(void) {
    unsigned char base_off = RAM(0x0000);
    RAM(0x0302 + base_off)     = RAM(0x0003);
    RAM(0x0302 + base_off - 1) = RAM(0x0002);
    RAM(0x0302 + base_off - 2) = RAM(0x0001);
}

void z01_format_decimal_count_byte(unsigned char val) {
    z01_format_decimal_byte(val);
    unsigned char hundreds = RAM(0x0001);
    if (hundreds == 0x24)
        hundreds = 33;
    RAM(0x0001) = hundreds;
    if (RAM(0x0002) == 0x24)
        c_format_char_doublet(RAM(0x0003));
}

void z01_format_decimal_count_byte_in_text_buf(unsigned char val, unsigned char buf_offset) {
    RAM(0x0000) = buf_offset;
    z01_format_decimal_count_byte(val);
    z01_copy_triplet_to_text_buf();
}

void z01_format_status_bar_text(void) {
    for (unsigned char i = 0; i <= 40; i++)
        RAM(0x0302 + i) = StatusBarTransferBufTemplate[i];
    RAM(0x000E) = RAM(0x066F);
    RAM(0x000F) = RAM(0x0670);
    z01_format_hearts_in_text_buf(3);
    z01_format_decimal_count_byte_in_text_buf(RAM(0x066D), 27);
    if (RAM(0x0664) != 0) {
        RAM(0x0000) = 33;
        RAM(0x0001) = 33;
        c_format_char_doublet(10);
        z01_copy_triplet_to_text_buf();
    } else {
        z01_format_decimal_count_byte_in_text_buf(RAM(0x066E), 33);
    }
    z01_format_decimal_count_byte_in_text_buf(RAM(0x0658), 39);
}

void z01_world_change_rupees(void) {
    if (RAM(0x0014) != 0) return;
    if (!(RAM(0x0302) & 0x80)) return;
    unsigned char rupees = RAM(0x066D);
    if (rupees == 0) {
        RAM(0x0657 + 39) = 0;
    } else {
        if (rupees == 0xFF)
            RAM(0x0657 + 38) = 0;
    }
    if (RAM(0x0015) & 1) return;
    if (RAM(0x067D) != 0) {
        RAM(0x067D)--;
        RAM(0x066D)++;
        RAM(0x0604) = 16;
    }
    if (RAM(0x067E) == 0) {
        z01_format_status_bar_text();
        return;
    }
    RAM(0x067E)--;
    RAM(0x066D)--;
    RAM(0x0604) = 16;
    z01_format_status_bar_text();
}

/* --- batch 61 --- */

#define NES_SRAM_BASE 0x6000u

extern const unsigned char OverworldPersonTextSelectors[];
extern const unsigned char MoneyGameLossAmounts[];
extern const unsigned char MoneyGamePermutations[];
extern const unsigned char MoneyGamePermutationEndIndexes[];

static void init_cave_continue(void);

void z01_init_cave(unsigned int slot) {
    z01_set_up_common_cave_objects(120, slot, 0x80);
    unsigned char room_type = RAM(0x0350);
    if (room_type == 0x72 || room_type == 0x71 || room_type >= 0x7B || room_type < 0x6E) {
        if (z01_get_room_flag_uw_item_state() != 0) {
            RAM(0x0350) = 0;
            z01_unhalt_link();
            return;
        }
    }
    init_cave_continue();
}

static void init_cave_continue(void) {
    unsigned char cave_idx = (unsigned char)(RAM(0x0350) - 0x6A);
    unsigned char sel_byte = OverworldPersonTextSelectors[cave_idx];
    RAM(0x0415) = sel_byte & 0x3F;
    RAM(0x0003) = sel_byte & 0xC0;
    unsigned char ware_off = (unsigned char)(3 * cave_idx);
    for (unsigned char i = 0; i < 3; i++) {
        unsigned char item = nes_ram[NES_SRAM_BASE + 0x0A7E + ware_off + i];
        RAM(0x0422 + i) = item;
        RAM(i) = item & 0xC0;
        RAM(0x0430 + i) = nes_ram[NES_SRAM_BASE + 0x0ABA + ware_off + i];
    }
    unsigned char cave_flags = (unsigned char)(RAM(0x0003) >> 6)
                             | RAM(0x0000)
                             | (unsigned char)(RAM(0x0002) >> 4)
                             | (unsigned char)(RAM(0x0001) >> 2);
    RAM(0x0413) = cave_flags;
    if (cave_flags & 0x20) {
        unsigned char thresh = 0xFF;
        unsigned char perm_idx = 6;
        while (thresh >= RAM(0x0019)) {
            thresh = (unsigned char)(thresh - 0x2B);
            perm_idx--;
            if (perm_idx == 0) break;
        }
        unsigned char end_idx = MoneyGamePermutationEndIndexes[perm_idx];
        RAM(0x046E) = MoneyGamePermutations[end_idx];
        RAM(0x046D) = MoneyGamePermutations[(unsigned char)(end_idx - 1)];
        RAM(0x046C) = MoneyGamePermutations[(unsigned char)(end_idx - 2)];
        RAM(0x046F) = MoneyGameLossAmounts[RAM(0x001A) & 1];
        RAM(0x0470) = 10;
        RAM(0x0471) = (RAM(0x001A) & 2) ? 50 : 20;
        for (signed int j = 2; j >= 0; j--) {
            unsigned char perm = RAM(0x046C + (unsigned char)j);
            RAM(0x0448 + (unsigned char)j) = RAM(0x046F + perm);
        }
    }
    RAM(0x0416) = 0;
    RAM(0x045F) = TextboxLineAddrsLo[2];
}

void z01_try_take_item(unsigned int slot) {
    if (RAM(0x03A8 + slot) >= 0xF0) return;
    unsigned char dy = (unsigned char)(RAM(0x0084) + 3 - RAM(0x0084 + slot));
    if (z01_abs(dy) >= 9) return;
    unsigned char dx = (unsigned char)(RAM(0x0070) - RAM(0x0070 + slot));
    if (z01_abs(dx) >= 9) return;
    RAM(0x00AC + slot) = 0xFF;
    RAM(0x0084 + slot) = 0xFF;
    if (slot == 19) z01_set_room_flag_uw_item_state();
    z01_take_item(RAM(0x0004));
}

void z01_try_take_room_item(void) {
    if ((RAM(0x00AC) & 0xC0) == 0x40) return;
    if (z01_get_room_flag_uw_item_state() != 0) return;
    unsigned int slot = 19;
    if (RAM(0x00AC + slot) & 0x80) return;
    RAM(0x0004) = RAM(0x0098 + slot);
    z01_try_take_item(slot);
}

/* --- batch 62 --- */

extern const unsigned char LevelMasks[];
extern const unsigned char LinkColors_CommonCode[];
extern const unsigned char SaveSlotToPaletteRowOffset[];
extern unsigned char MenuPalettesTransferBuf[];
extern const unsigned char ItemIdToSlot[];
extern const unsigned char ItemIdToDescriptor[];

extern void z07_patch_and_cue_level_palettes_transfer(void);

static void take_class0_complex(unsigned char item_id, unsigned char item_slot) {
    unsigned char level_raw = RAM(0x0010);
    if (level_raw == 0) return;
    if (item_slot == 0x1B) { z01_take_power_triforce(); return; }
    if (item_slot == 0x11) RAM(0x04E5) = 1;
    unsigned char level = (unsigned char)(level_raw - 1);
    if (level >= 8) {
        item_slot = (unsigned char)(item_slot + 2);
        level &= 7;
    } else {
        level &= 7;
    }
    RAM(0x0657 + item_slot) |= LevelMasks[level];
    if (item_slot != 0x1A) return;
    z07_end_game_mode();
    RAM(0x0012) = 18;
}

static void handle_class2(unsigned char item_slot) {
    unsigned char val = RAM(0x000A);
    if (val < RAM(0x0657 + item_slot)) return;
    RAM(0x0657 + item_slot) = val;
    if (item_slot != 0x0B) return;
    unsigned char ring_val = RAM(0x0662);
    unsigned char color = LinkColors_CommonCode[ring_val];
    unsigned char save_slot = RAM(0x0016);
    unsigned char palette_off = SaveSlotToPaletteRowOffset[save_slot];
    MenuPalettesTransferBuf[20 + palette_off] = color;
    z07_patch_and_cue_level_palettes_transfer();
}

static void check_class1(unsigned char item_id, unsigned char item_slot, unsigned char item_class) {
    if (item_class != 0x10) {
        if (item_class == 0x20) { handle_class2(item_slot); return; }
        unsigned char result = 0xFF;
        if (item_slot == 7 && result >= 3) result = 2;
        if (item_slot == 1 && result >= RAM(0x067C)) result = RAM(0x067C);
        z01_set_item_value(result, item_slot);
        return;
    }
    if (item_slot == 0x18) {
        unsigned char cur = RAM(0x0657 + item_slot);
        if (cur >= 0xF0) return;
        z01_set_item_value((unsigned char)(cur + 0x11), item_slot);
        return;
    }
    if (item_slot == 0x1C) { z01_take_5_rupees(); return; }
    if (item_slot == 0x16) { z01_take_one_rupee(); return; }
    if (item_slot == 0x19) { z01_take_hearts(); return; }
    if (item_slot == 0x17) z01_play_key_taken_tune();
    if (item_slot == 0x14) { z01_take_hearts_no_sound(); return; }
    unsigned int sum = (unsigned int)RAM(0x000A) + RAM(0x0657 + item_slot);
    unsigned char result = (sum > 0xFF) ? 0xFF : (unsigned char)sum;
    if (item_slot == 7 && result >= 3) result = 2;
    if (item_slot == 1 && result >= RAM(0x067C)) result = RAM(0x067C);
    z01_set_item_value(result, item_slot);
}

void z01_take_item(unsigned char item_id) {
    RAM(0x0602) = 8;
    if (item_id == 0x0E) RAM(0x0602) = 2;
    if (RAM(0x0012) != 5) {
        RAM(0x0506) = 0x80;
        RAM(0x0600) = 8;
        RAM(0x0505) = item_id;
    }
    unsigned char item_slot = ItemIdToSlot[item_id];
    unsigned char descriptor = ItemIdToDescriptor[item_id];
    RAM(0x000A) = descriptor & 0x0F;
    unsigned char item_class = descriptor & 0xF0;
    if (item_class != 0) {
        check_class1(item_id, item_slot, item_class);
        return;
    }
    if (item_slot == 0x11 || item_slot == 0x10 || item_slot == 0x1A || item_slot == 0x1B) {
        take_class0_complex(item_id, item_slot);
        return;
    }
    z01_set_item_value(RAM(0x000A), item_slot);
}

/* --- batch 63 --- */
extern void c_reset_moving_dir(void);
extern void c_move_object(unsigned short slot);

static void bound_direction_return(unsigned char dir_bit) {
    if (RAM(0x000F) & dir_bit)
        c_reset_moving_dir();
}

void z01_bound_direction_horizontally(unsigned int slot) {
    unsigned char x = RAM(0x0070 + slot);
    RAM(0x0000) = x;
    int adjust = (slot != 0) && (slot >= 0x0D || RAM(0x034F + slot) == 0x5C);
    if (adjust) RAM(0x0000) = (unsigned char)(x + 0x0B);
    if (RAM(0x0000) < RAM(0x0346)) {
        bound_direction_return(2);
        return;
    }
    if (adjust) RAM(0x0000) = (unsigned char)(RAM(0x0000) - 0x17);
    if (RAM(0x0000) >= RAM(0x0347))
        bound_direction_return(1);
}

void z01_bound_direction_vertically(unsigned int slot) {
    unsigned char y = RAM(0x0084 + slot);
    RAM(0x0000) = y;
    int adjust = (slot != 0) && (slot >= 0x0D || RAM(0x034F + slot) == 0x5C);
    if (adjust) RAM(0x0000) = (unsigned char)(y + 0x0F);
    if (RAM(0x0000) < RAM(0x0348)) {
        bound_direction_return(8);
        return;
    }
    if (adjust) RAM(0x0000) = (unsigned char)(RAM(0x0000) - 0x21);
    if (RAM(0x0000) >= RAM(0x0349))
        bound_direction_return(4);
}

unsigned char z01_bound_by_room(unsigned int slot) {
    z01_bound_direction_horizontally(slot);
    z01_bound_direction_vertically(slot);
    return RAM(0x000F);
}

unsigned char z01_bound_by_room_with_a(unsigned char direction, unsigned int slot) {
    RAM(0x000F) = direction;
    return z01_bound_by_room(slot);
}

unsigned int z01_add_q_speed_to_position_fraction(unsigned int slot) {
    unsigned int result = (unsigned int)RAM(0x03A8 + slot) + RAM(0x03BC + slot);
    RAM(0x03A8 + slot) = (unsigned char)result;
    unsigned int carry = result >> 8;
    unsigned char grid = RAM(0x0394 + slot);
    if (grid == RAM(0x010E) || grid == RAM(0x010F)) carry = 0;
    RAM(0x0394 + slot) = (unsigned char)(grid + (unsigned char)carry);
    return carry ? CARRY_SET : 0u;
}

unsigned int z01_sub_q_speed_from_position_fraction(unsigned int slot) {
    unsigned int frac = RAM(0x03A8 + slot);
    unsigned int sub_val = RAM(0x03BC + slot);
    unsigned int borrow = (frac < sub_val) ? 1u : 0u;
    RAM(0x03A8 + slot) = (unsigned char)(frac - sub_val);
    unsigned char grid = RAM(0x0394 + slot);
    if (grid == RAM(0x010E) || grid == RAM(0x010F))
        return 0u;
    RAM(0x0394 + slot) = (unsigned char)(grid - (unsigned char)borrow);
    return borrow ? 0u : CARRY_SET;
}

void z01_move_shot(unsigned char direction, unsigned int slot) {
    unsigned char dir_result = z01_bound_by_room_with_a(direction, slot);
    if (dir_result == 0) {
        RAM(0x000E) = 0x80;
        return;
    }
    unsigned char saved_offset = RAM(0x0394 + slot);
    RAM(0x0394 + slot) = 0;
    c_move_object((unsigned short)slot);
    unsigned char new_offset = RAM(0x0394 + slot);
    if (RAM(0x000E) == 0)
        RAM(0x0394 + slot) = (unsigned char)(saved_offset + new_offset);
    else
        RAM(0x0394 + slot) = saved_offset;
}

/* --- batch 64 --- */
unsigned char z01_get_one_direction_and_distance_to_target(unsigned char target_coord, unsigned char origin_coord) {
    RAM(0x0001) = target_coord;
    RAM(0x0002) = origin_coord;
    if (origin_coord < target_coord) {
        RAM(0x0002) = target_coord;
        RAM(0x0001) = origin_coord;
        RAM(0x000A) >>= 1;
    }
    unsigned char dist = (unsigned char)(RAM(0x0002) - RAM(0x0001));
    if (dist < 9) RAM(0x0000)++;
    return dist;
}

void z01_get_directions_and_distances_to_target(unsigned char target_slot, unsigned int origin_slot) {
    RAM(0x000A) = 2;
    RAM(0x0003) = z01_get_one_direction_and_distance_to_target(
        RAM(0x0070 + target_slot), RAM(0x0070 + origin_slot));
    RAM(0x000B) = RAM(0x000A);
    RAM(0x000A) = 8;
    RAM(0x0004) = z01_get_one_direction_and_distance_to_target(
        RAM(0x0084 + target_slot), RAM(0x0084 + origin_slot));
}

unsigned int z01_calc_diagonal_speed_index(unsigned int mid_speed_idx) {
    RAM(0x0000) = (unsigned char)mid_speed_idx;
    RAM(0x0001) = 0xFF;
    unsigned char h = RAM(0x0003);
    unsigned char v = RAM(0x0004);
    if (h < v) {
        RAM(0x0003) = v;
        RAM(0x0004) = h;
        RAM(0x0001) = 1;
        unsigned char tmp = h; h = v; v = tmp;
    }
    if ((unsigned char)(h - v) < 8)
        return (unsigned int)RAM(0x0000);
    for (;;) {
        unsigned char idx = (unsigned char)(RAM(0x0000) + RAM(0x0001));
        RAM(0x0000) = idx;
        if (idx == 0 || idx == 8) break;
        unsigned char new_diff = (unsigned char)(RAM(0x0003) - RAM(0x0004));
        RAM(0x0003) = new_diff;
        if (new_diff < RAM(0x0004)) break;
    }
    return (unsigned int)RAM(0x0000);
}

static unsigned char choose_offset_for_direction_h(unsigned char dir) {
    RAM(0x0000) = 0;
    unsigned char d = dir & 0x03;
    if (d == 0) return 0;
    if (d & 0x01) return RAM(0x0001);
    return RAM(0x0002);
}

void z01_place_weapon(unsigned char offset, unsigned int slot) {
    RAM(0x0001) = offset;
    RAM(0x0002) = 0xF0;
    unsigned char player_dir = RAM(0x0098);
    RAM(0x0098 + slot) = player_dir;
    RAM(0x0070 + slot) = (unsigned char)(RAM(0x0070) + choose_offset_for_direction_h(player_dir));
    RAM(0x0084 + slot) = (unsigned char)(RAM(0x0084) + choose_offset_for_direction_h((unsigned char)(player_dir >> 2)));
}

void z01_place_weapon_for_player_state(unsigned int slot) {
    RAM(0x00AC) = 16;
    z01_place_weapon(16, slot);
}

void z01_place_weapon_for_player_state_and_anim(unsigned int slot) {
    RAM(0x03D0) = 1;
    z01_place_weapon_for_player_state(slot);
}

void z01_place_weapon_for_player_state_and_anim_and_weapon_state(unsigned char weapon_state, unsigned int slot) {
    RAM(0x00AC + slot) = weapon_state;
    z01_place_weapon_for_player_state_and_anim(slot);
}

/* --- batch 65 --- */

unsigned int z01_sub1_from_int16_at4(void) {
    unsigned char lo = RAM(0x0004);
    unsigned int borrow = (lo == 0) ? 1u : 0u;
    RAM(0x0004) = (unsigned char)(lo - 1u);
    if (borrow)
        RAM(0x0005) = (unsigned char)(RAM(0x0005) - 1u);
    return borrow ? 0u : CARRY_SET;
}

void z01_wield_bomb(unsigned int slot) {
    if (RAM(0x0658) == 0) return;
    unsigned int use_slot = 16;
    unsigned char state16 = RAM(0x00AC + 16);
    if (state16 != 0 && (state16 & 0xF0) == 0x10) {
        use_slot = 17;
        unsigned char state17 = RAM(0x00AC + 17);
        if (state17 != 0 && (state17 & 0xF0) == 0x10)
            return;
    }
    unsigned int other_slot = use_slot ^ 1u;
    unsigned char other_state = RAM(0x00AC + other_slot);
    if (other_state != 0 && other_state < 0x13) return;
    RAM(0x0658) = (unsigned char)(RAM(0x0658) - 1u);
    RAM(0x0604) = 32;
    RAM(0x0028 + use_slot) = 0;
    z01_place_weapon_for_player_state_and_anim_and_weapon_state(17, use_slot);
}

unsigned int z01_wield_candle(unsigned int slot) {
    unsigned int use_slot = 16;
    if (RAM(0x00AC + 16) != 0) {
        use_slot = 17;
        if (RAM(0x00AC + 17) != 0)
            return 0u;
    }
    if (RAM(0x065B) == 1 && RAM(0x0513) != 0)
        return 0u;
    RAM(0x0513) = 1;
    RAM(0x0394 + use_slot) = 0;
    RAM(0x03A8 + use_slot) = 0;
    RAM(0x03BC + use_slot) = 32;
    RAM(0x00AC + use_slot) = 33;
    z01_play_effect(4);
    RAM(0x03D0 + use_slot) = 4;
    z01_place_weapon_for_player_state(use_slot);
    return 0u;
}

unsigned int z01_get_shortcut_or_item_xy_for_room(unsigned int room_id) {
    unsigned char lookup = nes_ram[NES_SRAM_BASE + 0x0AFE + room_id];
    unsigned char type_idx = (lookup & 0x30) >> 4;
    unsigned char entry = nes_ram[NES_SRAM_BASE + 0x0BA7 + type_idx];
    unsigned char y = (unsigned char)((entry & 0x0F) << 4);
    unsigned char x = entry & 0xF0;
    return ((unsigned int)x << 8) | y;
}

unsigned int z01_get_shortcut_or_item_xy(void) {
    return z01_get_shortcut_or_item_xy_for_room((unsigned int)RAM(0x00EB));
}

/* --- batch 66 --- */
void z01_get_object_middle(unsigned int slot) {
    RAM(0x0002) = 8;
    RAM(0x0003) = 8;
    if (RAM(0x04BF + slot) & 0x40)
        RAM(0x0002) >>= 1;
    RAM(0x0002) = (unsigned char)(RAM(0x0070 + slot) + RAM(0x0002));
    RAM(0x0003) = (unsigned char)(RAM(0x0084 + slot) + RAM(0x0003));
}

unsigned int z01_animate_world_fading(void) {
    if (RAM(0x0034) != 0) return 1u;
    unsigned char val = RAM(0x051C);
    if (val & 0x80)
        val ^= 0x83;
    RAM(0x0000) = val;
    unsigned char sram_idx = (unsigned char)(((unsigned char)(val << 3) + val) & 0xFCu);
    unsigned char pos = RAM(0x0301);
    RAM(0x0302 + pos) = 63;
    pos++;
    RAM(0x0302 + pos) = 8;
    pos++;
    RAM(0x0302 + pos) = 8;
    RAM(0x0000) = 8;
    pos++;
    unsigned char count = 8;
    while (count != 0) {
        RAM(0x0302 + pos) = nes_ram[NES_SRAM_BASE + 0x0BFA + sram_idx];
        sram_idx++;
        pos++;
        count--;
    }
    RAM(0x0302 + pos) = 0xFF;
    RAM(0x0301) = pos;
    RAM(0x051C)++;
    if ((RAM(0x051C) & 0x0F) == 4)
        return 0u;
    RAM(0x0034) = 10;
    return 1u;
}

void z01_check_mazes(void) {
    static const unsigned char forest_dirs[4] = {0x08, 0x02, 0x04, 0x02};
    static const unsigned char mountain_dirs[4] = {0x08, 0x08, 0x08, 0x08};
    unsigned char step = RAM(0x052F);
    unsigned char dir = RAM(0x0098);
    unsigned char room = RAM(0x00EB);
    if (room == 0x61) {
        if (dir != forest_dirs[step]) {
            if (dir == 0x01) return;
            RAM(0x052F) = 0;
            RAM(0x00EC) = room;
            return;
        }
        if (step == 3) { RAM(0x0602) = 4; return; }
        RAM(0x052F)++;
        RAM(0x00EC) = room;
        return;
    }
    if (room != 0x1B) { RAM(0x052F) = 0; return; }
    if (dir == mountain_dirs[step]) {
        if (step == 3) { RAM(0x0602) = 4; return; }
        RAM(0x052F)++;
        RAM(0x00EC) = room;
        return;
    }
    if (dir == 0x02) return;
    RAM(0x052F) = 0;
    RAM(0x00EC) = room;
}

/* --- batch 67 --- */
void z01_cycle_cur_sprite_index(void) {
    unsigned char idx = (unsigned char)(RAM(0x0341) + 1u);
    if (idx == 0x28)
        z01_reset_cur_sprite_index();
    else
        RAM(0x0341) = idx;
}

unsigned char z01_cycle_sprite_index_in_a(unsigned char idx) {
    idx = (unsigned char)(idx + 1u);
    if (idx == 0x28) {
        z01_reset_cur_sprite_index();
        return 0;
    }
    RAM(0x0341) = idx;
    return idx;
}

void z01_hide_object_sprites(void) {
    unsigned char d2 = 96;
    do {
        RAM(0x0200 + d2) = 0xF8;
        d2 = (unsigned char)(d2 + 4u);
    } while (d2 != 0);
    unsigned char new_idx = z01_cycle_sprite_index_in_a(RAM(0x0342));
    RAM(0x0342) = new_idx;
}

void z01_show_link_sprites_behind_horizontal_doors(void) {
    static const unsigned char extents[2] = {0x08, 0x00};
    unsigned int d3 = 10;
    RAM(0x0000) = RAM(0x0070);
    int d2 = 1;
    do {
        unsigned char x = (unsigned char)(RAM(0x0000) + extents[d2]);
        if (x >= 0xE9u || x < 0x10u) {
            unsigned char attr = RAM(0x0240 + d3);
            RAM(0x0240 + d3) = attr | 0x20u;
        }
        d3 = (d3 + 4u) & 0xFFu;
        if (d3 == 0) d3 = 32;
        d2--;
    } while (d2 >= 0);
}

/* --- batch 68 --- */
extern void z07_update_dead_dummy(unsigned int slot);

void z01_play_parry_sound_for_damage_type(void) {
    unsigned char dtype = RAM(0x0009);
    if (dtype == 0x20u || dtype == 0x08u) return;
    z01_play_parry_tune();
}

void z01_handle_monster_died(unsigned int slot) {
    RAM(0x0627)++;
    if (RAM(0x0050) < 0x0Au) {
        RAM(0x0050)++;
        if (RAM(0x0050) == 0x0Au && RAM(0x0009) == 0x08u)
            RAM(0x0051)++;
    }
    z07_update_dead_dummy(slot);
    RAM(0x003D + slot) = 0;
    z01_reset_shove_info_and_inv_timer(slot);
}

void z01_deal_damage(unsigned int slot) {
    RAM(0x0604) = 2;
    unsigned char hp = RAM(0x0485 + slot);
    unsigned char damage = RAM(0x0007);
    if (hp < damage) { z01_handle_monster_died(slot); return; }
    hp = (unsigned char)(hp - damage);
    RAM(0x0485 + slot) = hp;
    if (hp == 0) z01_handle_monster_died(slot);
}

extern void c_call_gohma_handle_weapon_collision(unsigned int monster_slot, unsigned int weapon_slot);
extern void c_call_begin_shove(unsigned int monster_slot);

void z01_handle_monster_weapon_collision(unsigned int monster_slot, unsigned int weapon_slot) {
    if (RAM(0x04B2 + monster_slot) & RAM(0x0009)) {
        z01_play_parry_sound_for_damage_type();
        return;
    }
    unsigned char mtype = RAM(0x034F + monster_slot);
    if (mtype == 0x33 || mtype == 0x34) {
        c_call_gohma_handle_weapon_collision(monster_slot, weapon_slot);
        return;
    }
    if (mtype == 0x13 || mtype == 0x12) {
        if (weapon_slot != 0x0F) RAM(0x0098 + monster_slot) = RAM(0x0098 + weapon_slot);
        z01_deal_damage(monster_slot);
        return;
    }
    if (mtype == 0x0B || mtype == 0x0C) {
        unsigned char combined = RAM(0x0098 + weapon_slot) | RAM(0x0098 + monster_slot);
        if (combined == 0x0C || combined == 0x03) {
            z01_play_parry_sound_for_damage_type();
            return;
        }
    }
    z01_deal_damage(monster_slot);
}

void z01_check_monster_weapon_collision(unsigned int monster_slot, unsigned int weapon_y_mid) {
    RAM(0x0005) = (unsigned char)weapon_y_mid;
    RAM(0x0006) = 0;
    unsigned int weapon_slot = (unsigned int)RAM(0x0000);
    if (RAM(0x00AC + weapon_slot) == 0) return;
    if (!z01_do_objects_collide_with_thresholds()) return;
    if (weapon_slot == 0x0F) {
        unsigned char inv = RAM(0x04B2 + monster_slot) & RAM(0x0009);
        if (inv) z01_play_parry_tune();
        RAM(0x00AC + weapon_slot) = 80;
        if (inv) return;
        RAM(0x0007) = 0;
        RAM(0x003D + monster_slot) = 16;
    }
    z01_handle_monster_weapon_collision(monster_slot, weapon_slot);
}

void z01_check_monster_slender_weapon_collision2(unsigned int monster_slot) {
    unsigned int weapon_slot = (unsigned int)RAM(0x0000);
    unsigned char dir = RAM(0x0098) & 0x0C;
    unsigned char wx, wy;
    if (dir != 0) {
        wx = (unsigned char)(RAM(0x0070 + weapon_slot) + 6);
        wy = (unsigned char)(RAM(0x0084 + weapon_slot) + 8);
    } else {
        wx = (unsigned char)(RAM(0x0070 + weapon_slot) + 8);
        wy = (unsigned char)(RAM(0x0084 + weapon_slot) + 6);
    }
    RAM(0x0004) = wx;
    z01_check_monster_weapon_collision(monster_slot, wy);
}

void z01_check_monster_slender_weapon_collision(unsigned int monster_slot, unsigned int damage_points) {
    RAM(0x0007) = (unsigned char)damage_points;
    RAM(0x000E) = RAM(0x000D);
    z01_check_monster_slender_weapon_collision2(monster_slot);
}

void z01_parry_or_shove(unsigned int monster_slot, unsigned int weapon_slot) {
    unsigned char mtype = RAM(0x034F + monster_slot);
    if (mtype == 0x0B || mtype == 0x0C) {
        unsigned char combined = RAM(0x0098 + weapon_slot) | RAM(0x0098 + monster_slot);
        if (combined == 0x0C || combined == 0x03) {
            z01_play_parry_tune();
            return;
        }
    }
    c_call_begin_shove(monster_slot);
}

void z01_check_monster_stabbing_collision(unsigned int monster_slot, unsigned int damage_points) {
    RAM(0x0007) = (unsigned char)damage_points;
    unsigned char dir = RAM(0x0098) & 0x0C;
    if (dir != 0) {
        RAM(0x000D) = 12;
        RAM(0x000E) = 16;
    } else {
        RAM(0x000D) = 16;
        RAM(0x000E) = 12;
    }
    z01_check_monster_slender_weapon_collision2(monster_slot);
    if (!RAM(0x0006)) return;
    z01_parry_or_shove(monster_slot, (unsigned int)RAM(0x0000));
}

static const unsigned char z01_sword_damage_points[3] = {0x10, 0x20, 0x40};

void z01_check_monster_sword_collision(unsigned int monster_slot, unsigned int weapon_slot) {
    RAM(0x0000) = (unsigned char)weapon_slot;
    RAM(0x0009) = 1;
    if (RAM(0x00AC + weapon_slot) != 2) return;
    unsigned int sword_level = (unsigned int)RAM(0x0657);
    z01_check_monster_stabbing_collision(monster_slot, z01_sword_damage_points[sword_level - 1]);
}

void z01_check_monster_shot_collision(unsigned int monster_slot, unsigned int weapon_slot, unsigned int damage_points) {
    z01_check_monster_slender_weapon_collision(monster_slot, damage_points);
    if (!RAM(0x0006)) return;
    if (weapon_slot != 0x12) {
        z01_parry_or_shove(monster_slot, weapon_slot);
        return;
    }
    unsigned char mtype = RAM(0x034F + monster_slot);
    if (mtype == 0x16) {
        RAM(0x0485 + monster_slot) = 0;
        z01_deal_damage(monster_slot);
        return;
    }
    RAM(0x00AC + weapon_slot) = 32;
    RAM(0x03D0 + weapon_slot) = 3;
    z01_parry_or_shove(monster_slot, weapon_slot);
}

void z01_check_monster_arrow_or_rod_collision(unsigned int monster_slot, unsigned int weapon_slot) {
    RAM(0x0000) = (unsigned char)weapon_slot;
    unsigned char state = RAM(0x00AC + weapon_slot);
    if (state >= 0x30) {
        RAM(0x0009) = 1;
        z01_check_monster_stabbing_collision(monster_slot, 32);
        return;
    }
    if (state >= 0x20) return;
    RAM(0x0009) = 4;
    unsigned int damage = (RAM(0x0659) == 1) ? 32u : 64u;
    RAM(0x000D) = 11;
    z01_check_monster_shot_collision(monster_slot, weapon_slot, damage);
}

void z01_check_monster_boomerang_or_food_collision(unsigned int monster_slot, unsigned int weapon_slot) {
    if (RAM(0x00AC + weapon_slot) & 0x80) return;
    RAM(0x0000) = (unsigned char)weapon_slot;
    RAM(0x0009) = 2;
    RAM(0x000D) = 10;
    RAM(0x000E) = 10;
    RAM(0x0004) = (unsigned char)(RAM(0x0070 + weapon_slot) + 4);
    z01_check_monster_weapon_collision(monster_slot, (unsigned int)(unsigned char)(RAM(0x0084 + weapon_slot) + 8));
}
