#ifndef TARGETING_STATE_H
#define TARGETING_STATE_H

#include "world_state.h"

/* Scratch and targeting state for promoted targeting helpers. */
#define TARGET_DIR_ACCUM               RAM(0x0000)
#define TARGET_MIN_COORD               RAM(0x0001)
#define TARGET_MAX_COORD               RAM(0x0002)
#define TARGET_H_DIST                  RAM(0x0003)
#define TARGET_V_DIST                  RAM(0x0004)
#define TARGET_H_DIR                   RAM(0x000A)
#define TARGET_V_DIR                   RAM(0x000B)

#endif
