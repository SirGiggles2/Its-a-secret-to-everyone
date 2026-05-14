#include "roomrom_magic_shot.h"
#include "roomrom_sprites.h"
#include "../../src/state/inventory.h"

/* Magic rod shot — projectile fired when B-item = ROD pressed.
 *
 * NES Z1 reference: Z_07.asm:3437 DrawSwordShotOrMagicShot. Tile dispatch
 * via Anim_ItemFrameTiles[$2B] = $7A (vertical) / $2B+1 = $7C (horizontal).
 * "Flash" effect: sprite attr = (FrameCounter & 3) | base_attr_for_dir.
 * Genesis impl cycles sub-pal 0..2 (atlas dropped sub-pal 3 in 4→3 unblock
 * 2026-05-08; NES sub-pal 3 wraps to 0).
 *
 * NES Z_05.asm WieldRod / Z_07.asm UpdateRodOrArrow: ownership = items
 * bit ITEMS_BIT_WAND ($0656 bit 1). No rupee cost (rod is free vs arrow). */

#define MAGIC_SHOT_SPEED_PX     3
#define MAGIC_SHOT_BOUND_X_MIN  ((short)(-16))
#define MAGIC_SHOT_BOUND_X_MAX  ((short)272)
#define MAGIC_SHOT_BOUND_Y_MIN  ((short)(-16))
#define MAGIC_SHOT_BOUND_Y_MAX  ((short)240)

typedef enum { MAGIC_SHOT_IDLE = 0, MAGIC_SHOT_FLYING } magic_shot_state_t;

static magic_shot_state_t s_state = MAGIC_SHOT_IDLE;
static link_face_t        s_face  = LINK_FACE_DOWN;
static short              s_x     = 0;
static short              s_y     = 0;
static unsigned char      s_flash = 0;   /* 0..2 cycles per frame */

void roomrom_magic_shot_init(void)
{
    s_state = MAGIC_SHOT_IDLE;
    s_flash = 0u;
    roomrom_sprites_clear_magic_shot();
}

void roomrom_magic_shot_fire(link_face_t face, short link_x, short link_y)
{
    if (s_state != MAGIC_SHOT_IDLE) return;
    if ((g_inventory.items & ITEMS_BIT_WAND) == 0u) return;
    s_state = MAGIC_SHOT_FLYING;
    s_face  = face;
    s_x = link_x;
    s_y = link_y;
    /* Spawn 16 px in facing direction (NES PlaceWeapon uses #$10). */
    switch (face) {
    case LINK_FACE_UP:    s_y = (short)(s_y - 16); break;
    case LINK_FACE_DOWN:  s_y = (short)(s_y + 16); break;
    case LINK_FACE_LEFT:  s_x = (short)(s_x - 16); break;
    case LINK_FACE_RIGHT: s_x = (short)(s_x + 16); break;
    }
    s_flash = 0u;
}

unsigned char roomrom_magic_shot_active(void)
{
    return s_state != MAGIC_SHOT_IDLE;
}

void roomrom_magic_shot_update(void)
{
    if (s_state == MAGIC_SHOT_IDLE) {
        return;
    }
    switch (s_face) {
    case LINK_FACE_UP:    s_y = (short)(s_y - MAGIC_SHOT_SPEED_PX); break;
    case LINK_FACE_DOWN:  s_y = (short)(s_y + MAGIC_SHOT_SPEED_PX); break;
    case LINK_FACE_LEFT:  s_x = (short)(s_x - MAGIC_SHOT_SPEED_PX); break;
    case LINK_FACE_RIGHT: s_x = (short)(s_x + MAGIC_SHOT_SPEED_PX); break;
    }
    if (s_x < MAGIC_SHOT_BOUND_X_MIN || s_x > MAGIC_SHOT_BOUND_X_MAX
        || s_y < MAGIC_SHOT_BOUND_Y_MIN || s_y > MAGIC_SHOT_BOUND_Y_MAX) {
        s_state = MAGIC_SHOT_IDLE;
        roomrom_sprites_clear_magic_shot();
        return;
    }
    /* Flash cycle 0..2. NES uses FrameCounter & 3 (0..3); Genesis sub-pal 3
     * dropped, wrap to 0. */
    s_flash = (unsigned char)((s_flash + 1u) % 3u);
    roomrom_sprites_set_magic_shot(s_x, s_y, s_face, s_flash);
}
