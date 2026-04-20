#include "nes_abi.h"

void c_move_object(unsigned short slot) {
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
            /* Right: add_qspeed, apply to ObjX */
            old_frac = OBJ(NES_OBJ_POS_FRAC, slot);
            frac = (unsigned char)(old_frac + OBJ(NES_OBJ_QSPD_FRAC, slot));
            step = (frac < old_frac) ? 1 : 0;
            OBJ(NES_OBJ_POS_FRAC, slot) = frac;
            grid_off = OBJ(NES_OBJ_GRID_OFFSET, slot);
            if (grid_off == pos_limit || grid_off == neg_limit)
                step = 0;
            OBJ(NES_OBJ_GRID_OFFSET, slot) = (unsigned char)(grid_off + step);
            OBJ(NES_OBJ_X, slot) += step;
        } else if (dir & 0x02) {
            /* Left: sub_qspeed, apply to ObjX */
            old_frac = OBJ(NES_OBJ_POS_FRAC, slot);
            speed = OBJ(NES_OBJ_QSPD_FRAC, slot);
            step = (old_frac < speed) ? 1 : 0;
            frac = (unsigned char)(old_frac - speed);
            OBJ(NES_OBJ_POS_FRAC, slot) = frac;
            grid_off = OBJ(NES_OBJ_GRID_OFFSET, slot);
            if (grid_off == pos_limit || grid_off == neg_limit)
                step = 0;
            OBJ(NES_OBJ_GRID_OFFSET, slot) = (unsigned char)(grid_off - step);
            OBJ(NES_OBJ_X, slot) -= step;
        } else if (dir & 0x04) {
            /* Down: add_qspeed, apply to ObjY */
            old_frac = OBJ(NES_OBJ_POS_FRAC, slot);
            frac = (unsigned char)(old_frac + OBJ(NES_OBJ_QSPD_FRAC, slot));
            step = (frac < old_frac) ? 1 : 0;
            OBJ(NES_OBJ_POS_FRAC, slot) = frac;
            grid_off = OBJ(NES_OBJ_GRID_OFFSET, slot);
            if (grid_off == pos_limit || grid_off == neg_limit)
                step = 0;
            OBJ(NES_OBJ_GRID_OFFSET, slot) = (unsigned char)(grid_off + step);
            OBJ(NES_OBJ_Y, slot) += step;
        } else {
            /* Up: sub_qspeed, apply to ObjY */
            old_frac = OBJ(NES_OBJ_POS_FRAC, slot);
            speed = OBJ(NES_OBJ_QSPD_FRAC, slot);
            step = (old_frac < speed) ? 1 : 0;
            frac = (unsigned char)(old_frac - speed);
            OBJ(NES_OBJ_POS_FRAC, slot) = frac;
            grid_off = OBJ(NES_OBJ_GRID_OFFSET, slot);
            if (grid_off == pos_limit || grid_off == neg_limit)
                step = 0;
            OBJ(NES_OBJ_GRID_OFFSET, slot) = (unsigned char)(grid_off - step);
            OBJ(NES_OBJ_Y, slot) -= step;
        }
    }
}
