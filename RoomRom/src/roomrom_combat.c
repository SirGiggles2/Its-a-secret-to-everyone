#include "roomrom_combat.h"
#include "roomrom_sprites.h"

/* RoomRom S7 v4 combat — sword swing.
 *
 * NES Z1 model (reference/aldonunez/Z_05.asm WieldSword + Z_07.asm
 * UpdateSwordOrRod + PlayerToWeaponOffsets[XY]):
 *
 *   State 1 (5 frames): windup. Sword raised UP regardless of facing.
 *                       Link in attack pose facing his current direction.
 *   State 2 (8 frames): full extend in facing direction.
 *   State 3 (1 frame):  mid-retract.
 *   State 4 (1 frame):  almost retracted.
 *   State 5 (1 frame):  invisible — sword sprite hidden, Link returns
 *                       to walk pose.
 *
 * Total swing window: 5 + 8 + 1 + 1 + 1 = 16 frames. Re-swing locked
 * the entire 16 frames. Link's body stays in attack pose for states
 * 1-4 (15 frames), reverts to walk pose at state 5.
 *
 * Sword position offsets (from PlayerToWeaponOffsetsX/Y at Z_07:4337):
 *   reverse-direction order = up, down, left, right
 *   state 1: X=-1,+1, 0,-8   Y=-9,-14,-11,-11
 *   state 2: X=-1,+1,-11,+11 Y=-10,+13,+3,+3
 *   state 3: X=-1,+1,-7,+7   Y=-9,+9,+3,+3
 *   state 4: X=-1,+1,-3,+3   Y=-1,+5,+3,+3
 *
 * For state 1 the sword is drawn UP (vertical, no flip) regardless of
 * Link's facing — the windup. The position offset for state 1 still
 * varies per facing (Link's hand position differs).
 */

#define COMBAT_STATE1_FRAMES   5u
#define COMBAT_STATE2_FRAMES   8u
#define COMBAT_STATE3_FRAMES   1u
#define COMBAT_STATE4_FRAMES   1u
#define COMBAT_STATE5_FRAMES   1u
#define COMBAT_TOTAL_FRAMES    (COMBAT_STATE1_FRAMES + COMBAT_STATE2_FRAMES \
                                + COMBAT_STATE3_FRAMES + COMBAT_STATE4_FRAMES \
                                + COMBAT_STATE5_FRAMES)

typedef enum {
    COMBAT_IDLE  = 0,
    COMBAT_ACTIVE
} combat_state_t;

static combat_state_t s_state    = COMBAT_IDLE;
static unsigned char  s_frame    = 0u;   /* 0..COMBAT_TOTAL_FRAMES-1 */
static link_face_t    s_face     = LINK_FACE_DOWN;

/* Per-state, per-facing X offset. Index: [state-1][face].
 * face order: 0=DOWN, 1=UP, 2=LEFT, 3=RIGHT.
 * NES tables are in reverse direction order (up, down, left, right);
 * reordered here to match RoomRom's link_face_t enum. */
static const signed char sword_offset_x[4][4] = {
    /*               DOWN UP   LEFT  RIGHT */
    /* state 1 */ {  +1, -1,    0,   -8 },
    /* state 2 */ {  +1, -1,  -11,  +11 },
    /* state 3 */ {  +1, -1,   -7,   +7 },
    /* state 4 */ {  +1, -1,   -3,   +3 },
};

static const signed char sword_offset_y[4][4] = {
    /*               DOWN UP   LEFT  RIGHT */
    /* state 1 */ { -14, -9,  -11,  -11 },
    /* state 2 */ { +13,-10,   +3,   +3 },
    /* state 3 */ {  +9, -9,   +3,   +3 },
    /* state 4 */ {  +5, -1,   +3,   +3 },
};

void roomrom_combat_init(void)
{
    s_state = COMBAT_IDLE;
    s_frame = 0u;
    roomrom_sprites_clear_sword();
}

void roomrom_combat_try_swing(link_face_t face, short link_x, short link_y)
{
    (void)link_x; (void)link_y;
    if (s_state != COMBAT_IDLE) return;
    s_state = COMBAT_ACTIVE;
    s_frame = 0u;
    s_face  = face;
}

unsigned char roomrom_combat_link_locked(void)
{
    return s_state != COMBAT_IDLE;
}

/* Returns 1..5 for active states, 0 for idle. */
static unsigned char compute_state(unsigned char frame)
{
    unsigned char acc = 0u;
    acc = (unsigned char)(acc + COMBAT_STATE1_FRAMES);
    if (frame < acc) return 1u;
    acc = (unsigned char)(acc + COMBAT_STATE2_FRAMES);
    if (frame < acc) return 2u;
    acc = (unsigned char)(acc + COMBAT_STATE3_FRAMES);
    if (frame < acc) return 3u;
    acc = (unsigned char)(acc + COMBAT_STATE4_FRAMES);
    if (frame < acc) return 4u;
    return 5u;
}

void roomrom_combat_update(short link_x, short link_y, link_face_t face)
{
    unsigned char st;
    short sx, sy;
    (void)face;

    if (s_state == COMBAT_IDLE) {
        roomrom_sprites_clear_sword();
        return;
    }

    st = compute_state(s_frame);

    /* Body pose: attack pose during states 1-4, walk pose at state 5
     * (set by main.c on the next frame once link_locked() returns 0). */
    if (st <= 4u) {
        roomrom_sprites_set_link_attack_pose(link_x, link_y, s_face);
    }

    if (st == 5u) {
        /* Invisible — sword sprite hidden. Link's walk pose will be
         * restored by main.c after combat_link_locked() returns 0. */
        roomrom_sprites_clear_sword();
    } else {
        unsigned char tier = (unsigned char)(st - 1u);   /* 0..3 */
        unsigned char face_idx = (unsigned char)s_face;
        sx = (short)(link_x + sword_offset_x[tier][face_idx]);
        sy = (short)(link_y + sword_offset_y[tier][face_idx]);

        if (st == 1u) {
            /* Windup: sword raised UP (vertical, no flip) regardless of
             * facing. Z_07.asm UpdateSwordOrRod: "If state = 1, use up
             * direction." */
            roomrom_sprites_set_sword_vertical(sx, sy, 0u);
        } else {
            /* States 2-4: sword in facing direction. */
            switch (s_face) {
            case LINK_FACE_DOWN:
                roomrom_sprites_set_sword_vertical(sx, sy, 1u);
                break;
            case LINK_FACE_UP:
                roomrom_sprites_set_sword_vertical(sx, sy, 0u);
                break;
            case LINK_FACE_LEFT:
                roomrom_sprites_set_sword_horizontal(sx, sy, 1u);
                break;
            case LINK_FACE_RIGHT:
                roomrom_sprites_set_sword_horizontal(sx, sy, 0u);
                break;
            }
        }
    }

    s_frame++;
    if (s_frame >= COMBAT_TOTAL_FRAMES) {
        s_state = COMBAT_IDLE;
        s_frame = 0u;
        roomrom_sprites_clear_sword();
    }
}
