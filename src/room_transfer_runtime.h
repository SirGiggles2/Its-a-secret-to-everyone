#ifndef ROOM_TRANSFER_RUNTIME_H
#define ROOM_TRANSFER_RUNTIME_H

#include "room_state.h"

#ifdef __cplusplus
extern "C" {
#endif

unsigned int roomxf_cycle9_in_direction(unsigned int d3_in);
void roomxf_copy_column_to_tilebuf(void);
void roomxf_copy_row_to_tilebuf(void);
void roomxf_copy_column_or_row_to_tilebuf(void);
void roomxf_fetch_tile_map_addr(void);
void roomxf_copy_play_area_attrs_half(unsigned int ppu_hi, unsigned int ppu_lo, unsigned int end_off);

#ifdef __cplusplus
}
#endif

#endif
