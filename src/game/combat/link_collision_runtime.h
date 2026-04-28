#ifndef LINK_COLLISION_RUNTIME_H
#define LINK_COLLISION_RUNTIME_H

#include "combat_state.h"

#ifdef __cplusplus
extern "C" {
#endif

void lcrt_harm_link(unsigned int monster_slot);
void lcrt_link_be_harmed(unsigned int monster_slot);
void lcrt_check_link_collision_preinit(unsigned int monster_slot);
void lcrt_check_link_collision(unsigned int monster_slot);
void lcrt_check_monster_collisions(unsigned int monster_slot);
void lcrt_begin_shove(unsigned int monster_slot);

#ifdef __cplusplus
}
#endif

/* --- External data arrays used by link_collision_runtime.c --- */
extern const unsigned char ObjTypeToDamagePoints[];

/* --- ASM shim / bank-forwarder functions used by link_collision_runtime.c --- */
extern unsigned int z01_get_opposite_dir(unsigned int dir);
extern void z01_play_sample(unsigned int val);
extern unsigned char z07_end_game_mode(void);
extern void z01_get_object_middle(unsigned int slot);
extern unsigned char z01_do_objects_collide_with_thresholds(void);
extern void z01_check_monster_boomerang_or_food_collision(unsigned int monster_slot, unsigned int weapon_slot);
extern void z01_check_monster_sword_shot_or_magic_shot_collision(unsigned int monster_slot, unsigned int weapon_slot);
extern void z01_check_monster_bomb_or_fire_collision(unsigned int monster_slot, unsigned int weapon_slot);
extern void z01_check_monster_sword_collision(unsigned int monster_slot, unsigned int weapon_slot);
extern void z01_check_monster_arrow_or_rod_collision(unsigned int monster_slot, unsigned int weapon_slot);

#endif
