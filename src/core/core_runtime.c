#include "core_runtime.h"
#include "legacy_bridge.h"
#include "object_state.h"
#include "sprite_state.h"
#include "link_state.h"
#include "progress_state.h"
#include "room_state.h"

void corert_play_character_sfx(void) {
    DEATH_FRAME_COUNTER = 8;
}

void corert_play_key_taken_tune(void) {
    DEATH_FRAME_COUNTER = 0;
    ROOM_SFX_MAIN = 8;
}

void corert_take_power_triforce(void) {
    POWER_TRIFORCE_FANFARE_FLAG++;
    RAM(0x0028) = 0xC0;
    OBJ_STATE(0) = 64;
}

unsigned char corert_silence_all_sound(void) {
    ROOM_SFX_MAIN = 0x80;
    ROOM_SFX_AUX = 0x80;
    RAM(0x0605) = 0;
    RAM(0x0607) = 0;
    return 0;
}

void corert_post_debit(unsigned int amount) {
    RAM(0x067E) = (unsigned char)(RAM(0x067E) + amount);
}

void corert_init_one_simple_object(unsigned int slot) {
    OBJ_TYPE(slot) = RAM(0x00);
    RAM(0x0492 + slot) = 0;
    RAM(0x04BF + slot) = RAM(0x01);
}

void corert_destroy_object_wram(unsigned int val, unsigned int slot) {
    OBJ_SHOVE_DIR(slot) = val;
    OBJ_SHOVE_DIST(slot) = val;
    RAM(0x0028 + slot) = val;
    OBJ_STATE(slot) = val;
    OBJ_INV_TIMER(slot) = val;
    RAM(0x0492 + slot) = 0xFF;
    OBJ_METASTATE(slot) = 1;
}

void corert_destroy_whirlwind(unsigned int slot) {
    corert_destroy_object_wram(0, slot);
}

void corert_unhalt_link(void) {
    OBJ_STATE(0) = 0;
}

void corert_inc_cave_state(void) {
    OBJ_STATE(1)++;
}

void corert_set_up_whirlwind(unsigned int slot) {
    OBJ_TILE_Y(slot) = OBJ_TILE_Y(0);
    OBJ_TILE_X(slot) = 0;
    OBJ_TYPE(slot) = 46;
}

void corert_uw_person_complex_state_delay_and_quit(void) {
    if (RAM(0x0029) == 0) {
        ROOM_OBJ_TYPE(0) = 0;
    }
}

void corert_set_boomerang_speed(unsigned int val, unsigned int slot) {
    RAM(0x03BC + slot) = val;
    if ((OBJ_STATE(slot) & 0xF0) == 0x40) {
        RAM(0x03BC + slot) >>= 1;
        RAM(0x0380 + slot)--;
        if (RAM(0x0380 + slot) == 0) {
            OBJ_STATE(slot) = 80;
        }
    }
}

void corert_set_up_common_cave_objects(unsigned int x, unsigned int slot, unsigned int y) {
    OBJ_TILE_X(slot) = x;
    OBJ_TILE_Y(slot) = y;
    RAM(0x0485 + slot) = 0;
    RAM(0x04BF + slot) = 0x81;
    OBJ_STATE(0) = 64;
    ROOM_OBJ_TYPE(1) = 64;
    ROOM_OBJ_TYPE(2) = 64;
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
    OBJ_INV_TIMER(slot) = 0;
}

void corert_update_person_state_reset_char_offset(void) {
    RAM(0x0416) = 0;
    OBJ_STATE(1)++;
}

void corert_begin_update_mode(void) {
    SUBMODE_VALUE = 0;
    ROOM_MODE_TIMER++;
}

void corert_cue_transfer_buf_and_advance_state(unsigned int val) {
    ROOM_TRANSFER_BUF_SELECT = (unsigned char)val;
    corert_inc_cave_state();
}

void corert_take_one_rupee(void) {
    DEATH_FRAME_COUNTER = 1;
    RAM(0x067D)++;
}

void corert_set_item_value(unsigned int val, unsigned int slot3) {
    PROG_ITEMS_BY_LEVEL(slot3) = (unsigned char)val;
}

void corert_init_whirlwind(unsigned int val, unsigned int slot) {
    OBJ_TILE_Y(0) = (unsigned char)val;
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
    ROOM_SFX_AUX |= (unsigned char)val;
}

void corert_play_sample(unsigned int val) {
    RAM(0x0601) |= (unsigned char)val;
}

void corert_play_parry_tune(void) {
    ROOM_SFX_MAIN = 1;
}

void corert_write_blank_priority_sprites(void) {
    static const unsigned char tmpl[] = {0x3D, 0x1C, 0x20, 0x00, 0xDD, 0x1C, 0x20, 0x00};
    unsigned char i;
    for (i = 0; i < 0x40; i++) {
        OAM_BYTE(i) = tmpl[i & 7];
    }
}

void corert_copy_price_list_template(void) {
    static const unsigned char tmpl[] = {
        0x22, 0xC8, 0x0D, 0x21, 0x24, 0x24, 0x24, 0x24,
        0x24, 0x24, 0x24, 0x24, 0x24, 0x24, 0x24, 0x24, 0xFF
    };
    signed char i;
    for (i = 16; i >= 0; i--) {
        ROOM_TILE_XFER_BUF((unsigned char)i) = tmpl[(unsigned char)i];
    }
}

unsigned char corert_compare_hearts_to_containers(void) {
    return (LINK_HEARTS >> 4);
}

void corert_uw_person_complex_state_begin(void) {
    if (ROOM_OBJ_TYPE(0) == 0x4F) {
        ROOM_TRANSFER_BUF_SELECT = 108;
    }
    RAM(0x0029) = 10;
    OBJ_STATE(1)++;
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
            unsigned char partial = LINK_PARTIAL_HEART;
            partial++;
            if (partial == 0) {
                return;
            }
            LINK_PARTIAL_HEART = 0xFF;
            return;
        }
        LINK_HEARTS++;
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

unsigned char corert_reset_obj_state(unsigned int slot) {
    OBJ_STATE(slot) = 0;
    return 0;
}

void corert_set_shove_info_with0(unsigned int val, unsigned int slot) {
    OBJ_SHOVE_DIR(slot) = (unsigned char)val;
    OBJ_SHOVE_DIST(slot) = (unsigned char)val;
}

void corert_reset_shove_info(unsigned int slot) {
    corert_set_shove_info_with0(0, slot);
}

void corert_reset_obj_metastate(unsigned int slot) {
    OBJ_METASTATE(slot) = 0;
}

void corert_reset_obj_metastate_and_timer(unsigned int slot) {
    RAM(0x0028 + slot) = 0;
    corert_reset_obj_metastate(slot);
}

void corert_decrement_invincibility_timer(unsigned int slot) {
    if (OBJ_INV_TIMER(slot) == 0) return;
    if (FRAME_COUNTER & 1) return;
    OBJ_INV_TIMER(slot)--;
}

void corert_update_dead_dummy(unsigned int slot) {
    DEATH_FRAME_COUNTER = 32;
    OBJ_METASTATE(slot) = 16;
}

void corert_set_shot_spreading_state(unsigned int slot) {
    OBJ_STATE(slot)++;
    OBJ_FLAG(slot) = 0xFE;
}

void corert_deactivate_shot(unsigned int slot) {
    corert_reset_obj_state(slot);
}

void corert_deactivate_link_shot(void) {
    corert_reset_obj_state(14);
}

void corert_destroy_monster(unsigned int slot) {
    OBJ_TYPE(slot) = 0;
    z01_destroy_object_wram(0, slot);
}

void corert_set_type_and_clear_object(unsigned int type, unsigned int slot) {
    OBJ_TYPE(slot) = (unsigned char)type;
    z01_destroy_object_wram(0, slot);
}

void corert_init_tile_obj_or_item(unsigned int slot) {
    RAM(0x04BF + slot) = 0x81;
    corert_reset_obj_metastate_and_timer(slot);
}

void corert_init_flute_secret(unsigned int slot) {
    RAM(NES_ROOM_LAYOUT_SCRATCH) = 1;
    RAM(0x0028 + slot) = 0;
    corert_reset_obj_metastate(slot);
}

void corert_ensure_object_aligned(unsigned int slot) {
    if (OBJ_ALIGN_FLAG(slot) != 0) return;
    OBJ_TILE_X(slot) &= 0xF8;
    OBJ_TILE_Y(slot) = (OBJ_TILE_Y(slot) & 0xF8) | 0x05;
}

void corert_reverse_obj_dir(unsigned int slot) {
    unsigned char dir = OBJ_FLAG(slot);
    unsigned char new_dir = (unsigned char)z01_get_opposite_dir(dir);
    OBJ_FLAG(slot) = new_dir;
    LINK_MOVING_DIR = new_dir;
}

unsigned char corert_reset_moving_dir(void) {
    LINK_MOVING_DIR = 0;
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
        ROOM_TILE_XFER_BUF(0) = 0xFF;
        return;
    }
}

void corert_handle_shot_blocked(unsigned int slot) {
    unsigned char saved_link_state;
    unsigned char saved_candle_used;

    if ((OBJ_STATE(slot) & 0x80) == 0) {
        corert_set_shot_spreading_state(slot);
        return;
    }

    if (RAM(0x0661) == 0) {
        corert_deactivate_shot(slot);
        return;
    }

    saved_link_state = OBJ_STATE(0);
    saved_candle_used = CANDLE_LIT_FLAG;
    CANDLE_LIT_FLAG = 0;
    c_wield_candle();
    CANDLE_LIT_FLAG = saved_candle_used;
    OBJ_STATE(0) = saved_link_state;

    if (OBJ_STATE(slot) != 0x21) {
        corert_deactivate_link_shot();
        return;
    }

    OBJ_STATE(slot) = 0x22;
    OBJ_TILE_X(slot) = OBJ_TILE_X(14);
    OBJ_TILE_Y(slot) = OBJ_TILE_Y(14);
    OBJ_FLAG(slot) = OBJ_FLAG(14);
    RAM(0x0028 + slot) = 79;
}
