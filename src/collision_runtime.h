#ifndef COLLISION_RUNTIME_H
#define COLLISION_RUNTIME_H

#include "combat_state.h"

#ifdef __cplusplus
extern "C" {
#endif

void colrt_handle_monster_weapon_collision(unsigned int monster_slot, unsigned int weapon_slot);
void colrt_check_monster_weapon_collision(unsigned int monster_slot, unsigned int weapon_y_mid);
void colrt_check_monster_slender_weapon_collision2(unsigned int monster_slot);
void colrt_check_monster_slender_weapon_collision(unsigned int monster_slot, unsigned int damage_points);
void colrt_parry_or_shove(unsigned int monster_slot, unsigned int weapon_slot);
void colrt_check_monster_stabbing_collision(unsigned int monster_slot, unsigned int damage_points);
unsigned char colrt_do_objects_collide_with_thresholds(void);
unsigned char colrt_do_objects_collide(unsigned int threshold);
void colrt_check_monster_sword_collision(unsigned int monster_slot, unsigned int weapon_slot);
void colrt_check_monster_shot_collision(unsigned int monster_slot, unsigned int weapon_slot, unsigned int damage_points);
void colrt_check_monster_arrow_or_rod_collision(unsigned int monster_slot, unsigned int weapon_slot);
void colrt_check_monster_boomerang_or_food_collision(unsigned int monster_slot, unsigned int weapon_slot);
void colrt_check_monster_sword_shot_or_magic_shot_collision(unsigned int monster_slot, unsigned int weapon_slot);
void colrt_check_monster_bomb_or_fire_collision(unsigned int monster_slot, unsigned int weapon_slot);

#ifdef __cplusplus
}
#endif

#endif
