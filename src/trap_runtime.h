#ifndef TRAP_RUNTIME_H
#define TRAP_RUNTIME_H

#include "trap_state.h"

#ifdef __cplusplus
extern "C" {
#endif

void trprt_init_trap_full(unsigned int slot);
void trprt_draw_whirlwind(unsigned int slot);
void trprt_update_whirlwind_full(unsigned int slot);
void trprt_check_init_whirlwind_and_begin_update(void);
void trprt_advance_teleporting_level_index(void);
void trprt_summon_whirlwind(void);
void trprt_update_rupee_stash_full(unsigned int slot);
void trprt_init_mode_b_enter_cave_bank5(void);
void trprt_check_passive_tile_objects(void);
void trprt_update_trap_full(unsigned int slot);

#ifdef __cplusplus
}
#endif

#endif
