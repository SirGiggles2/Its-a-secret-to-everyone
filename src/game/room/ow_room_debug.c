#include "ow_room_render.h"
#include "render_abi.h"

void ow_debug_entry(unsigned char room_id)
{
    render_display_enable(0);
    render_plane_fill(0xC000, 0, 2048);
    ow_room_render_upload_chr();
    ow_room_render_fill_plane_a(room_id);
    render_display_enable(1);
    while (1) {
        render_wait_vblank();
    }
}
