#ifndef PROGRESS_STATE_H
#define PROGRESS_STATE_H

#include "world_state.h"
#include "item_state.h"
#include "combat_state.h"

/* Shared state for save/progress/map/curtain owned C. */
#define SAVEFILE_PTR_LO                 RAM(0x00)
#define SAVEFILE_PTR_HI                 RAM(0x01)
#define SAVEFILE_MASK_LO                RAM(0x08)
#define SAVEFILE_MASK_HI                RAM(0x09)

#define CUR_LEVEL                      RAM(0x0010)
#define FRAME_COUNTER                  RAM(0x0015)
#define MODE_VALUE                     RAM(0x0012)
#define SUBMODE_VALUE                  RAM(0x0013)
#define CUR_ROOM_FLAGS_PTR             RAM(0x00E8)
#define MAP_FLASH_ATTR                 RAM(0x0256)

#define ROOM_TILE_OBJ_0                RAM(0x052B)
#define ROOM_TILE_OBJ_1                RAM(0x052C)
#define ROOM_TILE_OBJ_2                RAM(0x052D)
#define PLAYER_MARKER_DISABLE          RAM(0x0522)
#define POWER_TRIFORCE_FANFARE_FLAG    RAM(0x0509)
#define HUD_DIRTY_FLAG                 RAM(0x0672)
#define CURTAIN_LEFT_COL               RAM(0x007C)
#define CURTAIN_RIGHT_COL              RAM(0x007D)
#define CURTAIN_TIMER                  RAM(0x0028)
#define CUR_INV_TILE                   RAM(0x00FE)

#define MAP_MARKER_Y(idx)              RAM(0x0254 + (idx))
#define MAP_MARKER_TILE(idx)           RAM(0x0255 + (idx))
#define MAP_MARKER_ATTR(idx)           RAM(0x0256 + (idx))
#define MAP_MARKER_X(idx)              RAM(0x0257 + (idx))

#endif
