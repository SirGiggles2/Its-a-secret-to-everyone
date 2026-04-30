#include <genesis.h>
#include "ow_room_render_roomrom.h"
#include "uw_room_render_roomrom.h"
#include "roomrom_hud.h"
#include "roomrom_sprites.h"

/* Boots to overworld room 0x77.
 *
 * Modes (toggled by X):
 *   WALK       D-pad moves Link
 *   TELEPORT   D-pad jumps room (16x8 grid: room_id = (row<<4)|col)
 *
 * Walk style (toggled by Y):
 *   NES        Z1-faithful: single-axis only, grid-locked turns,
 *              QSpeed=$60 -> 1.5 px/frame avg, instant stop on release.
 *              Source: reference/aldonunez/Z_05.asm Link_HandleInput +
 *              Z_07.asm Walker_Move / MoveObject.
 *   ALTTP      8-direction (real diagonal), 8.8 sub-pixel position,
 *              cardinal vel=24, diagonal vel=16 (sqrt(2) compensation).
 *              Source: github.com/snesrev/zelda3 src/player.c
 *              Link_HandleVelocity + Link_MovePosition + kSpeedMod.
 *
 * Buttons (always):
 *   X         toggle WALK <-> TELEPORT
 *   Y         toggle NES <-> ALTTP walk style
 *   B         scene toggle (overworld <-> dungeon)
 *   C         map variant toggle (original <-> redux), per-scene
 *   A         (dungeon scene) cycle level 1..9
 *   START     (dungeon scene) toggle quest 1 <-> 2 */

typedef enum { SCENE_OW = 0, SCENE_UW = 1 } scene_t;
typedef enum { MODE_WALK = 0, MODE_TELEPORT = 1 } mode_t;
typedef enum { MOVE_STYLE_NES = 0, MOVE_STYLE_ALTTP = 1 } move_style_t;

/* NES Z1 movement direction (matches Z_05.asm Link_ModifyDir bit layout
 * conceptually: only one axis at a time, no diagonal). */
typedef enum {
    LINK_DIR_NONE  = 0,
    LINK_DIR_DOWN  = 1,
    LINK_DIR_UP    = 2,
    LINK_DIR_LEFT  = 3,
    LINK_DIR_RIGHT = 4
} link_dir_t;

static scene_t       s_scene       = SCENE_OW;
static mode_t        s_mode        = MODE_WALK;
static move_style_t  s_move_style  = MOVE_STYLE_NES;
static u8 s_room_id = 0x77;   /* exposed for Lua overlay */
static short s_link_x = 128;
static short s_link_y =  88;
static link_face_t s_link_face = LINK_FACE_DOWN;
static link_dir_t  s_link_dir  = LINK_DIR_NONE;  /* current motion axis (NES-style) */
static u8          s_link_grid_offset = 0u;      /* 0..7, pixels past last grid line */
static u8          s_link_pos_frac   = 0u;       /* NES single-axis sub-pixel */
static u8          s_link_subx       = 0u;       /* ALTTP per-axis sub-pixel X */
static u8          s_link_suby       = 0u;       /* ALTTP per-axis sub-pixel Y */

/* S6.6 transition state machine.
 * BG_A is a 64x64 tile staging plane split into four 32x32 screen slots.
 * The fixed HUD is drawn on Window, so BG_A can scroll as one plane in both
 * axes without a per-row vertical split. */
#define SCROLL_TOTAL_FRAMES 64u   /* 4 px/frame x 64 = 256 px = full slot */
#define SCROLL_PX_PER_FRAME 4
#define ROOMROM_SLOT_TILES 32u
#define ROOMROM_SLOT_PIXELS ((short)(ROOMROM_SLOT_TILES * 8u))
#define ROOMROM_PLANE_TILES 64u
#define ROOMROM_PLANE_PIXELS ((short)(ROOMROM_PLANE_TILES * 8u))
#define ROOMROM_VERTICAL_STRIDE_TILES ROOMROM_ROOM_ROWS

typedef enum {
    SCROLL_NONE    = 0,
    SCROLL_H_RIGHT = 1,   /* Link walked right; new room slides in from right */
    SCROLL_H_LEFT  = 2,   /* Link walked left;  new room slides in from left */
    SCROLL_V_DOWN  = 3,   /* Link walked down;  new room slides in from bottom */
    SCROLL_V_UP    = 4    /* Link walked up;    new room slides in from top */
} scroll_state_t;

static scroll_state_t s_scroll_state    = SCROLL_NONE;
static u8             s_scroll_frame    = 0u;     /* counts up during scroll */
static u8             s_scroll_total_frames = SCROLL_TOTAL_FRAMES;
static u8             s_active_slot_x   = 0u;     /* 0 = cols 0..31, 1 = cols 32..63 */
static u8             s_active_row_base = 0u;     /* room base row in the 64-row plane */
static u8             s_transition_target = 0u;
static u8             s_transition_row_base = 0u;
static short          s_active_scroll_x = 0;
static short          s_active_scroll_y = 0;
static short          s_scroll_start_x = 0;
static short          s_scroll_start_y = 0;
static short          s_scroll_target_x = 0;
static short          s_scroll_target_y = 0;
/* Pre-scroll Link screen position (where he was when edge was crossed). */
static short          s_scroll_start_link_x = 0;
static short          s_scroll_start_link_y = 0;
/* Post-scroll Link screen position (entry pos in the new room). */
static short          s_transition_link_x = 0;
static short          s_transition_link_y = 0;

/* Map room metatile col 0..15 into one 32x32 staging slot. */
static u8 plane_col_for_slot(u8 src_col, u8 slot_x)
{
    return (u8)(src_col + (slot_x ? 16u : 0u));
}

static short scroll_x_offset_for_slot(u8 slot)
{
    return slot ? (short)-ROOMROM_SLOT_PIXELS : 0;
}

static short canonical_scroll_y_for_row_base(u8 row_base)
{
    return (short)((short)row_base * 8);
}

static short nearest_equivalent_scroll(short canonical, short near_value)
{
    int value = canonical;
    while ((value - (int)near_value) > (ROOMROM_PLANE_PIXELS / 2))
        value -= ROOMROM_PLANE_PIXELS;
    while (((int)near_value - value) > (ROOMROM_PLANE_PIXELS / 2))
        value += ROOMROM_PLANE_PIXELS;
    return (short)value;
}

static u8 wrap_plane_row_base(short row_base)
{
    while (row_base < 0) row_base = (short)(row_base + ROOMROM_PLANE_TILES);
    while (row_base >= ROOMROM_PLANE_TILES) row_base = (short)(row_base - ROOMROM_PLANE_TILES);
    return (u8)row_base;
}

static u8 frames_for_scroll_delta(short delta)
{
    if (delta < 0) delta = (short)-delta;
    return (u8)((delta + SCROLL_PX_PER_FRAME - 1) / SCROLL_PX_PER_FRAME);
}

static void set_bg_scroll(short h_scroll, short v_scroll)
{
    VDP_setHorizontalScroll(BG_A, h_scroll);
    VDP_setVerticalScroll(BG_A, v_scroll);
}

static void anchor_active_slot(void)
{
    set_bg_scroll(s_active_scroll_x, s_active_scroll_y);
}

/* Render a room into the specified horizontal slot and vertical row base. */
static void render_room_into_slot(u8 room_id, u8 slot_x, u8 row_base)
{
    u8 c;
    if (s_scene == SCENE_UW) {
        for (c = 0; c < 16; c++) {
            roomrom_uw_room_render_fill_one_col_at(room_id, c,
                plane_col_for_slot(c, slot_x), row_base);
        }
    } else {
        for (c = 0; c < 16; c++) {
            roomrom_ow_room_render_fill_one_col_at(room_id, c,
                plane_col_for_slot(c, slot_x), row_base);
        }
    }
}
static u8          s_link_frame = 0u;
static u8          s_link_anim_tick = 0u;
#define LINK_ANIM_PERIOD 8u
#define LINK_GRID_SIZE   8u
#define LINK_QSPEED      0x60u   /* NES Z_05.asm InitLinkSpeed: $60 = 1.5 px/frame avg */

static void init_video(void)
{
    VDP_setScreenWidth256();
    /* 64x64 plane: 2x2 room slots for H/V scroll staging. */
    VDP_setPlaneSize(64, 64, TRUE);
    VDP_setWindowOnTop(ROOMROM_HUD_ROWS);
    /* HUD is fixed on Window; BG_A scrolls as one 2x2 staging plane. */
    VDP_setScrollingMode(HSCROLL_PLANE, VSCROLL_PLANE);
    set_bg_scroll(0, 0);
}

static void load_room(u8 room_id)
{
    VDP_clearPlane(BG_A, TRUE);
    s_active_slot_x = 0u;
    s_active_row_base = 0u;
    s_active_scroll_x = 0;
    s_active_scroll_y = 0;
    /* HUD is on Window; BG_A only carries staged room playfields. */
    if (s_scene == SCENE_UW) {
        roomrom_uw_room_render_load_palette(room_id);
        roomrom_hud_draw(roomrom_uw_room_render_get_map(), room_id);
    } else {
        roomrom_ow_room_render_load_palette(room_id);
        roomrom_hud_draw(roomrom_ow_room_render_get_map(), room_id);
    }
    render_room_into_slot(room_id, s_active_slot_x, s_active_row_base);
    anchor_active_slot();
    roomrom_sprites_load_palette();   /* PAL3 - reload after BG palette write */
}

static void upload_scene_chr(void)
{
    if (s_scene == SCENE_UW) {
        roomrom_uw_room_render_upload_chr();
    } else {
        roomrom_ow_room_render_upload_chr();
    }
    roomrom_hud_upload_chr();
}

/* S5 collision: returns 1 if Link's hotspot at the given pixel position
 * lands on a walkable metatile in the current room. Hotspot is roughly
 * Link's foot center: (x+8, y+12), mapped to 16x16 metatile grid where
 * the playfield starts at y=56 (HUD reserves top 56 px). UW currently
 * always walkable (collision data not yet exposed). */
static unsigned char link_walkable_at(short x, short y)
{
    short hot_x, hot_y;
    int col, row;
    if (s_scene == SCENE_UW) return 1u;
    hot_x = (short)(x + 8);
    hot_y = (short)(y + 12);
    if (hot_y < 56) return 0u;          /* HUD strip: blocked */
    col = (int)hot_x / 16;
    row = (int)(hot_y - 56) / 16;
    if (col < 0 || col > 15 || row < 0 || row > 10) return 1u;
    return roomrom_ow_room_render_walkable_at((unsigned char)col,
                                              (unsigned char)row);
}

/* S4: edge-triggered room transition. Both OW and UW use the same 16x8 grid
 * (room_id = (row<<4)|col). When Link's position crosses a playfield edge:
 *  - if the adjacent grid cell exists, load it and snap Link to the opposite
 *    edge (preserving the perpendicular coordinate);
 *  - else, clamp at the edge (no transition).
 * Resets sub-pixel/grid/anim state on transition so movement starts clean
 * in the new room. */
static void edge_load_or_clamp(void)
{
    u8 col = s_room_id & 0x0Fu;
    u8 row = (u8)(s_room_id >> 4);
    scroll_state_t want = SCROLL_NONE;

    /* Don't re-trigger while a scroll is already running. */
    if (s_scroll_state != SCROLL_NONE) return;

    /* Capture pre-edge position before clamping/snapping. */
    short pre_x = s_link_x;
    short pre_y = s_link_y;

    if (s_link_x < 0) {
        if (col > 0u) { col--; s_link_x = 232; want = SCROLL_H_LEFT; }
        else          { s_link_x = 0; }
    } else if (s_link_x > 240) {
        if (col < 15u) { col++; s_link_x = 8; want = SCROLL_H_RIGHT; }
        else           { s_link_x = 240; }
    }

    if (s_link_y < 56) {
        if (row > 0u) { row--; s_link_y = 200; want = SCROLL_V_UP; }
        else          { s_link_y = 56; }
    } else if (s_link_y > 208) {
        if (row < 7u) { row++; s_link_y = 64; want = SCROLL_V_DOWN; }
        else          { s_link_y = 208; }
    }

    if (want != SCROLL_NONE) {
        s_transition_target = (u8)((row << 4) | col);
        s_transition_link_x = s_link_x;
        s_transition_link_y = s_link_y;
        /* Pre-edge screen pos clamped to playfield bounds, used as scroll
         * start. For H_RIGHT pre_x is just past 240 (clamp to 240); for
         * H_LEFT pre_x is just past 0 (clamp to 0). Y is unchanged. */
        if (pre_x < 0)   pre_x = 0;
        if (pre_x > 240) pre_x = 240;
        if (pre_y < 56)  pre_y = 56;
        if (pre_y > 208) pre_y = 208;
        s_scroll_start_link_x = pre_x;
        s_scroll_start_link_y = pre_y;
        s_scroll_state = want;
        s_scroll_frame = 0u;
        /* Reset sub-pixel/grid so motion starts clean post-transition. */
        s_link_pos_frac    = 0u;
        s_link_subx        = 0u;
        s_link_suby        = 0u;
        s_link_grid_offset = 0u;
        s_link_anim_tick   = 0u;

        s_scroll_start_x = s_active_scroll_x;
        s_scroll_start_y = s_active_scroll_y;
        s_scroll_target_x = s_active_scroll_x;
        s_scroll_target_y = s_active_scroll_y;
        s_transition_row_base = s_active_row_base;
        if (want == SCROLL_H_RIGHT || want == SCROLL_H_LEFT) {
            u8 target_slot_x = (u8)(s_active_slot_x ^ 1u);
            render_room_into_slot(s_transition_target,
                                  target_slot_x,
                                  s_active_row_base);
            s_scroll_target_x = scroll_x_offset_for_slot(target_slot_x);
        } else {
            short target_base = (short)s_active_row_base;
            if (want == SCROLL_V_UP)
                target_base = (short)(target_base - ROOMROM_VERTICAL_STRIDE_TILES);
            else
                target_base = (short)(target_base + ROOMROM_VERTICAL_STRIDE_TILES);
            s_transition_row_base = wrap_plane_row_base(target_base);
            render_room_into_slot(s_transition_target,
                                  s_active_slot_x,
                                  s_transition_row_base);
            s_scroll_target_y = nearest_equivalent_scroll(
                canonical_scroll_y_for_row_base(s_transition_row_base),
                s_active_scroll_y);
        }
        {
            short dx = (short)(s_scroll_target_x - s_scroll_start_x);
            short dy = (short)(s_scroll_target_y - s_scroll_start_y);
            u8 fx = frames_for_scroll_delta(dx);
            u8 fy = frames_for_scroll_delta(dy);
            s_scroll_total_frames = (fx > fy) ? fx : fy;
            if (s_scroll_total_frames == 0u) s_scroll_total_frames = 1u;
        }
    }
}

int main(bool hardReset)
{
    u16 joy_prev = 0;

    (void)hardReset;

    init_video();
    upload_scene_chr();
    {
        u32 blank[8] = {0,0,0,0,0,0,0,0};
        VDP_loadTileData(blank, 0, 1, CPU);
    }
    roomrom_sprites_upload_chr();          /* one-shot sprite CHR */
    load_room(s_room_id);                  /* loads BG pal + sprite PAL3 */
    roomrom_sprites_spawn_link(s_link_x, s_link_y);

    while (TRUE) {
        SYS_doVBlankProcess();

        /* S6.6 transition state machine. */
        if (s_scroll_state != SCROLL_NONE) {
            int num = (int)(s_scroll_frame + 1u);
            int den = (int)s_scroll_total_frames;
            short h_scroll;
            short v_scroll;
            joy_prev = 0u;     /* swallow input across transition */

            h_scroll = (short)(s_scroll_start_x +
                (((int)s_scroll_target_x - (int)s_scroll_start_x) * num) / den);
            v_scroll = (short)(s_scroll_start_y +
                (((int)s_scroll_target_y - (int)s_scroll_start_y) * num) / den);
            set_bg_scroll(h_scroll, v_scroll);

            /* Linearly interpolate Link's screen position from pre-edge
             * to the new-room entry coord over the scroll duration. */
            {
                short lx = (short)(s_scroll_start_link_x +
                    (((int)s_transition_link_x - (int)s_scroll_start_link_x) * num) / den);
                short ly = (short)(s_scroll_start_link_y +
                    (((int)s_transition_link_y - (int)s_scroll_start_link_y) * num) / den);
                u8 frame = (u8)((s_scroll_frame >> 3) & 1u);
                roomrom_sprites_set_link_pose(lx, ly, s_link_face, frame);
            }

            if (s_scroll_frame >= s_scroll_total_frames - 1u) {
                if (s_scroll_state == SCROLL_H_RIGHT ||
                    s_scroll_state == SCROLL_H_LEFT) {
                    s_active_slot_x ^= 1u;
                } else {
                    s_active_row_base = s_transition_row_base;
                }
                s_active_scroll_x = s_scroll_target_x;
                s_active_scroll_y = s_scroll_target_y;
                s_room_id = s_transition_target;
                s_link_x  = s_transition_link_x;
                s_link_y  = s_transition_link_y;
                if (s_scene == SCENE_UW) {
                    roomrom_uw_room_render_load_palette(s_room_id);
                    roomrom_hud_draw(roomrom_uw_room_render_get_map(), s_room_id);
                } else {
                    roomrom_ow_room_render_load_palette(s_room_id);
                    roomrom_hud_draw(roomrom_ow_room_render_get_map(), s_room_id);
                }
                roomrom_sprites_load_palette();
                anchor_active_slot();
                s_scroll_state = SCROLL_NONE;
            } else {
                s_scroll_frame++;
            }
            continue;
        }

        u16 joy = JOY_readJoypad(JOY_1);
        u16 pressed = joy & ~joy_prev;
        joy_prev = joy;

        if (pressed & BUTTON_X) {
            s_mode = (s_mode == MODE_WALK) ? MODE_TELEPORT : MODE_WALK;
            continue;
        }

        if (pressed & BUTTON_Y) {
            s_move_style = (s_move_style == MOVE_STYLE_NES)
                         ? MOVE_STYLE_ALTTP : MOVE_STYLE_NES;
            /* Reset sub-pixel/grid state so style switch is clean. */
            s_link_pos_frac = 0u;
            s_link_subx = 0u;
            s_link_suby = 0u;
            s_link_grid_offset = 0u;
            s_link_dir = LINK_DIR_NONE;
            continue;
        }

        if (pressed & BUTTON_B) {
            s_scene = (s_scene == SCENE_OW) ? SCENE_UW : SCENE_OW;
            s_room_id = (s_scene == SCENE_UW) ? 0x00 : 0x77;
            upload_scene_chr();
            load_room(s_room_id);
            continue;
        }

        if (pressed & BUTTON_C) {
            if (s_scene == SCENE_UW) {
                u8 map_id = roomrom_uw_room_render_get_map();
                roomrom_uw_room_render_set_map(map_id ^ 1u);
            } else {
                u8 map_id = roomrom_ow_room_render_get_map();
                roomrom_ow_room_render_set_map(map_id ^ 1u);
            }
            upload_scene_chr();
            load_room(s_room_id);
            continue;
        }

        if ((pressed & BUTTON_A) && s_scene == SCENE_UW) {
            u8 lvl = roomrom_uw_room_render_get_level();
            lvl = (lvl >= ROOMROM_UW_LEVEL_MAX) ? ROOMROM_UW_LEVEL_MIN
                                                : (u8)(lvl + 1u);
            roomrom_uw_room_render_set_level(lvl);
            load_room(s_room_id);
            continue;
        }

        if ((pressed & BUTTON_START) && s_scene == SCENE_UW) {
            u8 q = roomrom_uw_room_render_get_quest();
            q = (q == ROOMROM_UW_QUEST_MIN) ? ROOMROM_UW_QUEST_MAX
                                             : ROOMROM_UW_QUEST_MIN;
            roomrom_uw_room_render_set_quest(q);
            load_room(s_room_id);
            continue;
        }

        if (s_mode == MODE_TELEPORT) {
            /* D-pad edge-press warps room across the 16x8 grid. */
            u8 col = s_room_id & 0x0F;
            u8 row = s_room_id >> 4;
            if      ((pressed & BUTTON_LEFT)  && col > 0)  col--;
            else if ((pressed & BUTTON_RIGHT) && col < 15) col++;
            else if ((pressed & BUTTON_UP)    && row > 0)  row--;
            else if ((pressed & BUTTON_DOWN)  && row < 7)  row++;
            else continue;
            s_room_id = (u8)((row << 4) | col);
            load_room(s_room_id);
        } else if (s_move_style == MOVE_STYLE_ALTTP) {
            /* ALTTP-style 8-direction movement, ported from
             * github.com/snesrev/zelda3 src/player.c Link_HandleVelocity
             * + Link_MovePosition + kSpeedMod. 8.8 fixed-point sub-pixel
             * per axis. Cardinal vel = 24 (kSpeedMod[0]); diagonal vel = 16
             * (kSpeedMod[1]) so sqrt(2) doesn't double diagonal speed. */

            u8 dir_bits = 0u;   /* bit 0=R, bit 1=L, bit 2=D, bit 3=U */
            if (joy & BUTTON_RIGHT) dir_bits |= 0x1u;
            if (joy & BUTTON_LEFT)  dir_bits |= 0x2u;
            if (joy & BUTTON_DOWN)  dir_bits |= 0x4u;
            if (joy & BUTTON_UP)    dir_bits |= 0x8u;

            {
                u8 has_h = (dir_bits & 0x3u) != 0u;
                u8 has_v = (dir_bits & 0xCu) != 0u;
                s8 vel = (has_h && has_v) ? (s8)16 : (s8)24;
                s8 vx = 0, vy = 0;

                if (dir_bits & 0x3u) vx = (dir_bits & 0x2u) ? (s8)-vel : vel;
                if (dir_bits & 0xCu) vy = (dir_bits & 0x8u) ? (s8)-vel : vel;

                /* Facing: keep current if compatible with motion; else pick
                 * H over V (matches general 4-frame sprite limitation). */
                if      (vx > 0) s_link_face = LINK_FACE_RIGHT;
                else if (vx < 0) s_link_face = LINK_FACE_LEFT;
                else if (vy > 0) s_link_face = LINK_FACE_DOWN;
                else if (vy < 0) s_link_face = LINK_FACE_UP;

                if (vx || vy) {
                    if (++s_link_anim_tick >= LINK_ANIM_PERIOD) {
                        s_link_frame ^= 1u;
                        s_link_anim_tick = 0u;
                    }
                } else {
                    s_link_frame = 0u;
                    s_link_anim_tick = 0u;
                }

                /* ALTTP Link_MovePosition formula (8.8 fixed-point):
                 * tmp = subpixel + vel*16 + coord*256
                 * subpixel = tmp & 0xFF; coord = tmp >> 8.
                 * Per-axis collision check after each step enables wall-slide. */
                if (vx) {
                    short old_x = s_link_x;
                    u8    old_sub = s_link_subx;
                    int tmp = (int)s_link_subx + ((int)vx * 16)
                            + ((int)s_link_x << 8);
                    s_link_subx = (u8)(tmp & 0xFF);
                    s_link_x = (short)(tmp >> 8);
                    if (!link_walkable_at(s_link_x, s_link_y)) {
                        s_link_x = old_x;
                        s_link_subx = old_sub;
                    }
                }
                if (vy) {
                    short old_y = s_link_y;
                    u8    old_sub = s_link_suby;
                    int tmp = (int)s_link_suby + ((int)vy * 16)
                            + ((int)s_link_y << 8);
                    s_link_suby = (u8)(tmp & 0xFF);
                    s_link_y = (short)(tmp >> 8);
                    if (!link_walkable_at(s_link_x, s_link_y)) {
                        s_link_y = old_y;
                        s_link_suby = old_sub;
                    }
                }
            }

            edge_load_or_clamp();
            roomrom_sprites_set_link_pose(s_link_x, s_link_y,
                                          s_link_face, s_link_frame);
        } else {
            /* NES-faithful Link movement, ported from
             *   Z_05.asm Link_HandleInput / Link_ModifyDirAtGridPoint
             *   Z_07.asm Walker_Move / MoveObject / AddQSpeedToPositionFraction
             *
             * Per-frame:
             * 1. If on a grid intersection (offset == 0), pick a single-axis
             *    direction from current input (no diagonal). H over V on tie.
             * 2. If input released, stop instantly (even mid-grid). Walker_Move
             *    @ChooseObjDirOrInputDir: input=0 -> moving_dir=0.
             * 3. If moving, run 4 quarter-steps. Each step adds QSpeed=$60 to
             *    pos_frac; on 8-bit overflow, advance 1 px in active axis and
             *    increment grid_offset. When grid_offset hits 8, wrap to 0
             *    (next intersection -> direction can change next frame). */

            u16 input = joy & (BUTTON_LEFT|BUTTON_RIGHT|BUTTON_UP|BUTTON_DOWN);
            u8 h_dir = (input & BUTTON_LEFT) ? 1u
                     : ((input & BUTTON_RIGHT) ? 2u : 0u);
            u8 v_dir = (input & BUTTON_UP)   ? 1u
                     : ((input & BUTTON_DOWN) ? 2u : 0u);

            if (input == 0u) {
                s_link_dir = LINK_DIR_NONE;
                s_link_pos_frac = 0u;       /* reset frac on stop */
            } else if (s_link_grid_offset == 0u) {
                link_dir_t want;
                if (h_dir && v_dir) {
                    /* NES Link_ModifyDirAtGridPoint with 2 inputs: in OW,
                     * picks "last walkable" (h_dir last in bit-iteration).
                     * H over V matches OW behavior. */
                    want = (h_dir == 1u) ? LINK_DIR_LEFT : LINK_DIR_RIGHT;
                } else if (h_dir) {
                    want = (h_dir == 1u) ? LINK_DIR_LEFT : LINK_DIR_RIGHT;
                } else {
                    want = (v_dir == 1u) ? LINK_DIR_UP : LINK_DIR_DOWN;
                }
                s_link_dir = want;
            }
            /* off-grid + input held: keep current direction (NES) */

            if (s_link_dir != LINK_DIR_NONE) {
                u8 step_count;
                u8 q;

                switch (s_link_dir) {
                    case LINK_DIR_LEFT:  s_link_face = LINK_FACE_LEFT;  break;
                    case LINK_DIR_RIGHT: s_link_face = LINK_FACE_RIGHT; break;
                    case LINK_DIR_UP:    s_link_face = LINK_FACE_UP;    break;
                    case LINK_DIR_DOWN:  s_link_face = LINK_FACE_DOWN;  break;
                    default: break;
                }
                if (++s_link_anim_tick >= LINK_ANIM_PERIOD) {
                    s_link_frame ^= 1u;
                    s_link_anim_tick = 0u;
                }

                /* 4 quarter-steps, each adds $60 to pos_frac; carry -> 1 px. */
                step_count = 0u;
                for (q = 0; q < 4u; q++) {
                    unsigned short sum = (unsigned short)s_link_pos_frac + LINK_QSPEED;
                    s_link_pos_frac = (u8)(sum & 0xFFu);
                    if (sum >= 0x100u) {
                        step_count++;
                        s_link_grid_offset++;
                        if (s_link_grid_offset >= LINK_GRID_SIZE) {
                            s_link_grid_offset = 0u;
                        }
                    }
                }

                {
                    short old_x = s_link_x, old_y = s_link_y;
                    switch (s_link_dir) {
                        case LINK_DIR_LEFT:  s_link_x -= step_count; break;
                        case LINK_DIR_RIGHT: s_link_x += step_count; break;
                        case LINK_DIR_UP:    s_link_y -= step_count; break;
                        case LINK_DIR_DOWN:  s_link_y += step_count; break;
                        default: break;
                    }
                    if (!link_walkable_at(s_link_x, s_link_y)) {
                        s_link_x = old_x;
                        s_link_y = old_y;
                        /* Single-axis NES motion -> blocking just halts. */
                    }
                }
            } else {
                s_link_frame = 0u;
                s_link_anim_tick = 0u;
                s_link_grid_offset = 0u;
            }

            edge_load_or_clamp();
            roomrom_sprites_set_link_pose(s_link_x, s_link_y,
                                          s_link_face, s_link_frame);
        }
    }

    return 0;
}
