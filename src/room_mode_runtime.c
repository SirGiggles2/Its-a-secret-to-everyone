#include "room_mode_runtime.h"
#include "room_load_runtime.h"
#include "room_runtime.h"

extern void z05_copy_row_to_tilebuf(void);
extern void z05_copy_play_area_attrs_half(unsigned int ppu_hi, unsigned int ppu_lo, unsigned int end_off);
extern void z01_begin_update_mode(void);
extern unsigned char LevelNumberTransferBuf[];
extern void z07_patch_and_cue_level_palettes_transfer(void);
extern unsigned char z07_end_game_mode(void);

void roommd_inc_submode(void) {
    SUBMODE_VALUE++;
}

void roommd_inc_2_submodes(void) {
    SUBMODE_VALUE++;
    SUBMODE_VALUE++;
}

void roommd_init_mode_a_sub_a_go_to_mode4(void) {
    roomld_reset_inv_obj_state();
    SUBMODE_VALUE = 0;
    MODE_VALUE = 4;
}

void roommd_init_mode4_go_to_sub0(void) {
    SUBMODE_VALUE = 0;
    ROOM_SCROLL_STATE = 0;
}

void roommd_update_mode11_death_sub6(void) {
    ROOM_PPU_MASK_FLAGS &= 0xFE;
    roommd_inc_submode();
}

void roommd_reset_vscroll_lo(void) {
    ROOM_VSCROLL_LO = 0;
    roommd_inc_submode();
}

void roommd_select_transfer_buf(unsigned int val) {
    ROOM_TRANSFER_BUF_SELECT = (unsigned char)val;
    roommd_inc_submode();
}

void roommd_select_transfer_buf_and_inc_state(unsigned int val) {
    ROOM_TRANSFER_BUF_SELECT = (unsigned char)val;
    ROOM_STATE_INDEX++;
}

unsigned int roommd_copy_next_row_to_transfer_buf(void) {
    unsigned int result;
    z05_copy_row_to_tilebuf();
    ROOM_ROW_INDEX++;
    result = ROOM_ROW_INDEX;
    if (ROOM_ROW_INDEX < 0x16)
        result |= CARRY_SET;
    return result;
}

unsigned int roommd_copy_next_row_advance_submode(void) {
    unsigned int result = roommd_copy_next_row_to_transfer_buf();
    if (!(result & CARRY_SET))
        SUBMODE_VALUE++;
    return result;
}

void roommd_set_fade_cycle_and_advance_submode(unsigned int val) {
    WORLD_FADE_STEP = (unsigned char)val;
    SUBMODE_VALUE++;
}

void roommd_update_mode7_scroll_sub2(void) {
    unsigned char frame;
    SUBMODE_VALUE++;
    frame = (unsigned char)(FRAME_COUNTER + 1);
    frame &= 0x03;
    if (CUR_LEVEL == 0)
        frame &= 0x01;
    ROOM_SCROLL_FRAME = frame;
}

void roommd_update_mode7_scroll_sub7(void) {
    SUBMODE_VALUE = 1;
    ROOM_MODE_TIMER = 0;
    ROOM_SCROLL_LOCK_FLAG = 0;
    ROOM_LEVEL_INDEX = 0;
    ROOM_SPRITE0_ENABLED = 0;
    MODE_VALUE = 4;
}

void roommd_update_mode7_scroll_sub6(void) {
    if (CUR_LEVEL == 0) {
        roommd_update_mode7_scroll_sub7();
        return;
    }
    if (roomrt_is_dark_room(CUR_ROOM_ID) == 0) {
        roommd_update_mode7_scroll_sub7();
        return;
    }
    ROOM_ROW_INDEX = 0;
    SUBMODE_VALUE++;
}

void roommd_cue_transfer_play_area_attrs_half_and_advance_submode(unsigned int ppu_hi, unsigned int ppu_lo, unsigned int end_off) {
    z05_copy_play_area_attrs_half(ppu_hi, ppu_lo, end_off);
    SUBMODE_VALUE++;
}

void roommd_update_menu_common2(void) {
    roommd_select_transfer_buf_and_inc_state(72);
}

void roommd_update_menu_common3(void) {
    roommd_select_transfer_buf_and_inc_state(74);
}

void roommd_update_menu_common4(void) {
    roommd_select_transfer_buf_and_inc_state(76);
}

void roommd_update_menu5_ow(void) {
    roommd_select_transfer_buf_and_inc_state(92);
}

void roommd_init_mode7_finish(void) {
    CUR_ROOM_ID = PREV_ROOM_ID;
    roomld_write_and_enable_sprite0();
    z01_begin_update_mode();
}

void roommd_switch_to_nt1(void) {
    ROOM_NAMETABLE_SELECT = 1;
}

void roommd_update_mode11_death_set_timer_inc_submode(unsigned int val) {
    CURTAIN_TIMER = (unsigned char)val;
    SUBMODE_VALUE++;
}

void roommd_update_mode11_death_sub4(void) {
    roommd_select_transfer_buf(98);
}

void roommd_update_mode11_death_sub5(void) {
    ROOM_SPRITE0_ENABLED = 0;
    roommd_select_transfer_buf(94);
}

void roommd_update_mode11_death_sub9(void) {
    ROOM_TRANSFER_BUF_SELECT = 44;
    ROOM_MENU_SCROLL_TIMER = 15;
    roommd_update_mode11_death_set_timer_inc_submode(24);
}

void roommd_init_mode9_transfer_attrs(void) {
    roommd_select_transfer_buf(38);
}

void roommd_start_filling_hearts(void) {
    ROOM_INV_OBJ_ACTIVE = 2;
    roommd_inc_submode();
}

void roommd_init_mode_b_sub1(void) {
    roommd_select_transfer_buf(62);
}

void roommd_update_mode12_end_level_sub1(void) {
    if (CURTAIN_TIMER == 0) {
        roommd_start_filling_hearts();
        return;
    }
    ROOM_TRANSFER_BUF_SELECT = (unsigned char)(((CURTAIN_TIMER & 7) < 4) ? 24 : 120);
}

void roommd_init_mode3_sub2(void) {
    roomld_fill_play_area_attrs(CUR_ROOM_ID);
    roommd_select_transfer_buf(24);
}

void roommd_init_mode3_sub3(void) {
    roommd_cue_transfer_play_area_attrs_half_and_advance_submode(35, 0xD0, 23);
}

void roommd_init_mode3_sub4(void) {
    roommd_cue_transfer_play_area_attrs_half_and_advance_submode(35, 0xE8, 47);
}

void roommd_init_mode3_sub5(void) {
    roommd_select_transfer_buf(14);
}

void roommd_init_mode3_sub6(void) {
    if (CUR_LEVEL != 0 && !roomrt_has_map()) {
        roommd_inc_submode();
        return;
    }
    roommd_select_transfer_buf(68);
}

void roommd_init_mode3_sub7(void) {
    if (ROOM_LEVEL_NUMBER_VALUE == 0) {
        roommd_inc_submode();
        return;
    }
    LevelNumberTransferBuf[9] = ROOM_LEVEL_NUMBER_VALUE;
    roommd_select_transfer_buf(12);
}

void roommd_init_mode_a_sub1(void) {
    if (CUR_LEVEL != 0) {
        roommd_inc_submode();
        return;
    }
    z07_patch_and_cue_level_palettes_transfer();
}

void roommd_update_mode11_death_sub_c(void) {
    if (MODE11_DEATH_TIMER != 0) return;
    z07_end_game_mode();
    MODE_VALUE = 8;
    DEATH_FRAME_COUNTER = 64;
    unsigned char slot = SAVE_SLOT_INDEX;
    unsigned char continue_count = CONTINUE_COUNT(slot);
    if (continue_count != 0xFF)
        CONTINUE_COUNT(slot) = continue_count + 1;
}

void roommd_update_mode11_death_sub2(void) {
    unsigned int result = roommd_copy_next_row_advance_submode();
    if (result & CARRY_SET) {
        roomld_write_and_enable_sprite0();
    }
    unsigned char val = RAM(0x0302);
    val = (unsigned char)(val + 0x08);
    RAM(0x0302) = val;
}

void roommd_end_game_mode12(void) {
    unsigned char result = z07_end_game_mode();
    ROOM_LEVEL_INDEX = result;
    CUR_LEVEL = result;
    MODE_VALUE = 2;
    ROOM_LINK_CELLAR_FLAG = 2;
    ROOM_SFX_MAIN = 0x80;
    CUR_INV_TILE &= 0xFE;
}
