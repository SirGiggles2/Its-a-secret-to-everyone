#include "enemy_runtime_private.h"

void enrt_init_monster_shot(unsigned int slot) {
    ENEMY_WALK_SPEED(slot) = 0xC0;
    z07_reset_obj_metastate(slot);
}

void enrt_init_boulder(unsigned int slot) {
    z07_reset_obj_metastate_and_timer(slot);
    enrt_init_tektite(slot);
}

void enrt_init_boulder_set(unsigned int slot) {
    ENEMY_BOULDER_SET_COUNT = 0;
    enrt_init_boulder(slot);
}

void enrt_destroy_monster_shot(unsigned int slot) {
    unsigned char type = ENEMY_TYPE(slot);
    if (type != 0x55 && type != 0x56)
        ENEMY_SHOT_COUNT--;
    z07_destroy_monster(slot);
}

void enrt_destroy_counted_monster_shot(unsigned int slot) {
    ENEMY_SHOT_COUNT--;
    z07_destroy_monster(slot);
}

void enrt_destroy_monster_bank4(unsigned int slot) {
    ENEMY_TYPE(slot) = 0;
    z07_set_shove_info_with0(0, slot);
    ENEMY_MOVE_TIMER(slot) = 0;
    ENEMY_STATE_TIMER(slot) = 0;
    ENEMY_HIT_REACTION(slot) = 0;
    ENEMY_ALIVE_FLAG(slot) = 0xFF;
    ENEMY_METASTATE(slot) = 1;
}

void enrt_shoot_fireball(unsigned int type, unsigned int source_slot) {
    unsigned int new_slot;
    ENEMY_SHOT_TYPE_SCRATCH = (unsigned char)type;
    new_slot = z07_find_empty_monster_slot();
    if (new_slot == 0)
        return;
    z07_set_type_and_clear_object(ENEMY_SHOT_TYPE_SCRATCH, new_slot);
    ENEMY_X(new_slot) = (unsigned char)(ENEMY_X(source_slot) + 4);
    ENEMY_Y(new_slot) = ENEMY_Y(source_slot);
}

void enrt_shoot_fireball_55(unsigned int source_slot) {
    enrt_shoot_fireball(85, source_slot);
}

void enrt_update_candle(void) {
    unsigned char state = ENEMY_CANDLE_STATE;
    if (state == 0) {
        if (enrt_is_dark_room_bank4(ENEMY_CANDLE_ROOM_ID) != 0) {
            ENEMY_CANDLE_FADE_TRIGGER = 0xC0;
            ENEMY_CANDLE_FADE_PHASE++;
            ENEMY_CANDLE_STATE++;
        }
    } else if (state == 1) {
        if (z01_animate_world_fading() == 0) {
            ENEMY_CANDLE_FADE_PHASE = 0;
            ENEMY_CANDLE_STATE++;
        }
    }
}

void enrt_update_boulder_set(unsigned int slot) {
    if (ENEMY_MOVE_TIMER(slot) != 0) {
        ENEMY_MOVE_TIMER(slot) = (unsigned char)(ENEMY_MOVE_TIMER(slot) + ENEMY_RNG_B(slot));
        return;
    }
    if (ENEMY_BOULDER_SET_COUNT == 3) {
        ENEMY_MOVE_TIMER(slot) = (unsigned char)(ENEMY_MOVE_TIMER(slot) + ENEMY_RNG_B(slot));
        return;
    }
    {
        unsigned int new_slot = z07_find_empty_monster_slot();
        if (new_slot == 0)
            return;

        ENEMY_BOULDER_SET_COUNT++;
        z07_set_type_and_clear_object(32, new_slot);

        {
            unsigned char rng = ENEMY_RNG_B(new_slot);
            if (LINK_X >= 0x80)
                rng |= 0x80;
            else
                rng &= 0x7F;
            ENEMY_X(new_slot) = rng;
        }
        ENEMY_Y(new_slot) = 64;
    }
    ENEMY_MOVE_TIMER(slot) = (unsigned char)((8 + ENEMY_RNG_B(slot)) & 0x1F);
}
