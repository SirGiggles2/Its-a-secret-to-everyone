#ifndef FRONTEND_STATE_H
#define FRONTEND_STATE_H

#include "progress_state.h"
#include "scratch_state.h"

/* Shared title/demo/name-entry/save-menu state for promoted z_02 code. */
#define FRONTEND_CUR_VSCROLL            RAM(0x00FC)
#define FRONTEND_NT_SWITCH_REQ          RAM(0x005C)
#define FRONTEND_SPRITE_CURSOR_X        RAM(0x0207)
#define FRONTEND_NAME_CURSOR_X          RAM(0x0071)
#define FRONTEND_NAME_CURSOR_Y          RAM(0x0085)

#define FRONTEND_SCROLL_SCREEN_COUNT    RAM(0x0415)
#define FRONTEND_DEMO_LINE_ATTR_LO      RAM(0x0417)
#define FRONTEND_DEMO_LINE_ATTR_HI      RAM(0x0418)
#define FRONTEND_DEMO_TIMER             RAM(0x041A)
#define FRONTEND_DEMO_LINE_TILE_LO      RAM(0x041C)
#define FRONTEND_DEMO_LINE_TILE_HI      RAM(0x041D)
#define FRONTEND_CHAR_BOARD_INDEX       RAM(0x041F)
#define FRONTEND_NAME_FIELD_INIT        RAM(0x0420)
#define FRONTEND_NAME_CHAR_OFFSET       RAM(0x0421)
#define FRONTEND_BUTTON_HELD            RAM(0x0426)
#define FRONTEND_BUTTON_REPEAT_STATE    RAM(0x0428)
#define FRONTEND_BUTTON_REPEAT_TIMER    RAM(0x0429)
#define FRONTEND_DEMO_SUBPHASE          RAM(0x042D)
#define FRONTEND_CREDITS_TILE_OFFSET    RAM(0x050B)

/* Zero-page scratch slots aliased through scratch_state.h. */
#define FRONTEND_ADD16_LO               ZP_TMPF
#define FRONTEND_ADD16_HI               ZP_TMPE
#define FRONTEND_SAVE_ADD16_LO          RAM(0x00CF)
#define FRONTEND_SAVE_ADD16_HI          RAM(0x00CE)

#endif
