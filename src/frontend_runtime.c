#include "frontend_runtime.h"
#include "room_state.h"
#include "world_state.h"
#include "item_state.h"

extern void c_import_demo_animate_objects(void);
extern void z07_hide_all_sprites(void);
extern void z01_silence_all_sound(void);
extern void z01_begin_update_mode(void);

void frontdemo_animate_phase1_sub0(void) {
    if (FRAME_COUNTER & 0x01) {
        FRONTEND_CUR_VSCROLL++;
        if (FRONTEND_CUR_VSCROLL == 0xF0) {
            FRONTEND_SCROLL_SCREEN_COUNT++;
            FRONTEND_CUR_VSCROLL = 0;
            FRONTEND_NT_SWITCH_REQ++;
        }
    }
    if (FRONTEND_CUR_VSCROLL == 0x08 && FRONTEND_SCROLL_SCREEN_COUNT != 0) {
        FRONTEND_SCROLL_SCREEN_COUNT = 0;
        FRONTEND_DEMO_SUBPHASE++;
    }
}

void frontdemo_animate_phase1_sub1(void) {
    FRONTEND_DEMO_TIMER++;
    if (FRONTEND_DEMO_TIMER == 0)
        FRONTEND_DEMO_SUBPHASE++;
    FRONTEND_DEMO_LINE_TILE_HI = 41;
    FRONTEND_DEMO_LINE_TILE_LO = 0;
    FRONTEND_DEMO_LINE_ATTR_HI = 43;
    FRONTEND_DEMO_LINE_ATTR_LO = 0xE0;
}

void frontdemo_disable_fallen_objects(void) {
    unsigned char x;
    for (x = 10; x >= 1; x--) {
        if (OBJ_Y(x) == 0xF0)
            OBJ_STATE(x) = 0xFF;
    }
}

void frontdemo_init_mode1_sub2(void) {
    ROOM_TRANSFER_BUF_SELECT = 20;
    SUBMODE_VALUE++;
}

void frontdemo_end_init_demo(unsigned int val) {
    ROOM_TRANSFER_BUF_SELECT = (unsigned char)val;
    FRONTEND_DEMO_SUBPHASE = 0;
    ROOM_MODE_TIMER++;
}

void frontdemo_inc_subphase(void) {
    FRONTEND_DEMO_SUBPHASE++;
}

void frontdemo_animate_p1_end(void) {
    z07_hide_all_sprites();
    c_import_demo_animate_objects();
}

void frontdemo_animate_p1_sub3(void) {
    FRONTEND_DEMO_TIMER++;
    if (FRONTEND_DEMO_TIMER == 0)
        FRONTEND_DEMO_SUBPHASE++;
    else
        frontdemo_animate_p1_end();
}

void frontdemo_init_demo_subphase_play_title_song(void) {
    ITEM_SFX_SECONDARY = 0x80;
    frontdemo_end_init_demo(16);
}

void frontdemo_init_mode13_sub3(void) {
    if (RAM(0x0029) != 0)
        return;
    z01_silence_all_sound();
    SUBMODE_VALUE++;
}

void frontdemo_init_mode13_sub4(void) {
    FRONTEND_CREDITS_TILE_OFFSET = 8;
    z01_begin_update_mode();
    ROOM_PUSH_TIMER = 0;
    RAM(0x0413) = 0;
    z07_hide_all_sprites();
}

void frontname_reset_variables(unsigned int val) {
    FRONTEND_CHAR_BOARD_INDEX = (unsigned char)val;
    FRONTEND_NAME_FIELD_INIT = (unsigned char)val;
    FRONTEND_NAME_CHAR_OFFSET = (unsigned char)val;
}

void frontname_reset_button_repeat_state(unsigned int val) {
    FRONTEND_BUTTON_HELD = (unsigned char)val;
    FRONTEND_BUTTON_REPEAT_STATE = (unsigned char)val;
    FRONTEND_BUTTON_REPEAT_TIMER = (unsigned char)val;
}

void frontname_set_name_cursor_sprite_x(void) {
    FRONTEND_SPRITE_CURSOR_X = LINK_X;
}

void frontname_sync_char_board_cursor(void) {
    unsigned char idx = FRONTEND_CHAR_BOARD_INDEX;
    unsigned char row = 0;
    if (idx & 0x80)
        idx += 44;
    if (idx >= 44)
        idx -= 44;
    if (idx == 43)
        idx = 9;
    FRONTEND_CHAR_BOARD_INDEX = idx;
    while (idx >= 11) {
        idx -= 11;
        row++;
    }
    FRONTEND_NAME_CURSOR_X = (unsigned char)((idx << 4) + 0x30);
    FRONTEND_NAME_CURSOR_Y = (unsigned char)((row << 4) + 0x88);
}

void frontutil_add_a_to_0f0e(unsigned int val) {
    unsigned int sum = (unsigned char)val + FRONTEND_ADD16_LO;
    FRONTEND_ADD16_LO = (unsigned char)sum;
    FRONTEND_ADD16_HI = (unsigned char)(FRONTEND_ADD16_HI + (sum >> 8));
}

void frontutil_add_a_to_cfce(unsigned int val) {
    unsigned int sum = (unsigned char)val + FRONTEND_SAVE_ADD16_LO;
    FRONTEND_SAVE_ADD16_LO = (unsigned char)sum;
    FRONTEND_SAVE_ADD16_HI = (unsigned char)(FRONTEND_SAVE_ADD16_HI + (sum >> 8));
}
