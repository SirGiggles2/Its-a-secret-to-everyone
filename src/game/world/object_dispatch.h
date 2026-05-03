/* object_dispatch.h — native object subsystem dispatch (Phase 4).
 *
 * Native rewrite of src/oracle/world/object_runtime.c. Both ROMs link.
 * Pure C, no shims (drain references RAM/OBJ macros only).
 *
 * Phase 4 first object port: bound_direction_* family + bound_by_room
 * variants — used by Phase 4 collision detection + enemy AI.
 */

#ifndef OBJECT_DISPATCH_H
#define OBJECT_DISPATCH_H

#ifdef __cplusplus
extern "C" {
#endif

/* Test the object's X coord against RoomBoundLeft / RoomBoundRight.
 * For non-Link objects in slots >= $0D or with ObjType == $5C
 * (boomerang), the test point is shifted by +$0B (left bound) or
 * -$17 (right bound) to account for the sprite's collision body.
 *
 * If the X coord crosses a bound AND the corresponding direction bit
 * (left=$02, right=$01) is set in NES_OBJ_DIR ($000F = direction
 * scratch param, NOT per-slot ObjDir), clear NES_OBJ_DIR. The
 * direction byte is left untouched if no bound was crossed.
 *
 * Mirrors NES BoundDirectionHorizontally (Z_01.asm:3312). */
void object_bound_direction_horizontally(unsigned int slot);

/* Mirror of `object_bound_direction_horizontally` for the Y axis.
 * Slot/type shifts are +$0F (top) and -$21 (bottom). Mirrors NES
 * BoundDirectionVertically (Z_01.asm:3382-onward). */
void object_bound_direction_vertically(unsigned int slot);

/* Run both bound checks then return the resulting NES_OBJ_DIR (0 if
 * any bound cleared it, else the original direction). Mirrors NES
 * BoundByRoom (Z_01.asm:3457). */
unsigned char object_bound_by_room(unsigned int slot);

/* As `object_bound_by_room` but accepts the direction param directly
 * (callsite-friendly wrapper that writes NES_OBJ_DIR before testing). */
unsigned char object_bound_by_room_with_dir(unsigned char direction,
                                            unsigned int slot);

#ifdef __cplusplus
}
#endif

#endif /* OBJECT_DISPATCH_H */
