/* Phase 8 Task 8.8 — Patra drain (NES Z_04.asm:9552 InitPatra,
 *                                  Z_04.asm:10070 UpdatePatra,
 *                                  Z_04.asm:10164 UpdatePatraChild,
 *                                  Z_04.asm:11898 PatraSines,
 *                                  Z_04.asm:11911 RotateObjectLocation,
 *                                  Z_04.asm:12025 ShiftMultiply,
 *                                  Z_04.asm:12055 DecreaseObjectAngle,
 *                                  Z_01.asm:5337  Anim_SetSpriteDescriptorRedPaletteRow).
 *
 * Drained C:  NONE (this file is the drain).
 * Coverage:   FULL — InitPatra + UpdatePatraChild + the four math
 *             helpers Patra needs that have no native body in the
 *             current Debug.md link set. UpdatePatra body lives in the
 *             bridge (boss_patra.c) because it calls the Gleeok-style
 *             keese-flight wrapper for state 2/3.
 * Stance:     ADOPT — math + state machine match NES asm exactly. The
 *             helpers are local to this TU because they're only called
 *             by Patra; promoting them later if needed is a one-line
 *             move (header decl + extern).
 */

#include "enemy_runtime_private.h"
#include "legacy_bridge.h"

extern void c_check_link_collision(unsigned int slot);

/* PatraSines (NES Z_04.asm:11898). Two quarter-cycles of sin*$80
 * sampled at 16 angle steps. */
static const unsigned char kPatraSines[16] = {
    0x00, 0x18, 0x30, 0x47, 0x5A, 0x6A, 0x76, 0x7D,
    0x80, 0x7D, 0x76, 0x6A, 0x5A, 0x47, 0x30, 0x18
};

/* PatraChildStartAngles (NES Z_04.asm:10152). 7 entries; used to
 * stagger child appearance during State 0. */
static const unsigned char kPatraChildStartAngles[7] = {
    0x14, 0x10, 0x0C, 0x08, 0x04, 0x00, 0x1C
};

/* PatraChild1RotationCosineBits (NES Z_04.asm:10155):
 *   maneuver-index 0: cosine bits = 6
 *   maneuver-index 1: cosine bits = 6 (PatraChild1RotationSineBits[0])
 * PatraChild1RotationSineBits   (NES Z_04.asm:10161):
 *   maneuver-index 0: sine bits = 6
 *   maneuver-index 1: sine bits = 6 (PatraChild1RotationSineBits[1])
 *
 * NES asm reads PatraChild1RotationCosineBits, Y for maneuver Y in {0,1};
 * Y=1 falls into PatraChild2RotationBits ($05) per the .BYTE layout. So
 * the effective Child1 table is { (cos=6, sin=6), (cos=5, sin=6) }. */
static const unsigned char kPatraChild1CosineBits[2] = { 0x06, 0x05 };
static const unsigned char kPatraChild1SineBits[2]   = { 0x06, 0x06 };

/* PatraChild2RotationBits (NES Z_04.asm:10158):
 *   maneuver-index 0: bits = 5
 *   maneuver-index 1: bits = 6 (PatraChild1RotationSineBits[0]) */
static const unsigned char kPatraChild2Bits[2] = { 0x05, 0x06 };

/* ShiftMultiply (NES Z_04.asm:12025).
 *   A = multiplicand, Y = num-high-bits-to-use, multiplier = high-Y bits
 *   of [00]. Returns product in [02:03] (lo:hi).
 *
 * Algorithm = repeated-shift multiply where each iteration shifts the
 * accumulator left and conditionally adds the multiplicand based on the
 * MSB of the multiplier register. The `INC $03` at the unknown block
 * handles the carry-out from the lo-byte add.
 */
static void patra_shift_multiply(unsigned char a_in,
                                 unsigned char y_bits,
                                 unsigned char mult_in,
                                 unsigned int *prod_lo,
                                 unsigned int *prod_hi)
{
    unsigned char mult = mult_in;
    unsigned char acc_lo = 0u;
    unsigned char acc_hi = 0u;
    unsigned char y;

    for (y = y_bits; y != 0u; --y) {
        unsigned int carry_lo;
        unsigned int carry_hi;
        unsigned int new_lo;
        unsigned int new_hi;

        /* ASL [02] / ROL [03] */
        carry_lo = (unsigned int)acc_lo & 0x80u;
        new_lo = (unsigned int)((unsigned char)(acc_lo << 1));
        carry_hi = (unsigned int)acc_hi & 0x80u;
        new_hi = (unsigned int)((unsigned char)((acc_hi << 1) | (carry_lo ? 1u : 0u)));
        acc_lo = (unsigned char)new_lo;
        acc_hi = (unsigned char)new_hi;

        /* ASL [00] — does the multiplier MSB say "add A"? */
        {
            unsigned int msb = (unsigned int)mult & 0x80u;
            mult = (unsigned char)(mult << 1);
            if (msb) {
                unsigned int sum = (unsigned int)acc_lo + (unsigned int)a_in;
                acc_lo = (unsigned char)sum;
                if (sum & 0x100u) {
                    acc_hi++;
                }
                /* Note: ADC with C=0 from CLC, then BCC @next on no carry
                 * -- equivalent to "if carry, INC [03]". (void)carry_hi; */
            }
            (void)carry_hi;
        }
    }

    *prod_lo = acc_lo;
    *prod_hi = acc_hi;
}

/* DecreaseObjectAngle (NES Z_04.asm:12055). Subtracts (high<<8|low)
 * from the slot's angle, capping the whole byte at $1F. */
static void patra_decrease_object_angle(unsigned char low,
                                        unsigned char high,
                                        unsigned int slot)
{
    int sub1   = (int)ENEMY_OBJ_ANGLE_FRAC(slot) - (int)low;
    int borrow = (sub1 < 0) ? 1 : 0;
    int sub2;

    ENEMY_OBJ_ANGLE_FRAC(slot) = (unsigned char)sub1;
    sub2 = (int)ENEMY_OBJ_ANGLE_WHOLE(slot) - (int)high - borrow;
    ENEMY_OBJ_ANGLE_WHOLE(slot) = (unsigned char)(sub2 & 0x1F);
}

/* RotateObjectLocation (NES Z_04.asm:11911). Updates ObjX/ObjXFrac
 * directly; returns the new ObjY (caller stores). */
static unsigned char patra_rotate_object_location(unsigned char cosine_bits,
                                                  unsigned char sine_bits,
                                                  unsigned int slot)
{
    unsigned char angle = ENEMY_OBJ_ANGLE_WHOLE(slot);
    unsigned int prod_lo;
    unsigned int prod_hi;
    unsigned char angle_plus_8;
    unsigned char angle_minus_8;
    unsigned char new_y;

    /* ---- X axis ---- */
    {
        unsigned char sin_idx = (unsigned char)(angle & 0x0Fu);
        unsigned char sin_val = kPatraSines[sin_idx];
        patra_shift_multiply(ENEMY_OBJ_QSPEED_FRAC(slot),
                             sine_bits, sin_val, &prod_lo, &prod_hi);
    }
    if (((unsigned char)(angle & 0x18u)) >= 0x10u) {
        int sub1 = (int)ENEMY_OBJ_X_FRAC(slot) - (int)prod_lo;
        int borrow = (sub1 < 0) ? 1 : 0;
        ENEMY_OBJ_X_FRAC(slot) = (unsigned char)sub1;
        ENEMY_X(slot) = (unsigned char)((int)ENEMY_X(slot) - (int)prod_hi - borrow);
    } else {
        unsigned int sum1 = (unsigned int)ENEMY_OBJ_X_FRAC(slot) + prod_lo;
        unsigned int carry = (sum1 >> 8) & 1u;
        ENEMY_OBJ_X_FRAC(slot) = (unsigned char)sum1;
        ENEMY_X(slot) = (unsigned char)((unsigned int)ENEMY_X(slot) + prod_hi + carry);
    }

    /* ---- Y axis (cosine = sin(angle + 8)) ---- */
    angle_plus_8 = (unsigned char)(angle + 8u);
    {
        unsigned char cos_idx = (unsigned char)(angle_plus_8 & 0x0Fu);
        unsigned char cos_val = kPatraSines[cos_idx];
        patra_shift_multiply(ENEMY_OBJ_QSPEED_FRAC(slot),
                             cosine_bits, cos_val, &prod_lo, &prod_hi);
    }
    angle_minus_8 = (unsigned char)(angle - 8u);
    if (((unsigned char)(angle_minus_8 & 0x18u)) >= 0x10u) {
        int sub1 = (int)ENEMY_OBJ_Y_FRAC(slot) - (int)prod_lo;
        int borrow = (sub1 < 0) ? 1 : 0;
        ENEMY_OBJ_Y_FRAC(slot) = (unsigned char)sub1;
        new_y = (unsigned char)((int)ENEMY_Y(slot) - (int)prod_hi - borrow);
    } else {
        unsigned int sum1 = (unsigned int)ENEMY_OBJ_Y_FRAC(slot) + prod_lo;
        unsigned int carry = (sum1 >> 8) & 1u;
        ENEMY_OBJ_Y_FRAC(slot) = (unsigned char)sum1;
        new_y = (unsigned char)((unsigned int)ENEMY_Y(slot) + prod_hi + carry);
    }
    return new_y;
}

/* PatraChild_Draw (NES Z_04.asm:10312).
 *   JSR Anim_SetSpriteDescriptorRedPaletteRow  ; A=2, [04]=[05]=$02
 *   JSR Anim_AdvanceAnimCounterAndSetObjPosForSpriteDescriptor (val=2)
 *   LDA ObjAnimFrame, X
 *   JMP DrawObjectNotMirrored
 */
static void patra_child_draw(unsigned int slot)
{
    z01_anim_set_sprite_desc_attrs(0x02u);
    c_anim_advance_and_fetch(2u, slot);
    {
        unsigned char frame = ENEMY_DRAW_FRAME(slot);
        c_draw_object_not_mirrored_with_frame(frame, slot);
    }
}

/* InitPatra (NES Z_04.asm:9552).
 *   ObjInvincibilityMask, X = $FE  (sword-only)
 *   ObjX = $80, ObjY = $70, ObjDir = $08 (up)
 *   Flyer_ObjSpeed, X = $1F, FlyingMaxSpeedFrac = $40
 *   SampleRequest = $40 (Digdogger/Manhandla/Patra roar)
 *   ObjTimer+1, X = $FF
 *   Patra type $47 -> child type $25; type $48 -> child type $26.
 *   Loop slots 2..9 setting ObjType[Y] = child_type and
 *   ObjInvincibilityMask[Y] = $FE.
 */
void enrt_init_patra(unsigned int slot)
{
    unsigned char child_type;
    unsigned int  child_slot;

    ENEMY_INVINCIBILITY(slot) = 0xFEu;
    ENEMY_X(slot) = 0x80u;
    ENEMY_Y(slot) = 0x70u;
    ENEMY_DIR(slot) = 0x08u;
    ENEMY_AIR_SPEED(slot) = 0x1Fu;
    ENEMY_MAX_AIR_SPEED   = 0x40u;
    ENEMY_SFX_BOSS_CRY    = 0x40u;
    ENEMY_OBJ_TIMER_HI(slot) = 0xFFu;

    child_type = (ENEMY_TYPE(slot) == 0x47u) ? 0x25u : 0x26u;
    for (child_slot = 2u; child_slot < 10u; ++child_slot) {
        ENEMY_TYPE(child_slot) = child_type;
        ENEMY_INVINCIBILITY(child_slot) = 0xFEu;
    }
}

/* UpdatePatraChild (NES Z_04.asm:10164). State 0 stages each child's
 * appearance off the slot-2 child's angle; State 1 orbits Patra. */
void enrt_update_patra_child(unsigned int slot)
{
    /* ObjState, X (= NES $AC) drives the State 0/1 toggle. */
    if (ENEMY_STATE_TIMER(slot) != 0u) {
        /* PatraChild_State1 (Z_04.asm:10244). */
        unsigned char maneuver_idx;
        unsigned char cos_bits;
        unsigned char sin_bits;
        unsigned char new_y;

        /* Add Patra's distance traveled (Flyer_ObjOffsetX/Y at slot 1). */
        ENEMY_X(slot) = (unsigned char)(ENEMY_X(slot) + ENEMY_FLYER_OFFSET_X(1));
        ENEMY_Y(slot) = (unsigned char)(ENEMY_Y(slot) + ENEMY_FLYER_OFFSET_Y(1));

        /* Decrease angle by $70 (Child1) or $60 (Child2). */
        {
            unsigned char low = (ENEMY_TYPE(slot) == 0x25u) ? 0x70u : 0x60u;
            patra_decrease_object_angle(low, 0x00u, slot);
        }

        maneuver_idx = (unsigned char)(ENEMY_PATRA_MANEUVER_INDEX(1) & 0x01u);
        if (ENEMY_TYPE(slot) == 0x25u) {
            cos_bits = kPatraChild1CosineBits[maneuver_idx];
            sin_bits = kPatraChild1SineBits[maneuver_idx];
        } else {
            unsigned char bits = kPatraChild2Bits[maneuver_idx];
            cos_bits = bits;
            sin_bits = bits;
        }
        new_y = patra_rotate_object_location(cos_bits, sin_bits, slot);
        ENEMY_Y(slot) = new_y;

        patra_child_draw(slot);

        /* ObjState+1 == 0 → Patra still in spawn animation, skip
         * collision until last child has appeared. */
        if (ENEMY_STATE_TIMER(1) == 0u)
            return;

        c_check_monster_collisions(slot);
        /* Post-collision: if monster's metastate cleared (= still alive),
         * exit. NES `LDA ObjMetastate, X / BEQ @Exit`. */
        if (ENEMY_METASTATE(slot) == 0u)
            return;
        enrt_set_dead_dummy_obj_type(slot);
        return;
    }

    /* State 0 (PatraChild_State0). */
    if (slot != 2u) {
        unsigned int probe_y;
        /* If slot 2 is still in State 0, no later child can advance. */
        if (ENEMY_STATE_TIMER(2) == 0u)
            return;
        /* Y = slot - 3 → index into PatraChildStartAngles. */
        probe_y = slot - 3u;
        if (ENEMY_OBJ_ANGLE_WHOLE(2) != kPatraChildStartAngles[probe_y])
            return;
    }
    /* @Ready: when slot 9 reaches here, advance Patra parent's state. */
    if (slot == 9u) {
        ENEMY_STATE_TIMER(1)++;
    }
    ENEMY_STATE_TIMER(slot)++;
    ENEMY_DIR(slot) = 0x80u;            /* TODO?: NES quirk */
    ENEMY_OBJ_ANGLE_WHOLE(slot) = 0x18u;
    ENEMY_X(slot) = ENEMY_X(1);
    {
        unsigned char radius = (ENEMY_TYPE(slot) == 0x25u) ? 0x2Cu : 0x18u;
        ENEMY_Y(slot) = (unsigned char)(ENEMY_Y(1) - radius);
    }
}
