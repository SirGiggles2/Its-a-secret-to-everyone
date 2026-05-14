/* Task 5.8.1 candle fire — NES Z_07.asm:4622 UpdateFire.
 *
 * NES TRUTH (re-derived 2026-05-08 from Z_01/Z_07 disasm):
 * - UpdateFire (Z_07.asm:4683) passes A=0 (frame=0) into DrawObjectWithType.
 * - ObjAnimations[$41] = $08. DrawObjectWithAnim (Z_01.asm:5054):
 *     Y = ObjAnimations[$41] + 0 = $08.
 *     tile_left  = ObjAnimFrameHeap[$08]   = $5C
 *     tile_right = ObjAnimFrameHeap[$08]+2 = $5E
 *   Tiles are FIXED at $5C / $5E for every visible frame. The disasm's
 *   ObjAnimFrameHeap[$09..$0B] = $9E/$44/$CE belong to OTHER objects, NOT
 *   candle fire — earlier code mis-attributed those to per-frame fire art.
 * - Anim_AdvanceAnimCounterAndSetObjPos (Z_07.asm:5116) decrements the
 *   counter; on rollover (every 4 ticks given A=$04 caller arg), it XORs
 *   ObjAnimFrame with 1, toggling 0/1.
 * - Anim_SetObjHFlipForSpriteDescriptor (Z_07.asm:5084) stores
 *   ObjAnimFrame into [0F]. Anim_WriteHorizontallyFlippableSpritePair flips
 *   tile pair + sets hflip attr if [0F] != 0.
 *
 * Net visual: tile $5C/$5D + $5E/$5F (16x16 in PPU 8x16 mode), sub-pal 2
 * (red — Anim_SetSpriteDescriptorRedPaletteRow), with HFLIP toggling every
 * 4 ticks. Two-state shimmer, NOT four-distinct-tile cycle.
 *
 * Atlas tiles $5C/$5D/$5E/$5F = ROOMROM_ITEM_TILE_CANDLE_FIRE_F0 (4 tiles).
 * Other "frame" entries in items_chr_x4.h (F1/F2/F3) are leftover atlas
 * data for the misattributed tiles — harmless dead VRAM, removable in a
 * future atlas refactor.
 */

#include "roomrom_candle_fire.h"
#include "../../src/state/inventory.h"

/* Travel: NES uses q-speed $20 = 0.5 px/frame for distance $10 (16 px),
 * then stand $3F frames. Approximate with whole-pixel travel.
 * 2026-05-08 visibility-debug: bumped TRAVEL to 48 + STAND to 30 so the
 * candle clears Link's 16x16 body footprint and shows visibly. NES-faithful
 * 16 px keeps the candle merged with Link visually. Restore to 16 once
 * NES movement model is fully ported (4-direction q-speed). */
#define CANDLE_FIRE_TRAVEL_PX     48
#define CANDLE_FIRE_STAND_FRAMES  30   /* shorter so cycle visible */
#define CANDLE_FIRE_SPEED_PX      1
#define CANDLE_FIRE_TICKS_PER_FRM 4    /* NES LDA #$04 — anim_counter rollover */
#define CANDLE_FIRE_FRAME_COUNT   2    /* NES toggles ObjAnimFrame 0/1 */

/* Single tile pair, sub-pal 2 (red). Frame index controls hflip only. */
#define CANDLE_FIRE_SUBPAL        2u

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

/* NES UsedCandle ($0506 in NES RAM map): blue candle 1-shot per room. */
static unsigned char s_used_candle = 0u;

unsigned char roomrom_candle_fire_used_this_room(void) { return s_used_candle; }
void          roomrom_candle_fire_mark_used(void)      { s_used_candle = 1u; }
void          roomrom_candle_fire_room_reset(void)     { s_used_candle = 0u; }

static void hide_slot(void)
{
    roomrom_sprites_clear_candle_fire();
}

void roomrom_candle_fire_init(void)
{
    s_state = FIRE_IDLE;
    s_anim_tick = 0u;
    s_anim_frame = 0u;
    hide_slot();
}

/* NES Z_01.asm:3958 WieldCandle: refuse if Link doesn't own a candle
 * (`InvCandle == 0`) or, for the blue candle (tier 1), if `UsedCandle`
 * is already set this room. Red candle (tier 2) ignores UsedCandle. */
void roomrom_candle_fire_spawn(link_face_t face, short link_x, short link_y)
{
    if (s_state != FIRE_IDLE) return;
    if (g_inventory.candle == INV_CANDLE_NONE) return;
    if (g_inventory.candle == INV_CANDLE_BLUE
        && roomrom_candle_fire_used_this_room()) return;
    roomrom_candle_fire_mark_used();
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
    /* NES candle fire = single tile pair $5C/$5E (with $5D/$5F as 8x16
     * bottoms), sub-pal 2 (red). ObjAnimFrame toggles 0/1 every 4 ticks
     * → hflip toggles. */
    unsigned char hflip = s_anim_frame & 1u;
    /* Priority bit set so flame renders ABOVE BG_A door art (which uses
     * BG priority 0x8000). NES Z1 fire is foreground. */
    roomrom_sprites_set_candle_fire(s_x, s_y, hflip, CANDLE_FIRE_SUBPAL);
}

static void advance_anim(void)
{
    s_anim_tick++;
    if (s_anim_tick >= CANDLE_FIRE_TICKS_PER_FRM) {
        s_anim_tick = 0u;
        s_anim_frame = (unsigned char)(s_anim_frame ^ 1u);  /* NES EOR #$01 toggle */
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
