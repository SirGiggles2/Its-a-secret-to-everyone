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
            /* Q2 underworld level — TODO STAGE-1 STUB.
             * Drain reads from LevelInfoUWQ2Replacements{1..9} blobs
             * (565 bytes total). Native port requires baking those
             * blobs as static const arrays. Title.md path keeps Q2
             * UW patches via transpile asm (NATIVE_ROOM=off default);
             * RoomRom OW test bench doesn't exercise Q2 UW. */
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
