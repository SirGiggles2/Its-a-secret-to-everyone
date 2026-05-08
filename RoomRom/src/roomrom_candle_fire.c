/* Task 5.8.1 candle fire — full 4-frame NES animation per Z_07.asm:4622.
 *
 * Frames cycle every 4 ticks (LDA #$04 / Anim_AdvanceAnimCounter).
 * Each frame is a 16x8 sprite (2 NES tiles side-by-side, left+2=right
 * per DrawObjectWithAnimAndSpecificSprites in Z_01.asm:5056).
 *
 * Tile pairs (NES PPU sprite indices) and sub-pal selections come from
 * ObjAnimations[$41]=$08 -> ObjAnimFrameHeap[$08..$0B] / ObjAnimAttrHeap[$08..$0B]:
 *   frame 0: ($5C/$5E)  sub_pal 2
 *   frame 1: ($9E/$A0)  sub_pal 0
 *   frame 2: ($44/$46)  sub_pal 0
 *   frame 3: ($CE/$D0)  sub_pal 1
 *
 * NES CHR sources (canonical UW group 1257 — L1/L2/L5/L7):
 *   $5C/$5E, $44/$46    -> CommonSpritePatterns
 *   $9E/$A0             -> PatternBlockUWSP127
 *   $CE/$D0             -> PatternBlockUWSPBoss1257
 * Bytes baked into items_chr_x4.h via item_chr_manifest.json -> gen_atlas.py.
 */

#include <genesis.h>
#include "roomrom_candle_fire.h"
#include "roomrom_vram_map.h"
#include "atlas/items_chr_x4.h"

/* Travel: NES uses q-speed $20 = 0.5 px/frame for distance $10 (16 px),
 * then stand $3F frames. Approximate with whole-pixel travel. */
#define CANDLE_FIRE_TRAVEL_PX     16
#define CANDLE_FIRE_STAND_FRAMES  63   /* $3F NES ticks */
#define CANDLE_FIRE_SPEED_PX      1
#define CANDLE_FIRE_SLOT          8
#define CANDLE_FIRE_TICKS_PER_FRM 4    /* NES LDA #$04 */
#define CANDLE_FIRE_FRAME_COUNT   4

/* Per-frame tile-base indices (left tile within items_chr_x4 atlas).
 * Right tile = left + 1 (gen_atlas concatenates tile_ids in order). */
static const unsigned char k_frame_tile_base[CANDLE_FIRE_FRAME_COUNT] = {
    ROOMROM_ITEM_TILE_CANDLE_FIRE_F0,
    ROOMROM_ITEM_TILE_CANDLE_FIRE_F1,
    ROOMROM_ITEM_TILE_CANDLE_FIRE_F2,
    ROOMROM_ITEM_TILE_CANDLE_FIRE_F3,
};
/* ObjAnimAttrHeap[$08..$0B] sub-pal indices. */
static const unsigned char k_frame_subpal[CANDLE_FIRE_FRAME_COUNT] = {
    2u, 0u, 0u, 1u,
};

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
static unsigned char s_stand_timer     = 0u;
static unsigned char s_anim_tick       = 0u;
static unsigned char s_anim_frame      = 0u;

static void hide_slot(void)
{
    VDP_setSpriteFull(CANDLE_FIRE_SLOT,
                      (s16)-32, (s16)-32,
                      SPRITE_SIZE(2, 1),
                      TILE_ATTR_FULL(PAL1, 1, 0, 0,
                          (unsigned short)(ROOMROM_ITEM_TILE_BASE_PAL(0)
                              + ROOMROM_ITEM_TILE_CANDLE_FIRE_F0)),
                      9);
    VDP_updateSprites(9, DMA);
}

void roomrom_candle_fire_init(void)
{
    s_state = FIRE_IDLE;
    s_anim_tick = 0u;
    s_anim_frame = 0u;
    hide_slot();
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
    s_anim_tick = 0u;
    s_anim_frame = 0u;
}

unsigned char roomrom_candle_fire_active(void)
{
    return s_state != FIRE_IDLE;
}

static void draw_fire(void)
{
    unsigned char frame = s_anim_frame;
    unsigned char subpal = k_frame_subpal[frame];
    unsigned short tile = (unsigned short)(ROOMROM_ITEM_TILE_BASE_PAL(subpal)
                                            + k_frame_tile_base[frame]);
    /* Priority bit set so flame renders ABOVE BG_A door art (which uses
     * BG priority 0x8000). NES Z1 fire is foreground. */
    VDP_setSpriteFull(CANDLE_FIRE_SLOT,
                      (s16)s_x, (s16)s_y,
                      SPRITE_SIZE(2, 1),
                      TILE_ATTR_FULL(PAL1, 1, 0, 0, tile),
                      9);
    VDP_updateSprites(9, DMA);
}

static void advance_anim(void)
{
    s_anim_tick++;
    if (s_anim_tick >= CANDLE_FIRE_TICKS_PER_FRM) {
        s_anim_tick = 0u;
        s_anim_frame = (unsigned char)((s_anim_frame + 1u) & 0x03u);
    }
}

void roomrom_candle_fire_update(void)
{
    if (s_state == FIRE_IDLE) {
        return;
    }
    advance_anim();
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
        hide_slot();
        return;
    }
    s_stand_timer--;
    draw_fire();
}
