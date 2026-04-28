#include "enemy_runtime_private.h"
#include "legacy_bridge.h"
#include "combat_state.h"
#include "room_state.h"
#include "sprite_state.h"
#include "enemy_gleeok_runtime.h"
#include "enemy_dodongo_runtime.h"
#include "enemy_manhandla_runtime.h"
#include "enemy_lamnola_runtime.h"

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

void enrt_flyer_set_state_and_turns(unsigned int state, unsigned int slot) {
    ENEMY_AI_STATE(slot) = (unsigned char)state;
    ENEMY_TURN_TIMER(slot) = 6;
}

void enrt_check_boss_hit_reaction(unsigned int slot) {
    z04_play_boss_death_cry_if_needed(slot);
    z07_set_shove_info_with0(0, slot);
}

void enrt_anim_set_sprite_desc_level_palette_row(void) {
    z01_anim_set_sprite_desc_attrs(3);
}

void enrt_init_aquamentus(unsigned int slot) {
    ENEMY_INVINCIBILITY(slot) = 0xE2;
    ENEMY_SFX_BOSS_CRY = 16;
    ENEMY_X(slot) = 0xB0;
    ENEMY_Y(slot) = 0x80;
}

void enrt_update_aquamentus(unsigned int slot) {
    if (ENEMY_PAUSE_FLAG == 0) {
        c_aquamentus_move(slot);
        c_aquamentus_shoot(slot);
    }
    c_aquamentus_draw(slot);
    c_check_monster_collisions(slot);
    enrt_play_boss_hit_cry_if_needed(slot);
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

/*====================================================================*
 * Gohma family
 *====================================================================*/

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
