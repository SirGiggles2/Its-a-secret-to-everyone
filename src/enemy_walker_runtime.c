#include "enemy_runtime_private.h"

/* Block-push family uses three room-state cells. Pull them in directly
 * to avoid including room_state.h here, which would re-include
 * world_state.h and redefine the LINK_X/LINK_Y macros from enemy_state.h.
 */
#define ROOM_MONSTER_ALL_DEAD          RAM(0x034D)
#define ROOM_INPUT_DIR                 RAM(0x03F8)
#define ROOM_BLOCK_SECRET_FLAG         RAM(0x04CF)

static void enrt_octorock_common(unsigned int slot, unsigned char speed) {
    ENEMY_WALK_SPEED(slot) = speed;
    ENEMY_MOVE_TIMER(slot) = (unsigned char)((slot + 1u) << 4);
    (void)z07_reset_obj_state(slot);
    ENEMY_DRAW_FRAME(slot) = 0;
    ENEMY_ANIM_TIMER(slot) = 6;
    enrt_init_walker(slot);
}

void enrt_update_bubble(unsigned int slot) {
    wanderer_update_common(64, slot);
    {
        unsigned char obj_type = ENEMY_TYPE(slot);
        unsigned char palette;
        if (obj_type == 0x2B) {
            palette = ENEMY_CUR_SPRITE_ATTR_ROW & 3;
        } else {
            palette = obj_type - 0x2B;
        }
        z01_anim_set_sprite_desc_attrs(palette);
    }
    enrt_animate_and_draw_common_object(1, slot);
    z01_check_link_collision(slot);
    if (!ENEMY_COLLISION_FLAG)
        return;
    if (ENEMY_TYPE(slot) == 0x2B) {
        ENEMY_BUBBLE_EFFECT = 16;
        return;
    }
    ENEMY_BUBBLE_STATUS = (unsigned char)(ENEMY_TYPE(slot) - 0x2C);
}

void enrt_init_leever(unsigned int slot) {
    ENEMY_LEEVER_TIMER = 5;
    z07_reset_obj_metastate_and_timer(slot);
}

void enrt_init_walker(unsigned int slot) {
    if (ENEMY_DIR(slot) != 0)
        return;
    {
        unsigned char link_x = LINK_X;
        unsigned char obj_x = ENEMY_X(slot);
        unsigned char diff_x = (unsigned char)(link_x - obj_x);
        unsigned char h_dir = (link_x >= obj_x) ? 2u : 1u;
        ENEMY_SHOT_TYPE_SCRATCH = diff_x;
        ENEMY_SCRATCH_Y = h_dir;
        ENEMY_DIR(slot) = h_dir;
    }
    {
        unsigned char link_y = LINK_Y;
        unsigned char obj_y = ENEMY_Y(slot);
        unsigned char diff_y = (unsigned char)(link_y - obj_y);
        unsigned char v_dir = (link_y >= obj_y) ? 4u : 8u;
        ENEMY_DIR(slot) = v_dir;
        if (diff_y < ENEMY_SHOT_TYPE_SCRATCH)
            return;
    }
    ENEMY_DIR(slot) = ENEMY_SCRATCH_Y;
}

void enrt_init_bubble(unsigned int slot) {
    ENEMY_WALK_SPEED(slot) = 64;
    enrt_init_walker(slot);
}

void enrt_init_rope(unsigned int slot) {
    ENEMY_CHARGE_SPEED(slot) = 16;
    if (SAVE_SLOT_QUEST(SAVE_SLOT_INDEX) != 0)
        ENEMY_CHARGE_SPEED(slot) = 64;
    enrt_init_walker(slot);
}

void enrt_init_darknut(unsigned int slot) {
    ENEMY_INVINCIBILITY(slot) = 0xF6;
    ENEMY_WALK_SPEED(slot) = (ENEMY_TYPE(slot) == 0x0B) ? 32u : 40u;
    enrt_init_walker(slot);
}

void enrt_init_slow_octorock_or_ghini(unsigned int slot) {
    enrt_octorock_common(slot, 32);
}

void enrt_init_fast_octorock(unsigned int slot) {
    enrt_octorock_common(slot, 48);
}

void enrt_init_gel(unsigned int slot) {
    ENEMY_STATE_TIMER(slot) = 2;
    enrt_init_walker(slot);
}

void enrt_update_rope(unsigned int slot) {
    unsigned char old_dir = ENEMY_DIR(slot);
    ENEMY_PUSH_DIR_SCRATCH(slot) = old_dir;

    if (!(ENEMY_PAUSE_FLAG | ENEMY_STUN_TIMER(slot))) {
        c_walker_move(slot);

        if ((OBJ(NES_OBJ_GRID_OFFSET, slot) & 0x0F) == 0)
            OBJ(NES_OBJ_GRID_OFFSET, slot) = 0;

        if (ENEMY_WALK_SPEED(slot) != 0x60 && ENEMY_MOVE_TIMER(slot) == 0) {
            ENEMY_MOVE_TIMER(slot) = ENEMY_RNG_A(slot) & 0x3F;
            if (OBJ(NES_OBJ_GRID_OFFSET, slot) == 0)
                ENEMY_BLOCKED_FLAG = 0;
        }
    }

    if (ENEMY_DIR(slot) != old_dir)
        ENEMY_WALK_SPEED(slot) = 0x20;

    if (ENEMY_WALK_SPEED(slot) == 0x20 && OBJ(NES_OBJ_GRID_OFFSET, slot) == 0) {
        unsigned char x_dist = z01_abs((unsigned char)(LINK_X - ENEMY_X(slot)));
        if (x_dist < 8) {
            ENEMY_DIR(slot) = 8;
            if (LINK_Y >= ENEMY_Y(slot))
                ENEMY_DIR(slot) >>= 1;
            ENEMY_WALK_SPEED(slot) = 0x60;
        } else {
            unsigned char y_dist = z01_abs((unsigned char)(LINK_Y - ENEMY_Y(slot)));
            if (y_dist < 8) {
                ENEMY_DIR(slot) = 2;
                if (LINK_X >= ENEMY_X(slot))
                    ENEMY_DIR(slot) >>= 1;
                ENEMY_WALK_SPEED(slot) = 0x60;
            }
        }
    }

    z07_anim_advance_and_fetch(10, slot);
    ENEMY_FRAME_FLAGS = (ENEMY_DIR(slot) & 0x02) >> 1;
    z01_anim_set_sprite_desc_attrs(2);

    if (SAVE_SLOT_QUEST(SAVE_SLOT_INDEX) != 0)
        z01_anim_set_sprite_desc_attrs(ENEMY_CUR_SPRITE_ATTR_ROW & 0x03);

    c_draw_object_not_mirrored_with_frame(ENEMY_DRAW_FRAME(slot), slot);
    c_check_monster_collisions(slot);
}

void enrt_update_standing_fire(unsigned int slot) {
    c_check_link_collision(slot);
    z01_anim_set_sprite_desc_attrs(2);
    ENEMY_DIR(slot) = 8;
    z07_animate_object_walking(slot);
    if (ENEMY_TYPE(slot) != 0x40)
        ENEMY_FRAME_FLAGS = 0;
    c_draw_object_not_mirrored_with_frame(0, slot);
}

void enrt_update_zol(unsigned int slot) {
    c_update_zol_state(slot);
    c_zol_check_collisions(slot);
    z07_anim_fetch_obj_pos(slot);
    c_draw_object_mirrored_with_frame((ENEMY_CUR_SPRITE_ATTR_ROW & 0x08) ? 0 : 1, slot);
}

void enrt_update_gel(unsigned int slot) {
    unsigned char orig_x = ENEMY_X(slot);
    c_gel_move(slot);
    c_gel_check_collisions(slot);
    ENEMY_X(slot) = orig_x + 4;
    z07_anim_fetch_obj_pos(slot);
    z01_anim_set_sprite_desc_attrs(3);
    c_draw_object_not_mirrored_with_frame((ENEMY_CUR_SPRITE_ATTR_ROW & 0x02) ? 0 : 1, slot);
    ENEMY_X(slot) = orig_x;
}

void enrt_update_zora(unsigned int slot) {
    if (ENEMY_PAUSE_FLAG)
        return;
    c_update_burrower(slot);
    if (ENEMY_STATE_TIMER(slot) == 3 && ENEMY_MOVE_TIMER(slot) == 0xFD) {
        enrt_shoot_fireball(85, slot);
        ENEMY_MOVE_TIMER(slot) = 32;
    }
    if (ENEMY_STATE_TIMER(slot) == 0) {
        ENEMY_ROOM_MONSTER_FLAG--;
        z07_destroy_monster(slot);
    }
}

/* ---- Plan C: drained from z_07 (walker_alt_dir cluster) --------------- */

extern const unsigned char ReverseDirections[];

unsigned int enrt_walker_alt_dir_get_opposite(void) {
    unsigned char dir = RAM(0x000F);
    if (dir & 0x0A)
        return dir >> 1;
    return (dir << 1) & 0xFF;
}

void enrt_walker_alt_dir_end_loop(void) {
    RAM(0x000E) = 0;
}

unsigned char enrt_walker_alt_dir_get_random_perpendicular(unsigned int slot) {
    unsigned char rnd = nes_ram[0x0018 + slot];
    unsigned char dir = nes_ram[0x0098 + slot];
    unsigned int idx = (rnd & 0x80) ? 0 : 1;
    if (dir & 0x0C) idx += 2;
    return ReverseDirections[idx];
}

/* ---- Plan C: drained from z_04 (block-push family) -------------------- */

/* IMPORT shim into the still-asm ChangeTileObjTiles.
 *   void c_change_tile_obj_tiles(unsigned int tile, unsigned int slot);
 *   D0 = tile, D2 = slot, void return.
 */
extern void c_change_tile_obj_tiles(unsigned int tile, unsigned int slot);
extern void c_move_object(unsigned short slot);

/* BlockPushDirections — index by Y[0..3] (which encodes:
 *   0 = Link below block (push UP)
 *   1 = Link above block (push DOWN)
 *   2 = Link right of block (push LEFT)
 *   3 = Link left of block (push RIGHT))
 * Values are NES dir bits: $08=UP, $04=DOWN, $02=LEFT, $01=RIGHT.
 */
static const unsigned char enrt_block_push_directions[4] = { 0x08, 0x04, 0x02, 0x01 };

/* Forward declarations for state handlers / helpers. */
static void enrt_update_block_0_idle(unsigned int slot);
static void enrt_update_block_1_moving(unsigned int slot);
static void enrt_update_block_2_done(unsigned int slot);
void enrt_draw_block(unsigned int slot);

/* Dispatcher: replaces the 6502 jump-table at UpdateBlock_JumpTable. */
void enrt_update_block(unsigned int slot) {
    unsigned char state = ENEMY_STATE_TIMER(slot) & 0x03;
    switch (state) {
        case 0: enrt_update_block_0_idle(slot); break;
        case 1: enrt_update_block_1_moving(slot); break;
        case 2: enrt_update_block_2_done(slot); break;
        default: break;  /* state 3 unreachable in original code */
    }
}

/* DrawBlock — fetch sprite descriptor pos, decrement Y by 1, draw. */
void enrt_draw_block(unsigned int slot) {
    z07_anim_fetch_obj_pos(slot);
    RAM(0x0001) = (unsigned char)(RAM(0x0001) - 1);
    c_draw_object_not_mirrored_with_frame(0, slot);
}

/* UpdateBlock0Idle — watch for Link pushing the block from a cardinal
 * direction. After enough push frames at a valid alignment+direction,
 * advance to state 1 and clear the source tile.
 */
static void enrt_update_block_0_idle(unsigned int slot) {
    /* If room still has live monsters, blocks can't be pushed. */
    if (ROOM_MONSTER_ALL_DEAD != 0) {
        enrt_reset_push_timer(slot);
        return;
    }

    unsigned char link_x = LINK_X;
    unsigned char obj_x = ENEMY_X(slot);
    unsigned char link_y = LINK_Y;
    unsigned char obj_y = ENEMY_Y(slot);
    unsigned char dir_idx;
    unsigned char diff;

    if (link_x == obj_x) {
        /* X-aligned: Link is directly above or below the block.
         * Diff in Y selects up/down direction.  base index = 0.
         */
        dir_idx = 0;
        diff = (unsigned char)((unsigned char)(link_y + 3) - obj_y);
    } else {
        /* Not X-aligned: require strict Y-alignment with link_y+3. */
        if ((unsigned char)(link_y + 3) != obj_y) {
            enrt_reset_push_timer(slot);
            return;
        }
        /* Y-aligned: Link is directly left or right.  base index = 2. */
        dir_idx = 2;
        diff = (unsigned char)(link_x - obj_x);
    }

    /* If diff is negative (Link up/left of block), bump direction index
     * to the opposite half of the table and use absolute distance.
     */
    if ((signed char)diff < 0) {
        dir_idx++;
        diff = (unsigned char)(-(signed char)diff);
    }

    /* Too far to count as a push attempt. */
    if (diff >= 0x11) {
        enrt_reset_push_timer(slot);
        return;
    }

    /* Input direction must match the cardinal Link is pushing toward. */
    unsigned char input_dir = ROOM_INPUT_DIR;
    unsigned char need_dir = enrt_block_push_directions[dir_idx];
    if (input_dir != need_dir) {
        enrt_reset_push_timer(slot);
        return;
    }

    /* Link is pushing in the right direction — accumulate push frames. */
    ENEMY_PUSH_TIMER(slot) = (unsigned char)(ENEMY_PUSH_TIMER(slot) + 1);
    if (ENEMY_PUSH_TIMER(slot) < 0x10) {
        return;
    }

    /* Push completed: lock direction, advance state, bump pushed-count
     * counter at $00F7, blank the source tile.
     */
    ENEMY_DIR(slot) = input_dir;
    ENEMY_STATE_TIMER(slot) = (unsigned char)(ENEMY_STATE_TIMER(slot) + 1);
    RAM(0x00F7) = (unsigned char)(RAM(0x00F7) + 1);
    c_change_tile_obj_tiles(116u, slot);
}

/* UpdateBlock1Moving — slide block one tile in its locked direction. */
static void enrt_update_block_1_moving(unsigned int slot) {
    unsigned char dir = ENEMY_DIR(slot);
    RAM(0x000F) = dir;
    c_move_object((unsigned short)slot);
    enrt_draw_block(slot);

    unsigned char grid_off = OBJ(0x0394, slot);
    /* Original: if grid_off != 0x10 AND grid_off != 0xF0, jmp UpdateBlock2Done (rts). */
    if (grid_off != 0x10 && grid_off != 0xF0) {
        return;
    }

    /* Block has slid the full tile-width: play secret-found tune,
     * drop the destination block tile, advance state, bump
     * ROOM_BLOCK_SECRET_FLAG so the room knows a push completed.
     */
    enrt_play_secret_found_tune();
    RAM(0x00F7) = (unsigned char)(RAM(0x00F7) + 1);
    c_change_tile_obj_tiles(0xB0u, slot);
    ENEMY_STATE_TIMER(slot) = (unsigned char)(ENEMY_STATE_TIMER(slot) + 1);
    ROOM_BLOCK_SECRET_FLAG = (unsigned char)(ROOM_BLOCK_SECRET_FLAG + 1);
}

/* UpdateBlock2Done — block has been pushed; nothing else to do. */
static void enrt_update_block_2_done(unsigned int slot) {
    (void)slot;
}
