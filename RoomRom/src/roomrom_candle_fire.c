/* Task 5.8.1 candle fire — slice-1 placeholder (explosion glyph). */

#include <genesis.h>
#include "roomrom_candle_fire.h"
#include "roomrom_vram_map.h"
#include "atlas/items_chr_x4.h"

/* NES UpdateFire (Z_07.asm:4622-4768): travel $10 px at 0.5 px/frame
 * (q-speed $20) then stand $3F frames. Slice-1 approximates with
 * 1 px/frame travel for 16 frames + 32-frame stand, since sub-pixel
 * isn't critical for visible feedback. */
#define CANDLE_FIRE_TRAVEL_PX     16
#define CANDLE_FIRE_STAND_FRAMES  32
#define CANDLE_FIRE_SPEED_PX      1

#define CANDLE_FIRE_SUBPAL        2u  /* arbitrary visible sub-pal */
#define CANDLE_FIRE_SLOT          8

typedef enum {
    FIRE_IDLE = 0,
    FIRE_FLYING,
    FIRE_STANDING
} fire_state_t;

static fire_state_t s_state = FIRE_IDLE;
static link_face_t  s_face  = LINK_FACE_DOWN;
static short        s_x     = 0;
static short        s_y     = 0;
static unsigned char s_offset_traveled = 0u;
static unsigned char s_stand_timer = 0u;

void roomrom_candle_fire_init(void)
{
    s_state = FIRE_IDLE;
    /* Park slot offscreen. */
    VDP_setSpriteFull(CANDLE_FIRE_SLOT,
                      (s16)-32, (s16)-32,
                      SPRITE_SIZE(1, 1),
                      TILE_ATTR_FULL(PAL1, 1, 0, 0,
                          (unsigned short)(ROOMROM_ITEM_TILE_BASE_PAL(0)
                              + ROOMROM_ITEM_TILE_EXPLOSION)),
                      9);
    VDP_updateSprites(9, DMA);
}

void roomrom_candle_fire_spawn(link_face_t face, short link_x, short link_y)
{
    if (s_state != FIRE_IDLE) return;
    s_state = FIRE_FLYING;
    s_face  = face;
    s_x     = link_x;
    s_y     = link_y;
    switch (face) {
    case LINK_FACE_UP:    s_y = (short)(s_y - 8); break;
    case LINK_FACE_DOWN:  s_y = (short)(s_y + 8); break;
    case LINK_FACE_LEFT:  s_x = (short)(s_x - 8); break;
    case LINK_FACE_RIGHT: s_x = (short)(s_x + 8); break;
    }
    s_offset_traveled = 0u;
    s_stand_timer = 0u;
}

unsigned char roomrom_candle_fire_active(void)
{
    return s_state != FIRE_IDLE;
}

static void draw_fire(void)
{
    unsigned short tile = (unsigned short)(ROOMROM_ITEM_TILE_BASE_PAL(CANDLE_FIRE_SUBPAL)
                                            + ROOMROM_ITEM_TILE_EXPLOSION);
    /* Priority bit set so flame renders ABOVE BG_A door art (which
     * uses BG priority 0x8000). NES Z1 fire is foreground. */
    VDP_setSpriteFull(CANDLE_FIRE_SLOT,
                      (s16)s_x, (s16)s_y,
                      SPRITE_SIZE(1, 1),
                      TILE_ATTR_FULL(PAL1, 1, 0, 0, tile),
                      9);
    VDP_updateSprites(9, DMA);
}

static void clear_fire(void)
{
    VDP_setSpriteFull(CANDLE_FIRE_SLOT,
                      (s16)-32, (s16)-32,
                      SPRITE_SIZE(1, 1),
                      TILE_ATTR_FULL(PAL1, 1, 0, 0,
                          (unsigned short)(ROOMROM_ITEM_TILE_BASE_PAL(0)
                              + ROOMROM_ITEM_TILE_EXPLOSION)),
                      9);
    VDP_updateSprites(9, DMA);
}

void roomrom_candle_fire_update(void)
{
    if (s_state == FIRE_IDLE) {
        return;
    }
    if (s_state == FIRE_FLYING) {
        switch (s_face) {
        case LINK_FACE_UP:    s_y = (short)(s_y - CANDLE_FIRE_SPEED_PX); break;
        case LINK_FACE_DOWN:  s_y = (short)(s_y + CANDLE_FIRE_SPEED_PX); break;
        case LINK_FACE_LEFT:  s_x = (short)(s_x - CANDLE_FIRE_SPEED_PX); break;
        case LINK_FACE_RIGHT: s_x = (short)(s_x + CANDLE_FIRE_SPEED_PX); break;
        }
        s_offset_traveled++;
        if (s_offset_traveled >= CANDLE_FIRE_TRAVEL_PX) {
            s_state = FIRE_STANDING;
            s_stand_timer = CANDLE_FIRE_STAND_FRAMES;
        }
        draw_fire();
        return;
    }
    /* FIRE_STANDING */
    if (s_stand_timer == 0u) {
        s_state = FIRE_IDLE;
        clear_fire();
        return;
    }
    s_stand_timer--;
    draw_fire();
}
