/* z_04.c — C port of z_04 leaf functions.
 * Data tables and remaining code stay in z_04.asm.
 */

#include "../nes_abi.h"

extern void z04_reset_flyer_state(unsigned int slot);
extern void z04_init_digdogger1(unsigned int slot);
extern unsigned char z07_reset_obj_state(unsigned int slot);
extern void z07_reset_obj_metastate(unsigned int slot);
extern void z07_reset_obj_metastate_and_timer(unsigned int slot);

extern const unsigned char TektiteStartingDirs[];
extern const unsigned char GanonStartXs[];
extern const unsigned char Directions8[];

void z04_hide_sprites_over_link(void) {
    RAM(0x0240) = 0xF8;
    RAM(0x0244) = 0xF8;
}

void z04_play_secret_found_tune(void) {
    RAM(0x0602) = 4;
}

void z04_play_boss_death_cry(void) {
    RAM(0x0601) = 2;
    RAM(0x0603) = 0x80;
}

void z04_dodongo_dec_bloated_timer(unsigned int slot) {
    RAM(0x045E + slot)--;
}

void z04_gleeok_dec_head_timer(void) {
    RAM(0x0418)--;
}

void z04_gleeok_set_segment_x(unsigned int val, unsigned int slot) {
    RAM(0x0072 + slot) = (unsigned char)val;
}

void z04_gohma_play_parry_tune(void) {
    RAM(0x0604) = 1;
}

void z04_flyer_set_state_and_turns(unsigned int state, unsigned int slot) {
    RAM(0x0444 + slot) = (unsigned char)state;
    RAM(0x042C + slot) = 6;
}

void z04_init_aquamentus(unsigned int slot) {
    RAM(0x04B2 + slot) = 0xE2;
    RAM(0x0601) = 16;
    RAM(0x0070 + slot) = 0xB0;
    RAM(0x0084 + slot) = 0x80;
}

void z04_init_tektite(unsigned int slot) {
    unsigned char rnd = RAM(0x0019 + slot) & 0x03;
    unsigned char dir = TektiteStartingDirs[rnd];
    RAM(0x0098 + slot) = dir;
    unsigned char timer = dir << 2;
    RAM(0x0028 + slot) = timer;
}

void z04_ganon_randomize_location(unsigned int slot) {
    RAM(0x0084 + slot) = 0xA0;
    unsigned char idx = RAM(0x0015) & 0x01;
    RAM(0x0070 + slot) = GanonStartXs[idx];
}

void z04_init_digdogger1(unsigned int slot) {
    RAM(0x0601) = 64;
    unsigned char rnd = RAM(0x0018 + slot) & 0x07;
    unsigned char dir = Directions8[rnd];
    RAM(0x0098 + slot) = dir;
    RAM(0x041F + slot) = 63;
    RAM(0x0437 + slot) = 0x80;
    RAM(0x0507) = 3;
}

void z04_end_init_flyer(unsigned int slot) {
    z04_reset_flyer_state(slot);
    RAM(0x04D1) = 0xA0;
    RAM(0x041F + slot) = 31;
}

void z04_init_digdogger2(unsigned int slot) {
    z04_init_digdogger1(slot);
    RAM(0x034F + slot) = 56;
    RAM(0x0507) = 1;
}

void z04_update_dodongo_bloated_sub_end(unsigned int slot) {
    z07_reset_obj_state(slot);
    RAM(0x042C + slot) = 0;
}

void z04_set_up_fairy_object(unsigned int slot) {
    RAM(0x0602) = 8;
    z04_reset_flyer_state(slot);
    RAM(0x0098 + slot) = 8;
    RAM(0x041F + slot) = 127;
    RAM(0x04D1) = 0xA0;
}

void z04_jumper_point_boulder_downward(unsigned int slot) {
    if (RAM(0x034F + slot) != 0x20)
        return;
    unsigned char dir = RAM(0x0098 + slot) & 0x03;
    RAM(0x0098 + slot) = dir | 0x04;
}

void z04_flyer_delay(unsigned int slot) {
    if (RAM(0x0028 + slot) == 0)
        RAM(0x0444 + slot) = 0;
}

void z04_manhandla_set_all_segments_direction(unsigned int val) {
    for (signed char i = 4; i >= 0; i--)
        RAM(0x0099 + (unsigned char)i) = (unsigned char)val;
}

unsigned int z04_extract_hit_point_value(unsigned int val) {
    if (RAM(0x0000) & 1)
        return (val << 4) & 0xFF;
    else
        return val & 0xF0;
}

void z04_reset_flyer_state(unsigned int slot) {
    RAM(0x0412 + slot) = 0;
    RAM(0x042C + slot) = 0;
    RAM(0x0437 + slot) = 0;
    RAM(0x0444 + slot) = 0;
    RAM(0x04F0 + slot) = 0;
}

void z04_reset_push_timer(unsigned int slot) {
    RAM(0x0412 + slot) = 0;
}

void z04_set_dead_dummy_obj_type(unsigned int slot) {
    RAM(0x034F + slot) = 93;
}

void z04_jumper_reset_vspeed_frac(unsigned int slot) {
    RAM(0x041F + slot) = 0;
}

void z04_gleeok_set_segment_y(unsigned int val3, unsigned int slot) {
    RAM(0x0086 + slot) = (unsigned char)val3;
}

void z04_init_monster_shot(unsigned int slot) {
    RAM(0x03BC + slot) = 0xC0;
    z07_reset_obj_metastate(slot);
}

void z04_init_boulder(unsigned int slot) {
    z07_reset_obj_metastate_and_timer(slot);
    z04_init_tektite(slot);
}

void z04_init_boulder_set(unsigned int slot) {
    RAM(0x0515) = 0;
    z04_init_boulder(slot);
}

void z04_play_boss_hit_cry_if_needed(unsigned int slot) {
    if (RAM(0x04F0 + slot) == 0x10)
        RAM(0x0601) = 2;
}

void z04_flyer_set_flying_state(unsigned int val, unsigned int slot) {
    RAM(0x0444 + slot) = (unsigned char)val;
}

extern void z04_play_boss_death_cry(void);

void z04_play_boss_death_cry_if_needed(unsigned int slot) {
    if (RAM(0x0405 + slot) == 0) return;
    z04_play_boss_death_cry();
}

extern void z07_destroy_monster(unsigned int slot);

void z04_destroy_monster_shot(unsigned int slot) {
    unsigned char type = RAM(0x034F + slot);
    if (type != 0x55 && type != 0x56)
        RAM(0x034C)--;
    z07_destroy_monster(slot);
}

void z04_destroy_counted_monster_shot(unsigned int slot) {
    RAM(0x034C)--;
    z07_destroy_monster(slot);
}

void z04_ganon_get_cur_cloud_bottom(unsigned int slot) {
    unsigned char y = RAM(0x0084 + slot);
    unsigned char dist = RAM(0x0478 + slot);
    RAM(0x0001) = (unsigned char)(y + dist);
}

void z04_ganon_get_cur_cloud_right(unsigned int slot) {
    unsigned char x = RAM(0x0070 + slot);
    unsigned char dist = RAM(0x0478 + slot);
    RAM(0x0000) = (unsigned char)(x + dist);
}

extern const unsigned char PolsVoiceWalkSpeedsX[];

void z04_pols_voice_move_x(unsigned int slot) {
    unsigned char dir_idx = RAM(0x0098 + slot) - 1;
    unsigned char pos = RAM(0x0070 + slot);
    unsigned char speed = PolsVoiceWalkSpeedsX[dir_idx];
    RAM(0x0070 + slot) = (unsigned char)(pos + speed);
}

void z04_init_blue_keese(unsigned int slot) {
    unsigned char rnd = RAM(0x0018 + slot) & 0x07;
    unsigned char dir = Directions8[rnd];
    RAM(0x0098 + slot) = dir;
    z04_reset_flyer_state(slot);
    RAM(0x04D1) = 0xC0;
    RAM(0x041F + slot) = 31;
}

void z04_init_red_or_black_keese(unsigned int slot) {
    z04_init_blue_keese(slot);
    RAM(0x041F + slot) = 127;
}

extern void z07_set_shove_info_with0(unsigned int val, unsigned int slot);

void z04_destroy_monster_bank4(unsigned int slot) {
    RAM(0x034F + slot) = 0;
    z07_set_shove_info_with0(0, slot);
    RAM(0x0028 + slot) = 0;
    RAM(0x00AC + slot) = 0;
    RAM(0x04F0 + slot) = 0;
    RAM(0x0492 + slot) = 0xFF;
    RAM(0x0405 + slot) = 1;
}

void z04_ganon_get_cur_cloud_left(unsigned int slot) {
    unsigned char x = RAM(0x0070 + slot);
    unsigned char dist = RAM(0x0478 + slot);
    RAM(0x0000) = (unsigned char)(x - dist);
}

void z04_ganon_get_cur_cloud_top(unsigned int slot) {
    unsigned char y = RAM(0x0084 + slot);
    unsigned char dist = RAM(0x0478 + slot);
    RAM(0x0001) = (unsigned char)(y - dist);
}

extern void z07_anim_advance_and_fetch(unsigned int val, unsigned int slot);
extern unsigned char z01_anim_set_sprite_desc_attrs(unsigned int val);

extern unsigned int z07_find_empty_monster_slot(void);
extern void z07_set_type_and_clear_object(unsigned int type, unsigned int slot);
extern void z07_reset_obj_metastate_and_timer(unsigned int slot);

void z04_shoot_fireball(unsigned int type, unsigned int source_slot) {
    RAM(0x0000) = (unsigned char)type;
    unsigned int new_slot = z07_find_empty_monster_slot();
    if (new_slot == 0) return;
    z07_set_type_and_clear_object(RAM(0x0000), new_slot);
    RAM(0x0070 + new_slot) = (unsigned char)(RAM(0x0070 + source_slot) + 4);
    RAM(0x0084 + new_slot) = RAM(0x0084 + source_slot);
}

void z04_wallmaster_prepare_to_draw(unsigned int slot) {
    static const unsigned char wallmaster_attrs[] = {
        0x01, 0x01, 0x08, 0x08, 0x08, 0x02, 0x02, 0x02,
        0xC1, 0xC1, 0xC4, 0xC4, 0xC4, 0xC2, 0xC2, 0xC2
    };
    z07_anim_advance_and_fetch(8, slot);
    unsigned char step = RAM(0x0412 + slot);
    unsigned char raw = wallmaster_attrs[step];
    unsigned char attrs = (raw & 0xF0) | 0x01;
    z01_anim_set_sprite_desc_attrs(attrs);
    if (raw & 0x40) {
        unsigned char cur = RAM(0x0004);
        z01_anim_set_sprite_desc_attrs(cur & 0x8F);
        RAM(0x000F)++;
    }
}

void z04_shoot_fireball_55(unsigned int source_slot) {
    z04_shoot_fireball(85, source_slot);
}

void z04_gohma_set_sprite_attributes(unsigned int slot) {
    unsigned char obj_type = RAM(0x034F + slot);
    unsigned char attrs = (unsigned char)(obj_type - 0x32);
    z01_anim_set_sprite_desc_attrs(attrs);
}

void z04_init_gohma(unsigned int slot) {
    RAM(0x0601) = 32;
    RAM(0x04B2 + slot) = 0xFB;
    RAM(0x0380 + slot)++;
    RAM(0x0070 + slot) = 0x80;
    RAM(0x0084 + slot) = 112;
    z07_reset_obj_metastate_and_timer(slot);
}

/* --- Carry-flag returning functions --- */

static const unsigned char SecretQuestNumbers[] = { 0x00, 0x00, 0x01 };

unsigned int z04_is_quest_secret_mismatch(void) {
    unsigned char val = RAM(0x04CD) >> 6;
    if (val == 0)
        return 0;
    unsigned char quest_for_secret = SecretQuestNumbers[val];
    unsigned char slot = RAM(0x0016);
    unsigned char save_quest = RAM(0x062D + slot);
    if (quest_for_secret == save_quest)
        return 0;
    return CARRY_SET;
}

extern unsigned char z07_get_collidable_tile(unsigned int hotspot_offset, unsigned int slot);
extern unsigned char z07_get_collidable_tile_still(unsigned int slot);

unsigned int z04_pols_voice_get_colliding_tile(unsigned int slot) {
    z07_get_collidable_tile(0, slot);
    unsigned char tile = RAM(0x049E + slot);
    unsigned char threshold = RAM(0x034A);
    RAM(0x041F + slot) = tile;
    if (tile < threshold)
        return CARRY_SET;
    return (unsigned int)tile;
}

unsigned int z04_wizzrobe_get_base_collidable_tile(unsigned int slot) {
    z07_get_collidable_tile_still(slot);
    unsigned char tile = RAM(0x049E + slot);
    unsigned char threshold = RAM(0x034A);
    RAM(0x041F + slot) = tile;
    if (tile < threshold)
        return CARRY_SET;
    return (unsigned int)tile;
}

extern unsigned char z01_get_room_flag_uw_item_state(void);

void z04_init_gleeok_head(unsigned int slot) {
    z04_init_blue_keese(slot);
    RAM(0x04D1) = 0xE0;
    RAM(0x041F + slot) = 0xBF;
}

void z04_ganon_activate_room_item(void) {
    if (RAM(0x00BF) == 0)
        return;
    unsigned char item_state = z01_get_room_flag_uw_item_state();
    if (item_state != 0)
        return;
    RAM(0x00BF) = 0;
    RAM(0x0602) = 2;
}

unsigned int z04_shoot(void) {
    unsigned char shot_slot = RAM(0x0059);
    z07_set_type_and_clear_object(RAM(0x0000), shot_slot);
    unsigned char thrower = RAM(0x0340);
    RAM(0x00AC + shot_slot) = 16;
    RAM(0x0028 + shot_slot) = 0;
    RAM(0x0098 + shot_slot) = RAM(0x0098 + thrower);
    RAM(0x0070 + shot_slot) = RAM(0x0070 + thrower);
    RAM(0x0084 + shot_slot) = RAM(0x0084 + thrower);
    return CARRY_SET;
}

extern void z04_update_dodongo_bloated_sub_end(unsigned int slot);

void z04_flyer_keese_decide_state(unsigned int slot) {
    unsigned char rnd = RAM(0x0019 + slot);
    unsigned char state;
    if (rnd >= 0xA0)
        state = 2;
    else if (rnd >= 0x20)
        state = 3;
    else
        state = 4;
    z04_flyer_set_state_and_turns(state, slot);
}

void z04_flyer_peahat_decide_state(unsigned int slot) {
    unsigned char rnd = RAM(0x0018 + slot);
    unsigned char state;
    if (rnd >= 0xB0)
        state = 2;
    else if (rnd >= 0x20)
        state = 3;
    else
        state = 4;
    z04_flyer_set_state_and_turns(state, slot);
}

void z04_update_dodongo_state2_stunned(unsigned int slot) {
    unsigned char timer = RAM(0x003D + slot);
    if (timer == 1) {
        z04_update_dodongo_bloated_sub_end(slot);
        return;
    }
    if (timer == 0)
        RAM(0x003D + slot) = 32;
}

extern void z04_end_init_flyer(unsigned int slot);

void z04_init_peahat(unsigned int slot) {
    z07_reset_obj_metastate_and_timer(slot);
    RAM(0x0098 + slot) = 8;
    z04_end_init_flyer(slot);
}

unsigned int z04_pols_voice_is_square_walkable(unsigned int slot) {
    unsigned int result = z04_pols_voice_get_colliding_tile(slot);
    if (result & CARRY_SET)
        return CARRY_SET;
    unsigned char saved_x = RAM(0x0070 + slot);
    RAM(0x0070 + slot) = (unsigned char)(saved_x + 0x0E);
    unsigned char saved_y = RAM(0x0084 + slot);
    RAM(0x0084 + slot) = (unsigned char)(saved_y + 0x06);
    result = z04_pols_voice_get_colliding_tile(slot);
    RAM(0x0084 + slot) = saved_y;
    RAM(0x0070 + slot) = saved_x;
    return result;
}
