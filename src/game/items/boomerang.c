#include "boomerang.h"
#include "../world/render/sprite_render.h"
#include "../../state/inventory.h"

extern void audio_sfx_play(unsigned char sfx);

/* NES: DrawBoomerangAndCheckCollision (Z_07.asm:3437) -> base attr 0
 * (RDirectionToWeaponBaseAttribute = 0 for all dirs).
 *
 * NES Z_05.asm WieldBoomerang: ownership = items bit ITEMS_BIT_BOOMERANG
 * ($0656 bit 2). Tier upgrade (wood→magic) also lives in items bitfield;
 * boomerang range/speed parity deferred until tier-aware atlas lands. */
#define ROOMROM_BOOMERANG_SUBPAL 0u

/* See roomrom_boomerang.h for NES disasm references. */

#define BOOMERANG_OUT_FRAMES     32u
#define BOOMERANG_RETURN_FRAMES  32u
#define BOOMERANG_TOTAL_FRAMES   (BOOMERANG_OUT_FRAMES + BOOMERANG_RETURN_FRAMES)
#define BOOMERANG_SPEED_PX       3
#define BOOMERANG_PHASE_FRAMES   2u   /* 2 frames per spin phase */

typedef enum {
    BOOMERANG_IDLE = 0,
    BOOMERANG_OUT,
    BOOMERANG_RETURN
} boomerang_state_t;

static boomerang_state_t s_state = BOOMERANG_IDLE;
static unsigned char     s_frame = 0u;        /* 0..BOOMERANG_TOTAL_FRAMES-1 */
static unsigned char     s_phase_idx = 0u;    /* 0..7 */
static unsigned char     s_phase_tick = 0u;   /* 0..BOOMERANG_PHASE_FRAMES-1 */
static link_face_t       s_face = LINK_FACE_DOWN;
static short             s_x = 0;
static short             s_y = 0;

void roomrom_boomerang_init(void)
{
    s_state = BOOMERANG_IDLE;
    s_frame = 0u;
    s_phase_idx = 0u;
    s_phase_tick = 0u;
    roomrom_sprites_clear_boomerang();
}

void roomrom_boomerang_throw(link_face_t face, short link_x, short link_y)
{
    if (s_state != BOOMERANG_IDLE) return;
    if ((g_inventory.items & ITEMS_BIT_BOOMERANG) == 0u) return;
    s_state = BOOMERANG_OUT;
    s_frame = 0u;
    s_phase_idx = 0u;
    s_phase_tick = 0u;
    s_face = face;
    s_x = link_x;
    s_y = link_y;
    /* NES Z_05.asm:2964-2965 LDA #$02 / JSR PlayEffect = boomerang/arrow
     * sound (bit 1 in NES bitmap; DMC sample 2 in our 1-based mapping). */
    audio_sfx_play(2u);
}

unsigned char roomrom_boomerang_active(void)
{
    return s_state != BOOMERANG_IDLE;
}

static void advance_phase(void)
{
    s_phase_tick++;
    if (s_phase_tick >= BOOMERANG_PHASE_FRAMES) {
        s_phase_tick = 0u;
        s_phase_idx = (unsigned char)((s_phase_idx + 1u) & 0x7u);
    }
}

void roomrom_boomerang_update(short link_x, short link_y)
{
    if (s_state == BOOMERANG_IDLE) {
        return;
    }

    if (s_state == BOOMERANG_OUT) {
        switch (s_face) {
        case LINK_FACE_UP:    s_y = (short)(s_y - BOOMERANG_SPEED_PX); break;
        case LINK_FACE_DOWN:  s_y = (short)(s_y + BOOMERANG_SPEED_PX); break;
        case LINK_FACE_LEFT:  s_x = (short)(s_x - BOOMERANG_SPEED_PX); break;
        case LINK_FACE_RIGHT: s_x = (short)(s_x + BOOMERANG_SPEED_PX); break;
        }
    } else {
        /* RETURN: chase Link's current position. */
        if      (s_x < link_x) s_x = (short)(s_x + BOOMERANG_SPEED_PX);
        else if (s_x > link_x) s_x = (short)(s_x - BOOMERANG_SPEED_PX);
        if      (s_y < link_y) s_y = (short)(s_y + BOOMERANG_SPEED_PX);
        else if (s_y > link_y) s_y = (short)(s_y - BOOMERANG_SPEED_PX);
    }

    roomrom_sprites_set_boomerang(s_x, s_y, s_phase_idx, ROOMROM_BOOMERANG_SUBPAL);
    advance_phase();

    s_frame++;
    if (s_frame >= BOOMERANG_OUT_FRAMES && s_state == BOOMERANG_OUT) {
        s_state = BOOMERANG_RETURN;
    }
    if (s_frame >= BOOMERANG_TOTAL_FRAMES) {
        s_state = BOOMERANG_IDLE;
        s_frame = 0u;
        roomrom_sprites_clear_boomerang();
    }
}
