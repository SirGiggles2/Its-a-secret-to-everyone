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
#include "combat/collision_dispatch.h"   /* collision_get_colliding_tile_moving */
#include "world/draw_dispatch.h"
#include "world/sprite_dispatch.h"
#include "world/object_dispatch.h"   /* object_bound_by_room, object_move_object */
#include "core/core_dispatch.h"      /* core_get_opposite_dir, core_reset_moving_dir */
#include "platform_abi.h"            /* RAM, OBJ, NES_OBJ_DIR, NES_SHOT_COLLISION_FLAG */
#include "roomrom_enemy_state.h"     /* ENEMY_* macros (re-export of state/enemy_state.h) */

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

void z07_anim_set_obj_hflip(unsigned int slot)
{
    /* Step 7: forwarder for enrt_animate_and_draw_common_object below.
     * Mirrors src/gen/z_07.c NATIVE_SPRITE branch — that file is not
     * linked into Debug.md so we route directly. */
    sprite_anim_set_obj_hflip(slot);
}

void enrt_animate_and_draw_common_object(unsigned int val, unsigned int slot)
{
    /* Step 7: native composition matching src/oracle/enemies/enemy_runtime.c.
     * Inlined here instead of linking enemy_runtime.c (avoids dragging in
     * legacy_bridge.h chain). Used by enrt_update_stalfos (and bubble/
     * standing fire / etc when those families wire later). */
    z07_anim_advance_and_fetch(val, slot);
    z07_anim_set_obj_hflip(slot);
    c_draw_object_not_mirrored_with_frame(0u, slot);
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

/* -------- Step 6: walker family unblock stubs -------- */

/* Helper: NES EnsureObjectAligned (Z_07.asm:2086). Snap X/Y to the
 * 8-pixel grid when GridOffset is 0; Y also gets +5 vertical offset
 * (NES uses ObjY = (Y & $F8) | 5 for top-left alignment). */
static void shove_ensure_object_aligned(unsigned int slot)
{
    if (OBJ(NES_OBJ_GRID_OFFSET, slot) != 0u)
        return;
    OBJ(NES_OBJ_X, slot) = (unsigned char)(OBJ(NES_OBJ_X, slot) & 0xF8u);
    OBJ(NES_OBJ_Y, slot) =
        (unsigned char)((OBJ(NES_OBJ_Y, slot) & 0xF8u) | 0x05u);
}

/* Helper: NES CheckPersonBlocking (Z_01.asm:3108). Reads Link's Y;
 * if Link is high in room (Y < $8E) AND moving up (bit 3 of dir set),
 * zero $0F via core_reset_moving_dir to signal blocked. Otherwise
 * leave $0F alone. */
static void shove_check_person_blocking(void)
{
    /* NES uses absolute ObjY (slot 0 = Link). */
    if (OBJ(NES_OBJ_Y, 0u) >= 0x8Eu)
        return;                           /* Link too low; not blocking */
    if ((RAM(NES_LINK_MOVING_DIR) & 0x08u) == 0u)
        return;                           /* not moving up */
    (void)core_reset_moving_dir();        /* clears $0F */
}

void c_obj_shove(unsigned int slot)
{
    /* NES Obj_Shove (Z_07.asm:2274). Phase 7 Task 7.2 step 16 native
     * drain. Stance: REPLACE (was step-6 stub).
     *
     * Two phases:
     *   - Init phase (high bit of ObjShoveDir set): clear high bit,
     *     pick perpendicular policy from ObjDir vs new shove dir.
     *   - Move phase: try to walk up to 4 pixels in shove direction,
     *     respecting GridOffset alignment, tile collision, room edges,
     *     person blocking. Decrements ObjShoveDistance per pixel; on
     *     any block cause, ResetShoveInfo (clears dir + dist).
     *
     * NES $0F = LINK_MOVING_DIR scratch (z07_get_colliding_tile_moving
     * reads it as the direction byte). $03 = pixel counter (4..0).
     * $02 = +1/-1 delta for the moved axis.
     */

    unsigned char shove_dir = (unsigned char)OBJ(NES_OBJ_SHOVE_DIR, slot);

    /* ASL on shove_dir: bit-7 was the "init" flag. */
    if ((shove_dir & 0x80u) != 0u) {
        /* @InitPhase — clear high bit, then check perpendicular. */
        unsigned char dir_low = (unsigned char)(shove_dir & 0x7Fu);
        OBJ(NES_OBJ_SHOVE_DIR, slot) = dir_low;

        unsigned char obj_dir = (unsigned char)ENEMY_DIR(slot);
        if (obj_dir < 0x03u) {
            /* @FacingHorizontally: shove_dir & $0C nonzero -> perpendicular */
            if ((dir_low & 0x0Cu) == 0u)
                return;                  /* horizontal shove + horizontal facing -> OK */
        } else {
            /* facing vertical: shove_dir & $03 nonzero -> perpendicular */
            if ((dir_low & 0x03u) == 0u)
                return;                  /* vertical shove + vertical facing -> OK */
        }

        /* @CheckPerpendicularShove */
        if (OBJ(NES_OBJ_GRID_OFFSET, slot) == 0u)
            return;                      /* aligned -> allow it */
        if (slot != 0u) {
            /* not Link -> ResetShoveInfo */
            OBJ(NES_OBJ_SHOVE_DIR, slot)  = 0u;
            OBJ(NES_OBJ_SHOVE_DIST_BASE, slot) = 0u;
            return;
        }
        /* Link: bounce shove backward (opposite of facing). NES uses
         * absolute addresses ObjDir + ObjShoveDir (slot 0). */
        {
            unsigned int packed = core_get_opposite_dir((unsigned int)ENEMY_DIR(0u));
            OBJ(NES_OBJ_SHOVE_DIR_BASE, 0u) = (unsigned char)(packed & 0xFFu);
        }
        return;
    }

    /* @MoveIfNotDone */
    if (OBJ(NES_OBJ_SHOVE_DIST_BASE, slot) == 0u) {
        /* ResetShoveInfo (no distance left). */
        OBJ(NES_OBJ_SHOVE_DIR, slot)       = 0u;
        OBJ(NES_OBJ_SHOVE_DIST_BASE, slot) = 0u;
        return;
    }

    /* ShoveMoveMin: 4-pixel move loop. */
    for (unsigned int counter = 0u; counter < 4u; counter++) {
        /* @LoopShovePixel */
        unsigned char grid_off = (unsigned char)OBJ(NES_OBJ_GRID_OFFSET, slot);
        if (grid_off == 0u) {
            shove_ensure_object_aligned(slot);
            unsigned char dir = (unsigned char)(OBJ(NES_OBJ_SHOVE_DIR, slot) & 0x0Fu);
            RAM(NES_LINK_MOVING_DIR) = dir;
            unsigned char tile = collision_get_colliding_tile_moving(slot);
            if (tile >= RAM(0x034Au)) {
                /* ObjectFirstUnwalkableTile -> blocked. */
                OBJ(NES_OBJ_SHOVE_DIR, slot)       = 0u;
                OBJ(NES_OBJ_SHOVE_DIST_BASE, slot) = 0u;
                return;
            }
        }

        /* @CheckBoundary */
        {
            unsigned char dir = (unsigned char)(OBJ(NES_OBJ_SHOVE_DIR, slot) & 0x0Fu);
            unsigned char post = object_bound_by_room_with_dir(dir, slot);
            if (post == 0u) {
                OBJ(NES_OBJ_SHOVE_DIR, slot)       = 0u;
                OBJ(NES_OBJ_SHOVE_DIST_BASE, slot) = 0u;
                return;
            }
        }

        /* Person-blocking gate: only fires if slot 1's type is the
         * grumble moblin ($36) OR a person ($4B..$52). */
        {
            unsigned char t1 = (unsigned char)ENEMY_TYPE(1u);
            int is_person = (t1 == 0x36u) ||
                            ((t1 >= 0x4Bu) && (t1 < 0x53u));
            if (is_person) {
                shove_check_person_blocking();
                if (RAM(NES_LINK_MOVING_DIR) == 0u) {
                    OBJ(NES_OBJ_SHOVE_DIR, slot)       = 0u;
                    OBJ(NES_OBJ_SHOVE_DIST_BASE, slot) = 0u;
                    return;
                }
            }
        }

        /* @ChooseSpeed: $02 = +1 if dir bit-0 (right) or bit-2 (down) set,
         * else -1. NES uses (ShoveDir & $05) as the "positive" mask. */
        unsigned char delta;
        {
            unsigned char dir = (unsigned char)OBJ(NES_OBJ_SHOVE_DIR, slot);
            delta = ((dir & 0x05u) != 0u) ? 0x01u : 0xFFu;
        }

        /* Decrement remaining distance. */
        OBJ(NES_OBJ_SHOVE_DIST_BASE, slot) =
            (unsigned char)(OBJ(NES_OBJ_SHOVE_DIST_BASE, slot) - 1u);

        /* Advance grid offset by delta; wrap to 0 on multiple of $10
         * (or 8 for Link). */
        {
            unsigned char new_off =
                (unsigned char)(OBJ(NES_OBJ_GRID_OFFSET, slot) + delta);
            unsigned char masked  = (unsigned char)(new_off & 0x0Fu);
            if (masked == 0u) {
                OBJ(NES_OBJ_GRID_OFFSET, slot) = 0u;
            } else if (slot == 0u && (masked & 0x07u) == 0u) {
                OBJ(NES_OBJ_GRID_OFFSET, slot) = 0u;
            } else {
                OBJ(NES_OBJ_GRID_OFFSET, slot) = new_off;
            }
        }

        /* @ApplySpeed: horizontal bits 0-1 of ShoveDir set -> bump X,
         * else bump Y. */
        {
            unsigned char dir = (unsigned char)OBJ(NES_OBJ_SHOVE_DIR, slot);
            if ((dir & 0x03u) != 0u) {
                OBJ(NES_OBJ_X, slot) =
                    (unsigned char)(OBJ(NES_OBJ_X, slot) + delta);
            } else {
                OBJ(NES_OBJ_Y, slot) =
                    (unsigned char)(OBJ(NES_OBJ_Y, slot) + delta);
            }
        }
    }
}

unsigned int c_shoot_if_wanted(unsigned int shot_type, unsigned int slot)
{
    /* NES Z_04.asm:11351 _ShootIfWanted + Z_07.asm:5795 FindEmptyMonsterSlot
     * + Z_07.asm:5782 SetTypeAndClearObject + Z_01.asm:4026 DestroyObject_WRAM.
     * Phase 7 Task 7.2 step 9 — projectile hook native drain.
     * Stance: REPLACE (was step 6 stub).
     *
     * NES sequence:
     *   1. If ObjWantsToShoot == 0 -> return C=0.
     *   2. FindEmptyMonsterSlot: scan Y=$0B downto $01 for ObjType==0.
     *      None found -> return C=0.
     *   3. If shot_type >= $53 (true projectile, not melee):
     *        if ActiveMonsterShots >= 4 -> return C=0.
     *        else INC ActiveMonsterShots.
     *   4. SetTypeAndClearObject(shot_type, empty): writes ObjType[empty];
     *      DestroyObject_WRAM zeroes ShoveDir/ShoveDist/Timer/State/
     *      InvincibilityTimer + sets Uninitialized=$FF + Metastate=$01.
     *   5. ObjState[empty] = $10, ObjTimer[empty] = 0,
     *      Dir/X/Y[empty] = Dir/X/Y[shooter].
     *   6. Return C=1, Y=empty.
     *
     * This-project convention:
     *   - empty slot == ENEMY_TYPE(s)==0 AND ENEMY_ALIVE_FLAG(s)==0.
     *   - ENEMY_ALIVE_FLAG=1 marks the slot occupied.
     *   - Shot UPDATE rows ($53 flying rock etc) must be wired in
     *     enemy_update_fns[] separately for the shot to do anything;
     *     until then it'll spawn but stand still — visible regression
     *     surface for the next step. */

    if (ENEMY_PUSH_TIMER(slot) == 0u) return 0u;

    unsigned int empty = 0u;
    {
        unsigned int y = 0x0Bu;
        for (;;) {
            if (ENEMY_TYPE(y) == 0u) { empty = y; break; }
            if (y == 0x01u) break;
            y--;
        }
    }
    if (empty == 0u) return 0u;

    if (shot_type >= 0x53u) {
        if (ENEMY_SHOT_COUNT >= 0x04u) return 0u;
        ENEMY_SHOT_COUNT = (unsigned char)(ENEMY_SHOT_COUNT + 1u);
    }

    /* SetTypeAndClearObject + DestroyObject_WRAM compositional clear.
     * Mirrors clear_slot_scratch() in enemy_loop.c but written out so
     * the trampoline match to NES sequence is auditable. */
    ENEMY_TYPE(empty)              = (unsigned char)shot_type;
    ENEMY_OBJ_SHOVE_DIR(empty)     = 0u;
    OBJ(0x00D3u, empty)            = 0u;  /* ObjShoveDistance */
    ENEMY_MOVE_TIMER(empty)        = 0u;  /* ObjTimer ($0028) */
    ENEMY_STATE_TIMER(empty)       = 0u;  /* ObjState ($00AC) */
    ENEMY_HIT_REACTION(empty)      = 0u;  /* ObjInvincibilityTimer ($04F0) */
    ENEMY_METASTATE(empty)         = 0x01u;
    ENEMY_ALIVE_FLAG(empty)        = 1u;  /* slot now occupied */

    /* Shoot block: state $10 = "shot active", copy dir/x/y from shooter. */
    ENEMY_STATE_TIMER(empty) = 0x10u;
    ENEMY_MOVE_TIMER(empty)  = 0u;
    ENEMY_DIR(empty)         = (unsigned char)ENEMY_DIR(slot);
    ENEMY_X(empty)           = (unsigned char)ENEMY_X(slot);
    ENEMY_Y(empty)           = (unsigned char)ENEMY_Y(slot);

    return CARRY_SET | empty;
}

/* -------- Step 6: native enrt_update_octorock -------- */

void enrt_update_octorock(unsigned int slot)
{
    /* NES UpdateOctorock (Z_04.asm:2966). Phase 7 Task 7.2 step 6.
     * Native composition over drained primitives. Stance: EXTEND.
     *
     * Replaces the earlier $07 dispatch row that reused enrt_update_rope
     * (semantically wrong — rope is type $29; enrt_update_rope's leever-
     * style speed-ramp is rope-only behavior). Octorok shape is simpler:
     * walker move + shoot-rock try + dir-based frame select.
     *
     * Steps:
     *   1. Turn rate (ENEMY_AIR_SPEED): blue ($09+) = $A0, red = $70.
     *   2. enrt_wanderer_target_player — runs c_walker_move + targeting.
     *   3. qspeed: $20 if slow ($07/$09), else $40 (fast $08/$0A).
     *   4. _TryShooting flying rock $53. Inlined from enrt_try_shooting
     *      (which is `static` in enemy_walker_runtime.c). With the
     *      step-6 c_shoot_if_wanted stub returning 0, this always lands
     *      in the failure path: ENEMY_WALK_SPEED = qspeed, no shot.
     *   5. sprite_anim_fetch_obj_pos — primes draw scratch + clears
     *      ENEMY_FRAME_FLAGS (ZP_TMPF / $000F).
     *   6. dir-based frame_offset: UP=1, DOWN=2, LEFT=0, RIGHT=0+hflip.
     *   7. anim counter DEC; on 0 reload to 6 + toggle DRAW_FRAME ^ 3.
     *   8. final_frame = dir_offset + DRAW_FRAME.
     *   9. Draw mirrored if dir & $0C, else not mirrored.
     *  10. CheckMonsterCollisions.
     */

    /* Step 1 — Turn rate. */
    ENEMY_AIR_SPEED(slot) =
        (ENEMY_TYPE(slot) >= 0x09u) ? 0xA0u : 0x70u;

    /* Step 2 — Wanderer chain. */
    enrt_wanderer_target_player(slot);

    /* Step 3 — qspeed by color. */
    unsigned char qspeed;
    {
        unsigned char t = ENEMY_TYPE(slot);
        qspeed = (t == 0x07u || t == 0x09u) ? 0x20u : 0x40u;
    }

    /* Step 4 — Inlined _TryShooting flying rock $53. Mirror of static
     * enrt_try_shooting in src/oracle/enemies/enemy_walker_runtime.c. */
    {
        unsigned char new_timer;
        if (ENEMY_HIT_REACTION(slot) != 0u) {
            new_timer = 0u;
        } else {
            unsigned char cur = OBJ(0x0451u, slot);     /* ObjShootTimer */
            if (cur != 0u) {
                new_timer = (unsigned char)(cur - 1u);
            } else if (OBJ(0x0412u, slot) == 0u) {      /* ObjWantsToShoot */
                ENEMY_WALK_SPEED(slot) = qspeed;
                goto draw_octorock;
            } else {
                new_timer = 0x30u;
            }
        }
        OBJ(0x0451u, slot) = new_timer;
        if (new_timer == 0u) {
            ENEMY_WALK_SPEED(slot) = qspeed;
            goto draw_octorock;
        }
        if (new_timer != 0x10u) {
            ENEMY_WALK_SPEED(slot) = 0u;
            goto draw_octorock;
        }
        if ((ENEMY_PAUSE_FLAG | ENEMY_STUN_TIMER(slot)) != 0u) {
            ENEMY_WALK_SPEED(slot) = 0u;
            goto draw_octorock;
        }
        unsigned int result = c_shoot_if_wanted(0x53u, slot);
        if ((result & CARRY_SET) == 0u) {
            ENEMY_WALK_SPEED(slot) = qspeed;
            goto draw_octorock;
        }
        ENEMY_MOVE_TIMER(slot) = 0x80u;
        OBJ(0x0437u, slot) = (unsigned char)(OBJ(0x0437u, slot) - 1u);
        OBJ(0x0412u, slot) = 0u;
        ENEMY_WALK_SPEED(slot) = 0u;
    }

draw_octorock:
    /* Step 5 — Anim_FetchObjPosForSpriteDescriptor. */
    (void)sprite_anim_fetch_obj_pos(slot);

    /* Step 6 — Direction-based frame offset. */
    unsigned char dir_offset;
    {
        unsigned char dir = ENEMY_DIR(slot);
        if ((dir & 0x0Cu) != 0u) {
            /* Vertical: UP=$08 -> 1, DOWN=$04 -> 2. */
            dir_offset = (dir == 0x08u) ? 1u : 2u;
        } else {
            /* Horizontal: LEFT/RIGHT both use offset 0; RIGHT also
             * sets hflip via ENEMY_FRAME_FLAGS (NES INC $0F). */
            dir_offset = 0u;
            if (dir == 0x01u) {
                ENEMY_FRAME_FLAGS =
                    (unsigned char)(ENEMY_FRAME_FLAGS + 1u);
            }
        }
    }

    /* Step 7 — Animate counter. */
    {
        unsigned char ctr = (unsigned char)(ENEMY_ANIM_TIMER(slot) - 1u);
        if (ctr == 0u) {
            ctr = 0x06u;
            ENEMY_DRAW_FRAME(slot) =
                (unsigned char)(ENEMY_DRAW_FRAME(slot) ^ 0x03u);
        }
        ENEMY_ANIM_TIMER(slot) = ctr;
    }

    /* Step 8 — final = dir_offset + DRAW_FRAME. */
    unsigned char final_frame =
        (unsigned char)(dir_offset + ENEMY_DRAW_FRAME(slot));

    /* Step 9 — Draw mirrored vs not. */
    if ((ENEMY_DIR(slot) & 0x0Cu) != 0u) {
        draw_object_mirrored_with_frame(final_frame, slot);
    } else {
        draw_object_not_mirrored_with_frame(final_frame, slot);
    }

    /* Step 10 — CheckMonsterCollisions. */
    link_collision_check_monster_collisions(slot);
}
