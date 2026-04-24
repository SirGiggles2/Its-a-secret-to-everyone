#ifndef ENEMY_WALLMASTER_RUNTIME_H
#define ENEMY_WALLMASTER_RUNTIME_H

#include "enemy_runtime_private.h"

unsigned int enrt_wallmaster_calc_start_position(unsigned int instr_offset,
                                                 unsigned int init_major_min,
                                                 unsigned int slot);
void enrt_wallmaster_put_sprite_behind_bg_if_needed(unsigned int sprite_byte_off);
void enrt_wallmaster_put_sprites_behind_bg_if_needed(void);

#endif
