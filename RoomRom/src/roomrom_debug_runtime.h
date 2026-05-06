#ifndef ROOMROM_DEBUG_RUNTIME_H
#define ROOMROM_DEBUG_RUNTIME_H

void roomrom_debug_enter(void);
void roomrom_debug_tick(void);
unsigned char roomrom_debug_get_scene(void);
unsigned char roomrom_debug_get_room_id(void);
short roomrom_debug_get_link_x(void);
short roomrom_debug_get_link_y(void);

/* Task 5.4: warp coordinator state surface. Both RoomRom.md and
 * CombinedDebug.md link these exports; BizHawk Lua probes read them
 * during Gate B/C verification. */
unsigned char roomrom_debug_warp_is_active(void);
unsigned char roomrom_debug_warp_unsupported_count(void);

/* Task 5.4: passive RAM state mirror for BizHawk Lua probes.
 *
 * The Genesis 68k has no script-host symbol resolution, so each tick we
 * mirror the gate-B field set into a fixed RAM block. Lua reads the
 * block; user drives input manually. Probes log transitions and dump
 * snapshots without needing scripted joypad input.
 *
 * Layout (little-endian byte ordering on Genesis but Lua uses the same
 * accessor pattern as A4 probe — big-endian publish, byte-swap reads):
 *
 *   off  size  field
 *   ---  ----  ----------------------------------------------------
 *   0    1     magic byte 'W' (0x57)
 *   1    1     magic byte 'P' (0x50)
 *   2    2     frame_counter (u16, BE)
 *   4    1     scene (SCENE_OW=0, SCENE_UW=1, SCENE_CAVE=2)
 *   5    1     room_id
 *   6    2     link_x (s16, BE)
 *   8    2     link_y (s16, BE)
 *   10   1     link_face
 *   11   1     link_dir
 *   12   1     link_grid_offset (s8)
 *   13   1     doorway_dir
 *   14   1     warp_is_active
 *   15   1     warp_unsupported_count
 *   16   1     uw_level (0 if scene != UW)
 *   17   1     uw_quest (0 if scene != UW)
 *   18   1     ow_raw_tile_stable (0/1)
 *   19   1     link_pos_frac
 *   20   1     underground_exit_type (slice-1 stub: always 0)
 *   21   1     tile_under_link_foot (raw NES BG tile id; 0 if cache unstable)
 *   22   1     save.version
 *   23   1     save.source_room_id
 *   24   1     save.source_underground_entrance_tile (post-collapse)
 *   25   1     save.source_underground_entrance_tile_raw
 *   26   2     save.source_link_x (s16, BE)
 *   28   2     save.source_link_y (s16, BE)
 *   30   1     save.source_link_face
 *   31   1     save.dest_level
 *   32   1     save.dest_quest
 *   33   1     save.dest_room_id *   34   1     save.dest_link_face
 *   35   1     walkable_at_link_metatile (s_walkable[col][row], 0/1)
 *   36   1     link_walkable_north (collision probe result for dir UP)
 *   37   1     link_metatile_col (0..15, OW only)
 *   38   1     link_metatile_row (0..10, OW only)
 *   39   1     reserved
 *
 * Total: 40 bytes at 0xFF7200..0xFF7227.
 */
#define ROOMROM_DEBUG_STATE_MIRROR_BASE  0x00FF7200UL
#define ROOMROM_DEBUG_STATE_MIRROR_BYTES 40u

void roomrom_debug_publish_state_mirror(void);

#endif
