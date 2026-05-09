/* enemy_walker_bridge.c -- Phase 7 Task 7.2 step 4/5 walker UPDATE
 * primitives bridge.
 *
 * Per debate 2026-05-09 verdict (Option C, Sonnet evidence): 6 of 7
 * walker UPDATE primitives already exist as drained native functions
 * linked into Debug.md. Step-5 closes the last gap with a native
 * Walker_Move drain composed from drained primitives.
 *
 * Drain Rule D1 stance: EXTEND. All callees here are drained C
 * (PRIMARY evidence). No NES asm linkage. No vasm/gas dialect bridge.
 *
 * Hard rule WT-5: lives at src/game/enemies/, not RoomRom/.
 *
 * Symbol map:
 *   c_walker_move                         -> NATIVE (this file, step 5)
 *                                            composes object_bound_by_room +
 *                                            object_move_object from
 *                                            world/object_dispatch.c
 *                                            (NES Z_07.asm:2555 Walker_Move)
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
#include "world/object_dispatch.h"   /* object_bound_by_room, object_move_object */
#include "core/core_dispatch.h"      /* core_get_opposite_dir */
#include "platform_abi.h"            /* RAM, OBJ, NES_OBJ_DIR, NES_SHOT_COLLISION_FLAG */

/* NES non-Link offsets (cell-level; OBJ macro adds slot index).
 * ObjStunTimer  = $003D  (per-slot)
 * InvClock      = $066C  (global; pause/clock flag)
 * ObjInputDir   = $03F8  (per-slot; aliases ENEMY_PUSH_DIR_SCRATCH)
 * ObjShoveDir   = $00C0  (per-slot)
 * ObjGridOffset = $0394  (per-slot; per platform_abi NES_OBJ_GRID_OFFSET) */
#define NES_OBJ_STUN_TIMER   0x003D
#define NES_INV_CLOCK        0x066C
#define NES_OBJ_INPUT_DIR    0x03F8
#define NES_OBJ_SHOVE_DIR    0x00C0

extern void enrt_wanderer_target_player(unsigned int slot);

void c_walker_move(unsigned int slot)
{
    /* NES Walker_Move (Z_07.asm:2555). Non-Link path only — slot 0
     * (Link) movement still runs through the RoomRom debug runtime so
     * Walker_Move is never called for it under Phase 7 Task 7.2.
     *
     * Drained scope (step 5):
     *   - ChooseObjDirOrInputDir  -> CheckStunned (non-Link branch)
     *   - CheckStunned             -> InvClock | ObjStunTimer gate
     *   - FilterInput              -> single-direction pick via
     *                                 core_get_opposite_dir + reverse table
     *   - SetMovingDir             -> mask $0F into NES_OBJ_DIR
     *   - CheckBoundary            -> object_bound_by_room
     *   - MoveObject               -> object_move_object
     *
     * Deferred (TODO; step 6 / next task):
     *   - Obj_Shove                — fires on damage knockback; not yet
     *                                wired to combat hit path so
     *                                ObjShoveDir(slot) is always 0 at
     *                                this point in Phase 7 Task 7.2.
     *   - Walker_CheckTileCollision — needs room tile data; without it
     *                                octoroks would freeze in walls
     *                                instead of bouncing. Defer until
     *                                room subsystem hooked into Debug.md.
     *
     * NES ReverseDirections table { $08, $04, $02, $01 } — selects the
     * lowest-bit single direction from a (possibly diagonal) input mask
     * to prevent objects from straddling two axes per frame.
     */

    /* Step 1 — Obj_Shove gate (deferred). */
    if (OBJ(NES_OBJ_SHOVE_DIR, slot) != 0u) {
        /* TODO step 6: native Obj_Shove. Until then, ignore the shove
         * so movement still ticks (worst case: octorok keeps walking
         * during what would have been a knockback frame — visually
         * benign with no combat wired). */
    }

    /* Step 2 — CheckStunned (non-Link path). */
    if ((RAM(NES_INV_CLOCK) | OBJ(NES_OBJ_STUN_TIMER, slot)) != 0u) {
        return;
    }

    /* Step 3 — FilterInput. ObjInputDir(slot) was seeded by
     * enrt_update_rope from ENEMY_DIR(slot) before the call. */
    unsigned char input = (unsigned char)OBJ(NES_OBJ_INPUT_DIR, slot);
    unsigned char dir;
    if (input == 0u) {
        dir = 0u;
    } else {
        /* core_get_opposite_dir returns (idx<<8)|opposite. NES then
         * indexes ReverseDirections[idx] = { $08, $04, $02, $01 }
         * which, combined with the lowest-set-bit scan inside
         * core_get_opposite_dir, picks one single-bit direction from
         * the input mask. Equivalent to (input & -input) for a single
         * lowest set bit but mapped through the NES table — match the
         * NES path exactly so behavior is bit-identical. */
        static const unsigned char k_reverse_dirs[4] = {
            0x08u, 0x04u, 0x02u, 0x01u
        };
        unsigned int packed = core_get_opposite_dir((unsigned int)input);
        unsigned char idx = (unsigned char)((packed >> 8) & 0x03u);
        dir = k_reverse_dirs[idx];
    }

    /* Step 4 — SetMovingDir. NES masks low nibble into $0F. */
    RAM(NES_OBJ_DIR) = (unsigned char)(dir & 0x0Fu);

    /* NES sets $0E = 0 (doorway scratch). Walker_CheckTileCollision
     * branch uses this; safe to clear unconditionally. */
    RAM(NES_SHOT_COLLISION_FLAG) = 0u;

    /* Step 5 — CheckBoundary. object_bound_by_room reads NES_OBJ_DIR,
     * runs both H/V bound tests, and returns the post-test DIR (0 if
     * a bound cleared it). The function's side effect on $0F is what
     * matters; we drop the return value because object_move_object
     * re-reads $0F. */
    (void)object_bound_by_room(slot);

    /* Step 6 — Walker_CheckTileCollision (DEFERRED). Without it,
     * octoroks pass through every tile but still respect room edges. */

    /* Step 7 — MoveObject. Reads NES_OBJ_DIR, advances X/Y for the
     * matching axis bit. */
    object_move_object((unsigned short)slot);
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
