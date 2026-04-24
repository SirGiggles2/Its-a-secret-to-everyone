#include "room_runtime.h"
#include "core_runtime.h"
#include "link_state.h"

#define NES_SRAM_BASE 0x6000u

static const unsigned char roomrt_level_masks[] = {
    0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80
};
static const unsigned char roomrt_reverse_directions[] = { 0x08, 0x04, 0x02, 0x01 };
static const unsigned char roomrt_player_screen_edge_bounds[] = { 0x3D, 0xDD, 0x00, 0xF0 };


unsigned char roomrt_get_room_flags(void) {
    unsigned char ptr_lo = nes_ram[NES_SRAM_BASE + NES_SRAM_ROOM_FLAGS_PTR_LO];
    unsigned char ptr_hi = nes_ram[NES_SRAM_BASE + NES_SRAM_ROOM_FLAGS_PTR_HI];
    unsigned short ptr;
    SAVEFILE_PTR_LO = ptr_lo;
    SAVEFILE_PTR_HI = ptr_hi;
    ptr = ((unsigned short)ptr_hi << 8) | ptr_lo;
    return nes_ram[ptr + CUR_ROOM_ID];
}

static unsigned char roomrt_has_item_by_level(unsigned char base_offset) {
    unsigned char level = CUR_LEVEL;
    unsigned char idx;
    unsigned char offset;
    unsigned char bit_idx;
    if (level == 0)
        return 0;
    idx = (unsigned char)(level - 1);
    offset = base_offset;
    if (idx >= 8)
        offset = (unsigned char)(offset + 2);
    bit_idx = idx & 7;
    return INVENTORY_VALUE(offset) & roomrt_level_masks[bit_idx];
}

unsigned char roomrt_has_compass(void) {
    return roomrt_has_item_by_level(16);
}

unsigned char roomrt_has_map(void) {
    return roomrt_has_item_by_level(17);
}

void roomrt_calc_open_doorway_mask(unsigned int attr, unsigned int dir_idx) {
    unsigned char is_open;
    unsigned char mask;
    if (attr < 4) {
        is_open = 1;
    } else {
        unsigned char flags = roomrt_get_room_flags();
        is_open = (flags & roomrt_level_masks[dir_idx]) ? 1u : 0u;
    }
    mask = ROOM_DOOR_MASK_ACC;
    mask = ((unsigned char)(mask << 1) | is_open) & 0x0F;
    ROOM_DOOR_MASK_ACC = mask;
}

void roomrt_add_door_flags(void) {
    unsigned char flags = roomrt_get_room_flags();
    signed char d;
    for (d = 3; d >= 0; d--) {
        unsigned char masked = flags & roomrt_level_masks[(unsigned char)d];
        if (masked)
            CUR_OPENED_DOORS |= masked;
    }
}

unsigned int roomrt_split_room_id(void) {
    unsigned char room = CUR_ROOM_ID;
    unsigned char col = room & 0x0F;
    unsigned char row = room >> 4;
    return ((unsigned int)row << 8) | col;
}

unsigned char roomrt_is_dark_room(unsigned int col) {
    if (CUR_LEVEL == 0)
        return 0;
    return nes_ram[NES_SRAM_BASE + 0x0A7E + col] & 0x80;
}

void roomrt_set_door_flag(unsigned int dir_idx) {
    unsigned char flags = roomrt_get_room_flags();
    unsigned short ptr = ((unsigned short)SAVEFILE_PTR_HI << 8) | SAVEFILE_PTR_LO;
    flags |= roomrt_level_masks[dir_idx];
    nes_ram[ptr + CUR_ROOM_ID] = flags;
}

void roomrt_reset_door_flag(unsigned int dir_idx) {
    unsigned short ptr;
    unsigned char flags;
    unsigned char mask;
    roomrt_get_room_flags();
    ptr = ((unsigned short)SAVEFILE_PTR_HI << 8) | SAVEFILE_PTR_LO;
    mask = roomrt_level_masks[dir_idx] ^ 0xFF;
    flags = nes_ram[ptr + CUR_ROOM_ID];
    nes_ram[ptr + CUR_ROOM_ID] = flags & mask;
}

void roomrt_check_has_living_monsters(void) {
    unsigned char max_slot = ROOM_MAX_MONSTER_SLOT;
    signed char i;
    for (i = (signed char)max_slot; i >= 0; i--) {
        unsigned char obj = ROOM_OBJ_TYPE((unsigned char)i);
        if (obj == 0)
            continue;
        if (obj < 0x2B)
            return;
        if (obj < 0x2E)
            continue;
        if (obj < 0x49)
            return;
    }
    LINK_DAMAGE_DISABLE_FLAG = 0;
    ROOM_MONSTER_ALL_DEAD++;
}

void roomrt_silence_sound(void) {
    ROOM_SFX_MAIN = 0x80;
    ROOM_SFX_AUX = 0x80;
}

void roomrt_set_entering_doorway(void) {
    unsigned char scroll_dir = ROOM_SCROLL_DIR;
    unsigned char a = (scroll_dir >> 1) & 0x05;
    unsigned char b = (scroll_dir << 1) & 0x0A;
    CUR_OPENED_DOORS = a | b;
}

void roomrt_save_kill_count_ow(unsigned int slot) {
    unsigned short ptr;
    unsigned char flags = roomrt_get_room_flags();
    unsigned char kill_count = flags & 7;
    unsigned char cell;
    unsigned char cur_count;
    unsigned char max_count;
    unsigned char new_kill;

    WORLD_TMP2 = kill_count;
    ptr = ((unsigned short)SAVEFILE_PTR_HI << 8) | SAVEFILE_PTR_LO;
    cell = nes_ram[ptr + slot] & 0xF8;
    nes_ram[ptr + slot] = cell;
    cur_count = ROOM_OW_CUR_KILL_TOTAL;
    max_count = ROOM_OW_KILL_COUNT;
    if (cur_count >= max_count) {
        new_kill = 7;
    } else {
        new_kill = (unsigned char)((cur_count & 7) + kill_count);
        if (new_kill >= 7)
            new_kill = 7;
    }
    nes_ram[ptr + slot] = cell | new_kill;
}

void roomrt_trigger_open_door(unsigned int val) {
    ROOM_OPEN_DOOR_ARG = (unsigned char)val;
    ROOM_OPEN_DOOR_TIMER = 6;
}

void roomrt_touch_door_wall(void) {
    ROOM_TOUCH_BLOCK_FLAG = 0xFF;
}

void roomrt_touch_door_open(void) {}

void roomrt_wield_nothing(void) {}

void roomrt_mask_cur_ppu_mask_grayscale(void) {
    CUR_INV_TILE &= 0xFE;
}

void roomrt_block_at_wall(void) {
    roomrt_touch_door_wall();
}

unsigned int roomrt_check_secret_trigger_none(void) {
    return 0;
}

unsigned int roomrt_trigger_shutters(void) {
    ROOM_SHUTTER_TRIGGERED = 1;
    return CARRY_SET;
}

unsigned int roomrt_return_false(void) {
    return 0;
}

unsigned int roomrt_check_secret_trigger_all_dead(void) {
    if (ROOM_MONSTER_ALL_DEAD != 0)
        return roomrt_trigger_shutters();
    return 0;
}

unsigned int roomrt_check_secret_trigger_last_boss(void) {
    if (ROOM_BOSS_SECRET_FLAG == 0)
        return 0;
    return roomrt_trigger_shutters();
}

unsigned int roomrt_check_secret_trigger_money_or_life(void) {
    if (ROOM_OBJ_TYPE(0) != 0)
        return 0;
    return roomrt_trigger_shutters();
}

unsigned int roomrt_check_secret_trigger_block_door(void) {
    if (ROOM_BLOCK_SECRET_FLAG == 0)
        return 0;
    return roomrt_trigger_shutters();
}

unsigned int roomrt_check_secret_trigger_ringleader(void) {
    signed char i;
    unsigned char first = ROOM_OBJ_TYPE(0);
    if (first != 0 && first < 0x53)
        return 0;
    for (i = (signed char)ROOM_MAX_MONSTER_SLOT; i >= 0; i--) {
        unsigned char slot = (unsigned char)i;
        unsigned char obj = ROOM_OBJ_TYPE(slot);
        if (obj == 0 || obj >= 0x53)
            continue;
        if (ROOM_OBJ_STUN_TIMER(slot) != 0)
            continue;
        ROOM_OBJ_STUN_TIMER(slot) = 16;
    }
    return CARRY_SET;
}

void roomrt_touch_door_bombable(void) {
    if (ROOM_TOUCH_DOOR_BITS & CUR_OPENED_DOORS)
        return;
    roomrt_touch_door_wall();
}

void roomrt_block_until_time(void) {
    if (CURTAIN_TIMER != 0)
        roomrt_block_at_wall();
}

unsigned int roomrt_touch_door_false(void) {
    unsigned char timer = CURTAIN_TIMER;
    if (timer == 1)
        return CARRY_SET;
    if (timer == 0)
        CURTAIN_TIMER = 24;
    roomrt_touch_door_wall();
    return 0;
}

void roomrt_touch_door_shutter(void) {
    unsigned char door_bits;
    if (ROOM_OPEN_DOOR_TIMER != 0) {
        roomrt_touch_door_wall();
        return;
    }
    door_bits = ROOM_TOUCH_DOOR_BITS & CUR_OPENED_DOORS;
    if (!door_bits) {
        roomrt_touch_door_wall();
        return;
    }
    if (door_bits & ROOM_SHUTTER_TOUCH_MASK) {
        roomrt_block_until_time();
        return;
    }
    ROOM_SHUTTER_TOUCH_MASK |= ROOM_TOUCH_DOOR_BITS;
}

/* ---- Plan C: drained from z_07 ----------------------------------------- */

void roomrt_hide_all_sprites(void) {
    for (unsigned char i = 0; i < 64; i++)
        ROOM_OAM_BYTE((unsigned short)i * 4) = 0xF8;
}

unsigned char roomrt_get_unique_room_id(void) {
    unsigned char room = CUR_ROOM_ID;
    return nes_ram[NES_SRAM_BASE + NES_SRAM_ROOM_UNIQUE_ID_BASE + room] & 0x3F;
}

void roomrt_clear_room_history(void) {
    ROOM_HISTORY_IDX = 0;
    for (signed char i = 5; i >= 0; i--)
        ROOM_HISTORY((unsigned char)i) = 0;
}

void roomrt_reset_player_state(void) {
    LINK_ACTION_TIMER = 0;
    LINK_HALT_FLAG = 0;
}

void roomrt_mark_room_visited(void) {
    unsigned char flags = roomrt_get_room_flags();
    unsigned short ptr = ((unsigned short)SAVEFILE_PTR_HI << 8) | SAVEFILE_PTR_LO;
    flags |= 0x20;
    nes_ram[ptr + CUR_ROOM_ID] = flags;
}

void roomrt_check_screen_edge(void) {
    unsigned int dir_info;
    unsigned char dir_idx;
    unsigned char single_dir;
    unsigned char coord;

    if (ROOM_INPUT_DIR == 0)
        return;

    dir_info = corert_get_opposite_dir(ROOM_INPUT_DIR);
    dir_idx = (unsigned char)(dir_info >> 8);
    single_dir = roomrt_reverse_directions[dir_idx];
    coord = LINK_Y;
    if ((single_dir & 0x0C) == 0)
        coord = LINK_X;

    if (coord != roomrt_player_screen_edge_bounds[dir_idx])
        return;

    LINK_DIR = single_dir;
    c_go_to_next_mode_from_play();
}
