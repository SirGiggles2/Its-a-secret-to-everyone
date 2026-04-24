#ifndef ROOM_LOAD_RUNTIME_H
#define ROOM_LOAD_RUNTIME_H

#include "room_state.h"

#ifdef __cplusplus
extern "C" {
#endif

void roomld_write_and_enable_sprite0(void);
void roomld_put_link_behind_background(void);
void roomld_reset_inv_obj_state(void);
void roomld_fill_play_area_attrs(unsigned int room_id);
void roomld_setup_obj_room_bounds(void);
void roomld_init_link_speed(void);
void roomld_transfer_level_pattern_blocks(void);
void roomld_init_mode2_submodes(void);
void roomld_copy_common_data_to_ram(void);
void roomld_update_mode2_load_full(void);

#ifdef __cplusplus
}
#endif

#endif
