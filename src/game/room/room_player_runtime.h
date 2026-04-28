#ifndef ROOM_PLAYER_RUNTIME_H
#define ROOM_PLAYER_RUNTIME_H

#include "room_state.h"

#ifdef __cplusplus
extern "C" {
#endif

void roompl_get_player_coords_for_direction(unsigned int dir);
unsigned int roompl_is_distance_safe_to_spawn(unsigned int slot);
void roompl_set_moving_dir_and_switch_to_player_slot(unsigned int dir);
void roompl_link_modify_dir_in_doorway(void);

#ifdef __cplusplus
}
#endif

#endif
