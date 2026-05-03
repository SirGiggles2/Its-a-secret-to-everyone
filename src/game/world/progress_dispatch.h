/* progress_dispatch.h — native progress subsystem dispatch (Phase 4).
 *
 * Native rewrite of src/oracle/world/progress_runtime.c. Both ROMs
 * link. Pure C, no transpile shims. Phase 4 first batch focuses on
 * the room-flag persistence pair that unblocks Phase 3 cave stubs:
 *
 *   set_room_flag_uw_item_state — mark current room's UW-item-taken bit.
 *   get_room_flag_uw_item_state — read current room's UW-item-taken bit.
 *
 * Both pair up to gate cave's "this item has already been taken" path
 * (cave_runtime.c branches on the result).
 */

#ifndef PROGRESS_DISPATCH_H
#define PROGRESS_DISPATCH_H

#ifdef __cplusplus
extern "C" {
#endif

/* Set bit $10 ("UW item taken / cave object destroyed") on the
 * current room's flag byte in the active save slot. Mirrors NES
 * SetRoomFlagUWItemState (drain at progress_runtime.c:32-38). */
void progress_set_room_flag_uw_item_state(void);

/* Read bit $10 of the current room's flag byte from the active save
 * slot. Returns the bit value masked (0 or $10). Mirrors NES
 * GetRoomFlagUWItemState (drain at progress_runtime.c:40-48). */
unsigned char progress_get_room_flag_uw_item_state(void);

/* Replace a 7th palette row in the dynamic transfer buffer (8-byte
 * record + 3-byte color triple at RAM($0306..$0308)). NES uses 3
 * variants seeded by GanonColorTriples offset:
 *   brown -> color_index = 2 (GanonColorTriples[0..2])
 *   blue  -> color_index = 5 (GanonColorTriples[3..5])
 *   ashes -> color_index = 8 (GanonColorTriples[6..8])
 *
 * Drain at progress_runtime.c:8-19, 21-23. Mirrors NES Z_01.asm
 * ReplaceGanonBrownPaletteRow / ReplaceGanonBluePaletteRow /
 * ReplaceAshesPaletteRow. */
void progress_replace_ganon_brown_palette_row(void);
void progress_replace_ganon_blue_palette_row(void);
void progress_replace_ashes_palette_row(void);

/* Zero ROOM_TILE_OBJ_0/1/2 ($052B..$052D) and return 0. NES
 * ResetRoomTileObjInfo. drain at progress_runtime.c:25-30. */
unsigned char progress_reset_room_tile_obj_info(void);

#ifdef __cplusplus
}
#endif

#endif /* PROGRESS_DISPATCH_H */
