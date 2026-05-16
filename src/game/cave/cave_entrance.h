/* cave_entrance.h — Tier 0 (plan v6) cave-entrance tile detection.
 *
 * NES source: reference/aldonunez/Z_05.asm:7313 HandleWarpOW.
 * Drained C:  NEW (src/game/cave/cave_entrance.c).
 * Coverage:   PARTIAL — tile-range check matches NES; LBA_B cave-id
 *             lookup deferred to v6b (Tier 1 follow-up).
 * Stance:     EXTEND (composes existing cave_init + collision tile
 *             lookup; new entrance-detection wrapper).
 *
 * MVP: returns a fixed cave_id when Link stands on a NES-Z1 cave
 * entrance tile ($24, $88, $70..$73). LBA_B per-room cave-id lookup
 * follows in a later commit; today's commit prioritizes "user can
 * enter cave" over correct cave-id selection.
 */

#ifndef SRC_GAME_CAVE_CAVE_ENTRANCE_H
#define SRC_GAME_CAVE_CAVE_ENTRANCE_H

#include "cave_dispatch.h"  /* cave_id_t */

/* Returns a non-zero cave_id_t when the tile Link is standing on is
 * a NES Z1 cave-entrance tile, else 0. */
cave_id_t cave_entrance_check(unsigned char tile);

#endif /* SRC_GAME_CAVE_CAVE_ENTRANCE_H */
