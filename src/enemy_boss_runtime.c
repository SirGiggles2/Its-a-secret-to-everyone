#include "enemy_runtime_private.h"

static const unsigned char enrt_secret_quest_numbers[] = { 0x00, 0x00, 0x01 };

void enrt_dodongo_dec_bloated_timer(unsigned int slot) {
    ENEMY_BLOATED_TIMER(slot)--;
}

void enrt_gleeok_dec_head_timer(void) {
    ENEMY_GLEEOK_HEAD_TIMER--;
}

void enrt_gleeok_set_segment_x(unsigned int val, unsigned int slot) {
    ENEMY_GLEEOK_SEG_X(slot) = (unsigned char)val;
}

void enrt_flyer_set_state_and_turns(unsigned int state, unsigned int slot) {
    ENEMY_AI_STATE(slot) = (unsigned char)state;
    ENEMY_TURN_TIMER(slot) = 6;
}

void enrt_gleeok_contract_segment_x(unsigned int slot) {
    unsigned char cur_x = ENEMY_GLEEOK_SEG_X(slot);
    unsigned char target_x = ENEMY_GLEEOK_SEG_X_TARGET(slot);
    unsigned char new_x = (unsigned char)(cur_x + 2);
    if (cur_x < target_x)
        new_x = (unsigned char)(new_x - 4);
    z04_gleeok_set_segment_x(new_x, slot);
}

void enrt_gleeok_contract_segment_y(unsigned int slot) {
    unsigned char cur_y = ENEMY_GLEEOK_SEG_Y(slot);
    unsigned char target_y = ENEMY_GLEEOK_SEG_Y_TARGET(slot);
    unsigned char new_y = (unsigned char)(cur_y + 2);
    if (cur_y > target_y)
        new_y = (unsigned char)(new_y - 4);
    z04_gleeok_set_segment_y(new_y, slot);
}

void enrt_gleeok_contract_segment(unsigned int slot) {
    if (ENEMY_RNG_A(0) & 0x80)
        enrt_gleeok_contract_segment_y(slot);
    else
        enrt_gleeok_contract_segment_x(slot);
}

void enrt_check_boss_hit_reaction(unsigned int slot) {
    z04_play_boss_death_cry_if_needed(slot);
    z07_set_shove_info_with0(0, slot);
}

void enrt_anim_set_sprite_desc_level_palette_row(void) {
    z01_anim_set_sprite_desc_attrs(3);
}

void enrt_gleeok_ignore_segment(void) {}

void enrt_update_dodongo_state2_stunned(unsigned int slot) {
    unsigned char timer = ENEMY_STUN_TIMER(slot);
    if (timer == 1) {
        z04_update_dodongo_bloated_sub_end(slot);
        return;
    }
    if (timer == 0)
    ENEMY_STUN_TIMER(slot) = 32;
}

void enrt_init_dodongo(unsigned int slot) {
    ENEMY_SFX_BOSS_CRY = 32;
    ENEMY_DIR(slot) = (ENEMY_RNG_A(slot) < 0x80) ? 1u : 2u;
}

void enrt_init_aquamentus(unsigned int slot) {
    ENEMY_INVINCIBILITY(slot) = 0xE2;
    ENEMY_SFX_BOSS_CRY = 16;
    ENEMY_X(slot) = 0xB0;
    ENEMY_Y(slot) = 0x80;
}

void enrt_init_tektite(unsigned int slot) {
    unsigned char rnd = ENEMY_RNG_B(slot) & 0x03;
    unsigned char dir = TektiteStartingDirs[rnd];
    ENEMY_DIR(slot) = dir;
    ENEMY_MOVE_TIMER(slot) = (unsigned char)(dir << 2);
}

void enrt_ganon_randomize_location(unsigned int slot) {
    ENEMY_Y(slot) = 0xA0;
    ENEMY_X(slot) = GanonStartXs[ENEMY_CUR_SPRITE_ATTR_ROW & 0x01];
}

void enrt_jumper_point_boulder_downward(unsigned int slot) {
    if (ENEMY_TYPE(slot) != 0x20)
        return;
    ENEMY_DIR(slot) = (ENEMY_DIR(slot) & 0x03) | 0x04;
}

void enrt_manhandla_set_all_segments_direction(unsigned int val) {
    signed char i;
    for (i = 4; i >= 0; --i)
        ENEMY_MANHANDLA_SEG_DIR((unsigned char)i) = (unsigned char)val;
}

void enrt_set_dead_dummy_obj_type(unsigned int slot) {
    ENEMY_TYPE(slot) = 93;
}

void enrt_gleeok_set_segment_y(unsigned int val3, unsigned int slot) {
    ENEMY_GLEEOK_SEG_Y(slot) = (unsigned char)val3;
}

void enrt_init_gleeok_head(unsigned int slot) {
    z04_init_blue_keese(slot);
    ENEMY_MAX_AIR_SPEED = 0xE0;
    ENEMY_AIR_SPEED(slot) = 0xBF;
}

void enrt_ganon_activate_room_item(void) {
    if (ENEMY_LIFE(0) == 0)
        return;
    if (z01_get_room_flag_uw_item_state() != 0)
        return;
    ENEMY_LIFE(0) = 0;
    ENEMY_SFX_SECRET = 2;
}

void enrt_play_boss_hit_cry_if_needed(unsigned int slot) {
    if (ENEMY_HIT_REACTION(slot) == 0x10)
        ENEMY_SFX_BOSS_CRY = 2;
}

void enrt_ganon_get_cur_cloud_bottom(unsigned int slot) {
    ENEMY_SCRATCH_Y = (unsigned char)(ENEMY_Y(slot) + ENEMY_BOUNCE_FLAGS(slot));
}

void enrt_ganon_get_cur_cloud_right(unsigned int slot) {
    ENEMY_SCRATCH_X = (unsigned char)(ENEMY_X(slot) + ENEMY_BOUNCE_FLAGS(slot));
}

void enrt_ganon_get_cur_cloud_left(unsigned int slot) {
    ENEMY_SCRATCH_X = (unsigned char)(ENEMY_X(slot) - ENEMY_BOUNCE_FLAGS(slot));
}

void enrt_ganon_get_cur_cloud_top(unsigned int slot) {
    ENEMY_SCRATCH_Y = (unsigned char)(ENEMY_Y(slot) - ENEMY_BOUNCE_FLAGS(slot));
}

void enrt_pols_voice_move_x(unsigned int slot) {
    unsigned char dir_idx = ENEMY_DIR(slot) - 1;
    ENEMY_X(slot) = (unsigned char)(ENEMY_X(slot) + PolsVoiceWalkSpeedsX[dir_idx]);
}

void enrt_wallmaster_prepare_to_draw(unsigned int slot) {
    static const unsigned char wallmaster_attrs[] = {
        0x01, 0x01, 0x08, 0x08, 0x08, 0x02, 0x02, 0x02,
        0xC1, 0xC1, 0xC4, 0xC4, 0xC4, 0xC2, 0xC2, 0xC2
    };
    unsigned char step;
    unsigned char raw;
    unsigned char attrs;
    z07_anim_advance_and_fetch(8, slot);
    step = ENEMY_PUSH_TIMER(slot);
    raw = wallmaster_attrs[step];
    attrs = (raw & 0xF0) | 0x01;
    z01_anim_set_sprite_desc_attrs(attrs);
    if (raw & 0x40) {
        unsigned char cur = ENEMY_ATTR_SCRATCH;
        z01_anim_set_sprite_desc_attrs(cur & 0x8F);
        ENEMY_FRAME_FLAGS++;
    }
}

void enrt_gohma_set_sprite_attributes(unsigned int slot) {
    unsigned char obj_type = ENEMY_TYPE(slot);
    z01_anim_set_sprite_desc_attrs((unsigned char)(obj_type - 0x32));
}

void enrt_init_gohma(unsigned int slot) {
    ENEMY_SFX_BOSS_CRY = 32;
    ENEMY_INVINCIBILITY(slot) = 0xFB;
    ENEMY_BOSS_HP_PHASE(slot)++;
    ENEMY_X(slot) = 0x80;
    ENEMY_Y(slot) = 112;
    z07_reset_obj_metastate_and_timer(slot);
}

unsigned int enrt_shoot(void) {
    unsigned char shot_slot = ENEMY_NEXT_SHOT_SLOT;
    unsigned char thrower = ENEMY_THROWER_SLOT;
    z07_set_type_and_clear_object(ENEMY_SHOT_TYPE_SCRATCH, shot_slot);
    ENEMY_STATE_TIMER(shot_slot) = 16;
    ENEMY_MOVE_TIMER(shot_slot) = 0;
    ENEMY_DIR(shot_slot) = ENEMY_DIR(thrower);
    ENEMY_X(shot_slot) = ENEMY_X(thrower);
    ENEMY_Y(shot_slot) = ENEMY_Y(thrower);
    return CARRY_SET;
}

unsigned int enrt_extract_hit_point_value(unsigned int val) {
    if (ENEMY_SHOT_TYPE_SCRATCH & 1)
        return (val << 4) & 0xFF;
    return val & 0xF0;
}

unsigned char enrt_is_dark_room_bank4(unsigned int room_idx) {
    if (ENEMY_DARK_ROOM_FLAG == 0)
        return 0;
    return nes_ram[0x6000u + 0x0A7E + room_idx] & 0x80;
}

void enrt_init_digdogger1(unsigned int slot) {
    unsigned char rnd;
    ENEMY_SFX_BOSS_CRY = 64;
    rnd = ENEMY_RNG_A(slot) & 0x07;
    ENEMY_DIR(slot) = Directions8[rnd];
    ENEMY_AIR_SPEED(slot) = 63;
    ENEMY_FLAP_PHASE(slot) = 0x80;
    ENEMY_DIGDOGGER_COUNT = 3;
}

void enrt_init_digdogger2(unsigned int slot) {
    enrt_init_digdogger1(slot);
    ENEMY_TYPE(slot) = 56;
    ENEMY_DIGDOGGER_COUNT = 1;
}

void enrt_update_dodongo_state1_bloated_sub_die(unsigned int slot) {
    z07_update_dead_dummy(slot);
    enrt_play_boss_death_cry();
    enrt_update_dodongo_bloated_sub_end(slot);
}

void enrt_update_dodongo_bloated_sub_end(unsigned int slot) {
    z07_reset_obj_state(slot);
    ENEMY_TURN_TIMER(slot) = 0;
}

void enrt_play_boss_death_cry_if_needed(unsigned int slot) {
    if (ENEMY_METASTATE(slot) != 0)
        enrt_play_boss_death_cry();
}

unsigned int enrt_is_quest_secret_mismatch(void) {
    unsigned char val = ENEMY_SECRET_KIND >> 6;
    unsigned char quest_for_secret;
    unsigned char slot;
    unsigned char save_quest;
    if (val == 0)
        return 0;
    quest_for_secret = enrt_secret_quest_numbers[val];
    slot = SAVE_SLOT_INDEX;
    save_quest = SAVE_SLOT_QUEST(slot);
    if (quest_for_secret == save_quest)
        return 0;
    return CARRY_SET;
}

unsigned int enrt_pols_voice_get_colliding_tile(unsigned int slot) {
    unsigned char tile;
    z07_get_collidable_tile(0, slot);
    tile = ENEMY_COLLIDED_TILE(slot);
    ENEMY_AIR_SPEED(slot) = tile;
    if (tile < ENEMY_DUNGEON_TILE_FLOOR)
        return CARRY_SET;
    return (unsigned int)tile;
}

unsigned int enrt_wizzrobe_get_base_collidable_tile(unsigned int slot) {
    unsigned char tile;
    z07_get_collidable_tile_still(slot);
    tile = ENEMY_COLLIDED_TILE(slot);
    ENEMY_AIR_SPEED(slot) = tile;
    if (tile < ENEMY_DUNGEON_TILE_FLOOR)
        return CARRY_SET;
    return (unsigned int)tile;
}

unsigned int enrt_pols_voice_is_square_walkable(unsigned int slot) {
    unsigned char saved_x;
    unsigned char saved_y;
    unsigned int result = enrt_pols_voice_get_colliding_tile(slot);
    if (result & CARRY_SET)
        return CARRY_SET;
    saved_x = ENEMY_X(slot);
    saved_y = ENEMY_Y(slot);
    ENEMY_X(slot) = (unsigned char)(saved_x + 0x0E);
    ENEMY_Y(slot) = (unsigned char)(saved_y + 0x06);
    result = enrt_pols_voice_get_colliding_tile(slot);
    ENEMY_Y(slot) = saved_y;
    ENEMY_X(slot) = saved_x;
    return result;
}
