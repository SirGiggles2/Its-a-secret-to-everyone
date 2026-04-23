#include "collision_runtime.h"

extern void c_call_gohma_handle_weapon_collision(unsigned int monster_slot, unsigned int weapon_slot);
extern void c_call_begin_shove(unsigned int monster_slot);
extern void c_call_handle_shot_blocked(unsigned int weapon_slot);
extern void z01_play_parry_tune(void);
extern void z01_play_parry_sound_for_damage_type(void);
extern void z01_deal_damage(unsigned int slot);
static const unsigned char colrt_sword_damage_points[3] = {0x10, 0x20, 0x40};

unsigned char colrt_do_objects_collide_with_thresholds(void) {
    COMBAT_COLLIDED = 0;
    {
        unsigned char dx = (unsigned char)(RAM(0x0002) - COMBAT_HITBOX_X);
        unsigned char abs_dx = (dx & 0x80) ? (unsigned char)((~dx + 1) & 0xFF) : dx;
        COMBAT_ABS_DX = abs_dx;
        if (abs_dx >= COMBAT_THRESHOLD_X) {
            return COMBAT_COLLIDED;
        }
    }
    {
        unsigned char dy = (unsigned char)(RAM(0x0003) - COMBAT_HITBOX_Y);
        unsigned char abs_dy = (dy & 0x80) ? (unsigned char)((~dy + 1) & 0xFF) : dy;
        COMBAT_ABS_DY = abs_dy;
        if (abs_dy >= COMBAT_THRESHOLD_Y) {
            return COMBAT_COLLIDED;
        }
    }
    COMBAT_COLLIDED++;
    return COMBAT_COLLIDED;
}

unsigned char colrt_do_objects_collide(unsigned int threshold) {
    COMBAT_THRESHOLD_X = (unsigned char)threshold;
    COMBAT_THRESHOLD_Y = (unsigned char)threshold;
    return colrt_do_objects_collide_with_thresholds();
}

void colrt_handle_monster_weapon_collision(unsigned int monster_slot, unsigned int weapon_slot) {
    if (MON_INVINCIBILITY(monster_slot) & COMBAT_DAMAGE_TYPE) {
        z01_play_parry_sound_for_damage_type();
        return;
    }
    {
        unsigned char mtype = MON_TYPE(monster_slot);
        if (mtype == 0x33 || mtype == 0x34) {
            c_call_gohma_handle_weapon_collision(monster_slot, weapon_slot);
            return;
        }
        if (mtype == 0x13 || mtype == 0x12) {
            if (weapon_slot != 0x0F) {
                OBJ_DIR(monster_slot) = OBJ_DIR(weapon_slot);
            }
            z01_deal_damage(monster_slot);
            return;
        }
        if (mtype == 0x0B || mtype == 0x0C) {
            unsigned char combined = OBJ_DIR(weapon_slot) | OBJ_DIR(monster_slot);
            if (combined == 0x0C || combined == 0x03) {
                z01_play_parry_sound_for_damage_type();
                return;
            }
        }
    }
    z01_deal_damage(monster_slot);
}

void colrt_check_monster_weapon_collision(unsigned int monster_slot, unsigned int weapon_y_mid) {
    unsigned int weapon_slot;
    COMBAT_HITBOX_Y = (unsigned char)weapon_y_mid;
    COMBAT_COLLIDED = 0;
    weapon_slot = (unsigned int)COMBAT_WEAPON_SLOT;
    if (OBJ_STATE(weapon_slot) == 0) {
        return;
    }
    if (!colrt_do_objects_collide_with_thresholds()) {
        return;
    }
    if (weapon_slot == 0x0F) {
        unsigned char inv = MON_INVINCIBILITY(monster_slot) & COMBAT_DAMAGE_TYPE;
        if (inv) {
            z01_play_parry_tune();
        }
        OBJ_STATE(weapon_slot) = 80;
        if (inv) {
            return;
        }
        COMBAT_DAMAGE_AMOUNT = 0;
        MON_STUN_TIMER(monster_slot) = 16;
    }
    colrt_handle_monster_weapon_collision(monster_slot, weapon_slot);
}

void colrt_check_monster_slender_weapon_collision2(unsigned int monster_slot) {
    unsigned int weapon_slot = (unsigned int)COMBAT_WEAPON_SLOT;
    unsigned char dir = LINK_DIR & 0x0C;
    unsigned char wx;
    unsigned char wy;
    if (dir != 0) {
        wx = (unsigned char)(OBJ_X(weapon_slot) + 6);
        wy = (unsigned char)(OBJ_Y(weapon_slot) + 8);
    } else {
        wx = (unsigned char)(OBJ_X(weapon_slot) + 8);
        wy = (unsigned char)(OBJ_Y(weapon_slot) + 6);
    }
    COMBAT_HITBOX_X = wx;
    colrt_check_monster_weapon_collision(monster_slot, wy);
}

void colrt_check_monster_slender_weapon_collision(unsigned int monster_slot, unsigned int damage_points) {
    COMBAT_DAMAGE_AMOUNT = (unsigned char)damage_points;
    COMBAT_THRESHOLD_Y = COMBAT_THRESHOLD_X;
    colrt_check_monster_slender_weapon_collision2(monster_slot);
}

void colrt_parry_or_shove(unsigned int monster_slot, unsigned int weapon_slot) {
    unsigned char mtype = MON_TYPE(monster_slot);
    if (mtype == 0x0B || mtype == 0x0C) {
        unsigned char combined = OBJ_DIR(weapon_slot) | OBJ_DIR(monster_slot);
        if (combined == 0x0C || combined == 0x03) {
            z01_play_parry_tune();
            return;
        }
    }
    c_call_begin_shove(monster_slot);
}

void colrt_check_monster_stabbing_collision(unsigned int monster_slot, unsigned int damage_points) {
    COMBAT_DAMAGE_AMOUNT = (unsigned char)damage_points;
    {
        unsigned char dir = LINK_DIR & 0x0C;
        if (dir != 0) {
            COMBAT_THRESHOLD_X = 12;
            COMBAT_THRESHOLD_Y = 16;
        } else {
            COMBAT_THRESHOLD_X = 16;
            COMBAT_THRESHOLD_Y = 12;
        }
    }
    colrt_check_monster_slender_weapon_collision2(monster_slot);
    if (!COMBAT_COLLIDED) {
        return;
    }
    colrt_parry_or_shove(monster_slot, (unsigned int)COMBAT_WEAPON_SLOT);
}

void colrt_check_monster_sword_collision(unsigned int monster_slot, unsigned int weapon_slot) {
    COMBAT_WEAPON_SLOT = (unsigned char)weapon_slot;
    COMBAT_DAMAGE_TYPE = 1;
    if (OBJ_STATE(weapon_slot) != 2) return;
    colrt_check_monster_stabbing_collision(monster_slot, colrt_sword_damage_points[ITEM_SWORD_LEVEL - 1]);
}

void colrt_check_monster_shot_collision(unsigned int monster_slot, unsigned int weapon_slot, unsigned int damage_points) {
    colrt_check_monster_slender_weapon_collision(monster_slot, damage_points);
    if (!COMBAT_COLLIDED) return;
    if (weapon_slot != 0x12) {
        colrt_parry_or_shove(monster_slot, weapon_slot);
        return;
    }
    if (MON_TYPE(monster_slot) == 0x16) {
        MON_HP(monster_slot) = 0;
        z01_deal_damage(monster_slot);
        return;
    }
    OBJ_STATE(weapon_slot) = 32;
    OBJ_ANIM_TIMER(weapon_slot) = 3;
    colrt_parry_or_shove(monster_slot, weapon_slot);
}

void colrt_check_monster_arrow_or_rod_collision(unsigned int monster_slot, unsigned int weapon_slot) {
    unsigned char state;
    COMBAT_WEAPON_SLOT = (unsigned char)weapon_slot;
    state = OBJ_STATE(weapon_slot);
    if (state >= 0x30) {
        COMBAT_DAMAGE_TYPE = 1;
        colrt_check_monster_stabbing_collision(monster_slot, 32);
        return;
    }
    if (state >= 0x20) return;
    COMBAT_DAMAGE_TYPE = 4;
    COMBAT_THRESHOLD_X = 11;
    colrt_check_monster_shot_collision(monster_slot, weapon_slot, (ITEM_ARROW_OR_ROD_LEVEL == 1) ? 32u : 64u);
}

void colrt_check_monster_boomerang_or_food_collision(unsigned int monster_slot, unsigned int weapon_slot) {
    if (OBJ_STATE(weapon_slot) & 0x80) return;
    COMBAT_WEAPON_SLOT = (unsigned char)weapon_slot;
    COMBAT_DAMAGE_TYPE = 2;
    COMBAT_THRESHOLD_X = 10;
    COMBAT_THRESHOLD_Y = 10;
    COMBAT_HITBOX_X = (unsigned char)(OBJ_X(weapon_slot) + 4);
    colrt_check_monster_weapon_collision(monster_slot, (unsigned int)(unsigned char)(OBJ_Y(weapon_slot) + 8));
}

void colrt_check_monster_sword_shot_or_magic_shot_collision(unsigned int monster_slot, unsigned int weapon_slot) {
    unsigned char state;
    unsigned int damage;
    COMBAT_WEAPON_SLOT = (unsigned char)weapon_slot;
    COMBAT_DAMAGE_TYPE = 16;
    state = OBJ_STATE(weapon_slot);
    if (state & 1) return;
    COMBAT_THRESHOLD_X = 12;
    if (state & 0x80) {
        damage = 32;
    } else {
        unsigned char level = ITEM_SWORD_LEVEL;
        COMBAT_DAMAGE_TYPE = 1;
        damage = (level == 3) ? 64u : (level == 2) ? 32u : 16u;
    }
    colrt_check_monster_shot_collision(monster_slot, weapon_slot, damage);
    if (!COMBAT_COLLIDED) return;
    c_call_handle_shot_blocked(14);
}

void colrt_check_monster_bomb_or_fire_collision(unsigned int monster_slot, unsigned int weapon_slot) {
    unsigned char state;
    COMBAT_WEAPON_SLOT = (unsigned char)weapon_slot;
    COMBAT_DAMAGE_TYPE = 32;
    COMBAT_DAMAGE_AMOUNT = 16;
    COMBAT_THRESHOLD_X = 14;
    state = OBJ_STATE(weapon_slot);
    if (state >= 0x20) {
    } else if (state == 0x13) {
        COMBAT_DAMAGE_TYPE = 8;
        COMBAT_DAMAGE_AMOUNT = 64;
        COMBAT_THRESHOLD_X = 24;
    } else {
        return;
    }
    COMBAT_HITBOX_X = (unsigned char)(OBJ_X(weapon_slot) + 8);
    COMBAT_HITBOX_Y = (unsigned char)(OBJ_Y(weapon_slot) + 8);
    COMBAT_THRESHOLD_Y = COMBAT_THRESHOLD_X;
    if (!colrt_do_objects_collide_with_thresholds()) return;
    colrt_handle_monster_weapon_collision(monster_slot, weapon_slot);
    if (MON_INVINCIBILITY(monster_slot) & COMBAT_DAMAGE_TYPE) return;
    c_call_begin_shove(monster_slot);
}
