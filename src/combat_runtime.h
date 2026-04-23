#ifndef COMBAT_RUNTIME_H
#define COMBAT_RUNTIME_H

#include "combat_state.h"

#ifdef __cplusplus
extern "C" {
#endif

void cobrt_play_parry_sound_for_damage_type(void);
void cobrt_handle_monster_died(unsigned int slot);
void cobrt_deal_damage(unsigned int slot);

#ifdef __cplusplus
}
#endif

#endif
