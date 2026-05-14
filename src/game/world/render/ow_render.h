#ifndef ROOMROM_OW_ROOM_RENDER_H
#define ROOMROM_OW_ROOM_RENDER_H

#define ROOMROM_MAP_ORIGINAL 0u
#define ROOMROM_MAP_REDUX    1u
#define ROOMROM_ROOM_COLS    32u
#define ROOMROM_ROOM_ROWS    22u
#define ROOMROM_HUD_ROWS     7u
#define ROOMROM_ROOM_FIRST_ROW ROOMROM_HUD_ROWS
#define ROOMROM_PLANE_ROWS   64u

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

/* Task 5.4: explicit bracket for callers using fill_one_col_at in a
 * 16-column loop to paint the active slot (e.g. load_room). Wrap the
 * loop:
 *
 *   roomrom_ow_room_render_begin_full_fill();
 *   for (c = 0; c < 16; c++) roomrom_ow_room_render_fill_one_col_at(...);
 *   roomrom_ow_room_render_mark_stable();
 *
 * Skipping the bracket leaves the cache unstable; callers that paint
 * scroll-staging slots (where Link is NOT yet) must NOT mark stable. */
void roomrom_ow_room_render_begin_full_fill(void);
void roomrom_ow_room_render_mark_stable(void);

/* Task 5.4: copy the 32x22 raw-tile cache to RAM probe block at
 * 0xFF7400 ('TC' magic). Called by the debug-tick state-mirror
 * publisher so BizHawk Lua can scan the cache for warp-tile positions
 * without a per-cell accessor call. */
void roomrom_ow_room_render_publish_cache(void);

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

/* PR-2 V scroll staging: select target plane for nametable writes.
 * 0 = BG_A (default, current room slot). 1 = BG_B (incoming room
 * staging during V scroll). Caller must reset to 0 after staging. */
void roomrom_ow_room_render_set_target_plane(unsigned char plane);

#endif
