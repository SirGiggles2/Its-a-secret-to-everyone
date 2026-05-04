/* room_dispatch.c — native room subsystem dispatch (Phase 4).
 *
 * Drain MATCH (verified-by-use; in production via Title.md gameplay).
 */

#include "room_dispatch.h"
#include <stdint.h>
#include "platform_abi.h"
#include "world_state.h"       /* CUR_ROOM_ID */
#include "progress_state.h"    /* CUR_LEVEL, SAVEFILE_PTR_LO/HI */
#include "room_state.h"        /* ROOM_MAX_MONSTER_SLOT, ROOM_MONSTER_ALL_DEAD,
                                * ROOM_OBJ_TYPE */
#include "combat_state.h"      /* LINK_DAMAGE_DISABLE_FLAG */

#define NES_SRAM_BASE 0x6000u

unsigned char room_get_room_flags(void)
{
    /* drain at room_runtime.c:14-22. NES GetRoomFlags.
     * SRAM ROOM_FLAGS_PTR_LO/HI at $6BAF/$6BB0; deref + read at
     * CUR_ROOM_ID offset. Stashes ptr to SAVEFILE_PTR_LO/HI. */
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

unsigned int room_split_room_id(void)
{
    /* drain at room_runtime.c:71-76. */
    const unsigned char room = (unsigned char)CUR_ROOM_ID;
    const unsigned char col = (unsigned char)(room & 0x0Fu);
    const unsigned char row = (unsigned char)(room >> 4);
    return ((unsigned int)row << 8) | (unsigned int)col;
}

unsigned char room_is_dark_room(unsigned int col)
{
    /* drain at room_runtime.c:78-82. */
    if (CUR_LEVEL == 0u) {
        return 0u;
    }
    return (unsigned char)(nes_ram[NES_SRAM_BASE + 0x0A7Eu + (col & 0xFFu)] & 0x80u);
}

void room_silence_sound(void)
{
    /* drain at room_runtime.c:120-123. */
    RAM(0x0604u) = 0x80u;  /* ROOM_SFX_MAIN */
    RAM(0x0603u) = 0x80u;  /* ROOM_SFX_AUX */
}

void room_check_has_living_monsters(void)
{
    /* drain at room_runtime.c:102-118. NES CheckHasLivingMonsters. */
    const unsigned char max_slot = (unsigned char)ROOM_MAX_MONSTER_SLOT;
    for (signed char i = (signed char)max_slot; i >= 0; i--) {
        const unsigned char obj = (unsigned char)ROOM_OBJ_TYPE((unsigned char)i);
        if (obj == 0u) {
            continue;
        }
        if (obj < 0x2Bu) {
            return;
        }
        if (obj < 0x2Eu) {
            continue;
        }
        if (obj < 0x49u) {
            return;
        }
    }
    LINK_DAMAGE_DISABLE_FLAG = 0u;
    ROOM_MONSTER_ALL_DEAD = (uint8_t)(ROOM_MONSTER_ALL_DEAD + 1u);
}
