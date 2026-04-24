#include "enemy_runtime_private.h"
#include "sprite_state.h"

/* Block-push family uses three room-state cells. Pull them in directly
 * to avoid including room_state.h here, which would re-include
 * world_state.h and redefine the LINK_X/LINK_Y macros from enemy_state.h.
 */
#define ROOM_MONSTER_ALL_DEAD          RAM(0x034D)
#define ROOM_INPUT_DIR                 RAM(0x03F8)
#define ROOM_BLOCK_SECRET_FLAG         RAM(0x04CF)

/* Wallmaster scratch: RAM[0]..RAM[4] are used as temporaries during the
 * "calc start position" / "patch sprites" flow. They alias the common
 * ENEMY_SCRATCH_X/Y/ENEMY_ATTR_SCRATCH etc. but we name them explicitly
 * here to match the NES comments.
 */
#define WALLMASTER_MINOR_MAJOR_MIN     RAM(0x0000)  /* minor init minor coord (min) */
#define WALLMASTER_MAJOR_MINOR_MIN     RAM(0x0001)  /* major coord minimum value  */
#define WALLMASTER_INSTR_AXIS          RAM(0x0002)  /* axis-decrease direction bit */
#define WALLMASTER_INSTR_MINOR_MIN     RAM(0x0003)  /* init minor distance (major min) */
#define WALLMASTER_INIT_MINOR_COORD    RAM(0x0004)  /* initial minor coord result */

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

/* ---- Plan C: drained from z_04 (Common Wanderer / Goriya family) ------ */

/* IMPORT shim into still-asm _ShootIfWanted (declared in c_shims.asm).
 *   unsigned int c_shoot_if_wanted(type, slot);
 *   Returns 0 on failure; (CARRY_SET | shot_slot) on success.
 */
extern unsigned int c_shoot_if_wanted(unsigned int type, unsigned int slot);

/* IMPORT shim into still-asm Obj_Shove (already-declared in c_wanderer.c).
 *   void c_obj_shove(slot);
 */
extern void c_obj_shove(unsigned int slot);

/* Forward decls so the dispatchers can reference each other. */
void enrt_wanderer_target_player(unsigned int slot);
void enrt_walker_set_input_dir_and_try_shooting_boomerang(unsigned int slot);

/* UpdateCommonWanderer — D0 = turn rate, D2 = slot.
 *   Stores turn rate at $041F+slot, dispatches to shove / pause / target-player.
 *   Mirror of wanderer_update_common in c_wanderer.c (kept in sync; this is
 *   the drained owner now that the asm body is being replaced).
 */
void enrt_update_common_wanderer(unsigned int turn_rate, unsigned int slot) {
    ENEMY_AIR_SPEED(slot) = (unsigned char)turn_rate;
    if (OBJ(0x00C0, slot) != 0) {
        c_obj_shove(slot);
        return;
    }
    if ((ENEMY_PAUSE_FLAG | ENEMY_STUN_TIMER(slot)) != 0)
        return;
    enrt_wanderer_target_player(slot);
}

/* Wanderer_TargetPlayer — turn-toward-player AI for common wanderers.
 *   - Decrement turn timer ($0478) if non-zero.
 *   - Run Walker_Move; bail if being shoved.
 *   - If speed=0 or between-grid, just push input dir = facing dir.
 *   - Else maybe pick a new facing direction toward Link based on RNG and
 *     distance heuristics, set "wants to shoot" flag, then dispatch to the
 *     boomerang/shoot path.
 */
void enrt_wanderer_target_player(unsigned int slot) {
    unsigned char d3_dir = 0;        /* chosen direction once SetDirTowardTarget runs */
    int set_dir = 0;                 /* whether we should set facing/timer/shoot */

    /* Decrement turn timer if non-zero (uses $0478 = ENEMY_BOUNCE_FLAGS cell). */
    if (ENEMY_BOUNCE_FLAGS(slot) != 0) {
        ENEMY_BOUNCE_FLAGS(slot) = (unsigned char)(ENEMY_BOUNCE_FLAGS(slot) - 1);
    }

    c_walker_move(slot);

    /* If being shoved, return (do not chain into SetInputDir). */
    if (OBJ(0x00C0, slot) != 0)
        return;

    /* If speed = 0 or sub-tile grid offset != 0, fall through to SetInputDir. */
    if (ENEMY_WALK_SPEED(slot) == 0)
        goto set_input_dir;
    if ((OBJ(NES_OBJ_GRID_OFFSET, slot) & 0x0F) != 0)
        goto set_input_dir;

    /* Sub-tile aligned: clear grid offset (the masked low nibble was 0). */
    OBJ(NES_OBJ_GRID_OFFSET, slot) = 0;

    /* Compare turn-rate ($041F) to RNG-B ($19): if turn_rate < rng, go check
     * "turn if time" branch. Also if Link state ($00AC) == $FF, go same.
     */
    {
        unsigned char turn_rate = ENEMY_AIR_SPEED(slot);
        unsigned char rng_b     = ENEMY_RNG_B(slot);
        if (turn_rate < rng_b)
            goto turn_if_time;
        if (RAM(0x00AC) == 0xFF)
            goto turn_if_time;
    }

    /* Compute |LINK_X - OBJ_X|. If >= 9, check vertical instead. */
    {
        unsigned char x_dist = z01_abs((unsigned char)(LINK_X - ENEMY_X(slot)));
        if (x_dist < 9) {
            /* Close horizontally: turn vertically toward Link. */
            goto turn_vertically;
        }
    }
    goto check_vertical_distance;

turn_vertically:
    /* Pick D3 = 8 (UP) if LINK_Y < OBJ_Y, 4 (DOWN) if LINK_Y > OBJ_Y;
     * if equal, fall through to check_vertical_distance.
     */
    if (LINK_Y < ENEMY_Y(slot)) {
        d3_dir = 8;
        set_dir = 1;
        goto set_dir_toward_target;
    }
    if (LINK_Y > ENEMY_Y(slot)) {
        d3_dir = 4;
        set_dir = 1;
        goto set_dir_toward_target;
    }
    /* equal: fall through */

check_vertical_distance:
    {
        unsigned char y_dist = z01_abs((unsigned char)(LINK_Y - ENEMY_Y(slot)));
        if (y_dist >= 9)
            goto turn_if_time;
    }
    /* fall through to turn_horizontally */

turn_horizontally:
    /* D3 = 1 (RIGHT) if LINK_X >= OBJ_X, else 2 (LEFT). */
    if (LINK_X >= ENEMY_X(slot))
        d3_dir = 1;
    else
        d3_dir = 2;
    set_dir = 1;
    /* fall through */

set_dir_toward_target:
    if (set_dir) {
        ENEMY_DIR(slot) = d3_dir;
        ENEMY_BOUNCE_FLAGS(slot) = ENEMY_RNG_A(slot);
        ENEMY_PUSH_TIMER(slot) = 1;
    }
    goto set_input_dir;

turn_if_time:
    ENEMY_PUSH_TIMER(slot) = 0;
    if (ENEMY_BOUNCE_FLAGS(slot) != 0)
        goto set_input_dir;
    /* Pick the perpendicular direction: vertical-facing -> turn horizontally,
     * horizontal-facing -> turn vertically.
     */
    if ((ENEMY_DIR(slot) & 0x0C) != 0)
        goto turn_horizontally;
    goto turn_vertically;

set_input_dir:
    enrt_walker_set_input_dir_and_try_shooting_boomerang(slot);
}

/* UpdateGoriya — Goriya/Armos AI: move, then maybe pick a chase direction
 * and shoot a boomerang. Mostly the same shape as Wanderer_TargetPlayer but
 * uses the larger of |dx|, |dy| to gate shooting at distance < $51.
 */
void enrt_update_goriya(unsigned int slot) {
    /* Armos (type $1E) skips the "delaying after shoot" early-out.
     * NOTE: the transpiled asm reads ($0350,A4,D2.W) — i.e. RAM[0x0350+slot]
     * — not the canonical ENEMY_TYPE at 0x034F+slot. Preserve this exact
     * indexing to keep parity with the asm callers; if it turns out to be
     * an off-by-one bug it should be fixed in the transpiler, not here.
     */
    if (OBJ(0x0350, slot) != 0x1E) {
        if ((ENEMY_STATE_TIMER(slot) & 0x80) != 0)
            return;  /* high bit set: monster is in shoot-delay state */
    }

    c_walker_move(slot);

    if (OBJ(0x00C0, slot) != 0)
        return;  /* being shoved */

    /* AfterMove: */
    if (ENEMY_WALK_SPEED(slot) == 0) {
        enrt_walker_set_input_dir_and_try_shooting_boomerang(slot);
        return;
    }
    if ((OBJ(NES_OBJ_GRID_OFFSET, slot) & 0x0F) != 0) {
        enrt_walker_set_input_dir_and_try_shooting_boomerang(slot);
        return;
    }
    OBJ(NES_OBJ_GRID_OFFSET, slot) = 0;
    if (RAM(0x00AC) == 0xFF) {
        enrt_walker_set_input_dir_and_try_shooting_boomerang(slot);
        return;
    }

    /* Build (|dy|, vert_dir) at scratch [0]/[2], (|dx|, horiz_dir) at [1]/[3].
     * vert_dir defaults to 4 (DOWN) — flipped to 8 (UP) if Link is above.
     * horiz_dir defaults to 1 (RIGHT) — flipped to 2 (LEFT) if Link is left.
     */
    {
        unsigned char link_y = LINK_Y;
        unsigned char obj_y  = ENEMY_Y(slot);
        unsigned char vdir   = 4;
        unsigned char a, b;
        if (link_y >= obj_y) {
            a = link_y; b = obj_y;
        } else {
            a = obj_y;  b = link_y;
            vdir <<= 1;  /* 4 -> 8 (UP) */
        }
        RAM(0x0002) = vdir;
        RAM(0x0000) = (unsigned char)(a - b);  /* |dy| */
    }
    {
        unsigned char link_x = LINK_X;
        unsigned char obj_x  = ENEMY_X(slot);
        unsigned char hdir   = 1;
        unsigned char a, b;
        if (link_x >= obj_x) {
            a = link_x; b = obj_x;
        } else {
            a = obj_x;  b = link_x;
            hdir <<= 1;  /* 1 -> 2 (LEFT) */
        }
        RAM(0x0003) = hdir;
        RAM(0x0001) = (unsigned char)(a - b);  /* |dx| */
    }

    /* Pick the larger distance: index 0 if |dy| >= |dx|, else 1. */
    {
        unsigned int idx = (RAM(0x0000) >= RAM(0x0001)) ? 0u : 1u;

        ENEMY_PUSH_TIMER(slot) = 0;

        /* If chosen distance < $51, set "wants to shoot" and face that way. */
        if (RAM(0x0000 + idx) < 0x51) {
            ENEMY_PUSH_TIMER(slot) = (unsigned char)(ENEMY_PUSH_TIMER(slot) + 1);
            ENEMY_DIR(slot) = RAM(0x0002 + idx);
        }
    }

    enrt_walker_set_input_dir_and_try_shooting_boomerang(slot);
}

/* L_Walker_SetInputDirAndTryShootingBoomerang —
 *   Always: input direction ($03F8) := facing direction ($0098).
 *   Goriya only: maybe spawn a boomerang shot tracked by both monster and shot.
 */
void enrt_walker_set_input_dir_and_try_shooting_boomerang(unsigned int slot) {
    /* Set input direction to facing direction. */
    ENEMY_PUSH_DIR_SCRATCH(slot) = ENEMY_DIR(slot);

    {
        unsigned char shot_type = 92;          /* boomerang object type ($5C) */
        unsigned char goriya_kind = ENEMY_TYPE(slot);

        if (goriya_kind != 0x05) {             /* not blue goriya */
            if (goriya_kind != 0x06)           /* not red goriya either */
                return;
            /* Red goriya: only shoots when RNG-A == $23 or $77. */
            {
                unsigned char rng = ENEMY_RNG_A(slot);
                if (rng != 0x23 && rng != 0x77)
                    return;
            }
            /* Reset shot type (dropped through CheckTimerToShootBoomerang). */
            shot_type = 92;
        }

        /* CheckTimerToShoot: if object move-timer ($28) != 0, return. */
        if (ENEMY_MOVE_TIMER(slot) != 0)
            return;

        /* Stash type for downstream Shoot path. */
        ENEMY_SHOT_TYPE_SCRATCH = shot_type;

        /* If frozen by clock or stunned, return. */
        if ((ENEMY_PAUSE_FLAG | ENEMY_STUN_TIMER(slot)) != 0)
            return;

        /* Try to shoot. Return if it failed. */
        {
            unsigned int result = c_shoot_if_wanted((unsigned int)shot_type, slot);
            if ((result & CARRY_SET) == 0)
                return;
            unsigned int shot_slot = result & 0xFFu;

            /* Monster: enter shoot-delay state ($80), clear "wants to shoot". */
            ENEMY_STATE_TIMER(slot) = 0x80;
            ENEMY_PUSH_TIMER(slot) = 0;

            /* Cross-link: shot tracks monster, monster tracks shot. */
            ENEMY_TURN_TIMER(shot_slot) = (unsigned char)slot;
            ENEMY_TURN_TIMER(slot)      = (unsigned char)shot_slot;

            /* Shot setup: flying state, q-speed $A0, $51 px range. */
            ENEMY_STATE_TIMER(shot_slot) = 0x10;
            ENEMY_WALK_SPEED(shot_slot)  = 0xA0;
            ENEMY_BOSS_HP_PHASE(shot_slot) = 0x51;
            ENEMY_METASTATE(shot_slot)   = 0;
            ENEMY_ANIM_TIMER(shot_slot)  = 3;

            /* Monster waits up to $3F frames before shooting again. */
            ENEMY_MOVE_TIMER(slot) = (unsigned char)(ENEMY_RNG_A(slot) & 0x3F);
        }
    }
}

/*
 * Wallmaster family — scratch/draw helpers shared between state init and
 * the sprite-patching path. See z_04.asm for the original comments.
 */

/* SpriteRelativeExtents table lives in bank 1 asm (z_01): {0x08, 0x00}.
 * Rather than add another import, inline it here — it's a two-byte constant
 * used only by the wallmaster sprite-patcher.
 */
static const unsigned char WallmasterSpriteRelExtents[2] = { 0x08, 0x00 };

/*
 * Wallmaster_CalcStartPosition
 *
 * Entry:
 *   instr_offset   = initial instruction-table offset (stored into
 *                    ENEMY_PUSH_TIMER(slot))
 *   init_major_min = minimum major coord (the wall's base position; also
 *                    serves as initial distance reference)
 *   slot           = monster slot (D2)
 *   Reads RAM:
 *     WALLMASTER_MINOR_MAJOR_MIN ($0000) — Link's minor coord
 *     WALLMASTER_MAJOR_MINOR_MIN ($0001) — Link's major coord
 *     WALLMASTER_INSTR_AXIS      ($0002) — axis-decrease direction bit
 *     ROOM_INPUT_DIR             ($03F8)
 *     LINK_DIR                   ($0098,A4,0) == ENEMY_DIR(0)
 *
 * Exit:
 *   Writes RAM:
 *     WALLMASTER_INSTR_MINOR_MIN ($0003) = init_major_min (passed through)
 *     WALLMASTER_INIT_MINOR_COORD ($0004) = computed initial minor coord
 *     ENEMY_PUSH_TIMER(slot)   = final instr offset (base + optional +8 / +$10)
 *   Returns index 0 or 1 — 0 if Link is at the minimum wall, 1 if at the
 *   farther wall (caller uses this to index an initial-coord table).
 */
unsigned int enrt_wallmaster_calc_start_position(unsigned int instr_offset,
                                                 unsigned int init_major_min,
                                                 unsigned int slot) {
    unsigned char dist;
    unsigned char instr_axis;
    unsigned char link_minor;
    unsigned char link_major;
    unsigned char idx;

    ENEMY_PUSH_TIMER(slot) = (unsigned char)instr_offset;
    WALLMASTER_INSTR_MINOR_MIN = (unsigned char)init_major_min;

    /* If Link is still (input dir = 0) use distance $24, else $32. */
    dist = (ROOM_INPUT_DIR == 0) ? 0x24 : 0x32;

    /* If Link faces in the direction passed in (which decreases along the
     * wall), negate the distance and add 8 to the instruction offset so we
     * consult the block for the opposite direction along the same wall.
     */
    instr_axis = WALLMASTER_INSTR_AXIS;
    if (ENEMY_DIR(0) == instr_axis) {
        ENEMY_PUSH_TIMER(slot) = (unsigned char)(ENEMY_PUSH_TIMER(slot) + 0x08);
        dist = (unsigned char)(-(int)(signed char)dist);
    }

    /* initial minor coord = Link's minor + (signed) dist. */
    link_minor = WALLMASTER_MINOR_MAJOR_MIN;
    WALLMASTER_INIT_MINOR_COORD = (unsigned char)(link_minor + dist);

    /* Default: return index 0 (minimum wall) for major-coord table lookup. */
    idx = 0;

    /* If Link's major coord <> minimum major coord, he's at the farther wall.
     * Add $10 to the instr offset and bump the index to 1.
     */
    link_major = WALLMASTER_MAJOR_MINOR_MIN;
    if (link_major != WALLMASTER_INSTR_MINOR_MIN) {
        ENEMY_PUSH_TIMER(slot) = (unsigned char)(ENEMY_PUSH_TIMER(slot) + 0x10);
        idx = 1;
    }
    return idx;
}

/*
 * Wallmaster_PutSpriteBehindBgIfNeeded
 *
 * Entry:
 *   sprite_byte_off = offset into OAM shadow of the sprite's attribute cell
 *                     (so attr = OAM[$0202 + off], x = OAM[$0203 + off]).
 *
 * Walks extent indices {1, 0}: checks sprite_x + SpriteRelativeExtents[idx].
 * If the result >= $E9 or < $18, sets priority bit $20 on the sprite
 * attribute (puts it behind the background).
 */
void enrt_wallmaster_put_sprite_behind_bg_if_needed(unsigned int sprite_byte_off) {
    int i;
    for (i = 1; i >= 0; --i) {
        unsigned char sx = RAM(0x0203 + sprite_byte_off);
        unsigned char probe = (unsigned char)(sx + WallmasterSpriteRelExtents[i]);
        if (probe >= 0xE9 || probe < 0x18) {
            unsigned char attr = RAM(0x0202 + sprite_byte_off);
            RAM(0x0202 + sprite_byte_off) = (unsigned char)(attr | 0x20);
        }
    }
}

/*
 * Wallmaster_PutSpritesBehindBgIfNeeded
 *
 * Applies PutSpriteBehindBgIfNeeded to both sprite offsets stored in
 * WALLMASTER_MINOR_MAJOR_MIN ($0000) and WALLMASTER_MAJOR_MINOR_MIN ($0001)
 * by _L_z04_L_Wallmaster_State1_PatchSprites. Note: the original asm falls
 * through into PutSpriteBehindBgIfNeeded after loading the second offset;
 * replicate that by calling the helper twice.
 */
void enrt_wallmaster_put_sprites_behind_bg_if_needed(void) {
    enrt_wallmaster_put_sprite_behind_bg_if_needed(WALLMASTER_MINOR_MAJOR_MIN);
    enrt_wallmaster_put_sprite_behind_bg_if_needed(WALLMASTER_MAJOR_MINOR_MIN);
}
