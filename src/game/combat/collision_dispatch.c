/* collision_dispatch.c — native collision subsystem dispatch (Phase 4).
 *
 * Drain MATCH per drain in src/oracle/combat/collision_runtime.c
 * (verified-by-use; in production via Title.md gameplay).
 */

#include "collision_dispatch.h"
#include <stdint.h>
#include "platform_abi.h"
#include "combat_state.h"      /* COMBAT_*, COMBAT_HITBOX_X/Y, COMBAT_THRESHOLD_X/Y, COMBAT_COLLIDED, COMBAT_ABS_DX/DY, COMBAT_PART_INDEX */
#include "enemy_state.h"       /* ENEMY_GLEEOK_NECK_Y_PTR_LO/HI, ENEMY_COLLIDED_TILE, ENEMY_DARK_ROOM_FLAG, ENEMY_CANDLE_ROOM_ID, ENEMY_PLAYER_OBJ_X/Y */
#include "object_state.h"      /* OBJ_TILE_X/_Y */

/* NES Z_07.asm PlayAreaColumnAddrs (line 336): 32 LE 16-bit pointers
 * pointing into nes_ram (SRAM range $6500..$67DA). Baked inline. */
static const unsigned char k_play_area_column_addrs[64] = {
    0x30u, 0x65u, 0x46u, 0x65u, 0x5Cu, 0x65u, 0x72u, 0x65u,
    0x88u, 0x65u, 0x9Eu, 0x65u, 0xB4u, 0x65u, 0xCAu, 0x65u,
    0xE0u, 0x65u, 0xF6u, 0x65u, 0x0Cu, 0x66u, 0x22u, 0x66u,
    0x38u, 0x66u, 0x4Eu, 0x66u, 0x64u, 0x66u, 0x7Au, 0x66u,
    0x90u, 0x66u, 0xA6u, 0x66u, 0xBCu, 0x66u, 0xD2u, 0x66u,
    0xE8u, 0x66u, 0xFEu, 0x66u, 0x14u, 0x67u, 0x2Au, 0x67u,
    0x40u, 0x67u, 0x56u, 0x67u, 0x6Cu, 0x67u, 0x82u, 0x67u,
    0x98u, 0x67u, 0xAEu, 0x67u, 0xC4u, 0x67u, 0xDAu, 0x67u
};

/* NES Z_07.asm WalkableTiles (line 2099): 9 bytes. */
static const unsigned char k_walkable_tiles[9] = {
    0x8Du, 0x91u, 0x9Cu, 0xACu, 0xADu, 0xCCu, 0xD2u, 0xD5u, 0xDFu
};

unsigned char collision_do_objects_collide_with_thresholds(void)
{
    /* drain at collision_runtime.c:8-28. */
    COMBAT_COLLIDED = 0u;
    {
        const unsigned char dx =
            (unsigned char)(ENEMY_GLEEOK_NECK_Y_PTR_LO - COMBAT_HITBOX_X);
        const unsigned char abs_dx =
            (dx & 0x80u) ? (unsigned char)((~dx + 1u) & 0xFFu) : dx;
        COMBAT_ABS_DX = abs_dx;
        if (abs_dx >= COMBAT_THRESHOLD_X) {
            return COMBAT_COLLIDED;
        }
    }
    {
        const unsigned char dy =
            (unsigned char)(ENEMY_GLEEOK_NECK_Y_PTR_HI - COMBAT_HITBOX_Y);
        const unsigned char abs_dy =
            (dy & 0x80u) ? (unsigned char)((~dy + 1u) & 0xFFu) : dy;
        COMBAT_ABS_DY = abs_dy;
        if (abs_dy >= COMBAT_THRESHOLD_Y) {
            return COMBAT_COLLIDED;
        }
    }
    COMBAT_COLLIDED = (uint8_t)(COMBAT_COLLIDED + 1u);
    return COMBAT_COLLIDED;
}

unsigned char collision_do_objects_collide(unsigned int threshold)
{
    /* drain at collision_runtime.c:30-34. */
    COMBAT_THRESHOLD_X = (uint8_t)threshold;
    COMBAT_THRESHOLD_Y = (uint8_t)threshold;
    return collision_do_objects_collide_with_thresholds();
}

unsigned char collision_get_collidable_tile(unsigned int hotspot_offset,
                                            unsigned int slot)
{
    /* drain at collision_runtime.c:239-308. NES GetCollidableTile. */
    static const unsigned char walkable_count = 9u;
    COMBAT_HITBOX_X = (uint8_t)hotspot_offset;
    const unsigned char y_pos = (unsigned char)OBJ_TILE_Y(slot);
    const unsigned char adjusted_y = (uint8_t)(y_pos + 0x0Bu);
    const unsigned char dir = COMBAT_PART_INDEX;

    unsigned char tile_y = adjusted_y;
    unsigned char tile_x;

    if (dir & 0x0Cu) {
        if (dir & 0x04u) {
            if (adjusted_y < 0xDDu) {
                tile_y =
                    (uint8_t)(adjusted_y + (unsigned char)hotspot_offset);
            }
        } else {
            tile_y = (uint8_t)(adjusted_y + (unsigned char)hotspot_offset);
        }
        tile_x = (unsigned char)OBJ_TILE_X(slot);
    } else {
        tile_x = (unsigned char)OBJ_TILE_X(slot);
        if (dir & 0x01u) {
            if (tile_x < 0xF0u) {
                tile_x = (uint8_t)(tile_x + (unsigned char)hotspot_offset);
            }
        } else {
            if (tile_x >= 0x10u) {
                tile_x = (uint8_t)(tile_x + (unsigned char)hotspot_offset);
            }
        }
    }

    const unsigned char col_idx = (unsigned char)((tile_x & 0xF8u) >> 2);
    const unsigned short col_addr =
        (unsigned short)(((unsigned short)k_play_area_column_addrs[col_idx]) |
                         ((unsigned short)k_play_area_column_addrs[col_idx + 1u] << 8));

    const unsigned char row_idx = (unsigned char)((tile_y - 0x40u) >> 3);

    unsigned char tile = (unsigned char)nes_ram[col_addr + row_idx];
    ENEMY_COLLIDED_TILE(slot) = tile;

    if (dir & 0x0Cu) {
        const unsigned char next_row = (uint8_t)(row_idx + 0x16u);
        const unsigned char next_tile =
            (unsigned char)nes_ram[col_addr + next_row];
        if (next_tile >= tile) {
            RAM(0x049E + slot) = next_tile;
        }
    }

    tile = (unsigned char)ENEMY_COLLIDED_TILE(slot);

    if (ENEMY_DARK_ROOM_FLAG == 0u) {
        tile = (unsigned char)ENEMY_COLLIDED_TILE(slot);
        for (signed char i = (signed char)(walkable_count - 1u); i >= 0; i--) {
            if (tile == k_walkable_tiles[i]) {
                tile = 0x26u;
                break;
            }
        }
        ENEMY_COLLIDED_TILE(slot) = tile;

        if (slot == 0u) {
            if (ENEMY_CANDLE_ROOM_ID == 0x1Fu) {
                if (dir & 0x0Cu) {
                    if (ENEMY_PLAYER_OBJ_X == 0x80u &&
                        ENEMY_PLAYER_OBJ_Y < 0x56u) {
                        ENEMY_COLLIDED_TILE(0) = 0x26u;
                    }
                }
            }
        }
    }

    return (unsigned char)ENEMY_COLLIDED_TILE(slot);
}

unsigned char collision_get_collidable_tile_still(unsigned int slot)
{
    /* drain at collision_runtime.c:310-313. */
    COMBAT_PART_INDEX = 0u;
    return collision_get_collidable_tile(0u, slot);
}

unsigned char collision_get_colliding_tile_moving(unsigned int slot)
{
    /* drain at collision_runtime.c:315-330. */
    unsigned char hotspot;
    if (slot == 0u) {
        hotspot = 0xF8u;
    } else {
        hotspot = 0xF0u;
    }
    const unsigned char dir = COMBAT_PART_INDEX;
    if (dir & 0x05u) {
        if (dir & 0x04u) {
            hotspot = 8u;
        } else {
            hotspot = 16u;
        }
    }
    return collision_get_collidable_tile(hotspot, slot);
}
