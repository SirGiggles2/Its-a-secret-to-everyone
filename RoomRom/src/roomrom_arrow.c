#include "roomrom_arrow.h"
#include "roomrom_sprites.h"
#include "inventory.h"

/* NES Z_05.asm:2945 WieldArrow / Z_07.asm UpdateRodOrArrow: refuse if
 * `Bow == 0` (InvBow ownership) OR if `InvArrow == 0` (no arrow tier
 * picked up) OR if `InvRupees == 0` (each shot costs 1 rupee — NES Z1
 * checks `LDA InvRupees / BEQ` before spawn).
 *
 * Phase 6 Task 6.10.10 (rupee tick) is now landed, so the 1-rupee cost
 * is queued via inventory_rupee_debit; the HUD ticks down through
 * inventory_rupee_tick on the every-other-frame cadence. */

/* NES: UpdateRodOrArrow (Z_07.asm:4322) -> arrow item slot 2, base attr 0
 * (RDirectionToWeaponBaseAttribute = 0 for all dirs). */
#define ROOMROM_ARROW_SUBPAL 0u

#define ARROW_SPEED_PX        3
#define ARROW_BOUND_X_MIN     ((short)(-16))
#define ARROW_BOUND_X_MAX     ((short)272)
#define ARROW_BOUND_Y_MIN     ((short)(-16))
#define ARROW_BOUND_Y_MAX     ((short)240)

typedef enum { ARROW_IDLE = 0, ARROW_FLYING } arrow_state_t;

static arrow_state_t s_state = ARROW_IDLE;
static link_face_t   s_face  = LINK_FACE_DOWN;
static short         s_x     = 0;
static short         s_y     = 0;

void roomrom_arrow_init(void)
{
    s_state = ARROW_IDLE;
    roomrom_sprites_clear_arrow();
}

void roomrom_arrow_fire(link_face_t face, short link_x, short link_y)
{
    if (s_state != ARROW_IDLE) return;
    if (g_inventory.bow == 0u) return;
    if (g_inventory.arrow == INV_ARROW_NONE) return;
    if (g_inventory.rupees == 0u) return;
    inventory_rupee_debit(1u);   /* NES: 1-rupee cost per arrow */
    s_state = ARROW_FLYING;
    s_face  = face;
    /* Spawn at Link's center, offset 8 px in facing direction. */
    s_x = link_x;
    s_y = link_y;
    switch (face) {
    case LINK_FACE_UP:    s_y = (short)(s_y - 8); break;
    case LINK_FACE_DOWN:  s_y = (short)(s_y + 8); break;
    case LINK_FACE_LEFT:  s_x = (short)(s_x - 8); break;
    case LINK_FACE_RIGHT: s_x = (short)(s_x + 8); break;
    }
}

unsigned char roomrom_arrow_active(void)
{
    return s_state != ARROW_IDLE;
}

void roomrom_arrow_update(void)
{
    if (s_state == ARROW_IDLE) {
        return;
    }
    switch (s_face) {
    case LINK_FACE_UP:    s_y = (short)(s_y - ARROW_SPEED_PX); break;
    case LINK_FACE_DOWN:  s_y = (short)(s_y + ARROW_SPEED_PX); break;
    case LINK_FACE_LEFT:  s_x = (short)(s_x - ARROW_SPEED_PX); break;
    case LINK_FACE_RIGHT: s_x = (short)(s_x + ARROW_SPEED_PX); break;
    }
    if (s_x < ARROW_BOUND_X_MIN || s_x > ARROW_BOUND_X_MAX
        || s_y < ARROW_BOUND_Y_MIN || s_y > ARROW_BOUND_Y_MAX) {
        s_state = ARROW_IDLE;
        roomrom_sprites_clear_arrow();
        return;
    }
    roomrom_sprites_set_arrow(s_x, s_y, s_face, ROOMROM_ARROW_SUBPAL);
}
