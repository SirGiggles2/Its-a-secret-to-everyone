#include <genesis.h>
#include "ow_room_render_roomrom.h"
#include "uw_room_render_roomrom.h"
#include "roomrom_hud.h"
#include "roomrom_sprites.h"

/* Boots to overworld room 0x77.
 *
 * Modes (toggled by X):
 *   WALK       D-pad moves Link (1 px/frame)
 *   TELEPORT   D-pad jumps room (16x8 grid: room_id = (row<<4)|col)
 *
 * Buttons (always):
 *   X         toggle WALK <-> TELEPORT mode
 *   B         scene toggle (overworld <-> dungeon)
 *   C         map variant toggle (original <-> redux), per-scene
 *   A         (dungeon scene) cycle level 1..9
 *   START     (dungeon scene) toggle quest 1 <-> 2 */

typedef enum { SCENE_OW = 0, SCENE_UW = 1 } scene_t;
typedef enum { MODE_WALK = 0, MODE_TELEPORT = 1 } mode_t;

/* NES Z1 movement direction (matches Z_05.asm Link_ModifyDir bit layout
 * conceptually: only one axis at a time, no diagonal). */
typedef enum {
    LINK_DIR_NONE  = 0,
    LINK_DIR_DOWN  = 1,
    LINK_DIR_UP    = 2,
    LINK_DIR_LEFT  = 3,
    LINK_DIR_RIGHT = 4
} link_dir_t;

static scene_t s_scene = SCENE_OW;
static mode_t  s_mode  = MODE_WALK;
static u8 s_room_id = 0x77;   /* exposed for Lua overlay */
static short s_link_x = 128;
static short s_link_y =  88;
static link_face_t s_link_face = LINK_FACE_DOWN;
static link_dir_t  s_link_dir  = LINK_DIR_NONE;  /* current motion axis (NES-style) */
static u8          s_link_grid_offset = 0u;      /* 0..7, pixels past last grid line */
static u8          s_link_frame = 0u;
static u8          s_link_anim_tick = 0u;
#define LINK_ANIM_PERIOD 8u
#define LINK_GRID_SIZE   8u

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
        } else {
            /* NES-faithful movement (Z_05.asm Link_HandleInput +
             * Link_ModifyDirAtGridPoint + Walker_Move):
             *
             * - Grid-locked: direction can only change when on an 8-px
             *   grid line (s_link_grid_offset == 0).
             * - Single-axis: no true diagonal. When two D-pad buttons
             *   are held, perpendicular-to-current-facing wins (NES
             *   "GoStraight" rule for dungeon corner behavior); on OW
             *   we fall back to H-over-V.
             * - Constant speed: 1 px/frame in the active axis.
             * - Releasing all D-pad stops Link instantly. */

            u16 input = joy & (BUTTON_LEFT|BUTTON_RIGHT|BUTTON_UP|BUTTON_DOWN);

            if (s_link_grid_offset == 0u) {
                link_dir_t want = LINK_DIR_NONE;
                u8 h = (u8)((input & BUTTON_LEFT) ? 1u : 0u)
                     | (u8)((input & BUTTON_RIGHT) ? 2u : 0u);
                u8 v = (u8)((input & BUTTON_UP)   ? 1u : 0u)
                     | (u8)((input & BUTTON_DOWN) ? 2u : 0u);
                u8 h_dir = (h == 1u) ? 1u : ((h == 2u) ? 2u : 0u);
                u8 v_dir = (v == 1u) ? 1u : ((v == 2u) ? 2u : 0u);

                if (h_dir && v_dir) {
                    /* Two axes pressed: pick perpendicular to current
                     * facing if any; else H over V. */
                    if (s_link_dir == LINK_DIR_LEFT || s_link_dir == LINK_DIR_RIGHT)
                        want = (v_dir == 1u) ? LINK_DIR_UP : LINK_DIR_DOWN;
                    else if (s_link_dir == LINK_DIR_UP || s_link_dir == LINK_DIR_DOWN)
                        want = (h_dir == 1u) ? LINK_DIR_LEFT : LINK_DIR_RIGHT;
                    else
                        want = (h_dir == 1u) ? LINK_DIR_LEFT : LINK_DIR_RIGHT;
                } else if (h_dir) {
                    want = (h_dir == 1u) ? LINK_DIR_LEFT : LINK_DIR_RIGHT;
                } else if (v_dir) {
                    want = (v_dir == 1u) ? LINK_DIR_UP : LINK_DIR_DOWN;
                }
                s_link_dir = want;
            }
            /* Off-grid: keep current direction unless input released. */
            else if (input == 0u) {
                /* NES holds direction until grid line; we mirror by
                 * letting it keep moving until offset wraps to 0. */
            }

            /* Update facing + anim. Facing only changes when we're
             * actively moving in a direction. */
            if (s_link_dir != LINK_DIR_NONE) {
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

                /* Step 1 px in the active axis. */
                switch (s_link_dir) {
                    case LINK_DIR_LEFT:  s_link_x--; break;
                    case LINK_DIR_RIGHT: s_link_x++; break;
                    case LINK_DIR_UP:    s_link_y--; break;
                    case LINK_DIR_DOWN:  s_link_y++; break;
                    default: break;
                }
                s_link_grid_offset = (u8)((s_link_grid_offset + 1u) & (LINK_GRID_SIZE - 1u));
            } else {
                s_link_frame = 0u;
                s_link_anim_tick = 0u;
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
