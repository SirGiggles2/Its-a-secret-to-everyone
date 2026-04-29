#include <genesis.h>
#include "ow_room_render_roomrom.h"

/* Boots to overworld room 0x77. D-pad navigates all 128 rooms.
 * Room layout: 16 wide x 8 tall, room_id = (row << 4) | col. */

static void load_room(u8 room_id)
{
    roomrom_ow_room_render_load_palette(room_id);
    VDP_clearPlane(BG_A, TRUE);
    roomrom_ow_room_render_fill_plane_a(room_id);
}

int main(bool hardReset)
{
    u8 room_id = 0x77;
    u16 joy_prev = 0;
    u8 col, row;

    (void)hardReset;

    roomrom_ow_room_render_upload_chr();
    {
        u32 blank[8] = {0,0,0,0,0,0,0,0};
        VDP_loadTileData(blank, 0, 1, CPU);
    }
    load_room(room_id);

    while (TRUE) {
        SYS_doVBlankProcess();

        u16 joy = JOY_readJoypad(JOY_1);
        u16 pressed = joy & ~joy_prev;
        joy_prev = joy;

        col = room_id & 0x0F;
        row = room_id >> 4;

        if (pressed & BUTTON_C) {
            u8 map_id = roomrom_ow_room_render_get_map();
            roomrom_ow_room_render_set_map(map_id ^ 1u);
            roomrom_ow_room_render_upload_chr();
            load_room(room_id);
            continue;
        }

        if      ((pressed & BUTTON_LEFT)  && col > 0)  col--;
        else if ((pressed & BUTTON_RIGHT) && col < 15) col++;
        else if ((pressed & BUTTON_UP)    && row > 0)  row--;
        else if ((pressed & BUTTON_DOWN)  && row < 7)  row++;
        else continue;

        room_id = (u8)((row << 4) | col);
        load_room(room_id);
    }

    return 0;
}
