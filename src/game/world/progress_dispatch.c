/* progress_dispatch.c — native progress subsystem dispatch (Phase 4).
 *
 * Phase 4 first progress batch: room-flag persistence pair that
 * unblocks Phase 3 cave stubs (set/get UW-item-taken bit).
 *
 * Drain MATCH per finding 4_4n. Pure C, no shims (the
 * z07_get_room_flags transpile shim that drain calls is replaced
 * with an inline RAM-deref of the same SRAM pointer pattern).
 */

#include "progress_dispatch.h"
#include "platform_abi.h"      /* RAM, nes_ram[], NES_SRAM_*, OBJ */
#include "save_state.h"        /* SAVE_ROOM_FLAGS_PTR_LO/HI */
#include "progress_state.h"    /* SAVEFILE_PTR_LO/HI, SAVEFILE_MASK_LO/HI */
#include "world_state.h"       /* CUR_ROOM_ID */

#define NES_SRAM_BASE 0x6000u

/* Inline equivalent of roomrt_get_room_flags / z07_get_room_flags
 * (src/oracle/room/room_runtime.c:14-22). Reads SRAM room-flags
 * pointer, derefs at CUR_ROOM_ID, returns the per-room flag byte.
 * Side effect: stashes the SRAM pointer into SAVEFILE_PTR_LO/HI
 * (NES caller convention — drain preserves this). */
static inline unsigned char progress_read_room_flags_inline(void)
{
    const unsigned char ptr_lo =
        nes_ram[NES_SRAM_BASE + NES_SRAM_ROOM_FLAGS_PTR_LO];
    const unsigned char ptr_hi =
        nes_ram[NES_SRAM_BASE + NES_SRAM_ROOM_FLAGS_PTR_HI];
    SAVEFILE_PTR_LO = ptr_lo;
    SAVEFILE_PTR_HI = ptr_hi;
    const unsigned short ptr =
        (unsigned short)(((unsigned short)ptr_hi << 8) | ptr_lo);
    return (unsigned char)nes_ram[ptr + CUR_ROOM_ID];
}

void progress_set_room_flag_uw_item_state(void)
{
    /* drain at progress_runtime.c:32-38. NES SetRoomFlagUWItemState:
     *   JSR GetRoomFlags    ; A = current room's flag byte; sets ptr scratch
     *   ORA #$10            ; mark UW-item-taken
     *   LDY CUR_ROOM_ID
     *   STA (ptr),Y         ; persist back into save slot table
     */
    unsigned char flags = progress_read_room_flags_inline();
    flags = (unsigned char)(flags | 0x10u);
    const unsigned short ptr =
        (unsigned short)(((unsigned short)SAVEFILE_PTR_HI << 8) | SAVEFILE_PTR_LO);
    nes_ram[ptr + CUR_ROOM_ID] = flags;
}

unsigned char progress_get_room_flag_uw_item_state(void)
{
    /* drain at progress_runtime.c:40-48. NES GetRoomFlagUWItemState
     * uses a different pointer-source path than the bare GetRoomFlags
     * — pulls SAVE_ROOM_FLAGS_PTR_* from the active save file (vs
     * the SRAM table that GetRoomFlags reads). drain stashes the
     * pointer into SAVEFILE_MASK_LO/HI as a side effect. */
    const unsigned char ptr_lo = SAVE_ROOM_FLAGS_PTR_LO;
    const unsigned char ptr_hi = SAVE_ROOM_FLAGS_PTR_HI;
    SAVEFILE_MASK_LO = ptr_lo;
    SAVEFILE_MASK_HI = ptr_hi;
    const unsigned short ptr =
        (unsigned short)(((unsigned short)ptr_hi << 8) | ptr_lo);
    return (unsigned char)(nes_ram[ptr + CUR_ROOM_ID] & 0x10u);
}
