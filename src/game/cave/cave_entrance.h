/* cave_entrance.h — OW→cave entrance detection per NES Z_05.asm:HandleWarpOW.
 *
 * NES source: reference/aldonunez/Z_05.asm:7313 HandleWarpOW.
 * Drained C:  NEW (src/game/cave/cave_entrance.c).
 * Coverage:   PARTIAL — tile-range + LBA_B selector + cave-id derivation;
 *             Mode B vs C distinction left to cave_dispatch internals.
 * Stance:     REPLACE (Tier 0 hardcoded cave_id $6A replaced with NES-
 *             aligned per-room dispatch from LevelBlockAttrsB).
 *
 * Returns:
 *   - non-zero cave_id_t when tile is a warp tile AND attr_b_fc routes to
 *     a cave (selector $40-$FC, excluding $00 and < $40 dungeons).
 *   - 0 when tile is non-warp, OR when warp routes to a dungeon
 *     (caller dispatches dungeon via detect_warp_ow in transition.c).
 */

#ifndef SRC_GAME_CAVE_CAVE_ENTRANCE_H
#define SRC_GAME_CAVE_CAVE_ENTRANCE_H

#include "cave_dispatch.h"  /* cave_id_t */

/* Tier 1: per-room cave_id derivation via LevelBlockAttrsB[room_id]. */
cave_id_t cave_entrance_check(unsigned char tile, unsigned char room_id);

#endif /* SRC_GAME_CAVE_CAVE_ENTRANCE_H */
