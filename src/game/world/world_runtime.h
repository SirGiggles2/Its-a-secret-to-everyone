#ifndef WORLD_RUNTIME_H
#define WORLD_RUNTIME_H

#include "world_state.h"

extern unsigned char z01_reset_cur_sprite_index(void);

#ifdef __cplusplus
extern "C" {
#endif

unsigned int worldrt_get_shortcut_or_item_xy_for_room(unsigned int room_id);
unsigned int worldrt_get_shortcut_or_item_xy(void);
void worldrt_get_object_middle(unsigned int slot);
unsigned int worldrt_animate_world_fading(void);
void worldrt_check_mazes(void);

#ifdef __cplusplus
}
#endif

#endif
