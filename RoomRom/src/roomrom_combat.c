#include "roomrom_combat.h"
#include "roomrom_sprites.h"

/* NES timing (z_05.asm WieldSword: $03D0+slot = 5 = state 1 frames).
 * State 2 retract is a single frame in z_07.asm UpdateSwordOrRod. */
#define COMBAT_EXTEND_FRAMES   5u
#define COMBAT_RETRACT_FRAMES  1u

typedef enum {
    COMBAT_IDLE = 0,
    COMBAT_SWORD_EXTEND,
    COMBAT_SWORD_RETRACT
} combat_state_t;

static combat_state_t s_state = COMBAT_IDLE;
static unsigned char  s_timer = 0u;
static link_face_t    s_face  = LINK_FACE_DOWN;

void roomrom_combat_init(void)
{
    s_state = COMBAT_IDLE;
    s_timer = 0u;
    roomrom_sprites_clear_sword();
}

void roomrom_combat_try_swing(link_face_t face, short link_x, short link_y)
{
    (void)link_x; (void)link_y;
    if (s_state != COMBAT_IDLE) return;
    s_state = COMBAT_SWORD_EXTEND;
    s_timer = COMBAT_EXTEND_FRAMES;
    s_face  = face;
}

unsigned char roomrom_combat_link_locked(void)
{
    return s_state != COMBAT_IDLE;
}

/* Sword draw position offset from Link's 16x16 sprite top-left, all 4 facings.
 * Sword sprite is 16x16; Link is 16x16. Sword extends 16 pixels in the facing
 * direction. */
static void compute_sword_pos(link_face_t face, short link_x, short link_y,
                              short *out_x, short *out_y)
{
    short sx = link_x;
    short sy = link_y;
    switch (face) {
    case LINK_FACE_UP:    sy = (short)(link_y - 16); break;
    case LINK_FACE_DOWN:  sy = (short)(link_y + 16); break;
    case LINK_FACE_LEFT:  sx = (short)(link_x - 16); break;
    case LINK_FACE_RIGHT: sx = (short)(link_x + 16); break;
    }
    *out_x = sx;
    *out_y = sy;
}

void roomrom_combat_update(short link_x, short link_y, link_face_t face)
{
    (void)face;  /* sword anchored to s_face captured at swing start */
    switch (s_state) {
    case COMBAT_IDLE:
        roomrom_sprites_clear_sword();
        return;
    case COMBAT_SWORD_EXTEND: {
        short sx, sy;
        compute_sword_pos(s_face, link_x, link_y, &sx, &sy);
        roomrom_sprites_set_sword_pose(s_face, sx, sy);
        if (s_timer > 0u) s_timer--;
        if (s_timer == 0u) {
            s_state = COMBAT_SWORD_RETRACT;
            s_timer = COMBAT_RETRACT_FRAMES;
        }
        return;
    }
    case COMBAT_SWORD_RETRACT:
        roomrom_sprites_clear_sword();
        if (s_timer > 0u) s_timer--;
        if (s_timer == 0u) {
            s_state = COMBAT_IDLE;
        }
        return;
    }
}
