#include "trap_runtime.h"

void trprt_init_trap_full(unsigned int slot) {
    WORLD_TMP1 = OBJ_STATUS_FLAGS(slot);
    WORLD_TMP0 = TRAP_OBJ_TYPE;
    {
        signed char count = (MON_TYPE(slot) == TRAP_OBJ_TYPE) ? 5 : 3;
        do {
            unsigned char ns = (unsigned char)((unsigned char)count + TRAP_BASE_SLOT);
            OBJ_X(ns) = TrapXs[(unsigned char)count];
            OBJ_Y(ns) = TrapYs[(unsigned char)count];
            z01_init_one_simple_object(ns);
            count--;
        } while (count >= 0);
    }
}

void trprt_draw_whirlwind(unsigned int slot) {
    z07_anim_advance_and_fetch(1, slot);
    z01_anim_set_sprite_desc_attrs((unsigned char)(FRAME_COUNTER & 3));
    z07_anim_set_obj_hflip(slot);
    c_draw_object_not_mirrored_with_frame(0, slot);
}

void trprt_update_whirlwind_full(unsigned int slot) {
    unsigned char halted = LINK_ACTION_TIMER & 0x40;
    unsigned char new_x = (unsigned char)(2 + OBJ_X(slot));
    OBJ_X(slot) = new_x;
    int skip_collision = 0;
    if (halted == 0x40) {
        unsigned char tele = TELEPORT_ACTIVE_FLAG;
        if (tele != 0) {
            LINK_X = new_x;
            if (tele != 1 && new_x == 0x80) {
                LINK_ACTION_TIMER = 0;
                TELEPORT_ACTIVE_FLAG = 0;
                MON_TYPE(slot) = 0;
                z01_update_player_position_marker();
                trprt_draw_whirlwind(slot);
                return;
            }
            skip_collision = 1;
        }
    }
    if (!skip_collision) {
        z01_check_link_collision(slot);
        if (COMBAT_COLLIDED) {
            LINK_DIR = 1;
            MON_SHOVE_DIR(0) = 0;
            MON_SHOVE_TIMER(0) = 0;
            LINK_CELLAR_FLAG = 0;
            LINK_ACTION_TIMER = 0x40;
            OAM_HIDE_2 = 0xF8;
            OAM_HIDE_3 = 0xF8;
            WHIRLWIND_PREV_ROOM_ID = WhirlwindPrevRoomIdList[TELEPORT_LEVEL_INDEX & 7];
            TELEPORT_ACTIVE_FLAG++;
        }
    }
    if (OBJ_X(slot) < 0xF0) {
        trprt_draw_whirlwind(slot);
        return;
    }
    z01_destroy_whirlwind(slot);
    if (TELEPORT_ACTIVE_FLAG) c_go_to_next_mode_from_play();
    trprt_draw_whirlwind(slot);
}

void trprt_check_init_whirlwind_and_begin_update(void) {
    if (TELEPORT_ACTIVE_FLAG != 0) {
        TELEPORT_ACTIVE_FLAG++;
        LINK_ACTION_TIMER = 64;
        trprt_advance_teleporting_level_index();
        LINK_Y = TeleportYs[TELEPORT_LEVEL_INDEX & 7];
        z01_set_up_whirlwind(9);
    }
    SUBMODE_VALUE = 0;
    MODE_TIMER++;
}

void trprt_advance_teleporting_level_index(void) {
    TELEPORT_LEVEL_INDEX++;
    if ((LINK_DIR & 0x09) == 0) {
        TELEPORT_LEVEL_INDEX -= 2;
    }
}

void trprt_summon_whirlwind(void) {
    if (MODE_VALUE != 5) return;
    trprt_advance_teleporting_level_index();
    WORLD_TMP0 = LevelMasks[TELEPORT_LEVEL_INDEX & 7];
    for (;;) {
        if (!RAM(0x0671)) return;
        if (RAM(0x0671) & WORLD_TMP0) break;
        trprt_advance_teleporting_level_index();
        {
            unsigned char mask = WORLD_TMP0;
            if (LINK_DIR & 9) mask = (unsigned char)((mask << 1) | (mask >> 7));
            else mask = (unsigned char)((mask >> 1) | (mask << 7));
            WORLD_TMP0 = mask;
        }
    }
    if (WHIRLWIND_ACTIVE_FLAG || TELEPORT_ACTIVE_FLAG) return;
    {
        unsigned int empty = z07_find_empty_monster_slot();
        if (!empty) return;
        WHIRLWIND_ACTIVE_FLAG++;
        z01_set_up_whirlwind(empty);
    }
}

void trprt_update_rupee_stash_full(unsigned int slot) {
    if (z01_abs((unsigned char)(LINK_Y - OBJ_Y(slot))) < 9 &&
        z01_abs((unsigned char)(LINK_X - OBJ_X(slot))) < 9) {
        z01_take_one_rupee();
        z07_destroy_monster(slot);
        RUPEE_STASH_FLAG = 0;
        return;
    }
    z07_anim_fetch_obj_pos(slot);
    c_draw_item_in_inventory(22, 22);
}

void trprt_init_mode_b_enter_cave_bank5(void) {
    unsigned char submode = SUBMODE_VALUE;
    c_init_mode_enter_room();
    z05_reset_inv_obj_state();
    LINK_X = 112;
    LINK_Y = 0xDD;
    LINK_DIR = 8;
    c_link_end_move_and_animate();
    c_run_cross_room_tasks_no_cellar();
    SUBMODE_VALUE = submode;
    MODE_TIMER = 0;
    SUBMODE_VALUE++;
    OBJ_GRID_OFFSET(0) = 48;
    LINK_CELLAR_FLAG = 1;
}

void trprt_check_passive_tile_objects(void) {
    if (OBJ_GRID_OFFSET(0) != 0) return;
    if (PASSIVE_OBJ_FLAG == 0) return;
    {
        unsigned char collided_tile = ENEMY_COLLIDED_TILE(0);
        unsigned char tile = 0xBB;
        int found = 0;
        for (int count = 8; count > 0; count--) {
            tile++;
            WORLD_TMP2 = tile;
            if (collided_tile == tile) { found = 1; break; }
        }
        if (!found) return;
    }
    WORLD_TMP0 = LINK_X;
    WORLD_TMP1 = LINK_Y;
    if (LINK_DIR & 0x0C) {
        unsigned char col_type = WORLD_TMP2 & 3;
        unsigned char lx = WORLD_TMP0;
        if (col_type < 2) lx = (unsigned char)(lx + 8);
        WORLD_TMP0 = lx & 0xF0;
    } else {
        if (!(WORLD_TMP2 & 1)) WORLD_TMP1 = (unsigned char)(WORLD_TMP1 + 8);
    }
    {
        unsigned int empty = z07_find_empty_monster_slot();
        if (!empty) return;
        {
            unsigned int opp = z01_get_opposite_dir(LINK_DIR);
            unsigned char opp_idx = (unsigned char)(opp >> 8);
            OBJ_X(empty) = (unsigned char)(WORLD_TMP0 + LinkToSquareOffsetsX[opp_idx]);
            OBJ_Y(empty) = (unsigned char)(WORLD_TMP1 + LinkToSquareOffsetsY[opp_idx]);
        }
        if (!ENEMY_ALIVE_FLAG(empty)) return;
        WORLD_TMP3 = (unsigned char)empty;
        for (signed char i = 11; i >= 1; i--) {
            unsigned char si = (unsigned char)i;
            if (si == (unsigned char)empty) continue;
            if (OBJ_X(si) != OBJ_X(empty)) continue;
            if (OBJ_Y(si) != OBJ_Y(empty)) continue;
            if (MON_TYPE(si) != 0) return;
            if (!ENEMY_ALIVE_FLAG(si)) return;
            break;
        }
        MON_TYPE(empty) = (WORLD_TMP2 >= 0xC0) ? TRAP_ALT_OBJ_TYPE : TRAP_PUSHED_OBJ_TYPE;
        z07_reset_obj_metastate(empty);
        OBJ_MOVE_TIMER(empty) = 63;
    }
}

void trprt_update_trap_full(unsigned int slot) {
    unsigned char state = OBJ_STATE(slot);
    if (state == 0) {
        unsigned char dy = (unsigned char)(LINK_Y - OBJ_Y(slot));
        if (z01_abs(dy) < 0x0E) {
            unsigned char dx = (unsigned char)(LINK_X - OBJ_X(slot));
            if (z01_abs(dx) < 0x0E) {
                unsigned char dir = 4;
                unsigned char lnky = LINK_Y;
                unsigned char trapy = OBJ_Y(slot);
                if (lnky == trapy) goto draw_and_check;
                if (lnky < trapy) dir = 8;
                {
                    unsigned char orig = trapy;
                    if (orig == 0) goto draw_and_check;
                    TRAP_RETURN_COORD(slot) = orig;
                    OBJ_DIR(slot) = dir;
                    if (!(dir & TrapAllowedDirs[slot - 1])) goto draw_and_check;
                    OBJ_STATE(slot)++;
                    OBJ_QSPD_FRAC(slot) = 0x70;
                    goto draw_and_check;
                }
            }
        }
        {
            unsigned char dir = 1;
            unsigned char lnkx = LINK_X;
            unsigned char trapx = OBJ_X(slot);
            if (lnkx == trapx) goto draw_and_check;
            if (lnkx < trapx) dir = 2;
            TRAP_RETURN_COORD(slot) = trapx;
            OBJ_DIR(slot) = dir;
            if (!(dir & TrapAllowedDirs[slot - 1])) goto draw_and_check;
            OBJ_STATE(slot)++;
            OBJ_QSPD_FRAC(slot) = 0x70;
        }
    } else {
        unsigned char coord, target;
        COMBAT_PART_INDEX = OBJ_DIR(slot);
        c_move_object(slot);
        if ((OBJ_GRID_OFFSET(slot) & 0x0F) == 0) OBJ_GRID_OFFSET(slot) = 0;
        z01_check_link_collision(slot);
        if (OBJ_DIR(slot) & 0x0C) {
            coord = OBJ_Y(slot);
            target = 0x90;
        } else {
            coord = OBJ_X(slot);
            target = 0x78;
        }
        if (OBJ_STATE(slot) & 1) {
            unsigned char dist = z01_abs((unsigned char)(coord - target));
            if (dist >= 5) goto draw_and_check;
            OBJ_DIR(slot) = (unsigned char)z01_get_opposite_dir(OBJ_DIR(slot));
            OBJ_QSPD_FRAC(slot) = 0x20;
            OBJ_STATE(slot)++;
        } else {
            if (coord != TRAP_RETURN_COORD(slot)) goto draw_and_check;
            OBJ_STATE(slot) = 0;
        }
    }
draw_and_check:
    c_person_draw_and_check_collisions(slot);
}
