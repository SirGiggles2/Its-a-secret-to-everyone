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
 */
#include "intro_handoff.h"
#include "intro_common.h"   /* vdp_display_off, vdp_set_vscroll, vdp_write_nametable_row */
#include "fs_main.h"
#include "nes_abi.h"

static void clear_plane(unsigned short plane_base) {
    unsigned short zero_row[32];
    unsigned short i;
    for (i = 0; i < 32; i++) zero_row[i] = 0;
    for (i = 0; i < 32; i++) {
        vdp_write_nametable_row(plane_base, i, zero_row);
    }
}

void intro_start_pressed(void) {
    nes_ram[0x07F2] = 0xAA;   /* probe: handoff begun */

    vdp_display_off();
    clear_plane(0xC000);
    clear_plane(0xE000);
    vdp_set_vscroll(0);

    /* Native File Select. fs_main sets its own VDP plane-size + CHR + palettes
     * + sprite table + display_on. Never returns. */
    fs_main();
}
