#ifndef TARGETING_RUNTIME_H
#define TARGETING_RUNTIME_H

#include "targeting_state.h"

unsigned char targrt_get_one_direction_and_distance_to_target(unsigned char target_coord,
                                                              unsigned char origin_coord);
void targrt_get_directions_and_distances_to_target(unsigned char target_slot,
                                                   unsigned int origin_slot);
unsigned int targrt_calc_diagonal_speed_index(unsigned int mid_speed_idx);

#endif
