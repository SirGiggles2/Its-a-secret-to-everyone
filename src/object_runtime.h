#ifndef OBJECT_RUNTIME_H
#define OBJECT_RUNTIME_H

#include "platform_abi.h"

#ifdef __cplusplus
extern "C" {
#endif

/* object_runtime is owned C for promoted movement/runtime code.
 * Generated bank C may wrap these, but fixes and optimization belong here.
 */
void objrt_move_object(unsigned short slot);
void objrt_bound_direction_horizontally(unsigned int slot);
void objrt_bound_direction_vertically(unsigned int slot);
unsigned char objrt_bound_by_room(unsigned int slot);
unsigned char objrt_bound_by_room_with_dir(unsigned char direction, unsigned int slot);
unsigned int objrt_add_q_speed_to_position_fraction(unsigned int slot);
unsigned int objrt_sub_q_speed_from_position_fraction(unsigned int slot);
void objrt_move_shot(unsigned char direction, unsigned int slot);

#ifdef __cplusplus
}
#endif

#endif /* OBJECT_RUNTIME_H */
