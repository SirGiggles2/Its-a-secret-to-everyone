#include "combat_runtime.h"

extern void z07_update_dead_dummy(unsigned int slot);
extern void z01_play_parry_tune(void);
extern void z01_reset_shove_info_and_inv_timer(unsigned int slot);

void cobrt_play_parry_sound_for_damage_type(void) {
    unsigned char dtype = COMBAT_DAMAGE_TYPE;
    if (dtype == 0x20u || dtype == 0x08u) {
        return;
    }
    z01_play_parry_tune();
}

void cobrt_handle_monster_died(unsigned int slot) {
    ROOM_KILL_COUNT++;
    if (ROOM_CHAIN_KILL_COUNT < 0x0Au) {
        ROOM_CHAIN_KILL_COUNT++;
        if (ROOM_CHAIN_KILL_COUNT == 0x0Au && COMBAT_DAMAGE_TYPE == 0x08u) {
            ROOM_CHAIN_KILL_BONUS++;
        }
    }
    z07_update_dead_dummy(slot);
    MON_STUN_TIMER(slot) = 0;
    z01_reset_shove_info_and_inv_timer(slot);
}

void cobrt_deal_damage(unsigned int slot) {
    unsigned char hp;
    unsigned char damage;
    SFX_COMBAT = 2;
    hp = MON_HP(slot);
    damage = COMBAT_DAMAGE_AMOUNT;
    if (hp < damage) {
        cobrt_handle_monster_died(slot);
        return;
    }
    hp = (unsigned char)(hp - damage);
    MON_HP(slot) = hp;
    if (hp == 0) {
        cobrt_handle_monster_died(slot);
    }
}
