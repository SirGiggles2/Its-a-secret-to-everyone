/* src/intro_handoff.c
 *
 * C side of Start press handoff. Performs VDP cleanup so the screen
 * is in a known state (display off, planes blank, V64 mode, vscroll=0)
 * before the ASM trampoline restores the translated runtime register
 * contract and re-enables transpiled NMI handling.
 */
#include "intro_handoff.h"
#include "intro_common.h"   /* vdp_display_off, vdp_set_mode_v64, vdp_set_vscroll, vdp_write_nametable_row */
#include "nes_abi.h"

extern void intro_to_file_select_trampoline(void);   /* in genesis_shell.asm */

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
    vdp_set_mode_v64();
    vdp_set_vscroll(0);

    /* Tail call into ASM trampoline. Trampoline does not return. */
    intro_to_file_select_trampoline();
}
