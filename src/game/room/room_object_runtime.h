#ifndef ROOM_OBJECT_RUNTIME_H
#define ROOM_OBJECT_RUNTIME_H

#include "room_state.h"

#ifdef __cplusplus
extern "C" {
#endif

void roomobj_init_mode10(void);
void roomobj_setup_tile_object_ow(void);
void roomobj_world_fill_hearts(void);
void roomobj_end_prepare_mode(void);
void roomobj_dec_submenu_scroll(void);

#ifdef __cplusplus
}
#endif

#endif
