#include "room_player_runtime.h"
#include "core_runtime.h"

void roompl_get_player_coords_for_direction(unsigned int dir) {
    if ((unsigned char)dir & 0x03) {
        WORLD_TMP0 = LINK_Y;
        WORLD_TMP1 = LINK_X;
    } else {
        WORLD_TMP0 = LINK_X;
        WORLD_TMP1 = LINK_Y;
    }
}

unsigned int roompl_is_distance_safe_to_spawn(unsigned int slot) {
    unsigned char dx = corert_abs((unsigned char)(LINK_X - OBJ_X((unsigned char)slot)));
    if (dx < 0x22) {
        unsigned char dy = corert_abs((unsigned char)(LINK_Y - OBJ_Y((unsigned char)slot)));
        if (dy < 0x22)
            return CARRY_SET;
    }
    return 0;
}

void roompl_set_moving_dir_and_switch_to_player_slot(unsigned int dir) {
    COMBAT_PART_INDEX = (unsigned char)dir;
}

void roompl_link_modify_dir_in_doorway(void) {
    if (ROOM_IN_DOORWAY_FLAG == 0)
        return;
    if (ROOM_INPUT_DIR == 0)
        return;
    if (LINK_DIR & ROOM_INPUT_DIR) {
        ROOM_INPUT_DIR = LINK_DIR;
        return;
    }
    WORLD_TMP0 = (unsigned char)corert_get_opposite_dir(LINK_DIR);
    if (WORLD_TMP0 & ROOM_INPUT_DIR) {
        ROOM_INPUT_DIR = WORLD_TMP0;
        return;
    }
    ROOM_INPUT_DIR = LINK_DIR;
}
