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

#endif
