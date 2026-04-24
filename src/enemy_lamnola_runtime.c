#include "enemy_runtime_private.h"
#include "combat_state.h"
#include "room_state.h"
#include "sprite_state.h"


static unsigned char enrt_rotate_dir_right(unsigned char dir) {
    dir = (unsigned char)(dir >> 1);
    if (dir == 0)
        dir = 8;
    return dir;
}

void enrt_init_lamnola(unsigned int slot) {
    signed char seg;
    unsigned char type;

    (void)slot;

    for (seg = 9; seg >= 0; --seg) {
        unsigned char uidx = (unsigned char)seg;
        RAM(0x0071u + uidx) = 64;
        RAM(0x0085u + uidx) = 0x8D;
        RAM(0x0099u + uidx) = 0;
        RAM(0x0406u + uidx) = 0;
        RAM(0x0493u + uidx) = 0;
        RAM(0x04C0u + uidx) = RAM(0x04C0u);
        RAM(0x0486u + uidx) = RAM(0x0486u);
        RAM(0x0350u + uidx) = RAM(0x0350u);
    }

    RAM(0x009Du) = 8;
    RAM(0x0385u) = 8;
    RAM(0x00A2u) = 8;
    RAM(0x038Au) = 8;

    type = RAM(0x0350u);
    ENEMY_LAMNOLA_TYPE = type;
    ENEMY_LAMNOLA_SPEED = (unsigned char)(type - 0x39u);

    RAM(0x034Eu) = 8;
}

void enrt_lamnola_update_head(unsigned int slot) {
    unsigned char cur_dir;
    unsigned char chosen_dir;
    unsigned char rng;
    unsigned char horiz_dir;
    unsigned char vert_dir;
    unsigned char tile;
    unsigned char i;
    unsigned char chain_slot = 0;

    if ((ENEMY_X(slot) & 0x07) != 0)
        return;
    if ((((unsigned char)(ENEMY_Y(slot) + 3)) & 0x07) != 0)
        return;

    if (slot != 5)
        chain_slot = 5;
    for (i = 0; i < 4; ++i, ++chain_slot)
        ENEMY_MANHANDLA_SEG_DIR(chain_slot) = OBJ(0x009A, chain_slot);

    if ((ENEMY_X(slot) & 0x0F) != 0)
        return;
    if ((((unsigned char)(ENEMY_Y(slot) + 3)) & 0x0F) != 0)
        return;

    cur_dir = ENEMY_DIR(slot);
    ENEMY_LAMNOLA_VIABLE_DIR_MASK = (unsigned char)(0x0Fu ^ c_get_opposite_dir(cur_dir));

    if (ENEMY_RNG_A(slot) < 0x80) {
        horiz_dir = 1;
        if (ENEMY_PLAYER_OBJ_X < ENEMY_X(slot))
            horiz_dir = 2;
        vert_dir = 4;
        if (ENEMY_PLAYER_OBJ_Y < ENEMY_Y(slot))
            vert_dir = 8;
        chosen_dir = horiz_dir;
        if ((ENEMY_LAMNOLA_VIABLE_DIR_MASK & horiz_dir) == 0
         || (ENEMY_DIR(slot) & horiz_dir) == 0)
            chosen_dir = vert_dir;
    } else {
        chosen_dir = cur_dir;
        rng = ENEMY_RNG_B(slot);
        if (rng < 0x80) {
            for (;;) {
                chosen_dir = enrt_rotate_dir_right(chosen_dir);
                if ((ENEMY_LAMNOLA_VIABLE_DIR_MASK & chosen_dir) == 0)
                    continue;
                if (rng >= 0x40)
                    break;
                rng = 0x40;
            }
        }
    }

    for (;;) {
        ENEMY_DIR(slot) = chosen_dir;
        ENEMY_JUMPER_BLOCKED_FLAG = chosen_dir;
        if (c_bound_by_room(slot) != 0) {
            tile = c_get_colliding_tile_moving(slot);
            if (tile < ENEMY_DUNGEON_TILE_FLOOR)
                return;
        }

        chosen_dir = enrt_rotate_dir_right(chosen_dir);
        if ((ENEMY_LAMNOLA_VIABLE_DIR_MASK & chosen_dir) == 0)
            continue;
    }
}

void enrt_lamnola_move(unsigned int slot) {
    unsigned char dir = ENEMY_DIR(slot);
    unsigned char step = ENEMY_LAMNOLA_SPEED;

    if (dir & 0x01)
        ENEMY_X(slot) = (unsigned char)(ENEMY_X(slot) + step);
    if (dir & 0x02)
        ENEMY_X(slot) = (unsigned char)(ENEMY_X(slot) - step);
    if (dir & 0x04)
        ENEMY_Y(slot) = (unsigned char)(ENEMY_Y(slot) + step);
    if (dir & 0x08)
        ENEMY_Y(slot) = (unsigned char)(ENEMY_Y(slot) - step);
}
