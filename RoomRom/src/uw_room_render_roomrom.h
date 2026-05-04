#ifndef ROOMROM_UW_ROOM_RENDER_H
#define ROOMROM_UW_ROOM_RENDER_H

#include "ow_room_render_roomrom.h"

#define ROOMROM_UW_LEVEL_MIN 1u
#define ROOMROM_UW_LEVEL_MAX 9u
#define ROOMROM_UW_QUEST_MIN 1u
#define ROOMROM_UW_QUEST_MAX 2u

void roomrom_uw_room_render_set_map(unsigned char map_id);
unsigned char roomrom_uw_room_render_get_map(void);

void roomrom_uw_room_render_set_level(unsigned char level);
unsigned char roomrom_uw_room_render_get_level(void);

void roomrom_uw_room_render_set_quest(unsigned char quest);
unsigned char roomrom_uw_room_render_get_quest(void);

void roomrom_uw_room_render_load_palette(unsigned char room_id);
void roomrom_uw_room_render_upload_chr(void);
void roomrom_uw_room_render_fill_plane_a(unsigned char room_id);

/* S6.5 scroll: render one metatile col (2 plane cols) of room_id from blob
 * at plane metatile col dst_col. */
void roomrom_uw_room_render_fill_one_col(unsigned char room_id,
                                         unsigned char src_col,
                                         unsigned char dst_col);
void roomrom_uw_room_render_fill_one_col_at(unsigned char room_id,
                                            unsigned char src_col,
                                            unsigned char dst_col,
                                            unsigned char dst_row_base);

/* S5.5 collision: returns non-zero if metatile (col, row) of the current
 * UW room is walkable. col 0..15, row 0..10. Out-of-bounds = 0. */
unsigned char roomrom_uw_room_render_walkable_at(unsigned char col,
                                                 unsigned char row);

/* Ph5.3 door-state layer: write tile, override walkability, query AT palette.
 * Call these AFTER fill_plane_a / fill_one_col_at (s_cur_attr must be set). */
void roomrom_uw_room_render_write_tile(unsigned char col, unsigned char row,
                                       unsigned char raw_tile, unsigned char pal);
void roomrom_uw_room_render_set_walkable(unsigned char col, unsigned char row,
                                         unsigned char val);
unsigned char roomrom_uw_room_render_palette_at(unsigned char nt_col,
                                                unsigned char nt_row);

#endif
