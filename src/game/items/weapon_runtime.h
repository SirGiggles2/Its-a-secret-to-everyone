#ifndef WEAPON_RUNTIME_H
#define WEAPON_RUNTIME_H

#include "world_state.h"
#include "item_state.h"

#ifdef __cplusplus
extern "C" {
#endif

void weprt_place_weapon(unsigned char offset, unsigned int slot);
void weprt_place_weapon_for_player_state(unsigned int slot);
void weprt_place_weapon_for_player_state_and_anim(unsigned int slot);
void weprt_place_weapon_for_player_state_and_anim_and_weapon_state(unsigned char weapon_state, unsigned int slot);
void weprt_wield_bomb(unsigned int slot);
unsigned int weprt_wield_candle(unsigned int slot);

#ifdef __cplusplus
}
#endif

#endif
