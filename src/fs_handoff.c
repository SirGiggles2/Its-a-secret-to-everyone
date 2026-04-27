/* src/fs_handoff.c — VDP teardown + jump to ASM trampoline. */
#include "fs_handoff.h"
#include "intro_common.h"   /* vdp_display_off, vdp_set_vscroll, vdp_write_nametable_row */
#include "nes_abi.h"

extern void fs_to_transpiled_trampoline(void);

static void clear_plane(unsigned short plane_base) {
    unsigned short zero_row[32];
    unsigned short i;
    for (i = 0; i < 32; i++) zero_row[i] = 0;
    for (i = 0; i < 32; i++) {
        vdp_write_nametable_row(plane_base, i, zero_row);
    }
}

void fs_handoff_to_transpiled(uint8_t slot) {
    nes_ram[0x07F2] = 0xCC;   /* probe: fs handoff begun */

    vdp_display_off();
    clear_plane(0xC000);
    clear_plane(0xE000);
    vdp_set_mode_v64();          /* match intro_handoff: V64 before trampoline */
    vdp_set_vscroll(0);

    /* Seed CurSaveSlot ($0016) directly here — m68k SysV byte-arg ABI is
     * unreliable, so the trampoline takes no args and reads from RAM. */
    nes_ram[0x0016] = slot;

    /* Trampoline restores V64 + Window 8, sets vblank_mode=1, jumps to
     * LoopForever. Does not return. */
    fs_to_transpiled_trampoline();
}
