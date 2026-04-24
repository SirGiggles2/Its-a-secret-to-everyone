#include "world_runtime.h"

#define NES_SRAM_BASE 0x6000u


unsigned int worldrt_get_shortcut_or_item_xy_for_room(unsigned int room_id) {
    unsigned char lookup = nes_ram[NES_SRAM_BASE + 0x0AFE + room_id];
    unsigned char type_idx = (lookup & 0x30) >> 4;
    unsigned char entry = nes_ram[NES_SRAM_BASE + 0x0BA7 + type_idx];
    unsigned char y = (unsigned char)((entry & 0x0F) << 4);
    unsigned char x = entry & 0xF0;
    return ((unsigned int)x << 8) | y;
}

unsigned int worldrt_get_shortcut_or_item_xy(void) {
    return worldrt_get_shortcut_or_item_xy_for_room((unsigned int)CUR_ROOM_ID);
}

void worldrt_get_object_middle(unsigned int slot) {
    WORLD_TMP2 = 8;
    WORLD_TMP3 = 8;
    if (OBJ_STATUS_FLAGS(slot) & 0x40) {
        WORLD_TMP2 >>= 1;
    }
    WORLD_TMP2 = (unsigned char)(OBJ_X(slot) + WORLD_TMP2);
    WORLD_TMP3 = (unsigned char)(OBJ_Y(slot) + WORLD_TMP3);
}

unsigned int worldrt_animate_world_fading(void) {
    unsigned char val;
    unsigned char sram_idx;
    unsigned char pos;
    unsigned char count;
    if (WORLD_FADE_TIMER != 0) {
        return 1u;
    }
    val = WORLD_FADE_STEP;
    if (val & 0x80) {
        val ^= 0x83;
    }
    WORLD_TMP0 = val;
    sram_idx = (unsigned char)(((unsigned char)(val << 3) + val) & 0xFCu);
    pos = TRANSFER_BUF_POS;
    TRANSFER_BUF_BYTE(pos) = 63;
    pos++;
    TRANSFER_BUF_BYTE(pos) = 8;
    pos++;
    TRANSFER_BUF_BYTE(pos) = 8;
    WORLD_TMP0 = 8;
    pos++;
    count = 8;
    while (count != 0) {
        TRANSFER_BUF_BYTE(pos) = nes_ram[NES_SRAM_BASE + 0x0BFA + sram_idx];
        sram_idx++;
        pos++;
        count--;
    }
    TRANSFER_BUF_BYTE(pos) = 0xFF;
    TRANSFER_BUF_POS = pos;
    WORLD_FADE_STEP++;
    if ((WORLD_FADE_STEP & 0x0F) == 4) {
        return 0u;
    }
    WORLD_FADE_TIMER = 10;
    return 1u;
}

void worldrt_check_mazes(void) {
    static const unsigned char forest_dirs[4] = {0x08, 0x02, 0x04, 0x02};
    static const unsigned char mountain_dirs[4] = {0x08, 0x08, 0x08, 0x08};
    unsigned char step = WORLD_MAZE_STEP;
    unsigned char dir = LINK_DIR;
    unsigned char room = CUR_ROOM_ID;
    if (room == 0x61) {
        if (dir != forest_dirs[step]) {
            if (dir == 0x01) {
                return;
            }
            WORLD_MAZE_STEP = 0;
            PREV_ROOM_ID = room;
            return;
        }
        if (step == 3) {
            WORLD_SECRET_SFX = 4;
            return;
        }
        WORLD_MAZE_STEP++;
        PREV_ROOM_ID = room;
        return;
    }
    if (room != 0x1B) {
        WORLD_MAZE_STEP = 0;
        return;
    }
    if (dir == mountain_dirs[step]) {
        if (step == 3) {
            WORLD_SECRET_SFX = 4;
            return;
        }
        WORLD_MAZE_STEP++;
        PREV_ROOM_ID = room;
        return;
    }
    if (dir == 0x02) {
        return;
    }
    WORLD_MAZE_STEP = 0;
    PREV_ROOM_ID = room;
}
