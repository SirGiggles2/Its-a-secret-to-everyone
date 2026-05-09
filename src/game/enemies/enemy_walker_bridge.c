/* enemy_walker_bridge.c -- Phase 7 Task 7.2 step 4 walker UPDATE
 * primitives bridge.
 *
 * Per debate 2026-05-09 verdict (Option C, Sonnet evidence): 6 of 7
 * walker UPDATE primitives already exist as drained native functions
 * linked into Debug.md. This file forwards each c_ and z_ symbol the
 * drained walker runtime calls to its native equivalent. Walker_Move
 * is the sole remaining gap, stubbed as PLACEHOLDER for this commit;
 * native drain follows in step 5.
 *
 * Drain Rule D1 stance: EXTEND. Forwarders point to drained C
 * (PRIMARY evidence). No NES asm linkage. No vasm/gas dialect bridge.
 *
 * Hard rule WT-5: lives at src/game/enemies/, not RoomRom/.
 *
 * Symbol map:
 *   c_walker_move                         -> STUB (Walker_Move drain TBD,
 *                                            z_07.asm:3763, ~80 lines)
 *   c_check_monster_collisions            -> link_collision_check_monster_collisions
 *                                            (link_collision_dispatch.c:263)
 *   c_check_link_collision                -> link_collision_check_link_collision
 *                                            (link_collision_dispatch.c)
 *   c_draw_object_not_mirrored_with_frame -> draw_object_not_mirrored_with_frame
 *                                            (draw_dispatch.c:426)
 *   c_wanderer_target_player              -> enrt_wanderer_target_player
 *                                            (enemy_wanderer_runtime.c:63)
 *   z07_anim_advance_and_fetch            -> sprite_anim_advance_and_fetch
 *                                            (sprite_dispatch.c:105)
 *   z01_anim_set_sprite_desc_attrs        -> core_anim_set_sprite_desc_attrs
 *                                            (core_dispatch.c:155)
 *   z01_abs                               -> trivial native one-liner
 */

#include "combat/link_collision_dispatch.h"
#include "world/draw_dispatch.h"
#include "world/sprite_dispatch.h"
#include "core/core_dispatch.h"

extern void enrt_wanderer_target_player(unsigned int slot);

void c_walker_move(unsigned int slot)
{
    /* PLACEHOLDER. Walker_Move drain pending (step 5). Stub means
     * octorok animation, palette, collision, and draw all run; movement
     * is frozen at spawn position. Probe will gate-1 verify the static
     * cells; movement-trace probe lands with the drain. */
    (void)slot;
}

void c_check_monster_collisions(unsigned int slot)
{
    link_collision_check_monster_collisions(slot);
}

void c_check_link_collision(unsigned int slot)
{
    link_collision_check_link_collision(slot);
}

void c_draw_object_not_mirrored_with_frame(unsigned int frame, unsigned int slot)
{
    draw_object_not_mirrored_with_frame((unsigned char)frame, slot);
}

void c_wanderer_target_player(unsigned int slot)
{
    enrt_wanderer_target_player(slot);
}

void z07_anim_advance_and_fetch(unsigned int val, unsigned int slot)
{
    sprite_anim_advance_and_fetch(val, slot);
}

unsigned char z01_anim_set_sprite_desc_attrs(unsigned int val)
{
    return core_anim_set_sprite_desc_attrs(val);
}

unsigned char z01_abs(unsigned int val)
{
    /* NES Abs at z_01.asm. Sign-test on bit 7. */
    unsigned char v = (unsigned char)val;
    return (v < 0x80u) ? v : (unsigned char)(0u - (unsigned int)v);
}
