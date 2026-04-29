#ifndef ROOMROM_OW_ROOM_RENDER_H
#define ROOMROM_OW_ROOM_RENDER_H

#define ROOMROM_MAP_ORIGINAL 0u
#define ROOMROM_MAP_REDUX    1u
#define ROOMROM_ROOM_COLS    32u
#define ROOMROM_ROOM_ROWS    22u
#define ROOMROM_HUD_ROWS     7u
#define ROOMROM_ROOM_FIRST_ROW ROOMROM_HUD_ROWS

void roomrom_ow_room_render_set_map(unsigned char map_id);
unsigned char roomrom_ow_room_render_get_map(void);
void roomrom_ow_room_render_load_palette(unsigned char room_id);
void roomrom_ow_room_render_upload_chr(void);
void roomrom_ow_room_render_fill_plane_a(unsigned char room_id);

#endif
