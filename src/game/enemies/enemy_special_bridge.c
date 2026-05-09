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

/* PolsVoice RAM cell aliases (NES ObjVars.inc + Variables.inc). */
#define POLS_OBJ_REM_DISTANCE(slot)     OBJ(0x0394u, (slot))  /* ObjRemDistance */
#define POLS_OBJ_STATE(slot)            OBJ(0x00ACu, (slot))  /* ObjState */
#define POLS_STUN_TIMER(slot)           OBJ(0x003Du, (slot))  /* ObjStunTimer */
#define POLS_OBJ_SPEED_WHOLE(slot)      OBJ(0x0412u, (slot))  /* PolsVoice_ObjSpeedWhole */
#define POLS_OBJ_LAST_TILE(slot)        OBJ(0x041Fu, (slot))  /* PolsVoice_ObjLastTile (alias of ENEMY_AIR_SPEED) */
#define POLS_OBJ_TARGET_Y(slot)         OBJ(0x042Cu, (slot))  /* PolsVoice_ObjTargetY (alias of ObjCaptureTimer) */
#define POLS_OBJ_SPEED_FRAC(slot)       OBJ(0x0444u, (slot))  /* PolsVoice_ObjSpeedFrac */
#define POLS_INV_CLOCK                  RAM(0x066Cu)          /* InvClock */
#define POLS_INVINCIBILITY_MASK(slot)   OBJ(0x04B2u, (slot))  /* ObjInvincibilityMask */
#define POLS_FRAME_COUNTER              RAM(0x0015u)          /* FrameCounter */
#define POLS_RANDOM(slot)               OBJ(0x0019u, (slot))  /* Random */

/* PolsVoice tables (verbatim from NES Z_04.asm:6516-6531).
 *
 * PolsVoiceWalkSpeedsX is the externally-linked NES table (drained
 * `enrt_pols_voice_move_x` in src/oracle/enemies/enemy_boss_runtime.c
 * declares it as `extern const unsigned char PolsVoiceWalkSpeedsX[]`).
 * Defined here so the drain links cleanly without adding a new TU. */
const unsigned char PolsVoiceWalkSpeedsX[10] = {
    0x01u, 0xFFu, 0x00u, 0x00u, 0x01u, 0xFFu, 0x00u, 0x00u, 0x01u, 0xFFu
};
static const unsigned char k_pols_voice_walk_speeds_y[10] = {
    0x00u, 0x00u, 0x00u, 0x01u, 0x01u, 0x01u, 0x00u, 0xFFu, 0xFFu, 0xFFu
};
static const unsigned char k_pols_voice_initial_jump_speeds[8] = {
    0xFDu, 0xFDu, 0xFFu, 0xFFu, 0xFFu, 0xFFu, 0xFFu, 0xFCu
};
static const unsigned char k_pols_voice_destination_y_offsets[8] = {
    0x00u, 0x00u, 0x20u, 0x20u, 0x20u, 0x20u, 0x20u, 0xE0u
};
static const unsigned char k_pols_voice_directions[4] = {
    0x01u, 0x02u, 0x04u, 0x08u
};

/* Drained primitives (enemy_walker_bridge / enemy_boss_bridge / projectile). */
extern void z04_update_common_wanderer(unsigned int turn_rate, unsigned int slot);
extern void c_check_monster_collisions(unsigned int slot);
extern unsigned char z07_anim_fetch_obj_pos(unsigned int slot);
extern void z07_anim_advance_and_fetch(unsigned int val, unsigned int slot);

/* Drained PolsVoice helpers (enemy_boss_runtime.c). */
extern void enrt_pols_voice_move_x(unsigned int slot);
extern unsigned int enrt_pols_voice_is_square_walkable(unsigned int slot);

/* CARRY_SET sentinel matches enrt_*_runtime.c. */
#ifndef CARRY_SET
#define CARRY_SET 0x10000u
#endif

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

/*--------------------------------------------------------------------
 * UpdatePolsVoice (drained from Z_04.asm:6533)
 *
 * Two-state machine driven by ObjState:
 *
 *   State 0 — walking. Decrement ObjRemDistance; on rollover schedule
 *             a state-1 jump. Add per-direction WalkSpeedY (table) to
 *             ObjY; check walkability — if blocked by tile $B0 or
 *             $F4..$FF, transition to state 1; else flip direction
 *             (horizontal: EOR $03 + 2 MoveX calls; vertical:
 *             EOR $0C).
 *
 *   State 1 — jumping. Add fractional accel $38 to SpeedFrac with
 *             carry into SpeedWhole; add SpeedWhole to ObjY (vertical
 *             projectile arc). Exit early if speed still negative or
 *             ObjY < TargetY. On reach: zero SpeedFrac/Whole, pick a
 *             new random direction (Random & 3 -> directions[$01,$02,
 *             $04,$08]), random distance ($31 or $71), then snap X/Y
 *             to grid (X=(X+8)&$F0, Y=((Y+8)&$F0)-3).
 *
 * Pre-pass guards (both states):
 *   - InvClock active OR ObjStunTimer != 0 -> draw + collisions only.
 *   - Odd FrameCounter (LSR carry set) -> draw + collisions only.
 *
 * Tail-call (both states):
 *   - Anim_AdvanceAnimCounterAndSetObjPosForSpriteDescriptor(8).
 *   - DrawObjectMirrored(ObjAnimFrame).
 *   - ObjInvincibilityMask = $FE  (sword-only damage; arrow special-
 *     cased outside).
 *   - CheckMonsterCollisions.
 *
 * Carry-from-CMP semantics (state-1 reach branch):
 *   The "ADC #$30" after "AND #$40" depends on carry from the prior
 *   "CMP PolsVoice_ObjTargetY" — taking the BCS-fall-through implies
 *   ObjY >= TargetY, so carry is set. The translation hardcodes +1 to
 *   match: ObjRemDistance = (Random & $40) + $30 + 1.
 *
 * PolsVoice_MoveX leaves Y register = ObjDir - 1 in NES asm; we
 * recompute that index after the call as `dir_idx`.
 *------------------------------------------------------------------*/
void enrt_update_pols_voice(unsigned int slot)
{
    unsigned char dir_idx = 0u;
    unsigned char tile;
    unsigned char dir;
    unsigned char y_idx;

    /* Magic clock or stun -> bypass movement. */
    if ((unsigned char)POLS_INV_CLOCK != 0u
        || (unsigned char)POLS_STUN_TIMER(slot) != 0u) {
        goto draw_and_check;
    }

    /* Odd frame -> bypass movement. NES: LDA FrameCounter / LSR / BCS. */
    if (((unsigned char)POLS_FRAME_COUNTER & 0x01u) != 0u) {
        goto draw_and_check;
    }

    /* Always JSR PolsVoice_MoveX before state branch. */
    enrt_pols_voice_move_x(slot);
    dir_idx = (unsigned char)((unsigned char)ENEMY_DIR(slot) - 1u);

    if ((unsigned char)POLS_OBJ_STATE(slot) != 0u) {
        /* State 1: jumping (Z_04.asm:6675 UpdatePolsVoiceState1_Jumping). */
        unsigned int sum_frac =
            (unsigned int)(unsigned char)POLS_OBJ_SPEED_FRAC(slot) + 0x38u;
        unsigned char carry = (sum_frac >= 0x100u) ? 1u : 0u;
        unsigned char whole;
        POLS_OBJ_SPEED_FRAC(slot) = (uint8_t)sum_frac;
        whole = (unsigned char)((unsigned char)POLS_OBJ_SPEED_WHOLE(slot)
                                + carry);
        POLS_OBJ_SPEED_WHOLE(slot) = whole;
        ENEMY_Y(slot) =
            (uint8_t)((unsigned char)ENEMY_Y(slot) + whole);

        /* If speed still negative OR ObjY < TargetY, fall through to
         * walkability check (NES: BMI/BCC -> @Exit -> RTS -> caller's
         * JMP @CheckWalkability). */
        if ((whole & 0x80u) == 0u
            && (unsigned char)ENEMY_Y(slot)
               >= (unsigned char)POLS_OBJ_TARGET_Y(slot))
        {
            /* Reached destination -> back to state 0, randomize. */
            unsigned char rng_dir;
            unsigned char rng_dist;
            POLS_OBJ_STATE(slot) = 0u;
            POLS_OBJ_SPEED_FRAC(slot) = 0u;
            POLS_OBJ_SPEED_WHOLE(slot) = 0u;
            rng_dir = (unsigned char)POLS_RANDOM(slot);
            ENEMY_DIR(slot) = k_pols_voice_directions[rng_dir & 0x03u];
            rng_dist = (unsigned char)POLS_RANDOM(slot);
            /* Carry from CMP target was set (we passed BCC) -> ADC adds 1. */
            POLS_OBJ_REM_DISTANCE(slot) =
                (uint8_t)((rng_dist & 0x40u) + 0x30u + 1u);
            /* Snap X/Y to grid. */
            ENEMY_X(slot) =
                (uint8_t)(((unsigned char)ENEMY_X(slot) + 0x08u) & 0xF0u);
            ENEMY_Y(slot) =
                (uint8_t)((((unsigned char)ENEMY_Y(slot) + 0x08u) & 0xF0u)
                          - 0x03u);
        }
        goto check_walkability;
    }

    /* State 0: walking. */
    if ((unsigned char)POLS_OBJ_REM_DISTANCE(slot) == 0u) {
        goto set_state1;
    }
    POLS_OBJ_REM_DISTANCE(slot) =
        (uint8_t)((unsigned char)POLS_OBJ_REM_DISTANCE(slot) - 1u);
    ENEMY_Y(slot) = (uint8_t)((unsigned char)ENEMY_Y(slot)
                              + k_pols_voice_walk_speeds_y[dir_idx]);
    /* Fall through. */

check_walkability:
    {
        unsigned int walk = enrt_pols_voice_is_square_walkable(slot);
        if ((walk & CARRY_SET) == 0u) {
            goto draw_and_check;
        }
    }
    tile = (unsigned char)((unsigned char)POLS_OBJ_LAST_TILE(slot) & 0xFCu);
    if (tile == 0xB0u || tile >= 0xF4u) {
        goto set_state1;
    }
    /* Flip direction. */
    dir = (unsigned char)ENEMY_DIR(slot);
    if ((dir & 0x03u) != 0u) {
        /* Horizontal: EOR $03 (right<->left), then 2x MoveX. */
        ENEMY_DIR(slot) = (uint8_t)((dir & 0x03u) ^ 0x03u);
        enrt_pols_voice_move_x(slot);
        enrt_pols_voice_move_x(slot);
    } else {
        /* Vertical: EOR $0C (down<->up). */
        ENEMY_DIR(slot) = (uint8_t)(dir ^ 0x0Cu);
    }
    goto draw_and_check;

set_state1:
    if ((unsigned char)POLS_OBJ_STATE(slot) != 0u) {
        /* Already jumping (entered SetState1 via tile-block). */
        goto draw_and_check;
    }
    POLS_OBJ_STATE(slot) =
        (uint8_t)((unsigned char)POLS_OBJ_STATE(slot) + 1u);
    y_idx = (unsigned char)((unsigned char)ENEMY_DIR(slot) - 1u);
    /* Edge guards: top half forces idx=3 (down jump), bottom forces
     * idx=7 (up jump), so PolsVoice never jumps off-screen. */
    if ((unsigned char)ENEMY_Y(slot) < 0x78u) {
        y_idx = 0x03u;
    }
    if ((unsigned char)ENEMY_Y(slot) >= 0xA8u) {
        y_idx = 0x07u;
    }
    POLS_OBJ_SPEED_WHOLE(slot) =
        k_pols_voice_initial_jump_speeds[y_idx];
    POLS_OBJ_TARGET_Y(slot) =
        (uint8_t)((unsigned char)ENEMY_Y(slot)
                  + k_pols_voice_destination_y_offsets[y_idx]);
    ENEMY_DIR(slot) = (uint8_t)(y_idx + 1u);
    /* Fall through. */

draw_and_check:
    z07_anim_advance_and_fetch(0x08u, slot);
    draw_object_mirrored_with_frame(
        (unsigned char)ENEMY_DRAW_FRAME(slot), slot);
    POLS_INVINCIBILITY_MASK(slot) = 0xFEu;
    c_check_monster_collisions(slot);
    (void)dir_idx;
}
