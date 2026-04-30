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
static u8          s_link_frame = 0u;
static u8          s_link_anim_tick = 0u;
#define LINK_ANIM_PERIOD 8u
#define LINK_GRID_SIZE   8u
#define LINK_QSPEED      0x60u   /* NES Z_05.asm InitLinkSpeed: $60 = 1.5 px/frame avg */

static void init_video(void)
{
    VDP_setScreenWidth256();
    VDP_setPlaneSize(32, 32, TRUE);
    VDP_setWindowOff();
    VDP_setScrollingMode(HSCROLL_PLANE, VSCROLL_PLANE);
    VDP_setHorizontalScroll(BG_A, 0);
    VDP_setVerticalScroll(BG_A, 0);
}

static void load_room(u8 room_id)
{
    VDP_clearPlane(BG_A, TRUE);
    if (s_scene == SCENE_UW) {
        roomrom_uw_room_render_load_palette(room_id);
        roomrom_uw_room_render_fill_plane_a(room_id);
        roomrom_hud_draw(roomrom_uw_room_render_get_map(), room_id);
    } else {
        roomrom_ow_room_render_load_palette(room_id);
        roomrom_ow_room_render_fill_plane_a(room_id);
        roomrom_hud_draw(roomrom_ow_room_render_get_map(), room_id);
    }
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
                 * subpixel = tmp & 0xFF; coord = tmp >> 8 */
                if (vx) {
                    int tmp = (int)s_link_subx + ((int)vx * 16)
                            + ((int)s_link_x << 8);
                    s_link_subx = (u8)(tmp & 0xFF);
                    s_link_x = (short)(tmp >> 8);
                }
                if (vy) {
                    int tmp = (int)s_link_suby + ((int)vy * 16)
                            + ((int)s_link_y << 8);
                    s_link_suby = (u8)(tmp & 0xFF);
                    s_link_y = (short)(tmp >> 8);
                }
            }

            if (s_link_x < 0)   { s_link_x = 0;   s_link_subx = 0u; }
            if (s_link_x > 240) { s_link_x = 240; s_link_subx = 0u; }
            if (s_link_y < 56)  { s_link_y = 56;  s_link_suby = 0u; }
            if (s_link_y > 208) { s_link_y = 208; s_link_suby = 0u; }

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

                switch (s_link_dir) {
                    case LINK_DIR_LEFT:  s_link_x -= step_count; break;
                    case LINK_DIR_RIGHT: s_link_x += step_count; break;
                    case LINK_DIR_UP:    s_link_y -= step_count; break;
                    case LINK_DIR_DOWN:  s_link_y += step_count; break;
                    default: break;
                }
            } else {
                s_link_frame = 0u;
                s_link_anim_tick = 0u;
                s_link_grid_offset = 0u;
            }

            if (s_link_x < 0)   s_link_x = 0;
            if (s_link_x > 240) s_link_x = 240;
            if (s_link_y < 56)  s_link_y = 56;
            if (s_link_y > 208) s_link_y = 208;

            roomrom_sprites_set_link_pose(s_link_x, s_link_y,
                                          s_link_face, s_link_frame);
        }
    }

    return 0;
}
