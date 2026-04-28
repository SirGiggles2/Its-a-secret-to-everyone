#ifndef WORLD_STATE_H
#define WORLD_STATE_H

#include "platform_abi.h"

/* Shared world/object state for promoted z_01 world and weapon code. */
#define WORLD_TMP0                     RAM(0x0000)
#define WORLD_TMP1                     RAM(0x0001)
#define WORLD_TMP2                     RAM(0x0002)
#define WORLD_TMP3                     RAM(0x0003)

#define LINK_DIR                       RAM(0x0098)
#define LINK_X                         RAM(NES_OBJ_X)
#define LINK_Y                         RAM(NES_OBJ_Y)
#define LINK_ACTION_TIMER              RAM(0x00AC)
#define CUR_ROOM_ID                    RAM(0x00EB)
#define PREV_ROOM_ID                   RAM(0x00EC)

#define WORLD_FADE_TIMER               RAM(0x0034)
#define WORLD_FADE_STEP                RAM(0x051C)
#define WORLD_MAZE_STEP                RAM(0x052F)
#define WORLD_SECRET_SFX               RAM(0x0602)
#define SFX_COMBAT                     RAM(0x0604)

#define TRANSFER_BUF_POS               RAM(0x0301)
#define TRANSFER_BUF_BYTE(off)         RAM(0x0302 + (off))

#define OBJ_DIR(slot)                  OBJ(0x0098, (slot))
#define OBJ_X(slot)                    OBJ(NES_OBJ_X, (slot))
#define OBJ_Y(slot)                    OBJ(NES_OBJ_Y, (slot))
#define OBJ_GRID_OFFSET(slot)          OBJ(NES_OBJ_GRID_OFFSET, (slot))
#define OBJ_POS_FRAC(slot)             OBJ(NES_OBJ_POS_FRAC, (slot))
#define OBJ_QSPD_FRAC(slot)            OBJ(NES_OBJ_QSPD_FRAC, (slot))
#define OBJ_STATUS_FLAGS(slot)         OBJ(0x04BF, (slot))
#define OBJ_STATE(slot)                OBJ(0x00AC, (slot))
#define OBJ_ANIM_TIMER(slot)           OBJ(0x03D0, (slot))
#define OBJ_MOVE_TIMER(slot)           OBJ(0x0028, (slot))

#define CANDLE_LIT_FLAG                RAM(0x0513)
#define WEAPON_DRAW_SLOT_A             16u
#define WEAPON_DRAW_SLOT_B             17u

#endif
