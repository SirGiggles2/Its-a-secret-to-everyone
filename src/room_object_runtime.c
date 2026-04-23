#include "room_object_runtime.h"
#include "core_runtime.h"
#include "progress_runtime.h"

extern unsigned char z07_get_collidable_tile_still(unsigned int slot);
extern unsigned char z01_compare_hearts_to_containers(void);

void roomobj_init_mode10(void) {
    z07_get_collidable_tile_still(0);
    if (ROOM_COLLIDABLE_TILE == 0x24) {
        ROOM_TRIFORCE_HOLD_FLAG = 0;
        ROOM_SFX_AUX = 8;
        ROOM_PUSH_TIMER = (unsigned char)(LINK_Y + 0x10);
    }
    ROOM_MODE_TIMER++;
}

void roomobj_setup_tile_object_ow(void) {
    unsigned char type;
    if (CUR_ROOM_ID == 0x3F || CUR_ROOM_ID == 0x55) {
        type = 97;
    } else {
        ROOM_OBJECT_X_SCRATCH = ROOM_TILE_OBJ_1;
        ROOM_OBJECT_Y_SCRATCH = ROOM_TILE_OBJ_2;
        type = ROOM_TILE_OBJ_0;
    }
    ROOM_OBJECT_SLOT_TYPE = type;
    progrt_reset_room_tile_obj_info();
    ROOM_OBJECT_INIT_DONE = 0;
}

void roomobj_world_fill_hearts(void) {
    if (ROOM_HEART_FILL_STATE == 0)
        return;
    ROOM_SFX_MAIN = 16;
    if (LINK_PARTIAL_HEART >= 0xF8) {
        LINK_PARTIAL_HEART = 0;
        if (z01_compare_hearts_to_containers() == WORLD_TMP0) {
            LINK_PARTIAL_HEART--;
            ROOM_SWORD_BLOCKED_FLAG = 0;
            ROOM_HEART_FILL_STATE = 0;
            ROOM_PAUSED_FLAG = 0;
            return;
        }
        LINK_HEARTS++;
        return;
    }
    LINK_PARTIAL_HEART = (unsigned char)(LINK_PARTIAL_HEART + 0x06);
}

void roomobj_end_prepare_mode(void) {
    SUBMODE_VALUE = 0;
    ROOM_MODE_TIMER = 0;
    COMBAT_PART_INDEX = 0;
    LINK_ACTION_TIMER = 0;
    MON_SHOVE_DIR(0) = 0;
    MON_SHOVE_TIMER(0) = 0;
    LINK_STUN_TIMER = 0;
}

void roomobj_dec_submenu_scroll(void) {
    ROOM_MENU_SCROLL_POS--;
}
