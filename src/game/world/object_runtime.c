#include "object_runtime.h"

static void objrt_reset_moving_dir_if_mask(unsigned char dir_bit) {
    if (RAM(NES_OBJ_DIR) & dir_bit)
        RAM(NES_OBJ_DIR) = 0;
}

void objrt_move_object(unsigned short slot) {
    unsigned char pos_limit, neg_limit;
    unsigned char dir, old_frac, frac, speed, grid_off, step;
    int i;

    if (slot == 0) {
        pos_limit = 0x08;
        neg_limit = 0xF8;
    } else {
        pos_limit = 0x10;
        neg_limit = 0xF0;
    }
    RAM(NES_POS_GRID_LIMIT) = pos_limit;
    RAM(NES_NEG_GRID_LIMIT) = neg_limit;

    dir = RAM(NES_OBJ_DIR);
    if (dir == 0)
        return;

    for (i = 0; i < 4; i++) {
        if (dir & 0x01) {
            old_frac = OBJ(NES_OBJ_POS_FRAC, slot);
            frac = (unsigned char)(old_frac + OBJ(NES_OBJ_QSPD_FRAC, slot));
            step = (frac < old_frac) ? 1 : 0;
            OBJ(NES_OBJ_POS_FRAC, slot) = frac;
            grid_off = OBJ(NES_OBJ_GRID_OFFSET, slot);
            if (grid_off == RAM(NES_POS_GRID_LIMIT) || grid_off == RAM(NES_NEG_GRID_LIMIT))
                step = 0;
            OBJ(NES_OBJ_GRID_OFFSET, slot) = (unsigned char)(grid_off + step);
            OBJ(NES_OBJ_X, slot) += step;
        } else if (dir & 0x02) {
            old_frac = OBJ(NES_OBJ_POS_FRAC, slot);
            speed = OBJ(NES_OBJ_QSPD_FRAC, slot);
            step = (old_frac < speed) ? 1 : 0;
            frac = (unsigned char)(old_frac - speed);
            OBJ(NES_OBJ_POS_FRAC, slot) = frac;
            grid_off = OBJ(NES_OBJ_GRID_OFFSET, slot);
            if (grid_off == RAM(NES_POS_GRID_LIMIT) || grid_off == RAM(NES_NEG_GRID_LIMIT))
                step = 0;
            OBJ(NES_OBJ_GRID_OFFSET, slot) = (unsigned char)(grid_off - step);
            OBJ(NES_OBJ_X, slot) -= step;
        } else if (dir & 0x04) {
            old_frac = OBJ(NES_OBJ_POS_FRAC, slot);
            frac = (unsigned char)(old_frac + OBJ(NES_OBJ_QSPD_FRAC, slot));
            step = (frac < old_frac) ? 1 : 0;
            OBJ(NES_OBJ_POS_FRAC, slot) = frac;
            grid_off = OBJ(NES_OBJ_GRID_OFFSET, slot);
            if (grid_off == RAM(NES_POS_GRID_LIMIT) || grid_off == RAM(NES_NEG_GRID_LIMIT))
                step = 0;
            OBJ(NES_OBJ_GRID_OFFSET, slot) = (unsigned char)(grid_off + step);
            OBJ(NES_OBJ_Y, slot) += step;
        } else {
            old_frac = OBJ(NES_OBJ_POS_FRAC, slot);
            speed = OBJ(NES_OBJ_QSPD_FRAC, slot);
            step = (old_frac < speed) ? 1 : 0;
            frac = (unsigned char)(old_frac - speed);
            OBJ(NES_OBJ_POS_FRAC, slot) = frac;
            grid_off = OBJ(NES_OBJ_GRID_OFFSET, slot);
            if (grid_off == RAM(NES_POS_GRID_LIMIT) || grid_off == RAM(NES_NEG_GRID_LIMIT))
                step = 0;
            OBJ(NES_OBJ_GRID_OFFSET, slot) = (unsigned char)(grid_off - step);
            OBJ(NES_OBJ_Y, slot) -= step;
        }
    }
}

void objrt_bound_direction_horizontally(unsigned int slot) {
    unsigned char x = RAM(NES_OBJ_X + slot);
    RAM(NES_TMP0) = x;
    if (slot != 0 && (slot >= 0x0D || RAM(NES_OBJ_TYPE + slot) == 0x5C))
        RAM(NES_TMP0) = (unsigned char)(x + 0x0B);
    if (RAM(NES_TMP0) < RAM(NES_BOUND_LEFT)) {
        objrt_reset_moving_dir_if_mask(2);
        return;
    }
    if (slot != 0 && (slot >= 0x0D || RAM(NES_OBJ_TYPE + slot) == 0x5C))
        RAM(NES_TMP0) = (unsigned char)(RAM(NES_TMP0) - 0x17);
    if (RAM(NES_TMP0) >= RAM(NES_BOUND_RIGHT))
        objrt_reset_moving_dir_if_mask(1);
}

void objrt_bound_direction_vertically(unsigned int slot) {
    unsigned char y = RAM(NES_OBJ_Y + slot);
    RAM(NES_TMP0) = y;
    if (slot != 0 && (slot >= 0x0D || RAM(NES_OBJ_TYPE + slot) == 0x5C))
        RAM(NES_TMP0) = (unsigned char)(y + 0x0F);
    if (RAM(NES_TMP0) < RAM(NES_BOUND_TOP)) {
        objrt_reset_moving_dir_if_mask(8);
        return;
    }
    if (slot != 0 && (slot >= 0x0D || RAM(NES_OBJ_TYPE + slot) == 0x5C))
        RAM(NES_TMP0) = (unsigned char)(RAM(NES_TMP0) - 0x21);
    if (RAM(NES_TMP0) >= RAM(NES_BOUND_BOTTOM))
        objrt_reset_moving_dir_if_mask(4);
}

unsigned char objrt_bound_by_room(unsigned int slot) {
    objrt_bound_direction_horizontally(slot);
    objrt_bound_direction_vertically(slot);
    return RAM(NES_OBJ_DIR);
}

unsigned char objrt_bound_by_room_with_dir(unsigned char direction, unsigned int slot) {
    RAM(NES_OBJ_DIR) = direction;
    return objrt_bound_by_room(slot);
}

unsigned int objrt_add_q_speed_to_position_fraction(unsigned int slot) {
    unsigned int result = (unsigned int)RAM(NES_OBJ_POS_FRAC + slot) + RAM(NES_OBJ_QSPD_FRAC + slot);
    RAM(NES_OBJ_POS_FRAC + slot) = (unsigned char)result;
    unsigned int carry = result >> 8;
    unsigned char grid = RAM(NES_OBJ_GRID_OFFSET + slot);
    if (grid == RAM(NES_POS_GRID_LIMIT) || grid == RAM(NES_NEG_GRID_LIMIT))
        carry = 0;
    RAM(NES_OBJ_GRID_OFFSET + slot) = (unsigned char)(grid + (unsigned char)carry);
    return carry ? CARRY_SET : 0u;
}

unsigned int objrt_sub_q_speed_from_position_fraction(unsigned int slot) {
    unsigned int frac = RAM(NES_OBJ_POS_FRAC + slot);
    unsigned int sub_val = RAM(NES_OBJ_QSPD_FRAC + slot);
    unsigned int borrow = (frac < sub_val) ? 1u : 0u;
    RAM(NES_OBJ_POS_FRAC + slot) = (unsigned char)(frac - sub_val);
    unsigned char grid = RAM(NES_OBJ_GRID_OFFSET + slot);
    if (grid == RAM(NES_POS_GRID_LIMIT) || grid == RAM(NES_NEG_GRID_LIMIT))
        return 0u;
    RAM(NES_OBJ_GRID_OFFSET + slot) = (unsigned char)(grid - (unsigned char)borrow);
    return borrow ? 0u : CARRY_SET;
}

void objrt_move_shot(unsigned char direction, unsigned int slot) {
    unsigned char dir_result = objrt_bound_by_room_with_dir(direction, slot);
    if (dir_result == 0) {
        RAM(NES_SHOT_COLLISION_FLAG) = 0x80;
        return;
    }
    unsigned char saved_offset = RAM(NES_OBJ_GRID_OFFSET + slot);
    RAM(NES_OBJ_GRID_OFFSET + slot) = 0;
    objrt_move_object((unsigned short)slot);
    unsigned char new_offset = RAM(NES_OBJ_GRID_OFFSET + slot);
    if (RAM(NES_SHOT_COLLISION_FLAG) == 0)
        RAM(NES_OBJ_GRID_OFFSET + slot) = (unsigned char)(saved_offset + new_offset);
    else
        RAM(NES_OBJ_GRID_OFFSET + slot) = saved_offset;
}
