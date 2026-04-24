#include "core_runtime.h"

extern void z07_set_shove_info_with0(unsigned int val, unsigned int slot);

void corert_play_character_sfx(void) {
    RAM(0x0602) = 8;
}

void corert_play_key_taken_tune(void) {
    RAM(0x0602) = 0;
    RAM(0x0604) = 8;
}

void corert_take_power_triforce(void) {
    RAM(0x0509)++;
    RAM(0x0028) = 0xC0;
    RAM(0x00AC) = 64;
}

unsigned char corert_silence_all_sound(void) {
    RAM(0x0604) = 0x80;
    RAM(0x0603) = 0x80;
    RAM(0x0605) = 0;
    RAM(0x0607) = 0;
    return 0;
}

void corert_post_debit(unsigned int amount) {
    RAM(0x067E) = (unsigned char)(RAM(0x067E) + amount);
}

void corert_init_one_simple_object(unsigned int slot) {
    RAM(0x034F + slot) = RAM(0x00);
    RAM(0x0492 + slot) = 0;
    RAM(0x04BF + slot) = RAM(0x01);
}

void corert_destroy_object_wram(unsigned int val, unsigned int slot) {
    RAM(0x00C0 + slot) = val;
    RAM(0x00D3 + slot) = val;
    RAM(0x0028 + slot) = val;
    RAM(0x00AC + slot) = val;
    RAM(0x04F0 + slot) = val;
    RAM(0x0492 + slot) = 0xFF;
    RAM(0x0405 + slot) = 1;
}

void corert_destroy_whirlwind(unsigned int slot) {
    corert_destroy_object_wram(0, slot);
}

void corert_unhalt_link(void) {
    RAM(0x00AC) = 0;
}

void corert_inc_cave_state(void) {
    RAM(0x00AD)++;
}

void corert_set_up_whirlwind(unsigned int slot) {
    RAM(0x0084 + slot) = RAM(0x0084);
    RAM(0x0070 + slot) = 0;
    RAM(0x034F + slot) = 46;
}

void corert_uw_person_complex_state_delay_and_quit(void) {
    if (RAM(0x0029) == 0) {
        RAM(0x0350) = 0;
    }
}

void corert_set_boomerang_speed(unsigned int val, unsigned int slot) {
    RAM(0x03BC + slot) = val;
    if ((RAM(0x00AC + slot) & 0xF0) == 0x40) {
        RAM(0x03BC + slot) >>= 1;
        RAM(0x0380 + slot)--;
        if (RAM(0x0380 + slot) == 0) {
            RAM(0x00AC + slot) = 80;
        }
    }
}

void corert_set_up_common_cave_objects(unsigned int x, unsigned int slot, unsigned int y) {
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

unsigned char corert_anim_set_sprite_desc_attrs(unsigned int val) {
    RAM(0x0004) = (unsigned char)val;
    RAM(0x0005) = (unsigned char)val;
    return (unsigned char)val;
}

void corert_post_credit(unsigned int val) {
    RAM(0x067D) = (unsigned char)(RAM(0x067D) + val);
}

unsigned char corert_add_to_int16_at_0(unsigned int val) {
    unsigned int sum = (unsigned char)val + RAM(0x0000);
    RAM(0x0000) = (unsigned char)sum;
    if (sum > 0xFF) {
        RAM(0x0001)++;
    }
    return (unsigned char)sum;
}

unsigned char corert_add_to_int16_at_2(unsigned int val) {
    unsigned int sum = (unsigned char)val + RAM(0x0002);
    RAM(0x0002) = (unsigned char)sum;
    if (sum > 0xFF) {
        RAM(0x0003)++;
    }
    return (unsigned char)sum;
}

unsigned char corert_add_to_int16_at_4(unsigned int val) {
    unsigned int sum = (unsigned char)val + RAM(0x0004);
    RAM(0x0004) = (unsigned char)sum;
    if (sum > 0xFF) {
        RAM(0x0005)++;
    }
    return (unsigned char)sum;
}

void corert_map_screen_pos_to_ppu_addr(void) {
    unsigned char y = RAM(0x0002);
    unsigned char x = RAM(0x0003);
    RAM(0x0000) = 0x20 | (y >> 6);
    RAM(0x0001) = ((y << 2) & 0xE0) | (x >> 3);
}

void corert_reset_shove_info_and_inv_timer(unsigned int slot) {
    z07_set_shove_info_with0(0, slot);
    RAM(0x04F0 + slot) = 0;
}

void corert_update_person_state_reset_char_offset(void) {
    RAM(0x0416) = 0;
    RAM(0x00AD)++;
}

void corert_begin_update_mode(void) {
    RAM(0x0013) = 0;
    RAM(0x0011)++;
}

void corert_cue_transfer_buf_and_advance_state(unsigned int val) {
    RAM(0x0014) = (unsigned char)val;
    corert_inc_cave_state();
}

void corert_take_one_rupee(void) {
    RAM(0x0602) = 1;
    RAM(0x067D)++;
}

void corert_set_item_value(unsigned int val, unsigned int slot3) {
    RAM(0x0657 + slot3) = (unsigned char)val;
}

void corert_init_whirlwind(unsigned int val, unsigned int slot) {
    RAM(0x0084) = (unsigned char)val;
    corert_set_up_whirlwind(slot);
}

unsigned char corert_add1_to_int16_at_0(void) {
    return corert_add_to_int16_at_0(1);
}

unsigned char corert_add1_to_int16_at_2(void) {
    return corert_add_to_int16_at_2(1);
}

unsigned char corert_add1_to_int16_at_4(void) {
    return corert_add_to_int16_at_4(1);
}

void corert_cue_transfer_blank_person_wares(void) {
    corert_cue_transfer_buf_and_advance_state(42);
}

void corert_take_5_rupees(void) {
    signed char i;
    for (i = 4; i >= 0; i--) {
        corert_take_one_rupee();
    }
}

unsigned int corert_get_opposite_dir(unsigned int dir) {
    static const unsigned char opposite_dirs[] = {0x04, 0x08, 0x01, 0x02};
    unsigned char d = (unsigned char)dir;
    signed char idx = 3;
    while (idx >= 0) {
        if (d & 1) {
            break;
        }
        d >>= 1;
        idx--;
    }
    if (idx < 0) {
        idx = 0;
    }
    return ((unsigned int)(unsigned char)idx << 8) | opposite_dirs[(unsigned char)idx];
}

unsigned char corert_abs(unsigned int val) {
    unsigned char v = (unsigned char)val;
    return (v & 0x80) ? (unsigned char)((~v + 1) & 0xFF) : v;
}

unsigned char corert_negate(unsigned int val) {
    unsigned char v = (unsigned char)val;
    return (unsigned char)((~v + 1) & 0xFF);
}

void corert_play_effect(unsigned int val) {
    RAM(0x0603) |= (unsigned char)val;
}

void corert_play_sample(unsigned int val) {
    RAM(0x0601) |= (unsigned char)val;
}

void corert_play_parry_tune(void) {
    RAM(0x0604) = 1;
}

void corert_write_blank_priority_sprites(void) {
    static const unsigned char tmpl[] = {0x3D, 0x1C, 0x20, 0x00, 0xDD, 0x1C, 0x20, 0x00};
    unsigned char i;
    for (i = 0; i < 0x40; i++) {
        RAM(0x0200 + i) = tmpl[i & 7];
    }
}

void corert_copy_price_list_template(void) {
    static const unsigned char tmpl[] = {
        0x22, 0xC8, 0x0D, 0x21, 0x24, 0x24, 0x24, 0x24,
        0x24, 0x24, 0x24, 0x24, 0x24, 0x24, 0x24, 0x24, 0xFF
    };
    signed char i;
    for (i = 16; i >= 0; i--) {
        RAM(0x0302 + (unsigned char)i) = tmpl[(unsigned char)i];
    }
}

unsigned char corert_compare_hearts_to_containers(void) {
    return (RAM(0x066F) >> 4);
}

void corert_uw_person_complex_state_begin(void) {
    if (RAM(0x0350) == 0x4F) {
        RAM(0x0014) = 108;
    }
    RAM(0x0029) = 10;
    RAM(0x00AD)++;
}

void corert_format_char_doublet(unsigned int val) {
    RAM(0x0002) = (unsigned char)val;
    RAM(0x0003) = 36;
}

unsigned char corert_reset_cur_sprite_index(void) {
    RAM(0x0341) = 0;
    return 0;
}

void corert_play_boomerang_sfx(unsigned int sfx_id) {
    if (RAM(0x003B) != 0) {
        return;
    }
    corert_play_effect(sfx_id);
    RAM(0x003B) = 10;
}

void corert_take_hearts_no_sound(void) {
    RAM(0x0001) = RAM(0x000A);
    for (;;) {
        if (corert_compare_hearts_to_containers() == RAM(0x0000)) {
            unsigned char partial = RAM(0x0670);
            partial++;
            if (partial == 0) {
                return;
            }
            RAM(0x0670) = 0xFF;
            return;
        }
        RAM(0x066F)++;
        RAM(0x0001)--;
        if ((signed char)RAM(0x0001) < 0) {
            return;
        }
    }
}

void corert_take_hearts(void) {
    corert_play_key_taken_tune();
    corert_take_hearts_no_sound();
}

unsigned int corert_sub1_from_int16_at4(void) {
    unsigned char lo = RAM(0x0004);
    unsigned int borrow = (lo == 0) ? 1u : 0u;
    RAM(0x0004) = (unsigned char)(lo - 1u);
    if (borrow) {
        RAM(0x0005) = (unsigned char)(RAM(0x0005) - 1u);
    }
    return borrow ? 0u : CARRY_SET;
}

/* ---- Plan C: drained from z_07 (object state cluster) ------------------ */

extern void z01_destroy_object_wram(unsigned int val, unsigned int slot);
extern unsigned int z01_get_opposite_dir(unsigned int dir);

unsigned char corert_reset_obj_state(unsigned int slot) {
    RAM(0x00AC + slot) = 0;
    return 0;
}

void corert_set_shove_info_with0(unsigned int val, unsigned int slot) {
    RAM(0x00C0 + slot) = (unsigned char)val;
    RAM(0x00D3 + slot) = (unsigned char)val;
}

void corert_reset_shove_info(unsigned int slot) {
    corert_set_shove_info_with0(0, slot);
}

void corert_reset_obj_metastate(unsigned int slot) {
    RAM(0x0405 + slot) = 0;
}

void corert_reset_obj_metastate_and_timer(unsigned int slot) {
    RAM(0x0028 + slot) = 0;
    corert_reset_obj_metastate(slot);
}

void corert_decrement_invincibility_timer(unsigned int slot) {
    if (RAM(0x04F0 + slot) == 0) return;
    if (RAM(0x0015) & 1) return;
    RAM(0x04F0 + slot)--;
}

void corert_update_dead_dummy(unsigned int slot) {
    RAM(0x0602) = 32;
    RAM(0x0405 + slot) = 16;
}

void corert_set_shot_spreading_state(unsigned int slot) {
    RAM(0x00AC + slot)++;
    RAM(0x0098 + slot) = 0xFE;
}

void corert_deactivate_shot(unsigned int slot) {
    corert_reset_obj_state(slot);
}

void corert_deactivate_link_shot(void) {
    corert_reset_obj_state(14);
}

void corert_destroy_monster(unsigned int slot) {
    RAM(0x034F + slot) = 0;
    z01_destroy_object_wram(0, slot);
}

void corert_set_type_and_clear_object(unsigned int type, unsigned int slot) {
    RAM(0x034F + slot) = (unsigned char)type;
    z01_destroy_object_wram(0, slot);
}

void corert_init_tile_obj_or_item(unsigned int slot) {
    RAM(0x04BF + slot) = 0x81;
    corert_reset_obj_metastate_and_timer(slot);
}

void corert_init_flute_secret(unsigned int slot) {
    RAM(0x051A) = 1;
    RAM(0x0028 + slot) = 0;
    corert_reset_obj_metastate(slot);
}

void corert_ensure_object_aligned(unsigned int slot) {
    if (RAM(0x0394 + slot) != 0) return;
    RAM(0x0070 + slot) &= 0xF8;
    RAM(0x0084 + slot) = (RAM(0x0084 + slot) & 0xF8) | 0x05;
}

void corert_reverse_obj_dir(unsigned int slot) {
    unsigned char dir = RAM(0x0098 + slot);
    unsigned char new_dir = (unsigned char)z01_get_opposite_dir(dir);
    RAM(0x0098 + slot) = new_dir;
    RAM(0x000F) = new_dir;
}

unsigned char corert_reset_moving_dir(void) {
    RAM(0x000F) = 0;
    return 0;
}

void corert_do_nothing(void) {}

void corert_clear_ram0300_up_to(unsigned int end_hi, unsigned int start_off) {
    unsigned char hi = (unsigned char)end_hi;
    unsigned char off = (unsigned char)start_off;

    for (;;) {
        nes_ram[((unsigned short)hi << 8) | off] = 0;
        off--;
        if (off != 0xFF)
            continue;
        hi--;
        if (hi >= 0x03) {
            off = 0xFF;
            continue;
        }
        nes_ram[0x0302] = 0xFF;
        return;
    }
}
