#include "enemy_runtime_private.h"

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
