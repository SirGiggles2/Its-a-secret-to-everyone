#include <genesis.h>
#include "ow_room_render_roomrom.h"
#include "uw_room_render_roomrom.h"
#include "roomrom_hud.h"

/* Boots to overworld room 0x77. D-pad navigates all 128 rooms.
 * Room layout: 16 wide x 8 tall, room_id = (row << 4) | col.
 *
 * Buttons:
 *   D-pad     room navigation
 *   B         scene toggle (overworld <-> dungeon)
 *   C         map variant toggle (original <-> redux), per-scene
 *   A         (dungeon scene) cycle level 1..9
 *   START     (dungeon scene) toggle quest 1 <-> 2 */

typedef enum { SCENE_OW = 0, SCENE_UW = 1 } scene_t;
static scene_t s_scene = SCENE_OW;
static u8 s_room_id = 0x77;   /* exposed for Lua overlay */

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
    u8 col, row;

    (void)hardReset;

    init_video();
    upload_scene_chr();
    {
        u32 blank[8] = {0,0,0,0,0,0,0,0};
        VDP_loadTileData(blank, 0, 1, CPU);
    }
    load_room(s_room_id);

    while (TRUE) {
        SYS_doVBlankProcess();

        u16 joy = JOY_readJoypad(JOY_1);
        u16 pressed = joy & ~joy_prev;
        joy_prev = joy;

        col = s_room_id & 0x0F;
        row = s_room_id >> 4;

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

        {
            /* UW grid: 16 cols x 8 rows (room_id = (row<<4)|col, col 0..15).
             * OW grid: 16 cols x 8 rows. Same bounds. */
            u8 max_col = 15u;
            u8 max_row = 7u;
            if      ((pressed & BUTTON_LEFT)  && col > 0)        col--;
            else if ((pressed & BUTTON_RIGHT) && col < max_col)  col++;
            else if ((pressed & BUTTON_UP)    && row > 0)        row--;
            else if ((pressed & BUTTON_DOWN)  && row < max_row)  row++;
            else continue;
        }

        s_room_id = (u8)((row << 4) | col);
        load_room(s_room_id);
    }

    return 0;
}
