#include "uw_person_runtime.h"
#include "legacy_bridge.h"
#include "cave_state.h"
#include "object_state.h"
#include "room_state.h"
#include "combat_state.h"
#include "item_state.h"
#include "link_state.h"
#include "enemy_state.h"
#include "progress_state.h"


static unsigned char uwrt_compare_hearts_to_containers(void) {
    unsigned char hearts = LINK_HEARTS;
    unsigned char filled = hearts & 0x0F;
    CAVE_TMP0 = filled;
    return hearts >> 4;
}

static void uwrt_complex_state_begin(void) {
    unsigned char obj = CAVE_ROOM_TYPE;
    if (obj == 0x4F)
        ROOM_TRANSFER_BUF_SELECT = 108;
    CAVE_DELAY_TIMER = 10;
    CAVE_PERSON_STATE++;
}

void uwrt_person_draw_and_check_collisions(unsigned int slot) {
    uwrt_person_check_collisions(slot);
    z07_anim_fetch_obj_pos(slot);
    c_draw_object_mirrored(slot);
}

void uwrt_init_underworld_person_b(unsigned int slot) {
    static const unsigned char text_selectors[] = {0x2A, 0x38, 0x3A, 0x2C, 0x40, 0x42, 0x42, 0x3C};
    unsigned char obj_type;
    unsigned char idx;
    z01_set_up_common_cave_objects(120, slot, 0x80);
    obj_type = OBJ_TYPE(slot);
    idx = (unsigned char)(obj_type - 0x4B);
    CAVE_TEXT_SELECTOR = text_selectors[idx];
    z01_play_character_sfx();
}

void uwrt_init_underworld_person_c(unsigned int slot) {
    unsigned char obj_type;
    unsigned char idx;
    z01_set_up_common_cave_objects(120, slot, 0x80);
    z01_play_character_sfx();
    obj_type = OBJ_TYPE(slot);
    idx = (unsigned char)(obj_type - 0x4B);
    CAVE_TEXT_SELECTOR = UnderworldPersonTextSelectorsC[idx];
    if (obj_type != 0x4B)
        return;
    if (RAM(0x0671) != 0xFF)
        return;
    ROOM_SHUTTER_TRIGGERED = 1;
    OBJ_STATE(0) = 0;
    z07_destroy_monster(slot);
}

void uwrt_init_grumble_full(unsigned int slot) {
    unsigned char item_state;
    z01_set_up_common_cave_objects(120, slot, 0x80);
    CAVE_TEXT_SELECTOR = 36;
    CAVE_TEXT_LINE_ADDR_LO = TextboxLineAddrsLo[2];
    item_state = z01_get_room_flag_uw_item_state();
    if (item_state == 0) {
        z01_play_character_sfx();
        return;
    }
    OBJ_STATE(0) = 0;
    CAVE_ROOM_TYPE = 0;
}

void uwrt_init_rupee_stash_full(unsigned int slot) {
    unsigned char i;
    (void)slot;
    CAVE_TMP1 = MON_STATUS_FLAGS(slot);
    CAVE_TMP0 = 53;
    for (i = 10; i >= 1; --i) {
        z01_init_one_simple_object(i);
        OBJ_TILE_X(i) = RupeeStashXs[i - 1];
        OBJ_TILE_Y(i) = RupeeStashYs[i - 1];
    }
}

void uwrt_update_life_or_money_state_0(void) {
    CAVE_DELAY_TIMER = 10;
    z01_cue_transfer_buf_and_advance_state(118);
}

void uwrt_underworld_person_destroy_if_taken(unsigned int slot) {
    unsigned char item_state = z01_get_room_flag_uw_item_state();
    if (item_state == 0) {
        z01_play_character_sfx();
        return;
    }
    OBJ_STATE(0) = 0;
    z07_destroy_monster(slot);
}

void uwrt_init_life_or_money_full(unsigned int slot) {
    z01_set_up_common_cave_objects(120, slot, 0x80);
    CAVE_TEXT_SELECTOR = 54;
    CAVE_TEXT_LINE_ADDR_LO = TextboxLineAddrsLo[2];
    uwrt_underworld_person_destroy_if_taken(slot);
}

void uwrt_person_flag_item_taken_and_advance_state(void) {
    z01_set_room_flag_uw_item_state();
    CAVE_DELAY_TIMER = 64;
    z01_cue_transfer_buf_and_advance_state(30);
}

void uwrt_check_person_blocking(void) {
    if (OBJ_TILE_Y(0) >= 0x8E)
        return;
    if ((LINK_MOVING_DIR & 0x08) == 0)
        return;
    z07_reset_moving_dir();
}

void uwrt_update_grumble1(void) {
    unsigned char val = OBJ_STATE(15);
    if ((val & 0x80) == 0)
        return;
    OBJ_STATE(0) = 64;
    ITEM_SFX_PRIMARY = 4;
    uwrt_person_flag_item_taken_and_advance_state();
}

void uwrt_init_underworld_person_a(unsigned int slot) {
    unsigned char idx;
    z01_set_up_common_cave_objects(120, slot, 0x80);
    idx = (unsigned char)(OBJ_TYPE(slot) - 0x4B);
    CAVE_TEXT_SELECTOR = UnderworldPersonTextSelectorsA[idx];
    if (CAVE_ROOM_TYPE == 0x4F) {
        uwrt_underworld_person_destroy_if_taken(slot);
        return;
    }
    z01_play_character_sfx();
}

void uwrt_update_complex_state_sense_link(void) {
    unsigned char ydiff;
    unsigned char max_bombs;
    if (CAVE_ROOM_TYPE != 0x4F)
        return;
    if (OBJ_TILE_X(0) != 0x78)
        return;
    ydiff = (unsigned char)(OBJ_TILE_Y(0) - 0x98);
    if (z01_abs((unsigned int)ydiff) >= 6)
        return;
    if (LINK_RUPEES < 100)
        return;
    CAVE_DOOR_REPAIR_RUPEE_DELTA = (unsigned char)(100 + CAVE_DOOR_REPAIR_RUPEE_DELTA);
    ROOM_SFX_MAIN = 8;
    max_bombs = (unsigned char)(LINK_MAX_HEARTS + 4);
    LINK_MAX_HEARTS = max_bombs;
    LINK_BOMB_COUNT = max_bombs;
    uwrt_person_flag_item_taken_and_advance_state();
}

void uwrt_update_life_or_money_state_2(void) {
    int i;
    for (i = 1; i >= 0; --i) {
        unsigned char ydiff;
        if (OBJ_TILE_X(0) != LifeOrMoneyItemXs[i])
            continue;
        ydiff = (unsigned char)(OBJ_TILE_Y(0) - 0x98);
        if (z01_abs((unsigned int)ydiff) >= 6)
            continue;
        if (i != 0) {
            if (LINK_RUPEES < 50)
                return;
            CAVE_DOOR_REPAIR_RUPEE_DELTA = (unsigned char)(50 + CAVE_DOOR_REPAIR_RUPEE_DELTA);
        } else {
            unsigned char hearts = LINK_HEARTS;
            unsigned char containers = hearts & 0xF0;
            if (containers >= 0x30) {
                unsigned char new_cont = (unsigned char)(containers - 0x10);
                int partial = (int)(hearts & 0x0F) - 1;
                CAVE_TMP0 = new_cont;
                if (partial < 0)
                    partial = 0;
                LINK_HEARTS = new_cont | (unsigned char)partial;
            } else {
                LINK_HEARTS = containers;
                LINK_PARTIAL_HEART = 0;
            }
        }
        ROOM_SFX_MAIN = 8;
        ROOM_SHUTTER_TRIGGERED = 1;
        uwrt_person_flag_item_taken_and_advance_state();
        return;
    }
}

void uwrt_person_check_collisions(unsigned int slot) {
    unsigned char killed;
    c_check_monster_collisions(slot);
    killed = ROOM_OBJ_STUN_TIMER(0);
    if (killed) {
        ENEMY_STATUE_PERSON_FIREBALLS = killed;
        ROOM_OBJ_STUN_TIMER(0) = 0;
    }
}

void uwrt_draw_life_or_money_items(void) {
    int i;
    for (i = 1; i >= 0; --i) {
        RAM(0x0083) = LifeOrMoneyItemXs[i];
        RAM(0x0097) = 0x98;
        c_animate_item_object(LifeOrMoneyItemTypes[i], 19);
    }
}

void uwrt_update_grumble3(void) {
    c_link_end_move_and_animate_bank1();
    if (CAVE_DELAY_TIMER != 0) {
        z01_init_underworld_person_do_nothing();
        return;
    }
    OBJ_STATE(15) = 0;
    RAM(0x065D) = 0;
    OBJ_STATE(0) = 0;
    CAVE_ROOM_TYPE = 0;
    z01_init_underworld_person_do_nothing();
}

void uwrt_update_person_complex(unsigned int slot) {
    unsigned char state = CAVE_PERSON_STATE;
    if (state != 4 || (FRAME_COUNTER & 1) == 0) {
        uwrt_person_draw_and_check_collisions(slot);
        if (CAVE_ROOM_TYPE == 0x4F) {
            RAM(0x0083) = 120;
            RAM(0x0097) = 0x98;
            c_animate_item_object(24, 19);
        }
    }
    switch (CAVE_PERSON_STATE) {
        case 0: uwrt_complex_state_begin(); break;
        case 1: c_update_person_state_textbox(); break;
        case 2: uwrt_update_complex_state_sense_link(); break;
        case 3: z01_cue_transfer_blank_person_wares(); break;
        case 4: z01_uw_person_complex_state_delay_and_quit(); break;
    }
}

void uwrt_update_person_full(unsigned int slot) {
    unsigned char level = CUR_LEVEL;
    if ((unsigned char)level < 3 || level == 5 || level == 7) {
        uwrt_update_person_complex(slot);
        return;
    }
    uwrt_person_draw_and_check_collisions(slot);
    switch (CAVE_PERSON_STATE) {
        case 0: z01_update_person_state_reset_char_offset(); break;
        case 1: c_update_person_state_textbox(); break;
        case 2: z01_update_person_state_do_nothing(); break;
    }
}

void uwrt_update_grumble_full(unsigned int slot) {
    unsigned char state = CAVE_PERSON_STATE;
    if (state != 3 || (FRAME_COUNTER & 1) == 0) {
        uwrt_person_check_collisions(slot);
        z07_anim_fetch_obj_pos(slot);
        c_draw_object_not_mirrored(slot);
    }
    switch (CAVE_PERSON_STATE) {
        case 0: c_update_person_state_textbox(); break;
        case 1: uwrt_update_grumble1(); break;
        case 2: z01_cue_transfer_blank_person_wares(); break;
        case 3: uwrt_update_grumble3(); break;
    }
}

void uwrt_update_life_or_money_full(unsigned int slot) {
    unsigned char state = CAVE_PERSON_STATE;
    if (state != 4 || (FRAME_COUNTER & 1) == 0) {
        uwrt_person_draw_and_check_collisions(slot);
        uwrt_draw_life_or_money_items();
    }
    switch (CAVE_PERSON_STATE) {
        case 0: uwrt_update_life_or_money_state_0(); break;
        case 1: c_update_person_state_textbox(); break;
        case 2: uwrt_update_life_or_money_state_2(); break;
        case 3: z01_cue_transfer_blank_person_wares(); break;
        case 4: z01_uw_person_complex_state_delay_and_quit(); break;
    }
}
