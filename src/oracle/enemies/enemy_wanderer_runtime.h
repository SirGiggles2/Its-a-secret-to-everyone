#ifndef ENEMY_WANDERER_RUNTIME_H
#define ENEMY_WANDERER_RUNTIME_H

#include "enemy_runtime_private.h"

unsigned int enrt_walker_alt_dir_get_opposite(void);
void enrt_walker_alt_dir_end_loop(void);
unsigned char enrt_walker_alt_dir_get_random_perpendicular(unsigned int slot);
void enrt_update_common_wanderer(unsigned int turn_rate, unsigned int slot);
void enrt_wanderer_target_player(unsigned int slot);
void enrt_update_goriya(unsigned int slot);
void enrt_walker_set_input_dir_and_try_shooting_boomerang(unsigned int slot);

#endif
