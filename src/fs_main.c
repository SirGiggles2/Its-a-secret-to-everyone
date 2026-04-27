/* src/fs_main.c — entry from boot.asm (proof ROM) or intro_handoff (main ROM v6).
 * v1: render static layout once, then spin forever in vblank loop.
 */
#include "fs_main.h"
#include "fs_render.h"
#include "intro_common.h"

#define VDP_CTRL_WORD (*(volatile unsigned short *)0x00C00004)

static void wait_vblank(void) {
    while ( (VDP_CTRL_WORD & 0x0008));
    while (!(VDP_CTRL_WORD & 0x0008));
}

void fs_main(void) {
    fs_render_clear_screen();
    fs_render_static_layout();
    vdp_display_on();
    for (;;) {
        wait_vblank();
        /* Phase machine + input poll added v2. */
    }
}
