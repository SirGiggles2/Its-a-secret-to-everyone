/* enemy_ganon_bridge.c — Phase 8 Task 8.10 Ganon ($3E) shim bridge.
 *
 * Drain Rule D1 stance: PARTIAL+EXTEND. Forwarders to dispatcher entry
 * points where drained equivalents already link into Debug.md, plus
 * stub shims for combat/sprite oracle subsystems whose .c files are
 * not yet wired into build_debug.py. Boot-smoke only — Ganon does not
 * spawn during smoke (slot 0 boss seed not poked), so collision /
 * sprite-fetch paths are unreachable.
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
 *   sprrt_anim_fetch_obj_pos     -> stub. world/sprite_runtime.c
 *                                   not yet in build_debug.py;
 *                                   Ganon DrawBurst / ganon_check_collisions
 *                                   reach this only when the boss is
 *                                   alive in slot 0. Boot smoke spawns
 *                                   no enemies, so stub is safe.
 *                                   TODO Phase 9 — wire sprite_runtime
 *                                   when broader OAM router lands.
 *   lcrt_check_link_collision_preinit
 *                                -> stub. combat/link_collision_runtime.c
 *                                   not yet in build. TODO Phase 9.
 *   colrt_check_monster_sword_collision
 *                                -> stub. combat/collision_runtime.c
 *                                   not yet in build. TODO Phase 9.
 *   colrt_check_monster_arrow_or_rod_collision
 *                                -> stub. ditto.
 */

#include "world/world_dispatch.h"     /* world_animate_world_fading */
#include "world/progress_dispatch.h"  /* progress_get_room_flag_uw_item_state */

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

/* PARTIAL stubs — boot-smoke unreachable. Drain in Phase 9 when
 * combat / sprite oracle subsystems land in build_debug.py. */

unsigned char sprrt_anim_fetch_obj_pos(unsigned int slot)
{
    (void)slot;
    return 0u;
}

void lcrt_check_link_collision_preinit(unsigned int monster_slot)
{
    (void)monster_slot;
}

void colrt_check_monster_sword_collision(unsigned int monster_slot,
                                         unsigned int weapon_slot)
{
    (void)monster_slot;
    (void)weapon_slot;
}

void colrt_check_monster_arrow_or_rod_collision(unsigned int monster_slot,
                                                unsigned int weapon_slot)
{
    (void)monster_slot;
    (void)weapon_slot;
}
