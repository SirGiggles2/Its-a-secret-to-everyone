/* enemy_ganon_bridge.c — Phase 8 Task 8.10 Ganon ($3E) shim bridge.
 *
 * Drain Rule D1 stance: PARTIAL+EXTEND. ALL refs are forwarders to the
 * drained dispatcher entry points, which link into Debug.md
 * (build_debug.py:117/122/129). No stubs remain (closed 2026-05-31) —
 * Ganon now gets real collision + sprite-pos fetch when spawned.
 *
 * Hard rule WT-5: lives at src/game/enemies/, not RoomRom/.
 *
 * Symbol map (resolves Ganon runtime undefined refs):
 *   GanonStartXs                 -> NES Z_04.asm line 10488. $30,$B0.
 *                                   k_ganon_start_xs is static in
 *                                   enemy_dispatch.c; expose under
 *                                   the NES name expected by the
 *                                   private header.
 *   z01_animate_world_fading     -> world_animate_world_fading
 *                                   (world_dispatch.c:46).
 *   z01_get_room_flag_uw_item_state
 *                                -> progress_get_room_flag_uw_item_state
 *                                   (progress_dispatch.c).
 *   sprrt_anim_fetch_obj_pos     -> sprite_anim_fetch_obj_pos
 *                                   (sprite_dispatch.c:92).
 *   lcrt_check_link_collision_preinit
 *                                -> link_collision_check_link_collision_preinit
 *                                   (link_collision_dispatch.c:191).
 *   colrt_check_monster_sword_collision
 *                                -> collision_check_monster_sword_collision
 *                                   (collision_dispatch.c:323).
 *   colrt_check_monster_arrow_or_rod_collision
 *                                -> collision_check_monster_arrow_or_rod_collision
 *                                   (collision_dispatch.c:361).
 */

#include "world/world_dispatch.h"            /* world_animate_world_fading */
#include "world/progress_dispatch.h"         /* progress_get_room_flag_uw_item_state */
#include "world/sprite_dispatch.h"           /* sprite_anim_fetch_obj_pos */
#include "combat/collision_dispatch.h"       /* collision_check_monster_sword/arrow */
#include "combat/link_collision_dispatch.h"  /* link_collision_check_link_collision_preinit */

/* GanonStartXs — NES Z_04.asm:10488 (table consumed by InitGanon
 * randomize_location at offset $30 / $B0 by sprite-attr-row & 1). */
const unsigned char GanonStartXs[2] = { 0x30u, 0xB0u };

unsigned int z01_animate_world_fading(void)
{
    return world_animate_world_fading();
}

unsigned char z01_get_room_flag_uw_item_state(void)
{
    return progress_get_room_flag_uw_item_state();
}

/* CLOSED 2026-05-31 — forward to the drained dispatch entry points, which
 * DO link into Debug.md (build_debug.py:117/122/129). The original stubs
 * predated those dispatchers being wired; the *_dispatch.c layer is the
 * drained equivalent of the combat/sprite runtime, same pattern as
 * z01_animate_world_fading -> world_animate_world_fading above. Signatures
 * verified identical (sprite_dispatch.h:49, collision_dispatch.h:68/80,
 * link_collision_dispatch.h:37). Ganon now gets real sword/arrow/rod
 * collision + link-collision preinit + sprite-pos fetch. */

unsigned char sprrt_anim_fetch_obj_pos(unsigned int slot)
{
    return sprite_anim_fetch_obj_pos(slot);
}

void lcrt_check_link_collision_preinit(unsigned int monster_slot)
{
    link_collision_check_link_collision_preinit(monster_slot);
}

void colrt_check_monster_sword_collision(unsigned int monster_slot,
                                         unsigned int weapon_slot)
{
    collision_check_monster_sword_collision(monster_slot, weapon_slot);
}

void colrt_check_monster_arrow_or_rod_collision(unsigned int monster_slot,
                                                unsigned int weapon_slot)
{
    collision_check_monster_arrow_or_rod_collision(monster_slot, weapon_slot);
}
