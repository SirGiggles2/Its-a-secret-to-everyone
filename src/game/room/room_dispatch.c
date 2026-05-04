/* room_dispatch.c — native room subsystem dispatch (Phase 4).
 *
 * Drain MATCH (verified-by-use; in production via Title.md gameplay).
 */

#include "room_dispatch.h"
#include <stdint.h>
#include "platform_abi.h"
#include "world_state.h"       /* CUR_ROOM_ID */
#include "progress_state.h"    /* CUR_LEVEL, SAVEFILE_PTR_LO/HI, SUBMODE_VALUE,
                                * MODE_VALUE */
#include "room_state.h"        /* ROOM_MAX_MONSTER_SLOT, ROOM_MONSTER_ALL_DEAD,
                                * ROOM_OBJ_TYPE, ROOM_MODE_TIMER */
#include "world_state.h"       /* TRANSFER_BUF_POS — included via combat below */
#include "combat_state.h"      /* LINK_DAMAGE_DISABLE_FLAG, LINK_ACTION_TIMER */
#include "link_state.h"        /* LINK_HALT_FLAG */

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

unsigned char room_end_game_mode(void)
{
    /* drain at room_mode_runtime.c:249-253. Plan-C drain (the inner
     * one). Outer roommd_end_game_mode12 is the cellar dance + level
     * fall — defer until cellar logic ports. */
    ROOM_MODE_TIMER = 0u;
    SUBMODE_VALUE = 0u;
    return 0u;
}

void room_hide_all_sprites(void)
{
    /* drain at room_runtime.c:273-276. */
    for (unsigned char i = 0u; i < 64u; ++i) {
        RAM(0x0200u + (unsigned short)((unsigned short)i * 4u)) = 0xF8u;
    }
}

unsigned char room_get_unique_room_id(void)
{
    /* drain at room_runtime.c:278-281. */
    const unsigned char room = (unsigned char)CUR_ROOM_ID;
    return (unsigned char)(nes_ram[NES_SRAM_BASE +
                                   NES_SRAM_ROOM_UNIQUE_ID_BASE + room] &
                           0x3Fu);
}

void room_clear_room_history(void)
{
    /* drain at room_runtime.c:283-287. */
    RAM(NES_ROOM_HISTORY_IDX) = 0u;
    for (signed char i = 5; i >= 0; --i) {
        RAM(NES_ROOM_HISTORY_BASE + (unsigned char)i) = 0u;
    }
}

void room_reset_player_state(void)
{
    /* drain at room_runtime.c:289-292. */
    LINK_ACTION_TIMER = 0u;
    LINK_HALT_FLAG = 0u;
}

void room_mark_room_visited(void)
{
    /* drain at room_runtime.c:294-299. Re-uses the GetRoomFlags ptr
     * stash side-effect. */
    const unsigned char flags = room_get_room_flags();
    const unsigned short ptr =
        (unsigned short)(((unsigned short)(unsigned char)SAVEFILE_PTR_HI << 8) |
                         (unsigned char)SAVEFILE_PTR_LO);
    nes_ram[ptr + CUR_ROOM_ID] = (uint8_t)(flags | 0x20u);
}

void room_go_to_next_mode(void)
{
    /* drain at room_mode_runtime.c:255-258. */
    MODE_VALUE = (uint8_t)((unsigned char)MODE_VALUE + 1u);
    (void)room_end_game_mode();
}

void room_copy_column_to_tilebuf(void)
{
    /* drain at room_transfer_runtime.c:6-32. NES CopyColumnToTilebuf.
     * Reads PlayArea ($6530 + col*$16); writes 22 column tiles into
     * the transfer-buffer at TRANSFER_BUF_POS. Stashes src + dst
     * pointers in SAVEFILE_PTR_LO/HI for the next pass. */
    #define ROOM_PLAY_AREA_BASE 0x6530u
    #define ROOM_COL_STRIDE     0x16u

    SAVEFILE_PTR_LO = 0x1Au;
    SAVEFILE_PTR_HI = 0x65u;

    const unsigned char col =
        (unsigned char)((unsigned char)CUR_ROOM_FLAGS_PTR - 1u);
    const unsigned char buf = (unsigned char)TRANSFER_BUF_POS;

    RAM(0x0302u + buf) = 33u;             /* TRANSFER_BUF_BYTE(buf) */
    RAM(0x0303u + buf) = col;

    unsigned short src =
        (unsigned short)(ROOM_PLAY_AREA_BASE +
                         (unsigned short)col * ROOM_COL_STRIDE);

    RAM(0x0304u + buf) = 0x96u;
    RAM(0x031Bu + buf) = 0xFFu;

    unsigned char dst = buf;
    for (unsigned char i = 0u; i < 22u; ++i) {
        RAM(0x0305u + dst) = nes_ram[src + i];
        ++dst;
    }
    src = (unsigned short)(src + 22u);
    dst = (unsigned char)(dst + 3u);
    TRANSFER_BUF_POS = dst;

    SAVEFILE_PTR_LO = (uint8_t)(src & 0xFFu);
    SAVEFILE_PTR_HI = (uint8_t)((src >> 8) & 0xFFu);

    #undef ROOM_PLAY_AREA_BASE
    #undef ROOM_COL_STRIDE
}
