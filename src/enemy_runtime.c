#include "enemy_runtime_private.h"

void enrt_animate_and_draw_common_object(unsigned int val, unsigned int slot) {
    z07_anim_advance_and_fetch(val, slot);
    z07_anim_set_obj_hflip(slot);
    c_draw_object_not_mirrored_with_frame(0, slot);
}
