/* enemy_projectile_bridge.c -- Phase 7 Task 7.2 step 12 shot UPDATE
 * primitives bridge. Forwarders for c_/z01_/z07_ symbols pulled in by
 * src/oracle/enemies/enemy_projectile_runtime.c. Same model as
 * src/game/enemies/enemy_walker_bridge.c. Drain Rule D1 stance: EXTEND.
 * WT-5: lives at src/game/enemies/, not RoomRom/.
 */

#include "core/core_dispatch.h"             /* core_get_opposite_dir, core_destroy_monster */
#include "combat/collision_dispatch.h"      /* collision_get_colliding_tile_moving */
#include "combat/link_collision_dispatch.h" /* link_collision_check_link_collision */
#include "combat/targeting_dispatch.h"      /* targeting_* */
#include "world/draw_dispatch.h"            /* draw_object_not_mirrored */
#include "world/object_dispatch.h"          /* object_bound_by_room, object_move_object */
#include "world/sprite_dispatch.h"          /* sprite_anim_fetch_obj_pos */

void c_move_object(unsigned short slot)
{
    object_move_object(slot);
}

void c_draw_object_not_mirrored(unsigned int slot)
{
    /* Deferred: NES would pull A from RAM[$0D] (the cached frame byte
     * enrt_draw_shot just stored). For step 12 we pass frame=0 — same
     * stance as moblin/goriya UPDATE (ticks but does not draw). */
    draw_object_not_mirrored(0u, slot);
}

void c_draw_arrow(unsigned int slot)
{
    /* Step 12 STUB: NES DrawArrow lives in zelda_translated/Z_01.asm
     * (not linked into Debug.md). Drain target for next step.
     * For step 12 verification, arrows ($5B) aren't shot by octorok
     * ($53) so this branch never fires. */
    (void)slot;
}

void c_draw_sword_shot_or_magic_shot(unsigned int slot)
{
    /* Step 12 STUB: same rationale as c_draw_arrow above. Sword/magic
     * shots ($57-$59) aren't shot by octorok ($53) so this never fires
     * during the step-12 multi-slot probe. */
    (void)slot;
}

unsigned char z01_bound_by_room(unsigned int slot)
{
    return object_bound_by_room(slot);
}

unsigned char z01_bound_by_room_with_a(unsigned char direction, unsigned int slot)
{
    return object_bound_by_room_with_dir(direction, slot);
}

void z01_check_link_collision(unsigned int slot)
{
    link_collision_check_link_collision(slot);
}

unsigned int z01_get_opposite_dir(unsigned int dir)
{
    return core_get_opposite_dir(dir);
}

void z01_get_directions_and_distances_to_target(unsigned char target_slot, unsigned int origin_slot)
{
    targeting_get_directions_and_distances_to_target(target_slot, origin_slot);
}

unsigned int z01_calc_diagonal_speed_index(unsigned int mid_speed_idx)
{
    return targeting_calc_diagonal_speed_index(mid_speed_idx);
}

void z07_destroy_monster(unsigned int slot)
{
    core_destroy_monster(slot);
}

unsigned char z07_get_colliding_tile_moving(unsigned int slot)
{
    return collision_get_colliding_tile_moving(slot);
}

unsigned char z07_anim_fetch_obj_pos(unsigned int slot)
{
    return sprite_anim_fetch_obj_pos(slot);
}
