#include "enemy_runtime_private.h"
#include "legacy_bridge.h"

/* Block-push family uses three room-state cells. Pull them in directly
 * to avoid including room_state.h here, which would re-include
 * world_state.h and redefine the LINK_X/LINK_Y macros from enemy_state.h.
 */
#define ROOM_MONSTER_ALL_DEAD          RAM(0x034D)
#define ROOM_INPUT_DIR                 RAM(0x03F8)
#define ROOM_BLOCK_SECRET_FLAG         RAM(0x04CF)

/* Wallmaster scratch alias reused by enrt_draw_block (WALLMASTER_MAJOR_MINOR_MIN
 * is decremented for the block Y-offset trick).
 */
#define WALLMASTER_MAJOR_MINOR_MIN     RAM(0x0001)  /* major coord minimum value  */


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
    WALLMASTER_MAJOR_MINOR_MIN = (unsigned char)(WALLMASTER_MAJOR_MINOR_MIN - 1);
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
    RAM(0x00F7) = (unsigned char)(RAM(0x00F7) + 1);  /* block-push counter */
    c_change_tile_obj_tiles(116u, slot);
}

/* UpdateBlock1Moving — slide block one tile in its locked direction. */
static void enrt_update_block_1_moving(unsigned int slot) {
    unsigned char dir = ENEMY_DIR(slot);
    ENEMY_FRAME_FLAGS = dir;
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
    RAM(0x00F7) = (unsigned char)(RAM(0x00F7) + 1);  /* block-push counter */
    c_change_tile_obj_tiles(0xB0u, slot);
    ENEMY_STATE_TIMER(slot) = (unsigned char)(ENEMY_STATE_TIMER(slot) + 1);
    ROOM_BLOCK_SECRET_FLAG = (unsigned char)(ROOM_BLOCK_SECRET_FLAG + 1);
}

/* UpdateBlock2Done — block has been pushed; nothing else to do. */
static void enrt_update_block_2_done(unsigned int slot) {
    (void)slot;
}
