#ifndef LINK_STATE_H
#define LINK_STATE_H

#include "platform_abi.h"

/* Link (player) state cells. Owned by link_collision_runtime and
 * link-side slices of room_player_runtime.
 */
#define LINK_MOVING_DIR       RAM(NES_LINK_MOVING_DIR)
#define LINK_ROOM_SCRATCH     RAM(NES_LINK_ROOM_SCRATCH)
#define LINK_HALT_FLAG        RAM(NES_LINK_HALT_FLAG)
#define MODE11_DEATH_TIMER    RAM(NES_MODE11_DEATH_TIMER)
#define DEATH_FRAME_COUNTER   RAM(NES_DEATH_FRAME_COUNTER)

#endif /* LINK_STATE_H */
