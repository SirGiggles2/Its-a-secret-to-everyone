#include "enemy_runtime_private.h"

static const unsigned char enrt_secret_quest_numbers[] = { 0x00, 0x00, 0x01 };
static const unsigned char enrt_vire_jump_offsets[] = {
    0x00, 0xFD, 0xFE, 0xFF, 0xFF, 0x00, 0xFF, 0x00,
    0x00, 0x01, 0x00, 0x01, 0x01, 0x02, 0x03, 0x00
};
static const unsigned char enrt_statue_room_layouts[] = { 0x24, 0x23 };
static const unsigned char enrt_statue_fireball_counts[] = { 0x03, 0x01, 0x01 };
static const unsigned char enrt_statue_fireball_start_times[] = { 0x50, 0x80, 0xF0, 0x60 };
static const unsigned char enrt_statue_pattern_base_index[] = { 0x00, 0x04, 0x06 };
static const unsigned char enrt_statue_xs[] = { 0x24, 0xC8, 0x24, 0xC8, 0x64, 0x88, 0x48, 0xA8 };
static const unsigned char enrt_statue_ys[] = { 0xC0, 0xBC, 0x64, 0x5C, 0x94, 0x8C, 0x82, 0x86 };
static const unsigned char enrt_jumper_y_offsets[] = { 0x00, 0x00, 0x00, 0x00, 0x00, 0x20, 0x20, 0x00, 0x00, 0xE0, 0xE0 };
static const unsigned char enrt_jumper_y_accelerations[] = {
    0x00, 0x40, 0x40, 0x00, 0x00, 0x40, 0x40, 0x00, 0x00, 0x30, 0x30,
    0x00, 0x80, 0x80, 0x00, 0x00, 0x80, 0x80, 0x00, 0x00, 0x50, 0x50,
    0x60, 0x60, 0x60, 0x60, 0x60, 0x60, 0x60
};
static const signed char enrt_jumper_start_speeds_hi[] = { -3, -4, -2 };
static const unsigned char enrt_jumper_y_accel_base_offsets[] = { 0x00, 0x0B, 0x16 };

static unsigned char enrt_jumper_get_kind(unsigned int slot) {
    unsigned char obj_type = ENEMY_TYPE(slot);
    if (obj_type == 0x0D)
        return 0;
    if (obj_type == 0x0E)
        return 1;
    return 2;
}

static void enrt_jumper_move_y(unsigned char accel, signed char max_speed_hi,
                               unsigned int slot) {
    unsigned int sum;
    signed char speed_hi;

    ENEMY_Y(slot) = (unsigned char)(ENEMY_Y(slot) + ENEMY_JUMPER_VSPEED_HI(slot));

    sum = (unsigned int)ENEMY_JUMPER_VSPEED_LO(slot) + (unsigned int)accel;
    ENEMY_JUMPER_VSPEED_LO(slot) = (unsigned char)sum;
    ENEMY_JUMPER_VSPEED_HI(slot) =
        (unsigned char)(ENEMY_JUMPER_VSPEED_HI(slot) + (unsigned char)(sum >> 8));

    speed_hi = (signed char)ENEMY_JUMPER_VSPEED_HI(slot);
    if (speed_hi < max_speed_hi)
        return;
    if (ENEMY_JUMPER_VSPEED_LO(slot) < 0x80)
        return;
    ENEMY_JUMPER_VSPEED_HI(slot) = (unsigned char)max_speed_hi;
}

static void enrt_jumper_animate_and_check_collisions(unsigned int slot) {
    unsigned char frame;

    z07_anim_fetch_obj_pos(slot);
    if (ENEMY_TYPE(slot) != 0x20) {
        frame = 0;
        if (ENEMY_STATE_TIMER(slot) != 0 || ENEMY_MOVE_TIMER(slot) < 0x21) {
            c_draw_object_mirrored_with_frame(frame, slot);
            c_check_monster_collisions(slot);
            return;
        }
        c_anim_advance_and_fetch(16, slot);
        frame = ENEMY_DRAW_FRAME(slot);
        c_draw_object_mirrored_with_frame(frame, slot);
        c_check_monster_collisions(slot);
        return;
    }

    c_anim_advance_and_fetch(6, slot);
    frame = ENEMY_DRAW_FRAME(slot);
    c_draw_object_not_mirrored_with_frame(frame, slot);
    z01_check_link_collision(slot);
    if (ENEMY_Y(slot) < 0xF0)
        return;
    ENEMY_BOULDER_SET_COUNT--;
    z07_destroy_monster(slot);
}

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

void enrt_update_tektite_or_boulder(unsigned int slot) {
    unsigned char dir;
    unsigned char obj_type;
    unsigned char kind;
    unsigned char accel_idx;
    unsigned char timer;
    unsigned char horiz_dir;
    unsigned char abs_dist;
    signed char x_step;

    if (ENEMY_JUMPER_SHOVE(slot) != 0) {
        enrt_jumper_animate_and_check_collisions(slot);
        return;
    }

    if ((ENEMY_PAUSE_FLAG | ENEMY_STUN_TIMER(slot)) != 0) {
        enrt_jumper_animate_and_check_collisions(slot);
        return;
    }

    if (ENEMY_STATE_TIMER(slot) == 0) {
        if (ENEMY_MOVE_TIMER(slot) != 0) {
            enrt_jumper_animate_and_check_collisions(slot);
            return;
        }

        c_turn_towards_player8();
        dir = ENEMY_DIR(slot);
        if ((dir & 0x03) == 0) {
            horiz_dir = 2;
            if (LINK_X < ENEMY_X(slot))
                horiz_dir = 1;
            ENEMY_DIR(slot) = (unsigned char)(dir | horiz_dir);
        }

        ENEMY_STATE_TIMER(slot)++;
    }

    if (ENEMY_JUMPER_REVERSALS(slot) >= 2) {
        ENEMY_DIR(slot) ^= 0x03;
        ENEMY_JUMPER_REVERSALS(slot) = 0;
    }

    enrt_jumper_point_boulder_downward(slot);
    dir = ENEMY_DIR(slot);
    ENEMY_JUMPER_TARGET_Y(slot) = (unsigned char)(ENEMY_Y(slot) + enrt_jumper_y_offsets[dir]);
    kind = enrt_jumper_get_kind(slot);
    ENEMY_JUMPER_VSPEED_HI(slot) = (unsigned char)enrt_jumper_start_speeds_hi[kind];
    enrt_jumper_reset_vspeed_frac(slot);

    if (ENEMY_STATE_TIMER(slot) == 0) {
        enrt_jumper_animate_and_check_collisions(slot);
        return;
    }

    c_bound_flyer(slot);
    if (ENEMY_JUMPER_BLOCKED_FLAG == 0) {
        ENEMY_JUMPER_REVERSALS(slot)++;
        enrt_jumper_point_boulder_downward(slot);
        dir = ENEMY_DIR(slot);
        ENEMY_JUMPER_TARGET_Y(slot) = (unsigned char)(ENEMY_Y(slot) + enrt_jumper_y_offsets[dir]);
        kind = enrt_jumper_get_kind(slot);
        ENEMY_JUMPER_VSPEED_HI(slot) = (unsigned char)enrt_jumper_start_speeds_hi[kind];
        enrt_jumper_reset_vspeed_frac(slot);
        enrt_jumper_animate_and_check_collisions(slot);
        return;
    }

    enrt_jumper_point_boulder_downward(slot);
    ENEMY_JUMPER_REVERSALS(slot) = 0;
    kind = enrt_jumper_get_kind(slot);
    accel_idx = (unsigned char)(enrt_jumper_y_accel_base_offsets[kind] + ENEMY_DIR(slot));
    enrt_jumper_move_y(enrt_jumper_y_accelerations[accel_idx], 2, slot);

    x_step = -1;
    if ((ENEMY_DIR(slot) & 0x02) == 0)
        x_step = 1;
    ENEMY_X(slot) = (unsigned char)(ENEMY_X(slot) + x_step);

    if ((signed char)ENEMY_JUMPER_VSPEED_HI(slot) < 0) {
        enrt_jumper_animate_and_check_collisions(slot);
        return;
    }

    abs_dist = z01_abs((unsigned char)(ENEMY_Y(slot) - ENEMY_JUMPER_TARGET_Y(slot)));
    if (abs_dist >= 3) {
        enrt_jumper_animate_and_check_collisions(slot);
        return;
    }

    (void)z07_reset_obj_state(slot);
    obj_type = ENEMY_TYPE(slot);
    if (obj_type == 0x20) {
        ENEMY_MOVE_TIMER(slot) = 0;
        enrt_jumper_animate_and_check_collisions(slot);
        return;
    }

    timer = (unsigned char)(ENEMY_RNG_B(slot) + 0x10);
    if (timer < 0x20)
        timer = (unsigned char)(timer - 0x40);

    if (obj_type != 0x0D) {
        timer &= 0x7F;
        if (ENEMY_RNG_B(slot) >= 0xA0)
            timer &= 0x0F;
    }

    ENEMY_MOVE_TIMER(slot) = timer;
    enrt_jumper_animate_and_check_collisions(slot);
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

void enrt_manhandla_check_collisions(unsigned int slot) {
    unsigned char saved_dir = ENEMY_DIR(slot);
    unsigned char saved_move_timer = ENEMY_MOVE_TIMER(slot);
    signed char hand_slot;
    unsigned char hand_count;

    c_check_monster_collisions(slot);
    ENEMY_MOVE_TIMER(slot) = saved_move_timer;
    ENEMY_DIR(slot) = saved_dir;

    if (slot == 5)
        ENEMY_HIT_REACTION(slot) = 0;

    c_play_boss_hit_cry_if_needed(slot);
    if (ENEMY_METASTATE(slot) == 0)
        return;

    c_reset_shove_info(slot);
    if (slot == 5)
        return;

    hand_count = 0;
    for (hand_slot = 3; hand_slot >= 0; --hand_slot) {
        if (ENEMY_TYPE((unsigned char)hand_slot) == 0x3C)
            hand_count++;
    }
    hand_count--;

    if (hand_count != 0) {
        ENEMY_TYPE(slot) = 93;
        ENEMY_MANHANDLA_SEGMENT_DIED_FLAG++;
        return;
    }

    c_play_boss_death_cry();
    ENEMY_TYPE(5) = 93;
    ENEMY_METASTATE(5) = 16;
    ENEMY_STATE_TIMER(5) = 16;
    ENEMY_MANHANDLA_SEGMENT_DIED_FLAG++;
}

void enrt_manhandla_move(unsigned int slot) {
    unsigned int speed_sum;
    unsigned char step;
    unsigned char dir = ENEMY_DIR(slot);
    unsigned int frame_sum;

    speed_sum = (unsigned int)ENEMY_PUSH_TIMER(slot)
              + ((unsigned int)ENEMY_AIR_SPEED(slot) & 0xE0u);
    ENEMY_PUSH_TIMER(slot) = (unsigned char)speed_sum;
    step = (unsigned char)(ENEMY_TURN_TIMER(slot) + (unsigned char)(speed_sum >> 8));

    if (dir & 0x01)
        ENEMY_X(slot) = (unsigned char)(ENEMY_X(slot) + step);
    if (dir & 0x02)
        ENEMY_X(slot) = (unsigned char)(ENEMY_X(slot) - step);
    if (dir & 0x04)
        ENEMY_Y(slot) = (unsigned char)(ENEMY_Y(slot) + step);
    if (dir & 0x08)
        ENEMY_Y(slot) = (unsigned char)(ENEMY_Y(slot) - step);

    frame_sum = (unsigned int)ENEMY_MANHANDLA_FRAME_ACCUM(slot)
              + (unsigned int)(ENEMY_RNG_B(slot) & 0x03)
              + (unsigned int)step;
    ENEMY_MANHANDLA_FRAME_ACCUM(slot) = (unsigned char)frame_sum;

    c_bound_flyer(slot);
    z07_anim_fetch_obj_pos(slot);
}

void enrt_manhandla_draw(unsigned int slot) {
    unsigned char frame_attrs;
    unsigned char frame_idx;

    z07_anim_fetch_obj_pos(slot);
    frame_attrs = ENEMY_MANHANDLA_FRAME_ATTR(slot);
    z01_anim_set_sprite_desc_attrs((unsigned char)((frame_attrs & 0x80) | 0x01));
    if (frame_attrs & 0x40)
        ENEMY_FRAME_FLAGS++;

    frame_idx = (unsigned char)(frame_attrs & 0x0F);
    if (frame_idx == 2 || frame_idx == 3) {
        c_draw_object_not_mirrored(slot);
        return;
    }
    c_draw_object_mirrored(slot);
}

static unsigned char enrt_rotate_dir_right(unsigned char dir) {
    dir = (unsigned char)(dir >> 1);
    if (dir == 0)
        dir = 8;
    return dir;
}

void enrt_lamnola_update_head(unsigned int slot) {
    unsigned char cur_dir;
    unsigned char chosen_dir;
    unsigned char rng;
    unsigned char horiz_dir;
    unsigned char vert_dir;
    unsigned char tile;
    unsigned char i;
    unsigned char chain_slot = 0;

    if ((ENEMY_X(slot) & 0x07) != 0)
        return;
    if ((((unsigned char)(ENEMY_Y(slot) + 3)) & 0x07) != 0)
        return;

    if (slot != 5)
        chain_slot = 5;
    for (i = 0; i < 4; ++i, ++chain_slot)
        ENEMY_MANHANDLA_SEG_DIR(chain_slot) = OBJ(0x009A, chain_slot);

    if ((ENEMY_X(slot) & 0x0F) != 0)
        return;
    if ((((unsigned char)(ENEMY_Y(slot) + 3)) & 0x0F) != 0)
        return;

    cur_dir = ENEMY_DIR(slot);
    ENEMY_LAMNOLA_VIABLE_DIR_MASK = (unsigned char)(0x0Fu ^ c_get_opposite_dir(cur_dir));

    if (ENEMY_RNG_A(slot) < 0x80) {
        horiz_dir = 1;
        if (ENEMY_PLAYER_OBJ_X < ENEMY_X(slot))
            horiz_dir = 2;
        vert_dir = 4;
        if (ENEMY_PLAYER_OBJ_Y < ENEMY_Y(slot))
            vert_dir = 8;
        chosen_dir = horiz_dir;
        if ((ENEMY_LAMNOLA_VIABLE_DIR_MASK & horiz_dir) == 0
         || (ENEMY_DIR(slot) & horiz_dir) == 0)
            chosen_dir = vert_dir;
    } else {
        chosen_dir = cur_dir;
        rng = ENEMY_RNG_B(slot);
        if (rng < 0x80) {
            for (;;) {
                chosen_dir = enrt_rotate_dir_right(chosen_dir);
                if ((ENEMY_LAMNOLA_VIABLE_DIR_MASK & chosen_dir) == 0)
                    continue;
                if (rng >= 0x40)
                    break;
                rng = 0x40;
            }
        }
    }

    for (;;) {
        ENEMY_DIR(slot) = chosen_dir;
        RAM(0x000F) = chosen_dir;
        if (c_bound_by_room(slot) != 0) {
            tile = c_get_colliding_tile_moving(slot);
            if (tile < ENEMY_DUNGEON_TILE_FLOOR)
                return;
        }

        chosen_dir = enrt_rotate_dir_right(chosen_dir);
        if ((ENEMY_LAMNOLA_VIABLE_DIR_MASK & chosen_dir) == 0)
            continue;
    }
}

void enrt_lamnola_move(unsigned int slot) {
    unsigned char dir = ENEMY_DIR(slot);
    unsigned char step = ENEMY_LAMNOLA_SPEED;

    if (dir & 0x01)
        ENEMY_X(slot) = (unsigned char)(ENEMY_X(slot) + step);
    if (dir & 0x02)
        ENEMY_X(slot) = (unsigned char)(ENEMY_X(slot) - step);
    if (dir & 0x04)
        ENEMY_Y(slot) = (unsigned char)(ENEMY_Y(slot) + step);
    if (dir & 0x08)
        ENEMY_Y(slot) = (unsigned char)(ENEMY_Y(slot) - step);
}

void enrt_update_vire_state(unsigned int slot) {
    if (ENEMY_STATE_TIMER(slot) != 0) {
        if (c_gel_move_splitting(slot) & CARRY_SET)
            ENEMY_STATE_TIMER(slot)++;
        return;
    }

    z04_update_common_wanderer(0x80, slot);
    if (ENEMY_PAUSE_FLAG != 0 || ENEMY_STUN_TIMER(slot) != 0)
        return;
    if ((ENEMY_DIR(slot) & 0x03) == 0)
        return;

    ENEMY_Y(slot) = (unsigned char)(ENEMY_Y(slot) + enrt_vire_jump_offsets[z01_abs(OBJ(0x0394, slot))]);
}

void enrt_check_vire_collisions(unsigned int slot) {
    if (ENEMY_STATE_TIMER(slot) != 0)
        return;

    c_check_monster_collisions(slot);
    if (ENEMY_METASTATE(slot) != 0)
        return;
    if (ENEMY_HIT_REACTION(slot) == 0)
        return;
    ENEMY_STATE_TIMER(slot)++;
}

void enrt_draw_vire(unsigned int slot) {
    unsigned char frame = ENEMY_DRAW_FRAME(slot);
    c_anim_advance_and_fetch(10, slot);
    if (ENEMY_DIR(slot) & 0x08)
        frame = (unsigned char)(frame + 2);
    c_draw_object_mirrored_with_frame(frame, slot);
}

void enrt_update_statues(void) {
    unsigned char pattern = 2;
    unsigned char source_slot;
    signed char fireball_idx;

    if (ENEMY_STATUE_PERSON_FIREBALLS == 0) {
        unsigned char room_id = z07_get_unique_room_id();
        pattern = 1;
        while (pattern != 0xFF) {
            if (enrt_statue_room_layouts[pattern] == room_id)
                break;
            pattern--;
        }
        if (pattern == 0xFF)
            return;
    }

    source_slot = c_find_empty_monster_slot();
    if (source_slot == 0 || source_slot < 6)
        return;

    for (fireball_idx = (signed char)enrt_statue_fireball_counts[pattern];
         fireball_idx >= 0;
         --fireball_idx) {
        unsigned char idx = (unsigned char)fireball_idx;
        unsigned char timer = (unsigned char)(ENEMY_STATUE_FIREBALL_TIMER(idx) - 1);
        ENEMY_STATUE_FIREBALL_TIMER(idx) = timer;
        if ((unsigned char)(timer + 1) != 0)
            continue;
        if (ENEMY_RNG_A(idx) >= 0xF0)
            continue;

        ENEMY_STATUE_FIREBALL_TIMER(idx) =
            enrt_statue_fireball_start_times[ENEMY_RNG_A(idx) & 0x03];

        {
            unsigned char pos_idx = (unsigned char)(idx + enrt_statue_pattern_base_index[pattern]);
            unsigned char fire_x = enrt_statue_xs[pos_idx];
            unsigned char fire_y = enrt_statue_ys[pos_idx];
            unsigned char mask = 3;

            ENEMY_X(source_slot) = fire_x;
            ENEMY_Y(source_slot) = fire_y;

            if ((unsigned char)(LINK_Y - fire_y) < 0x18 || (unsigned char)(LINK_Y - fire_y) >= 0xE8)
                mask = (unsigned char)(mask >> 1);
            if ((unsigned char)(LINK_X - fire_x) < 0x18 || (unsigned char)(LINK_X - fire_x) >= 0xE8)
                mask = (unsigned char)(mask >> 1);
            if (mask != 0)
                c_shoot_fireball(85, source_slot);
        }
    }
}

void enrt_update_vire(unsigned int slot) {
    unsigned char tries;

    enrt_update_vire_state(slot);
    if (ENEMY_STATE_TIMER(slot) < 2) {
        enrt_check_vire_collisions(slot);
        enrt_draw_vire(slot);
        return;
    }

    ENEMY_SHOT_COUNT++;
    z07_destroy_monster(slot);
    for (tries = 1; ; --tries) {
        if (c_find_empty_monster_slot() != 0) {
            ENEMY_VIRE_SPLIT_TYPE = 28;
            c_shoot(ENEMY_VIRE_SPLIT_TYPE);
        }
        if ((signed char)tries < 0)
            break;
    }
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

/*--------------------------------------------------------------------
 * UpdateGohma  (drained from z_04.asm:9160)
 *
 * Per-frame Gohma update. State machine has two parts:
 *   1. Movement: either pick a new random direction, or accumulate
 *      a 1/2-pixel speed and step ENEMY_X/Y by 1 in that direction.
 *      Every 0x20 pixels traveled, reverse direction; every other
 *      reversal randomizes the next direction.
 *   2. Eye animation: open eye timer drives an "open / half-open /
 *      closed" cycle. When the closed-eye anim cycle ticks over,
 *      flip between two closed-eye frames.
 *
 * Decrements a shoot timer; on rollover, fires fireball type 86.
 * Tail-calls Gohma_AnimateAndDraw + Gohma_CheckCollisions (asm).
 *------------------------------------------------------------------*/
void enrt_update_gohma(unsigned int slot) {
    unsigned char dir;
    unsigned char dist_mask;
    unsigned char accum;
    unsigned char open_eye;
    unsigned char eye_frame;

    if (ENEMY_GOHMA_GO_STRAIGHT(slot) == 0) {
        /* Pick a new direction based on RNG: >=0xB0 right, >=0x60 left, else down */
        unsigned char rng = ENEMY_RNG_A(slot);
        if (rng >= 0xB0)        dir = 1;       /* right */
        else if (rng >= 0x60)   dir = 2;       /* left */
        else                    dir = 4;       /* down */
        ENEMY_DIR(slot) = dir;
        ENEMY_GOHMA_GO_STRAIGHT(slot)++;
        goto animate_eye;
    }

    /* Movement accumulator add 0x80; only step when it overflows */
    accum = ENEMY_GOHMA_MOVE_ACCUM(slot);
    {
        unsigned int sum = (unsigned int)accum + 0x80u;
        ENEMY_GOHMA_MOVE_ACCUM(slot) = (unsigned char)sum;
        if (sum < 0x100u)
            goto animate_eye;
    }

    /* Step 1 pixel in each direction component, then check sprint distance */
    ENEMY_GOHMA_DIST_TRAVELED(slot)++;
    dir = ENEMY_DIR(slot);
    dist_mask = 1;
    if (dir & dist_mask) ENEMY_X(slot)++;          /* right */
    dist_mask <<= 1;
    if (dir & dist_mask) ENEMY_X(slot)--;          /* left */
    dist_mask <<= 1;
    if (dir & dist_mask) ENEMY_Y(slot)++;          /* down */
    dist_mask <<= 1;
    if (dir & dist_mask) ENEMY_Y(slot)--;          /* up */

    if (ENEMY_GOHMA_DIST_TRAVELED(slot) != 0x20)
        goto animate_eye;

    /* Sprinted 0x20 pixels: reset, reverse direction, count this sprint.
     * If the previous sprint count was odd, flag a random direction next. */
    ENEMY_GOHMA_DIST_TRAVELED(slot) = 0;
    c_reverse_obj_dir8(slot);
    {
        unsigned char prev_sprints = ENEMY_GOHMA_SPRINTS(slot);
        ENEMY_GOHMA_SPRINTS(slot)++;
        if (prev_sprints & 1)
            ENEMY_GOHMA_GO_STRAIGHT(slot) = 0;
    }

animate_eye:
    /* If the next-open-eye counter is 0, set the open-eye timer to 0x80
     * and reload the next-open-eye counter to (0xC0 | random). */
    if (ENEMY_GOHMA_NEXT_OPEN_EYE(slot) == 0) {
        ENEMY_GOHMA_OPEN_EYE_TIMER(slot) = 0x80;
        ENEMY_GOHMA_NEXT_OPEN_EYE(slot) =
            (unsigned char)(0xC0u | ENEMY_RNG_A(slot));
    }

    /* Decrement next-open-eye every other frame (driven by attr-row LSB) */
    if ((ENEMY_CUR_SPRITE_ATTR_ROW & 1) == 0)
        ENEMY_GOHMA_NEXT_OPEN_EYE(slot)--;

    open_eye = ENEMY_GOHMA_OPEN_EYE_TIMER(slot);
    if (open_eye == 0) {
        /* Closed-eye animation: count up; at 8, flip between frame 0 and 1.
         * If the counter is anywhere else, just leave the current eye frame
         * alone (the draw call below uses ENEMY_GOHMA_EYE_FRAME directly). */
        ENEMY_GOHMA_CLOSED_EYE_CNTR(slot)++;
        if (ENEMY_GOHMA_CLOSED_EYE_CNTR(slot) == 8) {
            ENEMY_GOHMA_CLOSED_EYE_CNTR(slot) = 0;
            eye_frame =
                (unsigned char)((ENEMY_GOHMA_EYE_FRAME(slot) & 0x01u) ^ 0x01u);
            ENEMY_GOHMA_EYE_FRAME(slot) = eye_frame;
        }
    } else {
        ENEMY_GOHMA_OPEN_EYE_TIMER(slot) = (unsigned char)(open_eye - 1);
        /* Frame 2 = fully open (timer in [0x10, 0x70)), else frame 3 = half */
        if (open_eye >= 0x70 || open_eye < 0x10)
            eye_frame = 2;
        else
            eye_frame = 3;
        ENEMY_GOHMA_EYE_FRAME(slot) = eye_frame;
    }
    (void)eye_frame;  /* suppress "set but not used" — value reread below */

    /* Decrement shoot timer; on rollover to 0, set to 0x41 and shoot 86 */
    ENEMY_GOHMA_SHOOT_TIMER(slot)--;
    if (ENEMY_GOHMA_SHOOT_TIMER(slot) == 0) {
        ENEMY_GOHMA_SHOOT_TIMER(slot) = 65;
        c_shoot_fireball(86, slot);
    }

    c_gohma_animate_and_draw((unsigned int)ENEMY_GOHMA_EYE_FRAME(slot), slot);
    c_gohma_check_collisions(slot);
}

/*--------------------------------------------------------------------
 * UpdateGleeok  (drained from z_04.asm:9623)
 *
 * Top-level per-frame Gleeok update.
 *   1. Draw the body sprite group.
 *   2. Compute neck count = ENEMY_TYPE - 0x42.
 *   3. For each living neck (bit not in dead-neck mask):
 *        - Fetch this neck's per-segment data array NES pointers.
 *        - LDA ($ptr),Y for Y in 5..0 to copy each segment's X/Y/misc
 *          bytes from external arrays into working slots 1..6.
 *        - One neck per frame (chosen by frame_tick & 3) actually moves
 *          and may try to shoot.
 *        - All necks then draw + check collisions.
 *        - Save per-segment data back through the same pointers.
 *------------------------------------------------------------------*/
static unsigned char gleeok_load_byte(unsigned int ptr_addr,
                                      unsigned int seg_index) {
    /* LDA (ptr),Y in NES RAM where ptr is at NES RAM[ptr_addr..ptr_addr+1]. */
    unsigned int ptr =
        (unsigned int)RAM(ptr_addr) | ((unsigned int)RAM(ptr_addr + 1) << 8);
    return nes_ram[ptr + seg_index];
}

static void gleeok_store_byte(unsigned int ptr_addr,
                              unsigned int seg_index,
                              unsigned char value) {
    unsigned int ptr =
        (unsigned int)RAM(ptr_addr) | ((unsigned int)RAM(ptr_addr + 1) << 8);
    nes_ram[ptr + seg_index] = value;
}

void enrt_update_gleeok(unsigned int slot) {
    unsigned char obj_type;
    int neck_index;
    int seg;

    c_gleeok_draw_body();

    obj_type = OBJ(NES_OBJ_TYPE, 1);            /* ($0350,A4) = type of slot 1 */
    ENEMY_GLEEOK_NECK_INDEX = (unsigned char)(obj_type - 0x42);

    for (neck_index = (int)(unsigned char)ENEMY_GLEEOK_NECK_INDEX;
         neck_index >= 0;
         neck_index--) {
        unsigned char level_bit;
        ENEMY_GLEEOK_NECK_INDEX = (unsigned char)neck_index;

        level_bit = LevelMasks[(unsigned char)neck_index];
        if (ENEMY_GLEEOK_DEAD_NECK_MASK & level_bit)
            continue;

        c_gleeok_fetch_neck_addrs();

        /* Load this neck's segment bytes from external NES arrays into the
         * working object slots (X→OBJ(0x70,1..6), Y→OBJ(0x84,1..6), misc→
         * RAM[0x0413+1..0x0413+6]). Loop seg = 5..0. */
        for (seg = 5; seg >= 0; seg--) {
            unsigned int s = (unsigned int)seg;
            RAM(0x0071 + s) = gleeok_load_byte(0x0000, s);
            RAM(0x0085 + s) = gleeok_load_byte(0x0002, s);
            RAM(0x0413 + s) = gleeok_load_byte(0x0004, s);
        }

        /* One neck per frame moves + may shoot; selected by frame_tick & 3. */
        {
            unsigned char chosen = (unsigned char)(ENEMY_CUR_SPRITE_ATTR_ROW & 0x03u);
            ENEMY_SHOT_TYPE_SCRATCH = chosen;       /* RAM[$00] */
            if ((unsigned char)slot == chosen) {
                c_gleeok_move_neck();
                c_gleeok_move_head();
                /* Switch focus to the head slot (5). If RNG <0x20 and slot
                 * 0xB has no fireball, shoot fireball 86. */
                {
                    unsigned int head_slot = 5;
                    unsigned char rng = ENEMY_RNG_A(head_slot);
                    if (rng < 0x20 && OBJ(NES_OBJ_TYPE, 0x0B) == 0)
                        c_shoot_fireball(86, head_slot);
                }
            }
        }

        c_gleeok_draw_head_and_check_collisions();

        /* Save segment data back to the external NES arrays. */
        c_gleeok_fetch_neck_addrs();
        for (seg = 5; seg >= 0; seg--) {
            unsigned int s = (unsigned int)seg;
            gleeok_store_byte(0x0000, s, RAM(0x0071 + s));
            gleeok_store_byte(0x0002, s, RAM(0x0085 + s));
            gleeok_store_byte(0x0004, s, RAM(0x0413 + s));
        }
    }
}

/*--------------------------------------------------------------------
 * L_Gleeok_StoreRefSegDistance  (drained from z_04.asm:9834)
 *
 * Continuation of Gleeok_MoveNeck: given the signed reference segment
 * distance (head→base divided by 4) in D0, this routine:
 *   1. Stores the signed dist into ENEMY_GLEEOK_REF_SEG_DIST.
 *   2. Computes 2nd & 3rd tier H/V reference limits via
 *      Gleeok_CalcSegmentLimits (axis=0 horizontal, axis=1 vertical).
 *   3. For each of segments 0..3, if the gap to the previous segment
 *      exceeds the 3rd-tier limit, pulls it 2 pixels closer (X then Y).
 *   4. Calls Gleeok_StretchNeck for segments 0..2.
 *   5. For each middle segment 2..0, computes the reference X coord
 *      (base_X + ref_dist * (i+1)) and nudges the segment's X by ±1
 *      toward it.
 *   6. For segments 4 and 3, keeps the segment's Y between its
 *      neighbors (slots 4-3 in OBJ(0x86)).
 *
 * The asm entry is reached by JMP from Gleeok_MoveNeck (and from
 * L_Gleeok_UDiv4) with D0 = signed reference distance.
 *------------------------------------------------------------------*/
void enrt_gleeok_store_ref_seg_distance(unsigned int signed_ref_dist) {
    unsigned int axis;
    unsigned int seg;
    unsigned char abs_dist;
    int i;

    ENEMY_GLEEOK_REF_SEG_DIST = (unsigned char)signed_ref_dist;

    /* Horizontal tier limits from |signed_ref_dist|. */
    abs_dist = z01_abs(signed_ref_dist);
    c_gleeok_calc_segment_limits((unsigned int)abs_dist, 0u);

    /* Vertical tier limits: |head_y - base_y| / 4. */
    abs_dist = z01_abs((unsigned int)(unsigned char)
                       (ENEMY_GLEEOK_HEAD_Y - ENEMY_GLEEOK_BASE_Y));
    abs_dist = (unsigned char)(abs_dist >> 2);
    c_gleeok_calc_segment_limits((unsigned int)abs_dist, 1u);

    /* Keep adjacent segments within the 3rd tier reference distance.
     * For each seg in [0..3], compute |prev_x - cur_x| and |prev_y - cur_y|
     * (slots 0..3 vs 1..4 mapped onto OBJ(0x71,seg) etc). When the gap
     * exceeds the limit, nudge cur 2 pixels toward prev. */
    for (seg = 0; seg < 4; seg++) {
        unsigned char prev_x = RAM(0x0071 + seg);
        unsigned char cur_x  = RAM(0x0072 + seg);
        unsigned char dx = z01_abs((unsigned int)(unsigned char)(prev_x - cur_x));
        unsigned char prev_y, cur_y, dy;

        if (dx >= ENEMY_GLEEOK_REF_LIMIT_H_3) {
            unsigned char new_x = (unsigned char)(cur_x + 2);
            if (cur_x >= prev_x)
                new_x = (unsigned char)(new_x - 4);
            RAM(0x0072 + seg) = new_x;
        }

        prev_y = RAM(0x0085 + seg);
        cur_y  = RAM(0x0086 + seg);
        dy = z01_abs((unsigned int)(unsigned char)(prev_y - cur_y));

        if (dy >= ENEMY_GLEEOK_REF_LIMIT_V_3) {
            unsigned char new_y = (unsigned char)(cur_y + 2);
            if (cur_y >= prev_y)
                new_y = (unsigned char)(new_y - 4);
            RAM(0x0086 + seg) = new_y;
        }
    }

    /* Stretch / contract per segment for segs 0..2. */
    for (seg = 0; seg < 3; seg++)
        c_gleeok_stretch_neck(seg);

    /* Pull each middle segment X toward its computed reference X
     * (base_X + ref_dist * (i+1)) by 1. */
    for (i = 2; i >= 0; i--) {
        unsigned char ref_x = ENEMY_GLEEOK_BASE_X;       /* OBJ(0x70, 1) */
        int j;
        for (j = i; j >= 0; j--)
            ref_x = (unsigned char)(ref_x + ENEMY_GLEEOK_REF_SEG_DIST);
        {
            unsigned char cur = RAM(0x0072 + (unsigned int)i);
            unsigned char nudged = (unsigned char)(cur + 1);
            if (cur >= ref_x)
                nudged = (unsigned char)(nudged - 2);
            RAM(0x0072 + (unsigned int)i) = nudged;
        }
    }

    /* Keep the Y of segments 4 and 3 (OBJ(0x87,1..2)) between their
     * vertical neighbors. The asm walks D2=1..0 over OBJ(0x86..0x88). */
    for (i = 1; i >= 0; i--) {
        unsigned char cur = RAM(0x0087 + (unsigned int)i);
        unsigned char above = RAM(0x0086 + (unsigned int)i);
        unsigned char below = RAM(0x0088 + (unsigned int)i);

        if (cur < above) {
            /* cur < above: if also cur < below, nudge up (++) toward middle */
            if (cur < below)
                RAM(0x0087 + (unsigned int)i)++;
        } else {
            /* cur >= above: if also cur >= below, nudge down (--) toward middle */
            if (cur >= below)
                RAM(0x0087 + (unsigned int)i)--;
        }
    }
}

/*--------------------------------------------------------------------
 * Gleeok_CheckCollisions  (drained from z_04.asm:10285)
 *
 * Per-segment collision step. Called with D2 = current segment slot
 * from Gleeok_DrawSegmentAndCheckCollisions; returns when slot drops
 * below 1 (whole loop done) or when the boss dies.
 *
 * For non-head/base segments (slot != 5 and != 1), no collision check;
 * just continue to the next segment.
 *
 * For head (slot 5) and base (slot 1):
 *   - CheckMonsterCollisions, set writhe + low anim cntr if hit.
 *   - ResetShoveInfo.
 *   - Base: ResetObjMetastate, continue.
 *   - Head/upper: PlayBossHitCryIfNeeded; if not killed, continue.
 *   - If head was killed: spawn a flying head in slot (neck+7),
 *     hide both head & base sprites, OR this neck into the dead mask,
 *     count dead necks; if all dead -> boss died.
 *
 * Loop continues by tail-call to Gleeok_DrawSegmentAndCheckCollisions
 * (which then JMPs back into here). We use bounded recursion (max 5
 * levels) which mirrors the asm tail-jump chain.
 *------------------------------------------------------------------*/
void enrt_gleeok_check_collisions(unsigned int slot) {
    unsigned int next_slot;

    if (slot != 5 && slot != 1)
        goto next_segment;

    c_check_monster_collisions(slot);

    /* ENEMY_OBJ_SHOVE_DIR != 0 means the segment was hit this frame */
    if (ENEMY_OBJ_SHOVE_DIR(slot) != 0) {
        ENEMY_GLEEOK_WRITHE_CNTR = 6;
        ENEMY_GLEEOK_ANIM_CNTR   = 6;
    }
    c_reset_shove_info(slot);

    /* The base segment can writhe but never dies. */
    if (slot == 1) {
        c_reset_obj_metastate(slot);
        goto next_segment;
    }

    c_play_boss_hit_cry_if_needed(slot);

    /* If the metastate didn't transition to "killed" yet, continue. */
    if (ENEMY_METASTATE(slot) == 0)
        goto next_segment;

    /* This neck died. Prepare to make a flying head. */
    ENEMY_CHARGE_SPEED(slot) = 96;
    {
        unsigned int saved_slot = slot;     /* mirrors PHA */
        unsigned int destroy_slot = slot;

        if (slot == 5) {
            /* Spawn a flying head in slot (neck_index + 7). */
            unsigned int flying = (unsigned int)
                (unsigned char)(ENEMY_GLEEOK_NECK_INDEX + 7);
            ENEMY_ALIVE_FLAG(flying) = 0xFF;       /* OBJ(0x0492) */
            ENEMY_X(flying) = ENEMY_GLEEOK_HEAD_X;
            ENEMY_Y(flying) = ENEMY_GLEEOK_HEAD_Y;
            OBJ(NES_OBJ_TYPE, flying) = 70;        /* type 0x46 = flying head */
        }

        destroy_slot = saved_slot;             /* PLA -> D2 */

        /* Hide the original head's sprite and the base segment's sprite.
         * sprite_offset = neck_index << 3; OAM bytes at $200 and $220. */
        {
            unsigned int sprite_off =
                (unsigned int)((unsigned char)(ENEMY_GLEEOK_NECK_INDEX << 3));
            RAM(0x0200 + sprite_off) = 0xF8;
            RAM(0x0220 + sprite_off) = 0xF8;
        }

        /* Add this neck's bit to the dead-neck mask, then count bits. */
        {
            unsigned char level_bit = LevelMasks[(unsigned char)ENEMY_GLEEOK_NECK_INDEX];
            unsigned char new_mask =
                (unsigned char)(ENEMY_GLEEOK_DEAD_NECK_MASK | level_bit);
            unsigned char shifter = new_mask;
            unsigned char dead_count = 0;
            int b;

            ENEMY_GLEEOK_DEAD_NECK_MASK = new_mask;

            for (b = 0; b < 4; b++) {
                if (shifter & 1u)
                    dead_count++;
                shifter = (unsigned char)(shifter >> 1);
            }

            /* Compare to original neck count (type - 0x41). */
            {
                unsigned char total_necks =
                    (unsigned char)(OBJ(NES_OBJ_TYPE, 1) - 0x41);
                if (dead_count == total_necks)
                    goto boss_died;
            }
        }

        c_reset_obj_metastate(destroy_slot);
        return;
    }

next_segment:
    if (slot < 1 || slot - 1 < 1)
        return;
    next_slot = slot - 1;
    c_gleeok_draw_segment_and_check_collisions(next_slot);
    return;

boss_died:
    /* Whole gleeok died. Hide the first 0x10 priority sprites, play death
     * cry, set metastate of slot 0 (well, monster slot 1's metastate base
     * cell) to 0x11 to spawn a death spark, and clear types of slots 2..9. */
    c_write_blank_priority_sprites();
    c_play_boss_death_cry();
    RAM(0x0406) = 17;
    {
        unsigned int s;
        for (s = 1; s < 0x0A; s++)
            OBJ(NES_OBJ_TYPE, s) = 0;
    }
}

/*====================================================================*
 * Dodongo family (drained from z_04.asm:6001+). The Dodongo boss
 * logic — collisions with the player's weapons, eating bombs (bloat
 * state machine), and the draw routine that picks frame images from
 * per-direction tables. Mouth/bomb hotspot limits live here as
 * ROM-equivalent constant tables.
 *====================================================================*/

/* Left-side mouth limits keyed by (direction >> 1).
 * 5-way direction index: 0=right, 1=left, 2=down, 3=unused, 4=up. */
static const unsigned char DodongoMouthNegativeLimits0[] = {
    0xF0, 0x00, 0xF8, 0xFF, 0xF8
};
static const unsigned char DodongoMouthPositiveLimits0[] = {
    0x00, 0x10, 0x08, 0xFF, 0x08
};
static const unsigned char DodongoMouthNegativeLimits1[] = {
    0xFC, 0xFC, 0xF0, 0xFF, 0x00
};
static const unsigned char DodongoMouthPositiveLimits1[] = {
    0x04, 0x04, 0x00, 0xFF, 0x10
};

/* Bomb hotspot limits indexed by D3 (0=dust cloud, 1=bomb). */
static const unsigned char DodongoBombPositiveLimits[] = { 0x0C, 0x11 };
static const unsigned char DodongoBombNegativeLimits[] = { 0xF4, 0xF0 };

/* 5-way direction index -> frame-image number.
 * Two animation frames: 0..4 and 5..9 (index 3 is unused/FF). */
static const unsigned char DodongoFrameImages[] = {
    0x00, 0x01, 0x06, 0xFF, 0x08,
    0x02, 0x03, 0x06, 0xFF, 0x08
};
static const unsigned char DodongoFrameHFlips[] = {
    0x00, 0x40, 0x00, 0xFF, 0x00,
    0x00, 0x40, 0x40, 0xFF, 0x40
};
static const unsigned char DodongoFrameImagesBloated[] = {
    0x04, 0x05, 0x07, 0xFF, 0x09,
    0x04, 0x05, 0x07, 0xFF, 0x09
};
static const unsigned char DodongoFrameHFlipsBloated[] = {
    0x00, 0x40, 0x00, 0xFF, 0x00,
    0x00, 0x40, 0x00, 0xFF, 0x00
};

/*--------------------------------------------------------------------
 * Dodongo_CheckCollisionsStandardSize (drained from z_04.asm:6052)
 *
 * Sets full invincibility ($FF), runs the shared monster-collision
 * pass, and — only when the Dodongo is stunned (state 2) — re-runs a
 * sword-only collision at the object middle. Damage counts 13 (bomb
 * shots inflict the sword-damage bit).
 *------------------------------------------------------------------*/
void enrt_dodongo_check_collisions_standard_size(unsigned int slot) {
    ENEMY_INVINCIBILITY(slot) = 0xFF;
    c_check_monster_collisions(slot);
    if (ENEMY_STATE_TIMER(slot) != 2)
        return;
    /* Stunned: allow sword hits only. */
    ENEMY_INVINCIBILITY(slot) = 0xFE;
    c_get_object_middle(slot);
    c_check_monster_sword_collision(slot, 13);
}

/*--------------------------------------------------------------------
 * Dodongo_CheckCollisions (drained from z_04.asm:6001)
 *
 * Runs the standard-size collision pass. If the Dodongo wasn't hurt
 * and it is facing horizontally (direction < 4), shifts the hitbox
 * right by $10 pixels and runs the pass again so both halves of the
 * long sprite can take hits. If either pass hurt it, dies via the
 * bloated sub-die path and drops a 10-bomb/10-rupee stash.
 *------------------------------------------------------------------*/
void enrt_dodongo_check_collisions(unsigned int slot) {
    enrt_dodongo_check_collisions_standard_size(slot);
    if (ENEMY_HIT_REACTION(slot) != 0)
        goto die;

    /* Vertical orientation (dir >= 4): no right-half recheck, return. */
    if (ENEMY_DIR(slot) >= 4)
        return;

    /* Save X, shift right $10, re-run, restore X. */
    {
        unsigned char saved_x = ENEMY_X(slot);
        ENEMY_X(slot) = (unsigned char)(saved_x + 0x10);
        enrt_dodongo_check_collisions_standard_size(slot);
        ENEMY_X(slot) = saved_x;
    }
    if (ENEMY_HIT_REACTION(slot) == 0)
        return;

die:
    enrt_update_dodongo_state1_bloated_sub_die(slot);
    /* Drop bomb-slot counters at RAM[$50]/[$51] = 10 (NES meta). */
    RAM(0x0050) = 10;
    RAM(0x0051) = 10;
}

/*--------------------------------------------------------------------
 * Dodongo_IsBombInRange (drained from z_04.asm:6270)
 *
 * Checks a bomb/dust-cloud hotspot against the monster's hotspot
 * stored at RAM[0]/[1] vs RAM[2]/[3]. Indexed by limit_idx (0=dust
 * cloud, 1=live bomb).
 *
 * Returns 0 when the bomb is in range on both axes (D0=0/Z=1 in the
 * NES convention); RAM[4]=dx, RAM[5]=dy when in-range on that axis.
 *------------------------------------------------------------------*/
unsigned int enrt_dodongo_is_bomb_in_range(unsigned int limit_idx) {
    unsigned char pos_limit = DodongoBombPositiveLimits[limit_idx & 1];
    unsigned char neg_limit = DodongoBombNegativeLimits[limit_idx & 1];
    unsigned char mask = 3;         /* bit 0 = Y close, bit 1 = X close */
    int axis;

    RAM(0x0006) = pos_limit;
    RAM(0x0007) = neg_limit;
    RAM(0x0008) = mask;

    /* axis=1 first (Y), then axis=0 (X) — matches 6502 LDY #1 / dey loop.
     * Scratch layout: RAM[0],[1] = monster X/Y; RAM[2],[3] = bomb X/Y. */
    for (axis = 1; axis >= 0; axis--) {
        unsigned char monster = RAM(0x0000 + axis);
        unsigned char bomb    = RAM(0x0002 + axis);
        signed char  dist     = (signed char)(monster - bomb);

        if ((signed char)dist >= (signed char)pos_limit)
            continue;
        if ((signed char)dist <  (signed char)neg_limit)
            continue;

        /* In-range on this axis. */
        RAM(0x0004 + axis) = (unsigned char)dist;
        mask = (unsigned char)(mask >> 1);
        RAM(0x0008) = mask;
    }
    /* mask == 0 means in-range on both axes; return it as the A reg. */
    return (unsigned int)RAM(0x0008);
}

/*--------------------------------------------------------------------
 * Dodongo_TryEatBomb (drained from z_04.asm:6168)
 *
 * Precondition: bomb is close enough for the coarse test. Checks
 * whether the bomb is near the mouth — the mouth position depends on
 * the Dodongo's orientation. On a match, advances to bloated state
 * (state_timer++), deactivates the bomb, and resets bloated substate.
 *
 * The 6502 version uses a tiny 1→0 loop over the two axes: first
 * horizontal, then vertical. For each axis it looks up signed
 * [neg_limit, pos_limit) for the 5-way direction index.
 *------------------------------------------------------------------*/
void enrt_dodongo_try_eat_bomb(unsigned int slot) {
    unsigned char dir_idx;
    int loop_counter;
    unsigned char dist;
    const unsigned char *neg_table = DodongoMouthNegativeLimits0;
    const unsigned char *pos_table = DodongoMouthPositiveLimits0;

    /* Coarse precheck (full sprite bounding). */
    if (enrt_dodongo_is_bomb_in_range(1) != 0)
        return;

    /* Loop counter in NES RAM[0]: starts at 1, decrements after each axis. */
    RAM(0x0000) = 1;
    loop_counter = 1;

    /* 5-way direction index for tables: dir >> 1. */
    dir_idx = (unsigned char)(ENEMY_DIR(slot) >> 1);

    /* First iteration: horizontal distance in RAM[4]. */
    dist = RAM(0x0004);
    for (;;) {
        if ((signed char)dist < (signed char)neg_table[dir_idx])
            return;
        if ((signed char)dist >= (signed char)pos_table[dir_idx])
            return;

        /* Advance to vertical table set (Mouth*1). */
        neg_table = DodongoMouthNegativeLimits1;
        pos_table = DodongoMouthPositiveLimits1;
        /* Load vertical distance and decrement loop counter. */
        dist = RAM(0x0005);
        RAM(0x0000) = (unsigned char)(--loop_counter);
        if (loop_counter < 0)
            break;
    }

    /* Bomb is in range of the mouth — advance to bloated state. */
    ENEMY_STATE_TIMER(slot)++;
    /* Deactivate first bomb slot (16) and reset bloated substate. */
    OBJ(0x00AC, 16) = 0;
    ENEMY_TURN_TIMER(slot) = 0;
}

/*--------------------------------------------------------------------
 * Dodongo_CheckBombHit (drained from z_04.asm:6092)
 *
 * When the Dodongo is in state 0 (moving), computes its mouth hotspot
 * (X+8 for vertical, X+$10 for horizontal; Y+8) and the first bomb's
 * hotspot (X+8, Y+8), then:
 *   - if bomb state == $12 (live): tail to TryEatBomb;
 *   - if bomb state >= $20 (fire): ignore;
 *   - else (dust cloud): if IsBombInRange(0) matches, stun (state=2).
 *------------------------------------------------------------------*/
void enrt_dodongo_check_bomb_hit(unsigned int slot) {
    unsigned char bomb_state;

    /* Only check while moving (state 0). */
    if (ENEMY_STATE_TIMER(slot) != 0)
        return;

    /* Monster hotspot: X + 8 (or +$10 for horizontal), Y + 8. */
    {
        unsigned char hx = (unsigned char)(ENEMY_X(slot) + 8);
        if (ENEMY_DIR(slot) < 4)
            hx = (unsigned char)(hx + 8);
        RAM(0x0000) = hx;
        RAM(0x0001) = (unsigned char)(ENEMY_Y(slot) + 8);
    }

    /* First bomb slot is fixed at $10 (16). */
    RAM(0x0002) = (unsigned char)(OBJ(NES_OBJ_X, 16) + 8);
    RAM(0x0003) = (unsigned char)(OBJ(NES_OBJ_Y, 16) + 8);

    bomb_state = OBJ(0x00AC, 16);
    if (bomb_state == 0)
        return;

    if (bomb_state == 0x12) {
        /* Live bomb — tail-call TryEatBomb. */
        enrt_dodongo_try_eat_bomb(slot);
        return;
    }
    if (bomb_state >= 0x20)
        return;

    /* Dust cloud from an exploded bomb: if it's in range, stun. */
    if (enrt_dodongo_is_bomb_in_range(0) != 0)
        return;
    ENEMY_STATE_TIMER(slot) = 2;
}

/*--------------------------------------------------------------------
 * Dodongo_Draw (drained from z_04.asm:6354)
 *
 * Picks an animation frame image from per-direction tables based on
 * state (0=walk, 1=bloated, 2=stunned) and draws the left half, and
 * — if facing horizontally — the right half at X+$10. The two frame
 * numbers come from DodongoFrameImages with an XOR-1 swap between
 * halves. Frame numbers 7 and 9 (vertical bloated images) are drawn
 * mirrored; others are drawn non-mirrored.
 *------------------------------------------------------------------*/
void enrt_dodongo_draw(unsigned int slot) {
    unsigned char dir_idx;      /* dir >> 1 — 5-way direction index. */
    unsigned char state;
    unsigned char turn_timer;   /* bloated substate when state==1. */
    unsigned char frame_index;  /* into DodongoFrameImages. */
    unsigned char frame_img;
    unsigned char mask_frames = 8;  /* default: switch every 8 frames. */
    unsigned char saved_frame_index;
    unsigned char saved_x;
    int draw_right_side = 0;

    enrt_anim_set_sprite_desc_level_palette_row();
    dir_idx = (unsigned char)(ENEMY_DIR(slot) >> 1);
    RAM(0x0000) = dir_idx;

    state = ENEMY_STATE_TIMER(slot);
    if (state == 0)
        goto draw_walking_fast;

    if (state > 1) {
        /* Stunned — switch every $20 frames. */
        mask_frames = 32;
        goto draw_walking;
    }

    /* state == 1 (bloated). */
    turn_timer = ENEMY_TURN_TIMER(slot);
    if (turn_timer == 0)
        goto draw_walking_fast;      /* substate 0: walk animation. */
    if (turn_timer == 2 || turn_timer == 3)
        goto draw_faded;

    /* State 1 substate 1 — bloated still frame set. */
    frame_index = (unsigned char)(dir_idx + 0x14);
    goto prepare_to_draw;

draw_faded:
    /* Every 2 frames, skip drawing for 2 frames. */
    if ((ENEMY_CUR_SPRITE_ATTR_ROW & 0x02) == 0)
        return;
    frame_index = dir_idx;
    goto prepare_to_draw;

draw_walking_fast:
    mask_frames = 8;
draw_walking:
    frame_index = dir_idx;
    if ((ENEMY_CUR_SPRITE_ATTR_ROW & mask_frames) != 0)
        frame_index = (unsigned char)(frame_index + 5);
    /* fall through */

prepare_to_draw:
    z07_anim_fetch_obj_pos(slot);
    saved_frame_index = frame_index;

    /* Left-half flip + frame image lookup. */
    if (frame_index >= 0x14) {
        ENEMY_FRAME_FLAGS = DodongoFrameHFlipsBloated[frame_index - 0x14];
        frame_img = DodongoFrameImagesBloated[frame_index - 0x14];
    } else {
        ENEMY_FRAME_FLAGS = DodongoFrameHFlips[frame_index];
        frame_img = DodongoFrameImages[frame_index];
    }

    /* Frame images 7 and 9 are vertical bloated frames drawn mirrored. */
    if (frame_img == 7 || frame_img == 9) {
        c_draw_object_mirrored_with_frame((unsigned int)frame_img, slot);
        draw_right_side = 1;
    } else {
        c_draw_object_not_mirrored_with_frame((unsigned int)frame_img, slot);
    }
    (void)draw_right_side;  /* both paths fall through to right-half logic. */

    /* If facing vertically, skip the right-side draw. */
    if ((ENEMY_DIR(slot) & 3) == 0)
        return;

    /* Right half: shift X by $10 and draw with the frame-XOR-1 image.
     * The H-flip already applied on the left half carries over. */
    saved_x = ENEMY_X(slot);
    ENEMY_X(slot) = (unsigned char)(saved_x + 0x10);
    enrt_anim_set_sprite_desc_level_palette_row();
    if (saved_frame_index >= 0x14)
        frame_img = DodongoFrameImagesBloated[saved_frame_index - 0x14];
    else
        frame_img = DodongoFrameImages[saved_frame_index];
    c_draw_object_not_mirrored_with_frame(
        (unsigned int)(frame_img ^ 0x01u), slot);
    ENEMY_X(slot) = saved_x;
}
