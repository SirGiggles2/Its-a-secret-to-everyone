#include "roomrom_bomb.h"
#include "roomrom_sprites.h"
#include "inventory.h"

/* NES: DrawCloud (Z_07.asm:4912) sets sprite attr Y=1 -> sub-pal 1 (blue). */
#define ROOMROM_BOMB_SUBPAL 1u

#define BOMB_FUSE_FRAMES        60u
#define BOMB_EXPLODE_FRAMES     24u
#define BOMB_PLACE_OFFSET       16

typedef enum {
    BOMB_IDLE = 0,
    BOMB_FUSE,
    BOMB_EXPLODE
} bomb_state_t;

static bomb_state_t s_state = BOMB_IDLE;
static unsigned char s_timer = 0u;
static short s_x = 0;
static short s_y = 0;

void roomrom_bomb_init(void)
{
    s_state = BOMB_IDLE;
    s_timer = 0u;
    roomrom_sprites_clear_bomb();
    roomrom_sprites_clear_explosion();
}

void roomrom_bomb_place(link_face_t face, short link_x, short link_y)
{
    if (s_state != BOMB_IDLE) return;
    /* NES Z_07.asm WieldBomb: refuse if InvBombs == 0; decrement on
     * spawn (one bomb per slot, NES uses two slots — RoomRom v6 single
     * slot only). */
    if (g_inventory.bombs == 0u) return;
    g_inventory.bombs--;
    s_state = BOMB_FUSE;
    s_timer = BOMB_FUSE_FRAMES;
    s_x = link_x;
    s_y = link_y;
    switch (face) {
    case LINK_FACE_UP:    s_y = (short)(s_y - BOMB_PLACE_OFFSET); break;
    case LINK_FACE_DOWN:  s_y = (short)(s_y + BOMB_PLACE_OFFSET); break;
    case LINK_FACE_LEFT:  s_x = (short)(s_x - BOMB_PLACE_OFFSET); break;
    case LINK_FACE_RIGHT: s_x = (short)(s_x + BOMB_PLACE_OFFSET); break;
    }
}

unsigned char roomrom_bomb_active(void)
{
    return s_state != BOMB_IDLE;
}

void roomrom_bomb_update(void)
{
    switch (s_state) {
    case BOMB_IDLE:
        roomrom_sprites_clear_bomb();
        roomrom_sprites_clear_explosion();
        return;
    case BOMB_FUSE:
        roomrom_sprites_set_bomb(s_x, s_y, ROOMROM_BOMB_SUBPAL);
        roomrom_sprites_clear_explosion();
        if (s_timer > 0u) s_timer--;
        if (s_timer == 0u) {
            s_state = BOMB_EXPLODE;
            s_timer = BOMB_EXPLODE_FRAMES;
        }
        return;
    case BOMB_EXPLODE:
        roomrom_sprites_clear_bomb();
        roomrom_sprites_set_explosion(s_x, s_y, s_timer, ROOMROM_BOMB_SUBPAL);
        if (s_timer > 0u) s_timer--;
        if (s_timer == 0u) {
            s_state = BOMB_IDLE;
            roomrom_sprites_clear_bomb();
            roomrom_sprites_clear_explosion();
        }
        return;
    }
}
