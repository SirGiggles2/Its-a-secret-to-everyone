/* collision_dispatch.h — native collision subsystem dispatch (Phase 4).
 *
 * Native rewrite of src/oracle/combat/collision_runtime.c collidable-tile
 * cluster + thresholds. Both ROMs link.
 */

#ifndef COLLISION_DISPATCH_H
#define COLLISION_DISPATCH_H

#ifdef __cplusplus
extern "C" {
#endif

/* Compare COMBAT_HITBOX vs ENEMY_GLEEOK_NECK_Y_PTR (used as second
 * point) within COMBAT_THRESHOLD_X/Y. Sets COMBAT_COLLIDED 0/1.
 * NES DoObjectsCollideWithThresholds. */
unsigned char collision_do_objects_collide_with_thresholds(void);

/* Set both thresholds to threshold + run with-thresholds.
 * NES DoObjectsCollide. */
unsigned char collision_do_objects_collide(unsigned int threshold);

/* Check the room-tile under a slot's hitbox + offset. Reads
 * PlayAreaColumnAddrs / WalkableTiles tables. NES GetCollidableTile. */
unsigned char collision_get_collidable_tile(unsigned int hotspot_offset,
                                            unsigned int slot);

/* COMBAT_PART_INDEX = 0; collision_get_collidable_tile(0, slot).
 * NES GetCollidableTileStill. */
unsigned char collision_get_collidable_tile_still(unsigned int slot);

/* Compute hotspot offset from slot+dir, then collision_get_collidable_tile.
 * NES GetCollidingTileMoving. */
unsigned char collision_get_colliding_tile_moving(unsigned int slot);

#ifdef __cplusplus
}
#endif

#endif /* COLLISION_DISPATCH_H */
