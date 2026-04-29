/* src/fs_handoff.c -- VDP teardown + jump to ASM trampoline.
 * S1.F4: vdp_* calls replaced with render_* API.
 */
#include "fs_handoff.h"
#include "render_abi.h"
#include "platform_abi.h"

extern void fs_to_transpiled_trampoline(void);

#ifdef OW_DEBUG_ENTRY
extern void ow_debug_entry(unsigned char room_id);
#endif

static void clear_plane(unsigned short plane_base) {
    unsigned short zero_row[32];
    unsigned short i;
    for (i = 0; i < 32; i++) zero_row[i] = 0;
    for (i = 0; i < 32; i++) {
        render_plane_write_row(plane_base, i, zero_row, 32u);
    }
}

void fs_handoff_to_transpiled(uint8_t slot) {
    nes_ram[0x07F2] = 0xCC;   /* probe: fs handoff begun */

    render_display_enable(0);
    clear_plane(0xC000);
    clear_plane(0xE000);
    render_mode_set_v64();
    render_vscroll_set(0);

    /* Seed CurSaveSlot ($0016) directly here -- m68k SysV byte-arg ABI is
     * unreliable, so the trampoline takes no args and reads from RAM. */
    nes_ram[0x0016] = slot;

    /* InitMode1_Sub6 (Z_02.asm:2526) runs @FindActiveSlot which loops while
     * IsSaveSlotActive[Y] == 0, scanning $0633+. With fresh RAM (all zero)
     * the loop runs off-array, INCing CurSaveSlot to a garbage value and
     * eventually catching a stray non-zero byte -- but in practice we observe
     * the init chain stalling at GameSubmode=06 with display off. Mark slot 0
     * active so @FindActiveSlot exits cleanly on the first iteration with
     * CurSaveSlot=0 and the rest of Sub6 (LDA #$00 STA GameSubmode INC
     * IsUpdatingMode) runs. SRAM read isn't wired yet; v6.full SRAM lands
     * the real per-slot detection. */
    nes_ram[0x0633] = 0x01;   /* IsSaveSlotActive[0] = 1 */

    /* Trampoline restores V64 + Window 8, sets vblank_mode=1, jumps to
     * LoopForever. Does not return. */
#ifdef OW_DEBUG_ENTRY
    render_display_enable(0);
    ow_debug_entry(0x77);  /* start room $77; does not return */
#else
    fs_to_transpiled_trampoline();
#endif
}
