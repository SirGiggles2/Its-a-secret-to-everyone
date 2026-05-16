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

    /* InitMode1_Full pre-Sub6 chain (Z_02.asm:2122 jump table):
     *   Sub0 = UpdateMode0Demo_Sub1  -- for each slot: if file-B uncommitted,
     *          CopyFileBToFileA (NUKES IsSaveSlotActive); else @CheckFileA
     *          which validates markers + checksum, calls FormatFileA on
     *          mismatch (ALSO NUKES IsSaveSlotActive).
     *   Sub1..5 = tile transfers.
     *   Sub6 = @FindActiveSlot loop -- hangs if IsSaveSlotActive[0..2]==0.
     *
     * Seeding IsSaveSlotActive[0]=1 alone is insufficient: Sub0 overwrites
     * it back to zero via CopyFileBToFileA (fresh-RAM file-B passes
     * all-zero checksum match). Then Sub6 hangs with display off
     * (VRamForceBlankGate=1).
     *
     * Fix: seed enough SRAM that Sub0 takes the no-write @NextSlot path
     * for every slot:
     *   IsSaveFileBCommitted[Y]=$01  -> skip CopyFileBToFileA branch
     *   SaveFileOpenMarkers[Y]=$5A   -> markers valid
     *   SaveFileCloseMarkers[Y]=$A5  -> markers valid
     *   FileAChecksums[Y*2..Y*2+1]=0 -> already true in fresh RAM
     *                                    (CalculateFileAChecksum on zero
     *                                    file = 0; 0==0)
     *
     * With these seeds, Sub0 runs all three slots @NextSlot, advances
     * GameSubmode normally. Sub1..5 tile-transfer. Sub6 finds
     * IsSaveSlotActive[0]=1 first iteration, exits with CurSaveSlot=0.
     */
    {
        uint8_t y;
        for (y = 0; y < 3; ++y) {
            nes_ram[0x0633 + y] = (y == 0) ? 0x01 : 0x00;  /* IsSaveSlotActive */
            nes_ram[0x651E + y] = 0x5A;                     /* SaveFileOpenMarkers */
            nes_ram[0x6521 + y] = 0xA5;                     /* SaveFileCloseMarkers */
            nes_ram[0x652A + y] = 0x01;                     /* IsSaveFileBCommitted */
        }
        /* FileAChecksums[0..5] = 0 already (fresh RAM) -> checksum match. */
    }

    /* Trampoline restores V64 + Window 8, sets vblank_mode=1, jumps to
     * LoopForever. Does not return. */
#ifdef OW_DEBUG_ENTRY
    render_display_enable(0);
    ow_debug_entry(0x77);  /* start room $77; does not return */
#else
    fs_to_transpiled_trampoline();
#endif
}
