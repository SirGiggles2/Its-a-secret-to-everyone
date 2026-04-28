#include "progress_runtime.h"
#include "legacy_bridge.h"
#include "save_state.h"
#include "room_state.h"

#define NES_SRAM_BASE 0x6000u

static void progrt_replace_palette_row_common(unsigned char color_index) {
    unsigned char len = TRANSFER_BUF_POS;
    unsigned char i;
    int j;
    for (i = 0; i < 8; i++) {
        TRANSFER_BUF_BYTE(len++) = PaletteRow7TransferRecord[i];
    }
    TRANSFER_BUF_POS = len;
    for (j = 0; j < 3; j++) {
        RAM(0x0306 + j) = GanonColorTriples[color_index - 2 + j];
    }
}

void progrt_replace_ganon_brown_palette_row(void) { progrt_replace_palette_row_common(2); }
void progrt_replace_ganon_blue_palette_row(void) { progrt_replace_palette_row_common(5); }
void progrt_replace_ashes_palette_row(void) { progrt_replace_palette_row_common(8); }

unsigned char progrt_reset_room_tile_obj_info(void) {
    ROOM_TILE_OBJ_0 = 0;
    ROOM_TILE_OBJ_1 = 0;
    ROOM_TILE_OBJ_2 = 0;
    return 0;
}

void progrt_set_room_flag_uw_item_state(void) {
    unsigned char flags = z07_get_room_flags();
    unsigned short ptr;
    flags |= 0x10;
    ptr = ((unsigned short)SAVEFILE_PTR_HI << 8) | SAVEFILE_PTR_LO;
    nes_ram[ptr + CUR_ROOM_ID] = flags;
}

unsigned char progrt_get_room_flag_uw_item_state(void) {
    unsigned char ptr_lo = SAVE_ROOM_FLAGS_PTR_LO;
    unsigned char ptr_hi = SAVE_ROOM_FLAGS_PTR_HI;
    unsigned short ptr;
    SAVEFILE_MASK_LO = ptr_lo;
    SAVEFILE_MASK_HI = ptr_hi;
    ptr = ((unsigned short)ptr_hi << 8) | ptr_lo;
    return nes_ram[ptr + CUR_ROOM_ID] & 0x10;
}

void progrt_update_bomb_flash_effect(unsigned int slot) {
    if (OBJ_STATE(slot) != 0x13) return;
    {
        unsigned char mask = CUR_INV_TILE;
        unsigned char timer = OBJ_MOVE_TIMER(slot);
        mask >>= 1;
        if (timer == 0x16 || timer == 0x11) {
            mask = (unsigned char)((mask << 1) | 1);
        } else if (timer == 0x12 || timer == 0x0D) {
            mask = (unsigned char)(mask << 1);
        } else {
            return;
        }
        CUR_INV_TILE = mask;
    }
}

void progrt_update_position_marker(unsigned char room_id, unsigned int idx) {
    unsigned char level = CUR_LEVEL;
    unsigned char row = (room_id & 0x70) >> 2;
    unsigned char col = room_id & 0x0F;
    unsigned char tile_val;
    unsigned char col_shifted;
    MAP_MARKER_Y(idx) = row + 0x17;
    if (level == 0) {
        tile_val = 17;
        col_shifted = (unsigned char)(col << 2);
    } else {
        tile_val = 18;
        col_shifted = (unsigned char)(col << 3);
    }
    MAP_MARKER_TILE(idx) = 62;
    MAP_MARKER_X(idx) = (unsigned char)(col_shifted + tile_val + nes_ram[NES_SRAM_BASE + 0x0BAC]);
    if (idx == 0) {
        MAP_MARKER_ATTR(0) = 0;
        return;
    }
    {
        unsigned char attr = 3;
        if (level != 9 && (RAM(0x0671) & LevelMasks[level - 1])) {
        } else {
            unsigned char flash = FRAME_COUNTER & 0x1F;
            if (flash < 0x10) attr = 2;
        }
        MAP_MARKER_ATTR(idx) = attr;
    }
}

void progrt_update_player_position_marker(void) {
    if (MODE_VALUE == 9) return;
    if (PLAYER_MARKER_DISABLE) return;
    progrt_update_position_marker(CUR_ROOM_ID, 0);
}

void progrt_update_world_curtain_effect(void) {
    if (CURTAIN_TIMER) return;
    ITEM_VALUE_SCRATCH = 1;
    do {
        unsigned char col_idx = ITEM_VALUE_SCRATCH;
        CUR_ROOM_FLAGS_PTR = RAM(0x007C + col_idx);
        z05_copy_column_to_tilebuf();
        ITEM_VALUE_SCRATCH--;
    } while ((signed char)ITEM_VALUE_SCRATCH >= 0);
    CUR_ROOM_FLAGS_PTR = 0xFF;
    CURTAIN_TIMER = 5;
    CURTAIN_LEFT_COL--;
    CURTAIN_RIGHT_COL++;
}

void progrt_update_world_curtain_effect_bank2(void) {
    progrt_update_world_curtain_effect();
}

void progrt_fetch_file_a_address_set(void) {
    unsigned char file_slot = SAVE_SLOT_INDEX;
    unsigned char end_idx = (unsigned char)(0x0D + file_slot * 0x0Eu);
    for (int i = 13; i >= 0; i--) {
        RAM(i) = SaveFileAAddressSets[end_idx];
        end_idx--;
    }
    RAM(0x000E) = 0x7F;
    RAM(0x000F) = 0x06;
}

void progrt_check_tile_objects_blocking(void) {
    for (int slot = 12; slot >= 1; slot--) {
        unsigned char mtype = MON_TYPE(slot);
        if (mtype != 0x68 && mtype != 0x62 && mtype != 0x65 && mtype != 0x66) continue;
        if (OBJ_STATE(slot) != 1) continue;
        {
            signed char dx = (signed char)(LINK_X - OBJ_X(slot));
            if (dx < 0) dx = (signed char)-dx;
            if ((unsigned char)dx >= 0x10) continue;
        }
        {
            unsigned char ly_adj = (unsigned char)(LINK_Y + 3);
            signed char dy = (signed char)(ly_adj - OBJ_Y(slot));
            if (dy < 0) dy = (signed char)-dy;
            if ((unsigned char)dy >= 0x10) continue;
        }
        COMBAT_PART_INDEX = 0;
    }
}

void progrt_check_power_triforce_fanfare(void) {
    if (!POWER_TRIFORCE_FANFARE_FLAG) return;
    if (!CURTAIN_TIMER) {
        progrt_replace_ashes_palette_row();
        ITEM_SFX_SECONDARY = 32;
        HUD_DIRTY_FLAG = 1;
        LINK_ACTION_TIMER = 0;
        POWER_TRIFORCE_FANFARE_FLAG = 0;
        return;
    }
    {
        unsigned char phase = CURTAIN_TIMER & 7;
        ROOM_TRANSFER_BUF_SELECT = (phase < 4) ? 120 : 24;
    }
}
