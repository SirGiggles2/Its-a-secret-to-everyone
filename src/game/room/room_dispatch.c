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
#include "world/progress_dispatch.h" /* progress_update_world_curtain_effect,
                                      * progress_reset_room_tile_obj_info */
#include "combat/collision_dispatch.h" /* collision_get_collidable_tile_still */
#include "item_state.h"         /* LINK_PARTIAL_HEART, LINK_HEARTS, ITEM_SFX_PRIMARY,
                                 * SAVE_SLOT_INDEX */
#include "save_state.h"         /* CONTINUE_COUNT */
#include "enemy_state.h"        /* SAVE_SLOT_QUEST */

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

/* roomld_obj_room_bounds[10]: 5 OW bounds + 5 UW bounds.
 * NES room_load_runtime.c:8-11. */
static const unsigned char k_obj_room_bounds[10] = {
    0x11u, 0xE0u, 0x4Eu, 0xCDu, 0x89u,
    0x21u, 0xD0u, 0x5Eu, 0xBDu, 0x78u
};

void room_setup_obj_room_bounds(void)
{
    /* drain at room_load_runtime.c:58-67. */
    unsigned char base = 5u;
    if ((unsigned char)CUR_LEVEL == 0u) {
        base = 0u;
        RAM(0x0053u) = 0u;  /* ROOM_IN_DOORWAY_FLAG */
    }
    for (unsigned char i = 0u; i < 5u; ++i) {
        RAM(0x0346u + i) = k_obj_room_bounds[base + i];
    }
}

/* roomld_sprite0_descriptor[4] (room_load_runtime.c:6). */
static const unsigned char k_sprite0_descriptor[4] = {
    0x27u, 0x61u, 0x20u, 0x58u
};

void room_write_and_enable_sprite0(void)
{
    /* drain at room_load_runtime.c:13-18. */
    RAM(0x00E3u) = 1u;  /* ROOM_SPRITE0_ENABLED */
    for (signed char i = 3; i >= 0; --i) {
        RAM(0x0200u + (unsigned char)i) =
            k_sprite0_descriptor[(unsigned char)i];
    }
}

void room_put_link_behind_background(void)
{
    /* drain at room_load_runtime.c:20-23. */
    RAM(0x024Au) = (uint8_t)(RAM(0x024Au) | 0x20u);
    RAM(0x024Eu) = (uint8_t)(RAM(0x024Eu) | 0x20u);
}

/* roomld_palette_to_nt_attr[4] (room_load_runtime.c:7). */
static const unsigned char k_palette_to_nt_attr[4] = {
    0x00u, 0x55u, 0xAAu, 0xFFu
};

void room_fill_play_area_attrs(unsigned int room_id)
{
    /* drain at room_load_runtime.c:32-56. */
    const unsigned char outer_sel =
        (unsigned char)(nes_ram[NES_SRAM_BASE + 0x087Eu + room_id] & 0x03u);
    const unsigned char outer_attr = k_palette_to_nt_attr[outer_sel];
    for (unsigned char d3 = 0u; d3 < 48u; ++d3) {
        RAM(0x0530u + d3) = outer_attr;
    }
    const unsigned char inner_sel =
        (unsigned char)(nes_ram[NES_SRAM_BASE + 0x08FEu + room_id] & 0x03u);
    const unsigned char inner_attr = k_palette_to_nt_attr[inner_sel];
    for (unsigned char d3 = 9u; d3 < 0x27u; ++d3) {
        const unsigned char mod = (unsigned char)(d3 & 0x07u);
        if (mod == 0u || mod == 7u) {
            continue;
        }
        if (d3 >= 0x21u) {
            const unsigned char cur = (unsigned char)RAM(0x0530u + d3);
            RAM(0x0530u + d3) =
                (uint8_t)((inner_attr & 0x0Fu) | (cur & 0xF0u));
        } else {
            RAM(0x0530u + d3) = inner_attr;
        }
    }
}

void room_init_link_speed(void)
{
    /* drain at room_load_runtime.c:69-81. */
    unsigned char speed = 96u;
    if ((unsigned char)CUR_LEVEL != 0u) {
        RAM(0x03BCu) = speed;  /* ROOM_LINK_SPEED */
        return;
    }
    const unsigned char tile = (unsigned char)RAM(0x049Eu);
    if (tile == 0x74u || tile == 0x75u) {
        speed = 48u;
        if ((unsigned char)RAM(0x03BCu) != 48u) {
            RAM(0x03A8u) = 0u;  /* ROOM_LINK_SPEED_FRAC */
        }
    }
    RAM(0x03BCu) = speed;
}

void room_init_mode10(void)
{
    /* drain at room_object_runtime.c:7-15. */
    (void)collision_get_collidable_tile_still(0u);
    if ((unsigned char)RAM(0x049Eu) == 0x24u) {  /* ROOM_COLLIDABLE_TILE */
        RAM(0x0619u) = 0u;                       /* ROOM_TRIFORCE_HOLD_FLAG */
        RAM(0x0603u) = 8u;                       /* ROOM_SFX_AUX */
        RAM(0x0412u) =
            (uint8_t)((unsigned char)LINK_Y + 0x10u);  /* ROOM_PUSH_TIMER */
    }
    ROOM_MODE_TIMER = (uint8_t)((unsigned char)ROOM_MODE_TIMER + 1u);
}

void room_end_prepare_mode(void)
{
    /* drain at room_object_runtime.c:50-58. */
    SUBMODE_VALUE = 0u;
    ROOM_MODE_TIMER = 0u;
    RAM(0x000Fu) = 0u;     /* COMBAT_PART_INDEX (ZP_TMPF) */
    LINK_ACTION_TIMER = 0u;
    RAM(0x00C0u) = 0u;     /* MON_SHOVE_DIR(0) */
    RAM(0x00D3u) = 0u;     /* MON_SHOVE_TIMER(0) */
    LINK_STUN_TIMER = 0u;
}

void room_setup_tile_object_ow(void)
{
    /* drain at room_object_runtime.c:17-29. */
    unsigned char type;
    if ((unsigned char)CUR_ROOM_ID == 0x3Fu ||
        (unsigned char)CUR_ROOM_ID == 0x55u) {
        type = 97u;
    } else {
        RAM(0x007Bu) = (unsigned char)RAM(0x052Cu);  /* X_SCRATCH = TILE_OBJ_1 */
        RAM(0x008Fu) = (unsigned char)RAM(0x052Du);  /* Y_SCRATCH = TILE_OBJ_2 */
        type = (unsigned char)RAM(0x052Bu);          /* TILE_OBJ_0 */
    }
    RAM(0x035Au) = type;     /* ROOM_OBJECT_SLOT_TYPE */
    progress_reset_room_tile_obj_info();
    RAM(0x00B7u) = 0u;        /* ROOM_OBJECT_INIT_DONE */
}

/* --------------------------------------------------------------- */
/* Mode-helper leaves — drain at room_mode_runtime.c.              */
/* --------------------------------------------------------------- */

void room_inc_submode(void)
{
    SUBMODE_VALUE = (uint8_t)((unsigned char)SUBMODE_VALUE + 1u);
}

void room_inc_2_submodes(void)
{
    SUBMODE_VALUE = (uint8_t)((unsigned char)SUBMODE_VALUE + 2u);
}

void room_init_mode_a_sub_a_go_to_mode4(void)
{
    /* room_mode_runtime.c:17-21. roomld_reset_inv_obj_state forwarder. */
    room_reset_inv_obj_state();
    SUBMODE_VALUE = 0u;
    MODE_VALUE = 4u;
}

void room_init_mode4_go_to_sub0(void)
{
    /* room_mode_runtime.c:23-26. */
    SUBMODE_VALUE = 0u;
    RAM(0x056Eu) = 0u;  /* ROOM_SCROLL_STATE */
}

void room_update_mode11_death_sub6(void)
{
    /* room_mode_runtime.c:28-31. */
    RAM(0x00FFu) = (uint8_t)((unsigned char)RAM(0x00FFu) & 0xFEu);
    room_inc_submode();
}

void room_reset_vscroll_lo(void)
{
    /* room_mode_runtime.c:33-36. */
    RAM(0x00E2u) = 0u;
    room_inc_submode();
}

void room_select_transfer_buf(unsigned int val)
{
    /* room_mode_runtime.c:38-41. */
    ROOM_TRANSFER_BUF_SELECT = (uint8_t)val;
    room_inc_submode();
}

void room_select_transfer_buf_and_inc_state(unsigned int val)
{
    /* room_mode_runtime.c:43-46. */
    ROOM_TRANSFER_BUF_SELECT = (uint8_t)val;
    RAM(0x00E1u) =
        (uint8_t)((unsigned char)RAM(0x00E1u) + 1u);  /* ROOM_STATE_INDEX */
}

void room_set_fade_cycle_and_advance_submode(unsigned int val)
{
    /* room_mode_runtime.c:65-68. */
    RAM(0x051Cu) = (uint8_t)val;  /* WORLD_FADE_STEP */
    room_inc_submode();
}

void room_switch_to_nt1(void)
{
    /* room_mode_runtime.c:129-131. */
    RAM(0x005Fu) = 1u;  /* ROOM_NAMETABLE_SELECT */
}

void room_update_menu_common2(void)
{
    room_select_transfer_buf_and_inc_state(72u);
}

void room_update_menu_common3(void)
{
    room_select_transfer_buf_and_inc_state(74u);
}

void room_update_menu_common4(void)
{
    room_select_transfer_buf_and_inc_state(76u);
}

void room_update_menu5_ow(void)
{
    room_select_transfer_buf_and_inc_state(92u);
}

void room_init_mode9_transfer_attrs(void)
{
    room_select_transfer_buf(38u);
}

void room_update_mode11_death_set_timer_inc_submode(unsigned int val)
{
    /* room_mode_runtime.c:133-136. */
    CURTAIN_TIMER = (uint8_t)val;
    room_inc_submode();
}

void room_update_mode11_death_sub4(void)
{
    room_select_transfer_buf(98u);
}

void room_update_mode11_death_sub5(void)
{
    /* room_mode_runtime.c:142-145. */
    RAM(0x00E3u) = 0u;  /* ROOM_SPRITE0_ENABLED */
    room_select_transfer_buf(94u);
}

void room_update_mode11_death_sub9(void)
{
    /* room_mode_runtime.c:147-151. */
    ROOM_TRANSFER_BUF_SELECT = 44u;
    RAM(0x00E5u) = 15u;  /* ROOM_MENU_SCROLL_TIMER */
    room_update_mode11_death_set_timer_inc_submode(24u);
}

void room_start_filling_hearts(void)
{
    /* room_mode_runtime.c:157-160. */
    RAM(0x0064u) = 2u;  /* ROOM_INV_OBJ_ACTIVE */
    room_inc_submode();
}

void room_init_mode7_finish(void)
{
    /* room_mode_runtime.c:123-127. */
    CUR_ROOM_ID = (uint8_t)RAM(0x00ECu);  /* PREV_ROOM_ID */
    room_write_and_enable_sprite0();
    core_begin_update_mode();
}

/* room_object_runtime.c:60-62. NES DecSubmenuScroll. */
void room_dec_submenu_scroll(void)
{
    ROOM_MENU_SCROLL_POS = (unsigned char)(ROOM_MENU_SCROLL_POS - 1u);
}

/* room_transfer_runtime.c:34-60. NES CopyRowToTilebuf. */
void room_copy_row_to_tilebuf(void)
{
    const unsigned char row = ROOM_ROW_INDEX;

    unsigned short ptr = 0x6530u + row;
    SAVEFILE_PTR_LO = (unsigned char)(ptr & 0xFFu);
    SAVEFILE_PTR_HI = (unsigned char)((ptr >> 8) & 0xFFu);

    unsigned short vram = 0x20E0u;
    for (signed char r = (signed char)row; r >= 0; r--)
        vram += 0x20u;
    TRANSFER_BUF_BYTE(0) = (unsigned char)((vram >> 8) & 0xFFu);
    RAM(0x0303u) = (unsigned char)(vram & 0xFFu);

    RAM(0x0304u) = 32u;
    RAM(0x0325u) = 0xFFu;

    unsigned short s = 0x6530u + row;
    for (unsigned char i = 0u; i < 32u; i++) {
        RAM(0x0305u + i) = nes_ram[s];
        s += 0x16u;
    }

    TRANSFER_BUF_POS = 35u;
    SAVEFILE_PTR_LO = (unsigned char)(s & 0xFFu);
    SAVEFILE_PTR_HI = (unsigned char)((s >> 8) & 0xFFu);
}

/* room_transfer_runtime.c:62-76. NES Cycle9InDirection. */
unsigned int room_cycle9_in_direction(unsigned int d3_in)
{
    unsigned char d3 = (unsigned char)d3_in;
    const unsigned char dir = (unsigned char)(ROOM_CYCLE_DIR & 0x03u);
    if (dir == 0u)
        return d3;
    if (dir & 1u)
        d3++;
    else
        d3--;
    if (d3 == 0xFFu)
        d3 = 8u;
    else if (d3 == 9u)
        d3 = 0u;
    return d3;
}

/* room_transfer_runtime.c:78-90. NES CopyColumnOrRowToTilebuf. */
void room_copy_column_or_row_to_tilebuf(void)
{
    const unsigned char row = ROOM_ROW_INDEX;
    if (row < 0x16u) {
        if (row == ROOM_LAST_ROW_INDEX)
            return;
        ROOM_LAST_ROW_INDEX = row;
        room_copy_row_to_tilebuf();
        return;
    }
    if (CUR_ROOM_FLAGS_PTR == 0u || CUR_ROOM_FLAGS_PTR >= 0x21u)
        return;
    room_copy_column_to_tilebuf();
}

/* room_transfer_runtime.c:92-95. NES FetchTileMapAddr. */
void room_fetch_tile_map_addr(void)
{
    SAVEFILE_PTR_LO = 48u;
    SAVEFILE_PTR_HI = 101u;
}

/* room_transfer_runtime.c:97-108. NES CopyPlayAreaAttrsHalf. */
void room_copy_play_area_attrs_half(unsigned int ppu_hi,
                                    unsigned int ppu_lo,
                                    unsigned int end_off)
{
    unsigned char src = (unsigned char)end_off;
    TRANSFER_BUF_BYTE(0) = (unsigned char)ppu_hi;
    TRANSFER_BUF_BYTE(1) = (unsigned char)ppu_lo;
    TRANSFER_BUF_BYTE(2) = 24u;
    TRANSFER_BUF_BYTE(27) = 0xFFu;
    for (unsigned char dst = 24u; dst > 0u; dst--) {
        TRANSFER_BUF_BYTE((unsigned char)(2u + dst)) = ROOM_PALETTE_ATTR(src);
        src--;
    }
}

/* room_player_runtime.c:4-12. NES GetPlayerCoordsForDirection. */
void room_player_get_coords_for_direction(unsigned int dir)
{
    if ((unsigned char)dir & 0x03u) {
        WORLD_TMP0 = LINK_Y;
        WORLD_TMP1 = LINK_X;
    } else {
        WORLD_TMP0 = LINK_X;
        WORLD_TMP1 = LINK_Y;
    }
}

/* room_player_runtime.c:14-22. NES IsDistanceSafeToSpawn. */
unsigned int room_player_is_distance_safe_to_spawn(unsigned int slot)
{
    const unsigned char dx =
        core_abs((unsigned char)(LINK_X - OBJ_X((unsigned char)slot)));
    if (dx < 0x22u) {
        const unsigned char dy =
            core_abs((unsigned char)(LINK_Y - OBJ_Y((unsigned char)slot)));
        if (dy < 0x22u)
            return CARRY_SET;
    }
    return 0u;
}

/* room_player_runtime.c:24-26. NES SetMovingDirAndSwitchToPlayerSlot. */
void room_player_set_moving_dir_and_switch_to_player_slot(unsigned int dir)
{
    COMBAT_PART_INDEX = (unsigned char)dir;
}

/* room_player_runtime.c:28-43. NES LinkModifyDirInDoorway. */
void room_player_link_modify_dir_in_doorway(void)
{
    if (ROOM_IN_DOORWAY_FLAG == 0u)
        return;
    if (ROOM_INPUT_DIR == 0u)
        return;
    if (LINK_DIR & ROOM_INPUT_DIR) {
        ROOM_INPUT_DIR = LINK_DIR;
        return;
    }
    WORLD_TMP0 = (unsigned char)core_get_opposite_dir(LINK_DIR);
    if (WORLD_TMP0 & ROOM_INPUT_DIR) {
        ROOM_INPUT_DIR = WORLD_TMP0;
        return;
    }
    ROOM_INPUT_DIR = LINK_DIR;
}

/* room_runtime.c:47-59. NES CalcOpenDoorwayMask. */
void room_calc_open_doorway_mask(unsigned int attr, unsigned int dir_idx)
{
    unsigned char is_open;
    if (attr < 4u) {
        is_open = 1u;
    } else {
        const unsigned char flags = room_get_room_flags();
        is_open = (flags & k_room_level_masks[dir_idx & 7u]) ? 1u : 0u;
    }
    unsigned char mask = ROOM_DOOR_MASK_ACC;
    mask = (unsigned char)(((unsigned char)(mask << 1) | is_open) & 0x0Fu);
    ROOM_DOOR_MASK_ACC = mask;
}

/* room_runtime.c:61-69. NES AddDoorFlags. */
void room_add_door_flags(void)
{
    const unsigned char flags = room_get_room_flags();
    for (signed char d = 3; d >= 0; d--) {
        const unsigned char masked =
            (unsigned char)(flags & k_room_level_masks[(unsigned char)d]);
        if (masked)
            CUR_OPENED_DOORS = (unsigned char)(CUR_OPENED_DOORS | masked);
    }
}

/* room_runtime.c:84-89. NES SetDoorFlag. */
void room_set_door_flag(unsigned int dir_idx)
{
    unsigned char flags = room_get_room_flags();
    const unsigned short ptr =
        (unsigned short)(((unsigned short)SAVEFILE_PTR_HI << 8) | SAVEFILE_PTR_LO);
    flags = (unsigned char)(flags | k_room_level_masks[dir_idx & 7u]);
    nes_ram[ptr + CUR_ROOM_ID] = flags;
}

/* room_runtime.c:91-100. NES ResetDoorFlag. */
void room_reset_door_flag(unsigned int dir_idx)
{
    (void)room_get_room_flags();
    const unsigned short ptr =
        (unsigned short)(((unsigned short)SAVEFILE_PTR_HI << 8) | SAVEFILE_PTR_LO);
    const unsigned char mask =
        (unsigned char)(k_room_level_masks[dir_idx & 7u] ^ 0xFFu);
    const unsigned char flags = nes_ram[ptr + CUR_ROOM_ID];
    nes_ram[ptr + CUR_ROOM_ID] = (unsigned char)(flags & mask);
}

/* room_runtime.c:125-130. NES SetEnteringDoorway. */
void room_set_entering_doorway(void)
{
    const unsigned char scroll_dir = LINK_DIR;  /* ROOM_SCROLL_DIR == LINK_DIR */
    const unsigned char a = (unsigned char)((scroll_dir >> 1) & 0x05u);
    const unsigned char b = (unsigned char)((scroll_dir << 1) & 0x0Au);
    CUR_OPENED_DOORS = (unsigned char)(a | b);
}

/* room_runtime.c:132-155. NES SaveKillCountOW. */
void room_save_kill_count_ow(unsigned int slot)
{
    const unsigned char flags = room_get_room_flags();
    const unsigned char kill_count = (unsigned char)(flags & 7u);
    WORLD_TMP2 = kill_count;
    const unsigned short ptr =
        (unsigned short)(((unsigned short)SAVEFILE_PTR_HI << 8) | SAVEFILE_PTR_LO);
    const unsigned char cell =
        (unsigned char)(nes_ram[ptr + (unsigned char)slot] & 0xF8u);
    nes_ram[ptr + (unsigned char)slot] = cell;
    const unsigned char cur_count = ROOM_OW_CUR_KILL_TOTAL;
    const unsigned char max_count = ROOM_OW_KILL_COUNT;
    unsigned char new_kill;
    if (cur_count >= max_count) {
        new_kill = 7u;
    } else {
        new_kill = (unsigned char)((cur_count & 7u) + kill_count);
        if (new_kill >= 7u)
            new_kill = 7u;
    }
    nes_ram[ptr + (unsigned char)slot] = (unsigned char)(cell | new_kill);
}

/* room_runtime.c:157-160. NES TriggerOpenDoor. */
void room_trigger_open_door(unsigned int val)
{
    ROOM_OPEN_DOOR_ARG = (unsigned char)val;
    ROOM_OPEN_DOOR_TIMER = 6u;
}

/* room_runtime.c:162-164. NES TouchDoorWall. */
void room_touch_door_wall(void)
{
    ROOM_TOUCH_BLOCK_FLAG = 0xFFu;
}

/* room_runtime.c:166. NES TouchDoorOpen — empty body. */
void room_touch_door_open(void) {}

/* room_runtime.c:168. NES WieldNothing — empty body. */
void room_wield_nothing(void) {}

/* room_runtime.c:170-172. NES MaskCurPpuMaskGrayscale. */
void room_mask_cur_ppu_mask_grayscale(void)
{
    CUR_INV_TILE = (unsigned char)(CUR_INV_TILE & 0xFEu);
}

/* room_runtime.c:174-176. NES BlockAtWall. */
void room_block_at_wall(void)
{
    room_touch_door_wall();
}

/* room_runtime.c:178-180. NES CheckSecretTriggerNone. */
unsigned int room_check_secret_trigger_none(void) { return 0u; }

/* room_runtime.c:182-185. NES TriggerShutters. */
unsigned int room_trigger_shutters(void)
{
    ROOM_SHUTTER_TRIGGERED = 1u;
    return CARRY_SET;
}

/* room_runtime.c:187-189. NES ReturnFalse. */
unsigned int room_return_false(void) { return 0u; }

/* room_runtime.c:191-195. NES CheckSecretTriggerAllDead. */
unsigned int room_check_secret_trigger_all_dead(void)
{
    if (ROOM_MONSTER_ALL_DEAD != 0u)
        return room_trigger_shutters();
    return 0u;
}

/* room_runtime.c:197-201. NES CheckSecretTriggerLastBoss. */
unsigned int room_check_secret_trigger_last_boss(void)
{
    if (ROOM_BOSS_SECRET_FLAG == 0u)
        return 0u;
    return room_trigger_shutters();
}

/* room_runtime.c:203-207. NES CheckSecretTriggerMoneyOrLife. */
unsigned int room_check_secret_trigger_money_or_life(void)
{
    if (ROOM_OBJ_TYPE(0) != 0u)
        return 0u;
    return room_trigger_shutters();
}

/* room_runtime.c:209-213. NES CheckSecretTriggerBlockDoor. */
unsigned int room_check_secret_trigger_block_door(void)
{
    if (ROOM_BLOCK_SECRET_FLAG == 0u)
        return 0u;
    return room_trigger_shutters();
}

/* room_runtime.c:215-230. NES CheckSecretTriggerRingleader. */
unsigned int room_check_secret_trigger_ringleader(void)
{
    const unsigned char first = ROOM_OBJ_TYPE(0);
    if (first != 0u && first < 0x53u)
        return 0u;
    for (signed char i = (signed char)ROOM_MAX_MONSTER_SLOT; i >= 0; i--) {
        const unsigned char slot = (unsigned char)i;
        const unsigned char obj = ROOM_OBJ_TYPE(slot);
        if (obj == 0u || obj >= 0x53u)
            continue;
        if (ROOM_OBJ_STUN_TIMER(slot) != 0u)
            continue;
        ROOM_OBJ_STUN_TIMER(slot) = 16u;
    }
    return CARRY_SET;
}

/* room_runtime.c:232-236. NES TouchDoorBombable. */
void room_touch_door_bombable(void)
{
    if (ROOM_TOUCH_DOOR_BITS & CUR_OPENED_DOORS)
        return;
    room_touch_door_wall();
}

/* room_runtime.c:238-241. NES BlockUntilTime. */
void room_block_until_time(void)
{
    if (CURTAIN_TIMER != 0u)
        room_block_at_wall();
}

/* room_runtime.c:243-251. NES TouchDoorFalse. */
unsigned int room_touch_door_false(void)
{
    const unsigned char timer = CURTAIN_TIMER;
    if (timer == 1u)
        return CARRY_SET;
    if (timer == 0u)
        CURTAIN_TIMER = 24u;
    room_touch_door_wall();
    return 0u;
}

/* room_runtime.c:253-269. NES TouchDoorShutter. */
void room_touch_door_shutter(void)
{
    if (ROOM_OPEN_DOOR_TIMER != 0u) {
        room_touch_door_wall();
        return;
    }
    const unsigned char door_bits =
        (unsigned char)(ROOM_TOUCH_DOOR_BITS & CUR_OPENED_DOORS);
    if (!door_bits) {
        room_touch_door_wall();
        return;
    }
    if (door_bits & ROOM_SHUTTER_TOUCH_MASK) {
        room_block_until_time();
        return;
    }
    ROOM_SHUTTER_TOUCH_MASK = (unsigned char)(ROOM_SHUTTER_TOUCH_MASK | ROOM_TOUCH_DOOR_BITS);
}

/* room_mode_runtime.c:48-56. NES CopyNextRowToTransferBuf.
 * Returns ROOM_ROW_INDEX | CARRY_SET if more rows remain. */
unsigned int room_copy_next_row_to_transfer_buf(void)
{
    room_copy_row_to_tilebuf();
    ROOM_ROW_INDEX = (unsigned char)(ROOM_ROW_INDEX + 1u);
    unsigned int result = ROOM_ROW_INDEX;
    if (ROOM_ROW_INDEX < 0x16u)
        result |= CARRY_SET;
    return result;
}

/* room_mode_runtime.c:58-63. NES CopyNextRowAdvanceSubmode. */
unsigned int room_copy_next_row_advance_submode(void)
{
    const unsigned int result = room_copy_next_row_to_transfer_buf();
    if (!(result & CARRY_SET))
        SUBMODE_VALUE = (unsigned char)(SUBMODE_VALUE + 1u);
    return result;
}

/* room_mode_runtime.c:70-78. NES UpdateMode7Scroll_Sub2. */
void room_update_mode7_scroll_sub2(void)
{
    SUBMODE_VALUE = (unsigned char)(SUBMODE_VALUE + 1u);
    unsigned char frame = (unsigned char)(FRAME_COUNTER + 1u);
    frame &= 0x03u;
    if (CUR_LEVEL == 0u)
        frame &= 0x01u;
    ROOM_SCROLL_FRAME = frame;
}

/* room_mode_runtime.c:80-87. NES UpdateMode7Scroll_Sub7. */
void room_update_mode7_scroll_sub7(void)
{
    SUBMODE_VALUE = 1u;
    ROOM_MODE_TIMER = 0u;
    ROOM_SCROLL_LOCK_FLAG = 0u;
    ROOM_LEVEL_INDEX = 0u;
    ROOM_SPRITE0_ENABLED = 0u;
    MODE_VALUE = 4u;
}

/* room_mode_runtime.c:89-100. NES UpdateMode7Scroll_Sub6. */
void room_update_mode7_scroll_sub6(void)
{
    if (CUR_LEVEL == 0u) {
        room_update_mode7_scroll_sub7();
        return;
    }
    if (room_is_dark_room(CUR_ROOM_ID) == 0u) {
        room_update_mode7_scroll_sub7();
        return;
    }
    ROOM_ROW_INDEX = 0u;
    SUBMODE_VALUE = (unsigned char)(SUBMODE_VALUE + 1u);
}

/* room_mode_runtime.c:102-105. NES CueTransferPlayAreaAttrsHalfAndAdvance. */
void room_cue_transfer_play_area_attrs_half_and_advance_submode(unsigned int ppu_hi,
                                                                unsigned int ppu_lo,
                                                                unsigned int end_off)
{
    room_copy_play_area_attrs_half(ppu_hi, ppu_lo, end_off);
    SUBMODE_VALUE = (unsigned char)(SUBMODE_VALUE + 1u);
}

/* room_mode_runtime.c:162-164. NES InitModeB_Sub1. */
void room_init_mode_b_sub1(void)
{
    room_select_transfer_buf(62u);
}

/* room_mode_runtime.c:166-172. NES UpdateMode12_EndLevel_Sub1. */
void room_update_mode12_end_level_sub1(void)
{
    if (CURTAIN_TIMER == 0u) {
        room_start_filling_hearts();
        return;
    }
    ROOM_TRANSFER_BUF_SELECT = (unsigned char)(((CURTAIN_TIMER & 7u) < 4u) ? 24u : 120u);
}

/* room_mode_runtime.c:174-177. NES InitMode3_Sub2. */
void room_init_mode3_sub2(void)
{
    room_fill_play_area_attrs(CUR_ROOM_ID);
    room_select_transfer_buf(24u);
}

/* room_mode_runtime.c:179-181. NES InitMode3_Sub3. */
void room_init_mode3_sub3(void)
{
    room_cue_transfer_play_area_attrs_half_and_advance_submode(35u, 0xD0u, 23u);
}

/* room_mode_runtime.c:183-185. NES InitMode3_Sub4. */
void room_init_mode3_sub4(void)
{
    room_cue_transfer_play_area_attrs_half_and_advance_submode(35u, 0xE8u, 47u);
}

/* room_mode_runtime.c:187-189. NES InitMode3_Sub5. */
void room_init_mode3_sub5(void)
{
    room_select_transfer_buf(14u);
}

/* room_mode_runtime.c:191-197. NES InitMode3_Sub6. */
void room_init_mode3_sub6(void)
{
    if (CUR_LEVEL != 0u && !room_has_map()) {
        room_inc_submode();
        return;
    }
    room_select_transfer_buf(68u);
}

/* room_mode_runtime.c:199-206. NES InitMode3_Sub7. */
void room_init_mode3_sub7(void)
{
    extern unsigned char LevelNumberTransferBuf[];
    if (ROOM_LEVEL_NUMBER_VALUE == 0u) {
        room_inc_submode();
        return;
    }
    LevelNumberTransferBuf[9] = ROOM_LEVEL_NUMBER_VALUE;
    room_select_transfer_buf(12u);
}

/* room_mode_runtime.c:208-214. NES InitModeA_Sub1. */
void room_init_mode_a_sub1(void)
{
    if (CUR_LEVEL != 0u) {
        room_inc_submode();
        return;
    }
    room_patch_and_cue_level_palettes_transfer();
}

/* room_mode_runtime.c:216-225. NES UpdateMode11_Death_SubC. */
void room_update_mode11_death_sub_c(void)
{
    if (MODE11_DEATH_TIMER != 0u) return;
    (void)room_end_game_mode();
    MODE_VALUE = 8u;
    DEATH_FRAME_COUNTER = 64u;
    const unsigned char slot = SAVE_SLOT_INDEX;
    const unsigned char continue_count = CONTINUE_COUNT(slot);
    if (continue_count != 0xFFu)
        CONTINUE_COUNT(slot) = (unsigned char)(continue_count + 1u);
}

/* room_mode_runtime.c:227-235. NES UpdateMode11_Death_Sub2. */
void room_update_mode11_death_sub2(void)
{
    const unsigned int result = room_copy_next_row_advance_submode();
    if (result & CARRY_SET)
        room_write_and_enable_sprite0();
    unsigned char val = TRANSFER_BUF_BYTE(0);
    val = (unsigned char)(val + 0x08u);
    TRANSFER_BUF_BYTE(0) = val;
}

/* room_mode_runtime.c:237-245. NES EndGameMode12. */
void room_end_game_mode12(void)
{
    const unsigned char result = room_end_game_mode();
    ROOM_LEVEL_INDEX = result;
    CUR_LEVEL = result;
    MODE_VALUE = 2u;
    ROOM_LINK_CELLAR_FLAG = 2u;
    ROOM_SFX_MAIN = 0x80u;
    CUR_INV_TILE = (unsigned char)(CUR_INV_TILE & 0xFEu);
}
