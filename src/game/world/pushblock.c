/* Task 5.7: UW push-block state machine.
 *
 * NES authority: reference/aldonunez/Z_04.asm:UpdateBlock (618-746)
 *                Z_04.asm:BlockPushDirections (615-616)
 *                Z_05.asm:FindAndCreatePushBlockObject (5461-5514)
 *                Variables.inc:137 (BlockPushComplete = $4CF)
 *
 * Stance: REPAIR the linked native state machine. The direct oracle
 * candidate at src/oracle/enemies/enemy_block_runtime.c is unlinked and
 * inverts the NES RoomAllDead gate; it is not an accepted replacement.
 *
 * Slice-1: NES-faithful state machine for L1Q1 manifest only.
 * Render uses snap-on-completion (no sub-tile sprite movement);
 * full smooth animation deferred per plan.
 */

#include "pushblock.h"
#include "../../../RoomRom/src/roomrom_main_state.h"
#include "../dungeon/push_block_meta.h"  /* Phase 12.2 promoted */
#include "../dungeon/uw_render.h"      /* Phase 12.2 promoted */
#include "draw_dispatch.h"            /* NES DrawBlock sprite path */
#include "platform_abi.h"              /* RAM macro for $034D RoomAllDead */

#define PB_SLOT 11u
#define PB_OBJ_X       RAM(0x0070u + PB_SLOT)
#define PB_OBJ_Y       RAM(0x0084u + PB_SLOT)
#define PB_OBJ_DIR     RAM(0x0098u + PB_SLOT)
#define PB_OBJ_STATE   RAM(0x00ACu + PB_SLOT)
#define PB_OBJ_GRID    RAM(0x0394u + PB_SLOT)

/* NES BlockPushDirections layout (Z_04.asm:615-616).
 *   idx 0 = $08 (UP / N)    -- Link below, pushing up
 *   idx 1 = $04 (DOWN / S)  -- Link above, pushing down
 *   idx 2 = $02 (LEFT / W)  -- Link right of block
 *   idx 3 = $01 (RIGHT / E) -- Link left of block
 */
#define PB_DIR_BIT_N  0x08u
#define PB_DIR_BIT_S  0x04u
#define PB_DIR_BIT_W  0x02u
#define PB_DIR_BIT_E  0x01u

#define PB_TIMER_THRESHOLD  0x10u  /* Z_04.asm:692-695 */
#define PB_OFFSET_FULL      0x10u  /* Z_04.asm:729-733 */
#define PB_DISTANCE_LIMIT   0x11u  /* Z_04.asm:677 */

/* Block tile cluster ($B0..$B3 form 2x2 metatile per NES PrimarySquare). */
#define PB_TILE_BLOCK_TL  0xB0u
#define PB_TILE_BLOCK_TR  0xB2u
#define PB_TILE_BLOCK_BL  0xB1u
#define PB_TILE_BLOCK_BR  0xB3u

/* Floor tile cluster ($74..$77). NES uses $74 as the "primary" floor
 * id for ChangeTileObjTiles (Z_04.asm:704); the 2x2 expansion writes
 * $74 (top-left), $76 (top-right), $75 (bottom-left), $77 (bottom-right). */
#define PB_TILE_FLOOR_TL  0x74u
#define PB_TILE_FLOOR_TR  0x76u
#define PB_TILE_FLOOR_BL  0x75u
#define PB_TILE_FLOOR_BR  0x77u

/* Internal state machine (split TIMING out of NES IDLE for mirror clarity). */
typedef enum {
    PB_S_IDLE   = 0,
    PB_S_TIMING = 1,
    PB_S_MOVING = 2,
    PB_S_DONE   = 3
} pb_s_t;

static pb_s_t          s_pb_state;
static unsigned char   s_pb_timer;
static unsigned char   s_pb_offset;
static unsigned char   s_pb_dir_bit;        /* 0x08/0x04/0x02/0x01 */
static unsigned char   s_pb_block_col_mt;
static unsigned char   s_pb_block_row_mt;
static unsigned char   s_pb_dst_col_mt;
static unsigned char   s_pb_dst_row_mt;
static unsigned char   s_pb_active_room;
static unsigned char   s_pb_complete_count;
static unsigned char   s_pb_state_per_room[256]; /* current-entry probe mirror */

/* Latched copy of last-tick room id so we detect room changes. */
static unsigned char   s_pb_last_seen_room = 0xFFu;
static unsigned char   s_pb_cached_room = 0xFFu;
static unsigned char   s_pb_cached_level = 0u;
static unsigned char   s_pb_cached_quest = 0u;
static unsigned char   s_pb_cached_has_meta = 0u;
static roomrom_pushblock_meta_t s_pb_cached_meta;

/* NES UpdateBlock runs in the object loop at slot 11: it moves the block,
 * then draws it (Z_04.asm:720-726). s_pb_obj_ran marks that the slot-11
 * handler ran the update this frame; s_pb_draw marks a frame where NES
 * reaches DrawBlock (the push frame and every moving frame). */
static unsigned char   s_pb_obj_ran;
static unsigned char   s_pb_draw;

static void pb_update(unsigned char advance);

/* RoomAllDead gate (Z_04.asm:630-631, Z_05.asm:2406+2413).
 *
 * NES RoomAllDead := $034D. Init by enemy_loop_room_init to the foe
 * count for the room; INC'd by KillObject when last enemy dies.
 * Z_04.asm:630 obj-push-block path checks this cell to gate the block-
 * pushable state. CheckSecretTriggerAllDead (Z_05.asm:2410) and shutter
 * unlock also read it.
 *
 * Pre-2026-05-18 returned constant 1u — push-blocks were always
 * pushable. NES behavior: blocks lock until room cleared.
 *
 * Genesis cell ROOM_MONSTER_ALL_DEAD ($034D) is already maintained by
 * enemy_loop kill path. Read the live cell. /enemy_fix Wave 3.4. */
unsigned char roomrom_pushblock_room_all_dead(void)
{
    return (unsigned char)RAM(0x034Du);
}

void roomrom_pushblock_init(void)
{
    unsigned short i;
    s_pb_state = PB_S_IDLE;
    s_pb_timer = 0u;
    s_pb_offset = 0u;
    s_pb_dir_bit = 0u;
    s_pb_block_col_mt = 0u;
    s_pb_block_row_mt = 0u;
    s_pb_dst_col_mt = 0u;
    s_pb_dst_row_mt = 0u;
    s_pb_active_room = 0xFFu;
    s_pb_complete_count = 0u;
    s_pb_last_seen_room = 0xFFu;
    s_pb_cached_room = 0xFFu;
    s_pb_cached_level = 0u;
    s_pb_cached_quest = 0u;
    s_pb_cached_has_meta = 0u;
    for (i = 0u; i < 256u; i++) s_pb_state_per_room[i] = 0u;
}

unsigned char roomrom_pushblock_state_for_room(unsigned char room_id)
{
    return s_pb_state_per_room[room_id];
}

unsigned char roomrom_pushblock_active_state(void)    { return (unsigned char)s_pb_state; }
unsigned char roomrom_pushblock_active_dir(void)      { return s_pb_dir_bit; }
unsigned char roomrom_pushblock_active_timer(void)    { return s_pb_timer; }
unsigned char roomrom_pushblock_active_offset(void)   { return s_pb_offset; }
unsigned char roomrom_pushblock_active_block_col(void){ return s_pb_block_col_mt; }
unsigned char roomrom_pushblock_active_block_row(void){ return s_pb_block_row_mt; }
unsigned char roomrom_pushblock_complete_count(void)  { return s_pb_complete_count; }

void roomrom_pushblock_publish_persist(void)
{
    volatile unsigned char *dst =
        (volatile unsigned char *)ROOMROM_DEBUG_PUSHBLOCK_PERSIST_BASE;
    unsigned short i;
    for (i = 0u; i < 256u; i++) dst[i] = s_pb_state_per_room[i];
}

/* NES UpdateBlock (Z_04.asm:618-746), object loop slot 11: update the
 * block, then DrawBlock on the push frame and every moving frame. The
 * move lands before the draw, as NES UpdateBlock1Moving does; drawing
 * first showed the block one pixel behind (T-169). */
void roomrom_pushblock_draw_object(unsigned int slot)
{
    if (slot != PB_SLOT) return;
    s_pb_obj_ran = 1u;
    s_pb_draw = 0u;
    pb_update(1u);
    if (!s_pb_draw) return;
    RAM(0x0000u) = (unsigned char)PB_OBJ_X;
    RAM(0x0001u) = (unsigned char)((unsigned char)PB_OBJ_Y - 1u);
    RAM(0x000Fu) = 0u;
    draw_object_not_mirrored(0u, slot);
}

/* Link and ObjY use NES screen coordinates. Genesis crops the top 8 video
 * lines for rendering, but the block collision origin is still NES $40. */
#define ROOMROM_PLAYFIELD_TOP_PX  ((short)0x40u)

/* Block top-left link_x / link_y. Block is 2x2 BG tiles = 16x16 px,
 * top-left at metatile col*16, row*16 + playfield_top. */
static short block_top_x(unsigned char col_mt) { return (short)(col_mt * 16u); }
static short block_top_y(unsigned char row_mt)
{
    return (short)((short)(row_mt * 16u) + ROOMROM_PLAYFIELD_TOP_PX);
}

/* NES alignment + direction derivation (Z_04.asm:632-685). Returns
 * the BlockPushDirections value (one of $08/$04/$02/$01) the player
 * MUST press for the current Link↔block geometry. Returns 0 if Link
 * is not aligned with the block. */
static unsigned char compute_required_input_dir(short link_x, short link_y,
                                                short blk_x, short blk_y,
                                                unsigned char allowed_dirs)
{
    short dx, dy;
    unsigned char dir = 0u;
    /* X-aligned (vertical push) takes priority — NES tests CMP ObjX, X
     * first (line 636-638). */
    if (link_x == blk_x) {
        dy = (short)(link_y + 3) - blk_y;
        if (dy < 0) {
            /* Link above. NES idx=1 -> S. */
            if (-dy >= (short)PB_DISTANCE_LIMIT) return 0u;
            dir = PB_DIR_BIT_S;
        } else {
            if (dy >= (short)PB_DISTANCE_LIMIT) return 0u;
            dir = PB_DIR_BIT_N;
        }
    } else if ((short)(link_y + 3) == blk_y) {
        dx = link_x - blk_x;
        if (dx < 0) {
            /* Link left of block. NES idx=3 -> E. */
            if (-dx >= (short)PB_DISTANCE_LIMIT) return 0u;
            dir = PB_DIR_BIT_E;
        } else {
            if (dx >= (short)PB_DISTANCE_LIMIT) return 0u;
            dir = PB_DIR_BIT_W;
        }
    } else {
        return 0u;  /* not aligned */
    }
    /* allowed_dirs mask: bit0=N bit1=S bit2=W bit3=E.
     * Slice-1 generator emits $0F always. */
    if (dir == PB_DIR_BIT_N && !(allowed_dirs & 0x01u)) return 0u;
    if (dir == PB_DIR_BIT_S && !(allowed_dirs & 0x02u)) return 0u;
    if (dir == PB_DIR_BIT_W && !(allowed_dirs & 0x04u)) return 0u;
    if (dir == PB_DIR_BIT_E && !(allowed_dirs & 0x08u)) return 0u;
    return dir;
}

static void dst_metatile_for_dir(unsigned char src_col, unsigned char src_row,
                                 unsigned char dir_bit,
                                 unsigned char *out_col, unsigned char *out_row)
{
    *out_col = src_col;
    *out_row = src_row;
    if (dir_bit == PB_DIR_BIT_N && src_row > 0u) (*out_row)--;
    else if (dir_bit == PB_DIR_BIT_S) (*out_row)++;
    else if (dir_bit == PB_DIR_BIT_W && src_col > 0u) (*out_col)--;
    else if (dir_bit == PB_DIR_BIT_E) (*out_col)++;
}

static unsigned char palette_at_metatile(unsigned char col_mt, unsigned char row_mt)
{
    /* AT spans NT in 32x32 quads; query at the top-left BG of the
     * metatile in NT space (NT row = blob row + HUD rows). */
    unsigned char nt_col = (unsigned char)(col_mt * 2u);
    unsigned char nt_row = (unsigned char)((row_mt * 2u) + 8u);
    return roomrom_uw_room_render_palette_at(nt_col, nt_row);
}

/* Paint a 2x2 metatile cluster on plane A + collision cache. */
static void paint_metatile(unsigned char col_mt, unsigned char row_mt,
                           unsigned char tile_tl, unsigned char tile_tr,
                           unsigned char tile_bl, unsigned char tile_br,
                           unsigned char walk)
{
    unsigned char c = (unsigned char)(col_mt * 2u);
    unsigned char r = (unsigned char)(row_mt * 2u);
    unsigned char pal = palette_at_metatile(col_mt, row_mt);
    roomrom_uw_room_render_write_tile(c,             r,             tile_tl, pal);
    roomrom_uw_room_render_write_tile((unsigned char)(c + 1u), r,             tile_tr, pal);
    roomrom_uw_room_render_write_tile(c,             (unsigned char)(r + 1u), tile_bl, pal);
    roomrom_uw_room_render_write_tile((unsigned char)(c + 1u), (unsigned char)(r + 1u), tile_br, pal);
    roomrom_uw_room_render_set_walkable(col_mt, row_mt, walk);
    roomrom_uw_room_render_set_walkable_tile(c, r, walk);
    roomrom_uw_room_render_set_walkable_tile((unsigned char)(c + 1u), r, walk);
    roomrom_uw_room_render_set_walkable_tile(c, (unsigned char)(r + 1u), walk);
    roomrom_uw_room_render_set_walkable_tile((unsigned char)(c + 1u), (unsigned char)(r + 1u), walk);
}

/* Reset to IDLE; the room-entry path also clears the pushed flag. */
static void reset_to_idle(void)
{
    s_pb_state = PB_S_IDLE;
    s_pb_timer = 0u;
    s_pb_offset = 0u;
    s_pb_dir_bit = 0u;
}

static void cache_room_meta(unsigned char level,
                            unsigned char quest,
                            unsigned char room_id)
{
    s_pb_cached_level = level;
    s_pb_cached_quest = quest;
    s_pb_cached_room = room_id;
    s_pb_cached_has_meta = roomrom_pushblock_for_room(level, quest, room_id,
                                                      &s_pb_cached_meta);
}

void roomrom_pushblock_room_load(unsigned char level,
                                 unsigned char quest,
                                 unsigned char room_id)
{
    reset_to_idle();
    s_pb_active_room = 0xFFu;
    s_pb_last_seen_room = room_id;
    cache_room_meta(level, quest, room_id);
    /* NES InitMode4 rebuilds the room and FindAndCreatePushBlockObject
     * seeds the original source block again, even after a successful push.
     * Door-open room flags survive separately. The old per-room latch made
     * a revisit erase the block altogether. */
    s_pb_state_per_room[room_id] = 0u;
}

/* Main-loop call: housekeeping (scene / room change) only. The state
 * machine advances from the slot-11 object handler, like NES. */
void roomrom_pushblock_tick(void)
{
    if (s_pb_obj_ran) {
        s_pb_obj_ran = 0u;
        return;
    }
    pb_update(0u);
}

static void pb_update(unsigned char advance)
{
    unsigned char scene = roomrom_main_current_scene();
    unsigned char mode  = roomrom_main_current_mode();
    unsigned char room_id;
    roomrom_pushblock_meta_t meta;
    short link_x, link_y;
    short blk_x, blk_y;
    unsigned char required_dir;
    unsigned char input_dir;

    if (scene != ROOMROM_MAIN_SCENE_UW || mode != ROOMROM_MAIN_MODE_WALK) {
        reset_to_idle();
        s_pb_last_seen_room = 0xFFu;
        return;
    }
    room_id = roomrom_main_current_room_id();

    /* Detect room change: clear in-flight push if active room differs. */
    if (room_id != s_pb_last_seen_room) {
        reset_to_idle();
        s_pb_active_room = 0xFFu;
        s_pb_last_seen_room = room_id;
        cache_room_meta(roomrom_uw_room_render_get_level(),
                        roomrom_uw_room_render_get_quest(),
                        room_id);
    }

    if (!advance) return;

    /* Once pushed during this entry, stop the private state machine.
     * room_load resets this latch on the next entry, as the NES does. */
    if (s_pb_state_per_room[room_id] >= 1u) {
        return;
    }

    /* No persistent done — run live state machine. */
    if (s_pb_cached_room != room_id ||
        s_pb_cached_level != roomrom_uw_room_render_get_level() ||
        s_pb_cached_quest != roomrom_uw_room_render_get_quest()) {
        cache_room_meta(roomrom_uw_room_render_get_level(),
                        roomrom_uw_room_render_get_quest(),
                        room_id);
    }
    if (s_pb_cached_has_meta == 0u) {
        reset_to_idle();
        s_pb_active_room = 0xFFu;
        return;
    }
    meta = s_pb_cached_meta;

    if (!roomrom_pushblock_room_all_dead()) {
        reset_to_idle();
        return;
    }

    link_x = roomrom_main_current_link_x();
    link_y = roomrom_main_current_link_y();
    blk_x  = block_top_x(meta.block_col_mt);
    blk_y  = block_top_y(meta.block_row_mt);
    required_dir = compute_required_input_dir(link_x, link_y, blk_x, blk_y,
                                              meta.allowed_dirs);
    input_dir = roomrom_main_current_input_dir();

    switch (s_pb_state) {

    case PB_S_IDLE:
    case PB_S_TIMING: {
        if (required_dir == 0u || (input_dir & required_dir) == 0u) {
            reset_to_idle();
            return;
        }
        if (s_pb_state == PB_S_IDLE) {
            s_pb_state = PB_S_TIMING;
            s_pb_timer = 0u;
            s_pb_dir_bit = required_dir;
            s_pb_block_col_mt = meta.block_col_mt;
            s_pb_block_row_mt = meta.block_row_mt;
            dst_metatile_for_dir(meta.block_col_mt, meta.block_row_mt,
                                 required_dir,
                                 &s_pb_dst_col_mt, &s_pb_dst_row_mt);
            s_pb_active_room = room_id;
        } else {
            /* Direction must match the latched dir while held. */
            if (required_dir != s_pb_dir_bit) {
                reset_to_idle();
                return;
            }
        }
        s_pb_timer++;
        if (s_pb_timer >= PB_TIMER_THRESHOLD) {
            /* TIMING -> MOVING: paint source as floor, snap walkable=1. */
            paint_metatile(s_pb_block_col_mt, s_pb_block_row_mt,
                           PB_TILE_FLOOR_TL, PB_TILE_FLOOR_TR,
                           PB_TILE_FLOOR_BL, PB_TILE_FLOOR_BR, 1u);
            s_pb_state = PB_S_MOVING;
            s_pb_offset = 0u;
            PB_OBJ_STATE = 1u;
            PB_OBJ_DIR = s_pb_dir_bit;
            PB_OBJ_GRID = 0u;
            s_pb_draw = 1u;  /* falls into DrawBlock, no move this frame */
        }
        break;
    }

    case PB_S_MOVING: {
        /* NES UpdateBlock1Moving -> MoveObject for slot 11: QSpeedFrac
         * ($3BC+11 = $20, half a pixel) steps ObjPosFrac ($3A8+11) by
         * q * 4 each tick; a borrow (up/left) or carry (down/right) moves
         * one pixel. Up/left therefore moves on the first moving tick,
         * down/right on the second. T-169: a private alternating counter
         * moved one tick late (t054_uw_block42_nes NES rows 866-873: frac
         * 00 -> 80 with Y $90 -> $8F on the first tick). */
        s_pb_draw = 1u;
        {
            unsigned char q = RAM(0x03BCu + 11u);
            unsigned char step, frac, moved;
            if (q == 0u) q = 0x20u;
            step = (unsigned char)(q << 2);
            frac = RAM(0x03A8u + 11u);
            if (s_pb_dir_bit == PB_DIR_BIT_N || s_pb_dir_bit == PB_DIR_BIT_W) {
                moved = (unsigned char)(frac < step);
                frac = (unsigned char)(frac - step);
            } else {
                const unsigned short sum = (unsigned short)(frac + step);
                moved = (unsigned char)(sum > 0xFFu);
                frac = (unsigned char)sum;
            }
            RAM(0x03A8u + 11u) = frac;
            if (!moved) break;
        }
        s_pb_offset++;
        if (s_pb_dir_bit == PB_DIR_BIT_N) {
            PB_OBJ_Y = (unsigned char)((unsigned char)PB_OBJ_Y - 1u);
            PB_OBJ_GRID = (unsigned char)(0u - s_pb_offset);
        } else if (s_pb_dir_bit == PB_DIR_BIT_S) {
            PB_OBJ_Y = (unsigned char)((unsigned char)PB_OBJ_Y + 1u);
            PB_OBJ_GRID = s_pb_offset;
        } else if (s_pb_dir_bit == PB_DIR_BIT_W) {
            PB_OBJ_X = (unsigned char)((unsigned char)PB_OBJ_X - 1u);
            PB_OBJ_GRID = (unsigned char)(0u - s_pb_offset);
        } else if (s_pb_dir_bit == PB_DIR_BIT_E) {
            PB_OBJ_X = (unsigned char)((unsigned char)PB_OBJ_X + 1u);
            PB_OBJ_GRID = s_pb_offset;
        }
        if (s_pb_offset >= PB_OFFSET_FULL) {
            /* MOVING -> DONE: paint destination as block, mark
             * destination unwalkable, latch persistent state. */
            paint_metatile(s_pb_dst_col_mt, s_pb_dst_row_mt,
                           PB_TILE_BLOCK_TL, PB_TILE_BLOCK_TR,
                           PB_TILE_BLOCK_BL, PB_TILE_BLOCK_BR, 0u);
            s_pb_state = PB_S_DONE;
            PB_OBJ_STATE = 2u;
            if (s_pb_complete_count < 0xFFu) s_pb_complete_count++;
            if (s_pb_state_per_room[room_id] < 1u) {
                s_pb_state_per_room[room_id] = 1u;  /* NES BlockPushComplete += 1 */
            }
            /* CheckUnderworldSecrets reads the NES room cell, not the
             * native per-room cache. Keep both sides of the boundary in
             * sync when the block finishes its 16-pixel move. */
            RAM(0x04CFu) = (unsigned char)(RAM(0x04CFu) + 1u);
        }
        break;
    }

    case PB_S_DONE:
    default:
        /* Stay DONE until room re-entry. */
        break;
    }
}
