#include "enemy_runtime_private.h"

void enrt_animate_and_draw_common_object(unsigned int val, unsigned int slot) {
    z07_anim_advance_and_fetch(val, slot);
    z07_anim_set_obj_hflip(slot);
    c_draw_object_not_mirrored_with_frame(0, slot);
}

/* ---- Plan C: drained from z_07 ----------------------------------------- */

unsigned int enrt_find_empty_monster_slot(void) {
    for (signed char i = 11; i >= 1; i--) {
        if (OBJ(NES_OBJ_TYPE, (unsigned char)i) == 0) {
            ENEMY_NEXT_SHOT_SLOT = (unsigned char)i;
            return (unsigned int)(unsigned char)i;
        }
    }
    return 0;
}
