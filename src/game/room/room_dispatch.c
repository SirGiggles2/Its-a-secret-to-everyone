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
#include "combat_state.h"      /* LINK_DAMAGE_DISABLE_FLAG, LINK_ACTION_TIMER,
                                * LINK_STUN_TIMER */
#include "link_state.h"        /* LINK_HALT_FLAG */
#include "item_state.h"        /* ITEM_SFX_SECONDARY */
#include "core/core_dispatch.h" /* core_get_opposite_dir,
                                  * core_compare_hearts_to_containers */
#include "hud/hud_dispatch.h"   /* hud_world_change_rupees */
#include "world/progress_dispatch.h" /* progress_update_world_curtain_effect */
#include "item_state.h"         /* LINK_PARTIAL_HEART, LINK_HEARTS, ITEM_SFX_PRIMARY,
                                 * SAVE_SLOT_INDEX */

/* Genesis VDP native primitive — display enable/disable (Reg 1 bit 6).
 * Forward decl from src/sgdk_adapter/render_adapter.c. */
extern void render_display_enable(unsigned char on);

/* Genesis ROM bank-window cache — Genesis-native asset cache primitive,
 * NOT NES MMC1 emulation. Forward decl from
 * src/sgdk_adapter/render_adapter.c. */
extern void render_bank_window_load(unsigned char bank);

/* Asm-bound data tables — NOT shims (not c_/z01_/z07_ prefixed).
 * MenuPalettesTransferBuf is RW state shared across item-pickup,
 * file-select, and palette-cue paths. SaveSlotToPaletteRowOffset
 * is read-only. Native code reads/writes the same backing memory
 * the transpile-asm path uses, ensuring NATIVE_ROOM=on/off paths
 * stay coherent. */
extern unsigned char MenuPalettesTransferBuf[];
extern const unsigned char SaveSlotToPaletteRowOffset[];

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

/* Z_07.asm LevelSongIds[10] (line 2977). */
static const unsigned char k_level_song_ids[10] = {
    0x01u, 0x40u, 0x40u, 0x40u, 0x40u,
    0x40u, 0x40u, 0x40u, 0x40u, 0x20u
};

void room_go_to_next_mode_reset_grid_offset(void)
{
    /* drain at room_mode_runtime.c:267-270. */
    room_go_to_next_mode();
    RAM(0x0394u) = 0u;
}

void room_go_to_next_mode_play_level_song(void)
{
    /* drain at room_mode_runtime.c:260-265. */
    const unsigned char level = (unsigned char)CUR_LEVEL;
    /* drain reads LevelSongIds[level] unbounded; CUR_LEVEL is
     * constrained to 0..9 by gameplay — table sized 10. */
    ITEM_SFX_SECONDARY = k_level_song_ids[level];
    room_go_to_next_mode();
    RAM(0x0394u) = 0u;
}

void room_go_to_next_mode_from_play(void)
{
    /* drain at room_mode_runtime.c:306-315. */
    MODE_VALUE = (uint8_t)((unsigned char)MODE_VALUE + 1u);
    SUBMODE_VALUE = 0u;
    ROOM_MODE_TIMER = 0u;
    RAM(0x000Fu) = 0u;
    LINK_ACTION_TIMER = 0u;
    RAM(0x00C0u) = 0u;
    RAM(0x00D3u) = 0u;
    LINK_STUN_TIMER = 0u;
}

/* roomrt_reverse_directions[4] (room_runtime.c:10). */
static const unsigned char k_room_reverse_directions[4] = {
    0x08u, 0x04u, 0x02u, 0x01u
};

/* roomrt_player_screen_edge_bounds[4] (room_runtime.c:11). */
static const unsigned char k_room_player_screen_edge_bounds[4] = {
    0x3Du, 0xDDu, 0x00u, 0xF0u
};

void room_check_screen_edge(void)
{
    /* drain at room_runtime.c:301-322. */
    if ((unsigned char)ROOM_INPUT_DIR == 0u) {
        return;
    }
    const unsigned int dir_info =
        core_get_opposite_dir((unsigned int)(unsigned char)ROOM_INPUT_DIR);
    const unsigned char dir_idx = (unsigned char)(dir_info >> 8);
    const unsigned char single_dir =
        k_room_reverse_directions[dir_idx & 3u];
    const unsigned char coord =
        ((single_dir & 0x0Cu) == 0u) ?
            (unsigned char)LINK_X :
            (unsigned char)LINK_Y;

    if (coord != k_room_player_screen_edge_bounds[dir_idx & 3u]) {
        return;
    }

    LINK_DIR = single_dir;
    room_go_to_next_mode_from_play();
}

void room_turn_off_all_video(void)
{
    /* drain Z_07.asm:1739 TurnOffAllVideo. NES asm path:
     *   moveq #0,D0
     *   jsr _ppu_write_1     ; PPUMASK=0 + Genesis VDP Reg 1 = $8134
     *   move.b D0,($00FE,A4) ; PPU_MASK shadow = 0
     *
     * Native equivalent: maintain shadow + disable Genesis VDP display.
     * Per debate 007 synthesis: Sonnet flagged that pure shadow write
     * is insufficient — without VDP Reg 1 disable, mode transitions
     * display stale VRAM (tearing). Both writes required. */
    RAM(NES_PPU_MASK_SHADOW) = 0u;
    render_display_enable(0u);
}

void room_world_fill_hearts(void)
{
    /* drain at room_object_runtime.c:31-48. NES WorldFillHearts.
     * Heart-fill animation tick: advance partial-heart by +6/tick;
     * roll over to next heart when full; stop at hearts=containers. */
    if ((unsigned char)ROOM_HEART_FILL_STATE == 0u) {
        return;
    }
    ROOM_SFX_MAIN = 16u;
    if ((unsigned char)LINK_PARTIAL_HEART >= 0xF8u) {
        LINK_PARTIAL_HEART = 0u;
        /* WORLD_TMP0 was set by caller (room_mode flow) to current
         * partial-heart filled-count; compare to containers. */
        if (core_compare_hearts_to_containers() == (unsigned char)RAM(0x0000u)) {
            LINK_PARTIAL_HEART = 0xFFu;
            RAM(0x052Eu) = 0u;             /* ROOM_SWORD_BLOCKED_FLAG */
            ROOM_HEART_FILL_STATE = 0u;
            RAM(0x00E0u) = 0u;             /* ROOM_PAUSED_FLAG */
            return;
        }
        LINK_HEARTS = (uint8_t)((unsigned char)LINK_HEARTS + 1u);
        return;
    }
    LINK_PARTIAL_HEART =
        (uint8_t)((unsigned char)LINK_PARTIAL_HEART + 6u);
}

void room_update_hearts_and_rupees(void)
{
    /* drain at room_mode_runtime.c:323-327. NES UpdateHeartsAndRupees:
     *   c_switch_bank(5);          // MMC1 PRG bank switch — Genesis no-op
     *   c_world_fill_hearts();
     *   c_world_change_rupees();
     *
     * Per debate 007 synthesis option A: drop MMC1 SwitchBank entirely
     * (Genesis flat M68K address space, no mapper). */
    room_world_fill_hearts();
    hud_world_change_rupees();
}

/* Q2 (second quest) BlockAttrsB room patches — Z_06 + room_patches.inc.
 * 8 specific RAM writes overlaying SRAM-loaded room data after bank load. */
static const unsigned char k_lblock_attrs_b_q2_offsets[8] = {
    0x0Eu, 0x0Fu, 0x22u, 0x34u, 0x3Cu, 0x45u, 0x74u, 0x8Bu
};
static const unsigned char k_lblock_attrs_b_q2_values[8] = {
    0x7Bu, 0x83u, 0x84u, 0x0Fu, 0x0Bu, 0x12u, 0x7Au, 0x2Fu
};

/* Q2 UW level-info replacement blobs — z_06.asm /
 * src/data/room_patches.inc. Per-level (1..9) replacement bytes
 * applied at SRAM($6BA7..). Sizes from
 * LevelInfoUWQ2ReplacementSizes[]. */
static const unsigned char k_q2_uw_replacements_1[57] = {
    0xC9u, 0xACu, 0x89u, 0xB7u, 0x00u, 0xE0u, 0x77u, 0x08u,
    0xFFu, 0x06u, 0x01u, 0x28u, 0xFFu, 0xFFu, 0xFFu, 0xFFu,
    0xFFu, 0xFFu, 0xFFu, 0xFFu, 0xFFu, 0x07u, 0x00u, 0x00u,
    0x00u, 0x00u, 0x00u, 0x00u, 0x00u, 0xFFu, 0xDBu, 0x00u,
    0x00u, 0x00u, 0x00u, 0x00u, 0x00u, 0x00u, 0x20u, 0x65u,
    0x42u, 0xFFu, 0x20u, 0x85u, 0x02u, 0xFFu, 0xFBu, 0x20u,
    0xA5u, 0x02u, 0xFFu, 0x67u, 0x20u, 0xC5u, 0x42u, 0xFFu, 0xFFu
};
static const unsigned char k_q2_uw_replacements_2[55] = {
    0xC9u, 0xACu, 0x89u, 0x87u, 0x05u, 0x00u, 0x75u, 0x20u,
    0xFFu, 0x06u, 0x03u, 0x56u, 0xFFu, 0xFFu, 0xFFu, 0xFFu,
    0xFFu, 0xFFu, 0xFFu, 0xFFu, 0xFFu, 0x30u, 0x00u, 0x00u,
    0x00u, 0x00u, 0x00u, 0x30u, 0x00u, 0x00u, 0x00u, 0x00u,
    0x7Fu, 0x03u, 0x00u, 0x00u, 0x00u, 0x00u, 0x20u, 0x67u,
    0x01u, 0xFBu, 0x20u, 0x82u, 0x01u, 0xFFu, 0x20u, 0x87u,
    0xC3u, 0xFFu, 0x20u, 0xC8u, 0x01u, 0xFFu, 0xFFu
};
static const unsigned char k_q2_uw_replacements_3[61] = {
    0xC9u, 0xACu, 0x89u, 0x37u, 0x0Du, 0xC8u, 0x79u, 0x1Bu,
    0xFFu, 0x06u, 0x02u, 0x09u, 0x0Bu, 0xFFu, 0xFFu, 0xFFu,
    0xFFu, 0xFFu, 0xFFu, 0xFFu, 0xFFu, 0x2Bu, 0x00u, 0x00u,
    0x00u, 0x00u, 0x00u, 0x00u, 0x7Fu, 0xECu, 0x7Fu, 0x00u,
    0x00u, 0x00u, 0x00u, 0x00u, 0x00u, 0x00u, 0x20u, 0x64u,
    0x03u, 0xFBu, 0xFFu, 0xFBu, 0x20u, 0x84u, 0x03u, 0xFFu,
    0x67u, 0xFFu, 0x20u, 0xA4u, 0x43u, 0xFFu, 0x20u, 0xC4u,
    0x03u, 0xFFu, 0x24u, 0xFFu, 0xFFu
};
static const unsigned char k_q2_uw_replacements_4[57] = {
    0xC9u, 0xACu, 0x89u, 0x86u, 0x06u, 0x10u, 0x72u, 0x00u,
    0xFFu, 0x06u, 0x05u, 0x21u, 0x58u, 0x7Au, 0xFFu, 0xFFu,
    0xFFu, 0xFFu, 0xFFu, 0xFFu, 0xFFu, 0x10u, 0x00u, 0x00u,
    0x00u, 0x00u, 0x00u, 0x00u, 0xCFu, 0xDBu, 0xF3u, 0x00u,
    0x00u, 0x00u, 0x00u, 0x00u, 0x00u, 0x00u, 0x20u, 0x64u,
    0x43u, 0xFFu, 0x20u, 0x85u, 0x02u, 0xFBu, 0xFFu, 0x20u,
    0xA4u, 0x02u, 0xFFu, 0x67u, 0x20u, 0xC4u, 0x43u, 0xFFu, 0xFFu
};
static const unsigned char k_q2_uw_replacements_5[67] = {
    0xC9u, 0xACu, 0x89u, 0x87u, 0x0Au, 0xB0u, 0x7Du, 0x4Fu,
    0xFFu, 0x06u, 0x04u, 0x0Fu, 0x6Au, 0x7Fu, 0xFFu, 0xFFu,
    0xFFu, 0xFFu, 0xFFu, 0xFFu, 0xFFu, 0x5Fu, 0x00u, 0x00u,
    0x00u, 0x00u, 0x00u, 0x00u, 0xFFu, 0xFFu, 0xE7u, 0x7Eu,
    0x00u, 0x00u, 0x00u, 0x00u, 0x00u, 0x00u, 0x20u, 0x64u,
    0x04u, 0xFFu, 0xFFu, 0xFFu, 0xFBu, 0x20u, 0x84u, 0x04u,
    0xFFu, 0xFFu, 0x67u, 0xFFu, 0x20u, 0xA4u, 0x04u, 0xFFu,
    0xFFu, 0xFBu, 0xFFu, 0x20u, 0xC4u, 0x04u, 0xFFu, 0xFFu,
    0xFFu, 0x67u, 0xFFu
};
static const unsigned char k_q2_uw_replacements_6[64] = {
    0x49u, 0x79u, 0x89u, 0x56u, 0x04u, 0x00u, 0x74u, 0x16u,
    0xFFu, 0x06u, 0x06u, 0x03u, 0x73u, 0x46u, 0xFFu, 0xFFu,
    0xFFu, 0xFFu, 0xFFu, 0xFFu, 0xFFu, 0x26u, 0x00u, 0x00u,
    0x00u, 0x00u, 0x00u, 0x04u, 0x0Cu, 0x7Eu, 0xFFu, 0x80u,
    0xF0u, 0x00u, 0x00u, 0x00u, 0x00u, 0x00u, 0x20u, 0x65u,
    0x03u, 0xFBu, 0xFFu, 0x67u, 0x20u, 0x68u, 0xC2u, 0xFFu,
    0x20u, 0x86u, 0xC3u, 0xFFu, 0x20u, 0x85u, 0x83u, 0xFFu,
    0xFFu, 0x67u, 0x20u, 0xA3u, 0x02u, 0xFBu, 0xFFu, 0xFFu
};
static const unsigned char k_q2_uw_replacements_7[63] = {
    0xC9u, 0xACu, 0x89u, 0x79u, 0x0Cu, 0xC0u, 0x7Fu, 0x2Du,
    0x7Fu, 0x07u, 0x08u, 0x02u, 0x03u, 0x04u, 0x05u, 0x20u,
    0x21u, 0x26u, 0x2Bu, 0x2Cu, 0xFFu, 0x3Du, 0x00u, 0x00u,
    0x00u, 0x00u, 0xFEu, 0xFEu, 0x82u, 0x82u, 0x82u, 0xBEu,
    0x80u, 0xFFu, 0x00u, 0x00u, 0x00u, 0x00u, 0x20u, 0x62u,
    0xC3u, 0xFFu, 0x20u, 0x63u, 0xC3u, 0xFFu, 0x20u, 0x64u,
    0x45u, 0x67u, 0x20u, 0x69u, 0xC4u, 0xFFu, 0x20u, 0x87u,
    0xC2u, 0xFFu, 0x20u, 0xC2u, 0x46u, 0x67u, 0xFFu
};
static const unsigned char k_q2_uw_replacements_8[67] = {
    0xC9u, 0xACu, 0x89u, 0x57u, 0x0Cu, 0xC0u, 0x79u, 0x1Bu,
    0x7Fu, 0x07u, 0x07u, 0x27u, 0x30u, 0x37u, 0x60u, 0x67u,
    0x70u, 0xFFu, 0xFFu, 0xFFu, 0xFFu, 0x1Cu, 0x00u, 0x00u,
    0x00u, 0x00u, 0x01u, 0x01u, 0x7Du, 0x5Du, 0x5Du, 0x41u,
    0x7Fu, 0x00u, 0x00u, 0x00u, 0x00u, 0x00u, 0x20u, 0x64u,
    0x45u, 0xFBu, 0x20u, 0x84u, 0x05u, 0xFFu, 0xFBu, 0xFBu,
    0x24u, 0xFFu, 0x20u, 0xA4u, 0x43u, 0xFFu, 0x20u, 0xA8u,
    0x01u, 0xFFu, 0x20u, 0xC2u, 0x46u, 0xFBu, 0x20u, 0xC8u,
    0x01u, 0xFFu, 0xFFu
};
static const unsigned char k_q2_uw_replacements_9[74] = {
    0xC9u, 0xACu, 0x89u, 0xB6u, 0x04u, 0x00u, 0x74u, 0x07u,
    0x7Fu, 0x07u, 0x09u, 0x71u, 0x72u, 0x75u, 0x76u, 0x77u,
    0xFFu, 0xFFu, 0xFFu, 0xFFu, 0xFFu, 0x17u, 0x00u, 0x00u,
    0x00u, 0x00u, 0xCCu, 0xDEu, 0x76u, 0x7Fu, 0x7Fu, 0x76u,
    0xDEu, 0xCCu, 0x00u, 0x00u, 0x00u, 0x00u, 0x20u, 0x62u,
    0x48u, 0xFFu, 0x20u, 0x64u, 0x44u, 0xFBu, 0x20u, 0x83u,
    0x46u, 0xFBu, 0x20u, 0x84u, 0x44u, 0xFFu, 0x20u, 0xA2u,
    0x08u, 0xFFu, 0xFFu, 0xFBu, 0xFFu, 0xFFu, 0xFBu, 0xFFu,
    0xFFu, 0x20u, 0xC3u, 0x46u, 0x67u, 0x20u, 0xC5u, 0x42u,
    0xFFu, 0xFFu
};

static const unsigned char *const k_q2_uw_blobs[9] = {
    k_q2_uw_replacements_1, k_q2_uw_replacements_2,
    k_q2_uw_replacements_3, k_q2_uw_replacements_4,
    k_q2_uw_replacements_5, k_q2_uw_replacements_6,
    k_q2_uw_replacements_7, k_q2_uw_replacements_8,
    k_q2_uw_replacements_9
};

static const unsigned char k_q2_uw_sizes[9] = {
    0x39u, 0x37u, 0x3Du, 0x39u, 0x43u, 0x40u, 0x3Fu, 0x43u, 0x4Au
};

/* Q2 path: patch_q2_rooms (room_load_runtime.c:284-297). */
static void room_patch_q2_rooms(void)
{
    for (signed char i = 7; i >= 0; --i) {
        const unsigned char off = k_lblock_attrs_b_q2_offsets[i];
        const unsigned char val = k_lblock_attrs_b_q2_values[i];
        nes_ram[NES_SRAM_BASE + 0x08FEu + off] = val;
    }
    nes_ram[NES_SRAM_BASE + 0x0A09u] = 123u;
    nes_ram[NES_SRAM_BASE + 0x0A3Au] = 123u;
    nes_ram[NES_SRAM_BASE + 0x0A72u] = 90u;
    nes_ram[NES_SRAM_BASE + 0x08BAu] = 114u;
    nes_ram[NES_SRAM_BASE + 0x08F2u] = 114u;
    nes_ram[NES_SRAM_BASE + 0x0B3Au] = 1u;
    nes_ram[NES_SRAM_BASE + 0x0B72u] = 0u;
}

void room_update_mode2_load(void)
{
    /* drain at room_mode_runtime.c:317-321 + room_load_runtime.c:299-325.
     * NES UpdateMode2_Load: turn_off_all_video; mode2_load_full;
     * go_to_next_mode. */
    room_turn_off_all_video();

    /* mode2_load_full inlined per debate 007 option D: bank load is
     * Genesis-native (render_bank_window_load), Q1 returns early on
     * quest=0, Q2 level=0 patches inline, Q2 level>0 STAGE-1 stub. */
    render_bank_window_load(6u);

    const unsigned char profile = (unsigned char)SAVE_SLOT_INDEX;
    const unsigned char quest = (unsigned char)SAVE_SLOT_QUEST(profile);
    if (quest == 0u) {
        /* Q1 (first quest) — no patches needed. */
    } else {
        const unsigned char level = (unsigned char)CUR_LEVEL;
        if (level == 0u) {
            /* Q2 overworld — Block-attr patches. */
            room_patch_q2_rooms();
        } else {
            /* Q2 underworld level — apply LevelInfoUWQ2Replacements
             * blob to SRAM($6BA7..). Drain at room_load_runtime.c:317-324
             * iterated count..0 inclusive. Direct array read replaces
             * RAM($00)/RAM($01) indirect pointer load. */
            const unsigned char idx = (unsigned char)(level - 1u);
            const unsigned char *blob = k_q2_uw_blobs[idx & 0x0Fu];
            const unsigned char count = k_q2_uw_sizes[idx & 0x0Fu];
            for (signed char i = (signed char)count; i >= 0; --i) {
                nes_ram[NES_SRAM_BASE + 0x0BA7u + (unsigned char)i] =
                    blob[(unsigned char)i];
            }
        }
    }

    room_go_to_next_mode();
}

void room_update_mode3_unfurl(void)
{
    /* drain at room_mode_runtime.c:295-304. NES UpdateMode3Unfurl:
     *   c_update_world_curtain_effect();
     *   if (CURTAIN_LEFT_COL != 0) return;
     *   c_set_mmc1_control(15);    // MMC1 ctrl reg — Genesis no-op
     *   if (ROOM_LINK_CELLAR_FLAG) go_to_next_mode_reset_grid_offset;
     *   else                       go_to_next_mode_play_level_song;
     *
     * Per debate 007 synthesis option A: drop MMC1 SetMMC1Control. */
    progress_update_world_curtain_effect();
    if ((unsigned char)CURTAIN_LEFT_COL != 0u) {
        return;
    }
    if ((unsigned char)ROOM_LINK_CELLAR_FLAG != 0u) {
        room_go_to_next_mode_reset_grid_offset();
    } else {
        room_go_to_next_mode_play_level_song();
    }
}

void room_patch_and_cue_level_palettes_transfer(void)
{
    /* drain at room_mode_runtime.c:272-279. */
    const unsigned char slot = (unsigned char)SAVE_SLOT_INDEX;
    const unsigned char row_off = SaveSlotToPaletteRowOffset[slot & 3u];
    const unsigned char color = MenuPalettesTransferBuf[20u + row_off];
    nes_ram[NES_SRAM_BASE + 0x0B92u] = color;
    ROOM_TRANSFER_BUF_SELECT = 24u;
    SUBMODE_VALUE = (uint8_t)((unsigned char)SUBMODE_VALUE + 1u);
}

void room_init_mode3_sub1(void)
{
    /* drain at room_mode_runtime.c:281-293. */
    unsigned char room_id;
    if ((unsigned char)CUR_LEVEL != 0u ||
        (unsigned char)ROOM_ID_ALT == 0xFFu) {
        room_id = nes_ram[NES_SRAM_BASE + 0x0BADu];
    } else {
        room_id = (unsigned char)ROOM_ID_ALT;
    }
    CUR_ROOM_ID = room_id;
    if (room_id == (unsigned char)ROOM_ID_ALT) {
        ROOM_ID_ALT = 0xFFu;
    }
    room_patch_and_cue_level_palettes_transfer();
}

void room_reset_inv_obj_state(void)
{
    /* drain at room_load_runtime.c:25-30. */
    RAM(0x0064u) = 0u;                    /* ROOM_INV_OBJ_ACTIVE */
    for (signed char i = 5; i >= 0; --i) {
        RAM(0x00B9u + (unsigned char)i) = 0u;  /* ROOM_INV_OBJ_STATE */
    }
}

/* roomrt_level_masks[8] — power-of-2 single-bit masks. Local bake
 * (mirrors progress_dispatch's k_level_masks). */
static const unsigned char k_room_level_masks[8] = {
    0x01u, 0x02u, 0x04u, 0x08u, 0x10u, 0x20u, 0x40u, 0x80u
};

static unsigned char room_has_item_by_level(unsigned char base_offset)
{
    /* drain at room_runtime.c:24-37. */
    const unsigned char level = (unsigned char)CUR_LEVEL;
    if (level == 0u) {
        return 0u;
    }
    const unsigned char idx = (unsigned char)(level - 1u);
    unsigned char offset = base_offset;
    if (idx >= 8u) {
        offset = (unsigned char)(offset + 2u);
    }
    const unsigned char bit_idx = (unsigned char)(idx & 7u);
    return (unsigned char)(RAM(0x0657u + offset) &
                           k_room_level_masks[bit_idx]);
}

unsigned char room_has_compass(void)
{
    /* drain at room_runtime.c:39-41. */
    return room_has_item_by_level(16u);
}

unsigned char room_has_map(void)
{
    /* drain at room_runtime.c:43-45. */
    return room_has_item_by_level(17u);
}

void room_update_triforce_position_marker(void)
{
    /* drain at Z_07.asm:1821-1834. */
    if ((unsigned char)CUR_LEVEL == 0u) {
        return;
    }
    /* SwitchBank(5) — Genesis no-op per debate 007. */
    if (room_has_compass() == 0u) {
        return;
    }
    progress_update_position_marker(
        nes_ram[NES_SRAM_BASE + 0x0BAEu], 4u);
}
