/* enemy_special_bridge.c — Phase 7 Task 7.5 special-enemy UPDATE
 * primitives bridge.
 *
 * Per Drain Rule D1 (drain primary, NES asm secondary tiebreaker):
 *
 * The special-enemy family ($16 PolsVoice / $17 LikeLike / $27
 * Wallmaster) UPDATE bodies are NOT directly drained as
 * enrt_update_<name> in src/oracle/enemies/. Helpers ARE drained
 * (enrt_pols_voice_move_x, enrt_wallmaster_*, etc), but the top-level
 * UPDATE state machines live only in NES Z_04.asm. This file carries
 * native bridge bodies translated per-line from NES asm with audit
 * trail, same model as enemy_boss_bridge.c (Aquamentus / Vire) and
 * enemy_jumper_bridge.c.
 *
 * Step 2 wires $17 LikeLike. Subsequent steps add $16 PolsVoice +
 * $27 Wallmaster.
 *
 * Hard rule WT-5: lives at src/game/enemies/, not RoomRom/.
 */

#include <stdint.h>                     /* uint8_t */
#include "platform_abi.h"               /* RAM, OBJ */
#include "enemy_state.h"                /* ENEMY_*, slot 0 = Link */
#include "world/draw_dispatch.h"        /* draw_object_mirrored_with_frame,
                                         * draw_object_mirrored_over_link */
#include "enemies/enemy_dispatch.h"     /* enemy_hide_sprites_over_link */

/* NES RAM cell aliases not yet in enemy_state.h. */
#define LIKELIKE_CAPTURE_TIMER(slot)    OBJ(0x042Cu, (slot))  /* ObjCaptureTimer */
#define LINK_PARALYZED_FLAG             RAM(0x0512u)          /* LinkParalyzed */
#define INV_MAGIC_SHIELD                RAM(0x0676u)          /* InvMagicShield */
#define LIKELIKE_OBJ_SHOVE_DIR(slot)    OBJ(0x00C0u, (slot))  /* ObjShoveDir */
#define LIKELIKE_OBJ_SHOVE_DIST(slot)   OBJ(0x00D3u, (slot))  /* ObjShoveDistance */

/* Drained primitives (enemy_walker_bridge / enemy_boss_bridge / projectile). */
extern void z04_update_common_wanderer(unsigned int turn_rate, unsigned int slot);
extern void c_check_monster_collisions(unsigned int slot);
extern unsigned char z07_anim_fetch_obj_pos(unsigned int slot);

/*--------------------------------------------------------------------
 * UpdateLikeLike (drained from Z_04.asm:6818)
 *
 * State machine has two paths driven by ObjCaptureTimer (slot's
 * $042C cell):
 *
 * 1. ObjCaptureTimer == 0 (free roaming):
 *    - UpdateCommonWanderer(turn_rate=$80) — wander + 1px-pulse.
 *    - 4-frame anim cycle (vs 2-frame default): every 8 frames
 *      step (frame+1) & 3.
 *    - Fetch obj pos + draw mirrored + check monster collisions.
 *    - If post-collision ObjCaptureTimer != 0 (Link grab fired
 *      inside CheckMonsterCollisions), seed capture state:
 *      monster X/Y = Link X/Y, clear Link's timer / metastate /
 *      shove dir+distance, reset monster anim (frame=0,counter=4),
 *      paralyze Link.
 *
 * 2. ObjCaptureTimer != 0 (Link captured):
 *    - Animate up to frame 3 (LDA #$02 / CMP frame / BCC = skip
 *      anim if frame > 2; else dec counter; on rollover counter=4
 *      and frame++).
 *    - Increment capture timer; on >= $60, clear magic shield + lock
 *      timer at $C0 (so the bite-flash keeps replaying without
 *      overflowing).
 *    - Draw mirrored OVER Link (sprite slots $10/$11) so the
 *      like-like body covers him.
 *    - Check collisions; if metastate != 0 (monster died from Link's
 *      sword swing), free Link (LinkParalyzed=0) + hide the
 *      over-Link sprites.
 *
 * NES tail-call HideSpritesOverLink at the bottom of @HandleCaptured
 * branch is replaced with a direct call to enemy_hide_sprites_over_link.
 *------------------------------------------------------------------*/
void enrt_update_like_like(unsigned int slot)
{
    if (LIKELIKE_CAPTURE_TIMER(slot) != 0u) {
        /* @HandleCaptured branch. */
        unsigned char frame = (unsigned char)ENEMY_DRAW_FRAME(slot);
        if (frame <= 0x02u) {
            /* NES: LDA #$02 / CMP frame / BCC @IncCaptureTime —
             * BCC = $02 < frame, i.e. frame > $02 -> skip animate. */
            unsigned char counter =
                (unsigned char)(ENEMY_ANIM_TIMER(slot) - 1u);
            ENEMY_ANIM_TIMER(slot) = counter;
            if (counter == 0u) {
                ENEMY_ANIM_TIMER(slot) = 0x04u; /* ASL of $02. */
                ENEMY_DRAW_FRAME(slot) = (uint8_t)(frame + 1u);
            }
        }
        /* @IncCaptureTime: */
        LIKELIKE_CAPTURE_TIMER(slot) =
            (uint8_t)((unsigned char)LIKELIKE_CAPTURE_TIMER(slot) + 1u);
        if ((unsigned char)LIKELIKE_CAPTURE_TIMER(slot) >= 0x60u) {
            INV_MAGIC_SHIELD = 0u;
            LIKELIKE_CAPTURE_TIMER(slot) = 0xC0u;
        }
        /* @DrawAfterCapture: */
        z07_anim_fetch_obj_pos(slot);
        draw_object_mirrored_over_link(
            (unsigned char)ENEMY_DRAW_FRAME(slot), slot);
        c_check_monster_collisions(slot);
        if ((unsigned char)ENEMY_METASTATE(slot) != 0u) {
            /* Monster died — release Link + hide over-Link sprites. */
            LINK_PARALYZED_FLAG = 0u;
            enemy_hide_sprites_over_link();
        }
        return;
    }

    /* Free-roaming path. */
    z04_update_common_wanderer(0x80u, slot);

    /* 4-frame anim. NES: DEC counter; BNE @Draw; LDA #$08; STA counter;
     * INY (frame+1); AND #$03; STA frame. */
    {
        unsigned char counter =
            (unsigned char)(ENEMY_ANIM_TIMER(slot) - 1u);
        ENEMY_ANIM_TIMER(slot) = counter;
        if (counter == 0u) {
            ENEMY_ANIM_TIMER(slot) = 0x08u;
            ENEMY_DRAW_FRAME(slot) =
                (uint8_t)(((unsigned char)ENEMY_DRAW_FRAME(slot) + 1u)
                          & 0x03u);
        }
    }

    /* @Draw. */
    z07_anim_fetch_obj_pos(slot);
    draw_object_mirrored_with_frame(
        (unsigned char)ENEMY_DRAW_FRAME(slot), slot);
    c_check_monster_collisions(slot);

    /* If post-collision capture timer fired, seed capture state. */
    if ((unsigned char)LIKELIKE_CAPTURE_TIMER(slot) == 0u) {
        return;
    }
    /* Monster captured Link — overlap him + reset link state. */
    ENEMY_X(slot) = (uint8_t)ENEMY_X(0u);
    ENEMY_Y(slot) = (uint8_t)ENEMY_Y(0u);
    ENEMY_MOVE_TIMER(0u) = 0u;
    ENEMY_METASTATE(0u) = 0u;
    LIKELIKE_OBJ_SHOVE_DIR(0u) = 0u;
    LIKELIKE_OBJ_SHOVE_DIST(0u) = 0u;
    /* Restart monster's movement frame cycle: frame 0, counter 4. */
    ENEMY_DRAW_FRAME(slot) = 0u;
    ENEMY_ANIM_TIMER(slot) = 0x04u;
    /* Now Link can't move. */
    LINK_PARALYZED_FLAG =
        (uint8_t)((unsigned char)LINK_PARALYZED_FLAG + 1u);
}
