#include "link_collision_runtime.h"
#include "link_state.h"
#include "progress_state.h"

void lcrt_link_be_harmed(unsigned int monster_slot) {
    if (MON_TYPE(monster_slot) != 0x2E) {
        z01_play_sample(8);
    }
    {
        unsigned char rings = LINK_RING_LEVEL;
        while (rings--) {
            unsigned char carry = COMBAT_THRESHOLD_X & 1;
            COMBAT_THRESHOLD_X >>= 1;
            COMBAT_THRESHOLD_Y = (unsigned char)(((carry) << 7) | (COMBAT_THRESHOLD_Y >> 1));
        }
    }
    ROOM_KILL_COUNT = 0;
    ROOM_CHAIN_KILL_COUNT = 0;
    ROOM_CHAIN_KILL_BONUS = 0;
    while (1) {
        unsigned char partial = LINK_PARTIAL_HEART;
        unsigned char dmg_lo = COMBAT_THRESHOLD_Y;
        if (partial >= dmg_lo) {
            LINK_PARTIAL_HEART = partial - dmg_lo;
            if (COMBAT_THRESHOLD_X > (LINK_HEARTS & 0x0F)) {
                break;
            }
            LINK_HEARTS = (unsigned char)(LINK_HEARTS - COMBAT_THRESHOLD_X);
            return;
        } else {
            COMBAT_THRESHOLD_Y = dmg_lo - partial;
            if ((LINK_HEARTS & 0x0F) == 0) {
                break;
            }
            LINK_HEARTS--;
            LINK_PARTIAL_HEART = 0xFF;
        }
    }
    LINK_HEARTS &= 0xF0;
    z07_end_game_mode();
    LINK_PARTIAL_HEART = 0;
    LINK_ACTION_TIMER = 0;
    MODE_VALUE = 17;
    LINK_DIR = 4;
}

void lcrt_harm_link(unsigned int monster_slot) {
    lcrt_begin_shove(monster_slot);
    COMBAT_HARM_FLAG++;
    {
        unsigned char mtype = MON_TYPE(monster_slot);
        unsigned char tbl = ObjTypeToDamagePoints[mtype];
        COMBAT_THRESHOLD_X = tbl & 0x0F;
        COMBAT_THRESHOLD_Y = tbl & 0xF0;
    }
    lcrt_link_be_harmed(monster_slot);
}

void lcrt_check_link_collision_preinit(unsigned int monster_slot) {
    unsigned char mtype;
    if (LINK_ACTION_TIMER == 0x40) return;
    if (LINK_DAMAGE_DISABLE_FLAG) return;
    mtype = MON_TYPE(monster_slot);
    if (mtype >= 0x53 && (OBJ_STATE(monster_slot) & 0xF0) != 0x10) return;
    COMBAT_HITBOX_X = (unsigned char)(OBJ_X(0) + 8);
    COMBAT_HITBOX_Y = (unsigned char)(OBJ_Y(0) + 8);
    COMBAT_THRESHOLD_X = 9;
    COMBAT_THRESHOLD_Y = 9;
    if (!z01_do_objects_collide_with_thresholds()) return;
    if (mtype < 0x53) { lcrt_harm_link(monster_slot); return; }
    ROOM_MONSTER_COLLISION_COUNT++;
    if (mtype == 0x56 || mtype == 0x5A) { lcrt_harm_link(monster_slot); return; }
    if (LINK_ACTION_TIMER & 0xF0) { lcrt_harm_link(monster_slot); return; }
    {
        unsigned char or_dirs = LINK_DIR | OBJ_DIR(monster_slot);
        if ((or_dirs & 0x0C) != 0x0C && (or_dirs & 0x03) != 0x03) {
            lcrt_harm_link(monster_slot);
            return;
        }
    }
    if (mtype >= 0x55 && mtype <= 0x5A) {
        if (!LINK_SHIELD_BLOCK_FLAG) { lcrt_harm_link(monster_slot); return; }
    }
    SFX_COMBAT = 1;
    COMBAT_COLLIDED = 0;
}

void lcrt_check_link_collision(unsigned int monster_slot) {
    z01_get_object_middle(monster_slot);
    ROOM_MONSTER_COLLISION_COUNT = 0;
    COMBAT_COLLIDED = 0;
    COMBAT_DAMAGE_TYPE = 0;
    COMBAT_HARM_FLAG = 0;
    COMBAT_WEAPON_SLOT = 0;
    if (LINK_STUN_TIMER | LINK_HALT_FLAG | MON_STUN_TIMER(0) | MON_STUN_TIMER(monster_slot)) return;
    lcrt_check_link_collision_preinit(monster_slot);
}

void lcrt_check_monster_collisions(unsigned int monster_slot) {
    z01_get_object_middle(monster_slot);
    if (!(MON_STATUS_FLAGS(monster_slot) & 0x20)) {
        if (MON_HIT_REACTION(monster_slot)) return;
        z01_check_monster_boomerang_or_food_collision(monster_slot, 15);
        z01_check_monster_sword_shot_or_magic_shot_collision(monster_slot, 14);
        z01_check_monster_bomb_or_fire_collision(monster_slot, 16);
        z01_check_monster_bomb_or_fire_collision(monster_slot, 17);
        z01_check_monster_sword_collision(monster_slot, 13);
        z01_check_monster_arrow_or_rod_collision(monster_slot, 18);
    }
    lcrt_check_link_collision(monster_slot);
    {
        unsigned char mtype = MON_TYPE(monster_slot);
        unsigned char dying = MON_METASTATE(monster_slot);
        if (!dying) {
            if ((mtype == 0x27 || mtype == 0x17) && COMBAT_HARM_FLAG) {
                MON_BOUNCE_TURNS(monster_slot)++;
            }
            return;
        }
        if (mtype == 0x05 || mtype == 0x06) {
            if (OBJ_STATE(monster_slot) & 0x80) {
                unsigned char bslot = MON_BOUNCE_TURNS(monster_slot);
                MON_TYPE(bslot) = 0;
            }
        }
    }
}

void lcrt_begin_shove(unsigned int monster_slot) {
    unsigned int weapon_slot = (unsigned int)COMBAT_WEAPON_SLOT;
    if (monster_slot < 0x0D) {
        if (MON_INVINCIBILITY(monster_slot) & COMBAT_DAMAGE_TYPE) return;
    }
    COMBAT_SHOVE_DIR = 8;
    COMBAT_HITBOX_X = OBJ_Y(monster_slot);
    COMBAT_HITBOX_Y = OBJ_Y(weapon_slot);
    {
        unsigned char check_h;
        if (weapon_slot == 0 && OBJ_GRID_OFFSET(0)) {
            check_h = (LINK_DIR & 0x03) ? 1 : 0;
        } else {
            check_h = (COMBAT_ABS_DY < 4) ? 1 : 0;
        }
        if (check_h) {
            COMBAT_SHOVE_DIR = 2;
            COMBAT_HITBOX_X = OBJ_X(monster_slot);
            COMBAT_HITBOX_Y = OBJ_X(weapon_slot);
        }
    }
    if (COMBAT_HITBOX_X < COMBAT_HITBOX_Y) {
        COMBAT_SHOVE_DIR = (unsigned char)(COMBAT_SHOVE_DIR >> 1);
    }
    if (weapon_slot != 0) {
        COMBAT_SHOVE_DIR = OBJ_DIR(weapon_slot);
        if (MON_STATUS_FLAGS(monster_slot) & 0x80) COMBAT_SHOVE_DIR |= 0x40;
        if (MON_HIT_REACTION(monster_slot)) return;
        {
            unsigned char mtype = MON_TYPE(monster_slot);
            if (mtype == 0x33 || mtype == 0x34) {
                unsigned char part = COMBAT_PART_INDEX;
                if (part != 3 && part != 4) return;
                if (MON_SUBSTATE(monster_slot) != 3) return;
            }
        }
        MON_SHOVE_DIR(monster_slot) = COMBAT_SHOVE_DIR | 0x80;
        MON_SHOVE_TIMER(monster_slot) = 64;
        MON_HIT_REACTION(monster_slot) = 16;
    } else {
        if (LINK_STUN_TIMER) return;
        MON_SHOVE_DIR(0) = COMBAT_SHOVE_DIR | 0x80;
        LINK_STUN_TIMER = 24;
        MON_SHOVE_TIMER(0) = 32;
        if (monster_slot >= 0x0D) return;
        if (MON_STATUS_FLAGS(monster_slot) & 0x80) return;
        if (MON_TYPE(monster_slot) == 0x12) return;
        OBJ_DIR(monster_slot) = (unsigned char)z01_get_opposite_dir(OBJ_DIR(monster_slot));
    }
}
