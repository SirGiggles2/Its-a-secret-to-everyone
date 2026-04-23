#ifndef SPRITE_RUNTIME_H
#define SPRITE_RUNTIME_H

#include "nes_abi.h"

#ifdef __cplusplus
extern "C" {
#endif

void sprrt_cycle_cur_sprite_index(void);
unsigned char sprrt_cycle_sprite_index_in_a(unsigned char idx);
void sprrt_hide_object_sprites(void);
void sprrt_show_link_sprites_behind_horizontal_doors(void);

#ifdef __cplusplus
}
#endif

#endif
