#include "weapon_runtime.h"


static unsigned char weprt_choose_offset_for_direction_h(unsigned char dir) {
    WORLD_TMP0 = 0;
    {
        unsigned char d = dir & 0x03;
        if (d == 0) {
            return 0;
        }
        if (d & 0x01) {
            return WORLD_TMP2;
        }
        return WORLD_TMP3;
    }
}

void weprt_place_weapon(unsigned char offset, unsigned int slot) {
    WORLD_TMP2 = offset;
    WORLD_TMP3 = 0xF0;
    {
        unsigned char player_dir = LINK_DIR;
        OBJ_DIR(slot) = player_dir;
        OBJ_X(slot) = (unsigned char)(LINK_X + weprt_choose_offset_for_direction_h(player_dir));
        OBJ_Y(slot) = (unsigned char)(LINK_Y + weprt_choose_offset_for_direction_h((unsigned char)(player_dir >> 2)));
    }
}

void weprt_place_weapon_for_player_state(unsigned int slot) {
    LINK_ACTION_TIMER = 16;
    weprt_place_weapon(16, slot);
}

void weprt_place_weapon_for_player_state_and_anim(unsigned int slot) {
    OBJ_ANIM_TIMER(0) = 1;
    weprt_place_weapon_for_player_state(slot);
}

void weprt_place_weapon_for_player_state_and_anim_and_weapon_state(unsigned char weapon_state, unsigned int slot) {
    OBJ_STATE(slot) = weapon_state;
    weprt_place_weapon_for_player_state_and_anim(slot);
}

void weprt_wield_bomb(unsigned int slot) {
    unsigned int use_slot;
    (void)slot;
    if (LINK_BOMB_COUNT == 0) {
        return;
    }
    use_slot = WEAPON_DRAW_SLOT_A;
    {
        unsigned char state16 = OBJ_STATE(WEAPON_DRAW_SLOT_A);
        if (state16 != 0 && (state16 & 0xF0) == 0x10) {
            use_slot = WEAPON_DRAW_SLOT_B;
            {
                unsigned char state17 = OBJ_STATE(WEAPON_DRAW_SLOT_B);
                if (state17 != 0 && (state17 & 0xF0) == 0x10) {
                    return;
                }
            }
        }
    }
    {
        unsigned int other_slot = use_slot ^ 1u;
        unsigned char other_state = OBJ_STATE(other_slot);
        if (other_state != 0 && other_state < 0x13) {
            return;
        }
    }
    LINK_BOMB_COUNT = (unsigned char)(LINK_BOMB_COUNT - 1u);
    SFX_COMBAT = 32;
    OBJ_MOVE_TIMER(use_slot) = 0;
    weprt_place_weapon_for_player_state_and_anim_and_weapon_state(17, use_slot);
}

unsigned int weprt_wield_candle(unsigned int slot) {
    unsigned int use_slot;
    (void)slot;
    use_slot = WEAPON_DRAW_SLOT_A;
    if (OBJ_STATE(WEAPON_DRAW_SLOT_A) != 0) {
        use_slot = WEAPON_DRAW_SLOT_B;
        if (OBJ_STATE(WEAPON_DRAW_SLOT_B) != 0) {
            return 0u;
        }
    }
    if (LINK_CANDLE_LEVEL == 1 && CANDLE_LIT_FLAG != 0) {
        return 0u;
    }
    CANDLE_LIT_FLAG = 1;
    OBJ_GRID_OFFSET(use_slot) = 0;
    OBJ_POS_FRAC(use_slot) = 0;
    OBJ_QSPD_FRAC(use_slot) = 32;
    OBJ_STATE(use_slot) = 33;
    z01_play_effect(4);
    OBJ_ANIM_TIMER(use_slot) = 4;
    weprt_place_weapon_for_player_state(use_slot);
    return 0u;
}
