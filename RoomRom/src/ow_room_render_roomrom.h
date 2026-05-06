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

/* S5 collision: returns non-zero if the metatile at (col, row) in the
 * current OW room is walkable. col 0..15, row 0..10. Out-of-bounds = 0. */
unsigned char roomrom_ow_room_render_walkable_at(unsigned char col,
                                                 unsigned char row);

/* Task 5.4: raw NES BG tile id for the active 32x22 playfield, populated
 * during fill_plane_a. tile_col 0..31, tile_row 0..21. Out-of-bounds = 0.
 *
 * SLICE-1 SEMANTICS:
 *   - Reflects the LAST full fill_plane_a render of the currently held
 *     room. Single-column scroll fills do NOT update cache contents and
 *     mark the cache unstable.
 *   - Tile mutations from secrets, bombed rocks, burnt bushes, pushed
 *     blocks are NOT republished here; future ticket adds the hook.
 *   - Callers that drive game-flow decisions (e.g. warp detection) must
 *     gate on roomrom_ow_room_render_is_stable() returning 1.
 */
unsigned char roomrom_ow_room_render_raw_tile_at(unsigned char tile_col,
                                                 unsigned char tile_row);

/* Returns 1 iff the raw-tile cache reflects a full fill_plane_a since the
 * last partial column write. Coordinator must check this before consuming
 * raw_tile_at output for warp-tile detection. */
unsigned char roomrom_ow_room_render_is_stable(void);

/* S6.5 scroll: render one metatile column of room_id at plane metatile
 * column dst_col (0..15). src_col selects the source room's col layout
 * (palette uses src position so attributes match the source room). Plane
 * cols wrap mod 32 via SGDK. Used by the scroll state machine to overwrite
 * "just-left-visible" plane cols with incoming-room data. */
void roomrom_ow_room_render_fill_one_col(unsigned char room_id,
                                         unsigned char src_col,
                                         unsigned char dst_col);
void roomrom_ow_room_render_fill_one_col_at(unsigned char room_id,
                                            unsigned char src_col,
                                            unsigned char dst_col,
                                            unsigned char dst_row_base);

#endif
