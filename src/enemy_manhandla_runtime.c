#include "enemy_runtime_private.h"
#include "combat_state.h"
#include "room_state.h"
#include "sprite_state.h"

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
