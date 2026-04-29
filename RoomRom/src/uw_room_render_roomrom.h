#ifndef ROOMROM_UW_ROOM_RENDER_H
#define ROOMROM_UW_ROOM_RENDER_H

#include "ow_room_render_roomrom.h"

#define ROOMROM_UW_LEVEL_MIN 1u
#define ROOMROM_UW_LEVEL_MAX 9u

void roomrom_uw_room_render_set_map(unsigned char map_id);
unsigned char roomrom_uw_room_render_get_map(void);

void roomrom_uw_room_render_set_level(unsigned char level);
unsigned char roomrom_uw_room_render_get_level(void);

void roomrom_uw_room_render_load_palette(unsigned char room_id);
void roomrom_uw_room_render_upload_chr(void);
void roomrom_uw_room_render_fill_plane_a(unsigned char room_id);

#endif
