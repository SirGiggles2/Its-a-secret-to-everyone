/* src/intro_handoff.c
 *
 * C side of Start press handoff. Performs VDP cleanup so the screen
 * is in a known state (display off, planes blank, vscroll=0) before
 * fs_main takes over. fs_main sets V32 internally then renders the
 * native File Select.
 *
 * v6 minimal-promote: replaces the transpiled FS trampoline call with
 * direct fs_main entry. fs_main never returns; back-handoff to transpiled
 * gameplay is added in v6.2 (FS_HANDOFF phase + ASM trampoline).
 *
 * S1.F4: vdp_* calls replaced with render_* API.
 */
#include "intro_handoff.h"
#include "render_abi.h"
#include "fs_main.h"
#include "platform_abi.h"

static void clear_plane(unsigned short plane_base) {
    unsigned short zero_row[32];
    unsigned short i;
    for (i = 0; i < 32; i++) zero_row[i] = 0;
    for (i = 0; i < 32; i++) {
        render_plane_write_row(plane_base, i, zero_row, 32u);
    }
}

void intro_start_pressed(void) {
    nes_ram[0x07F2] = 0xAA;   /* probe: handoff begun */

    render_display_enable(0);
    clear_plane(0xC000);
    clear_plane(0xE000);
    render_vscroll_set(0);

    /* Native File Select. fs_main sets its own VDP plane-size + CHR + palettes
     * + sprite table + display_on. Never returns. */
    fs_main();
}
