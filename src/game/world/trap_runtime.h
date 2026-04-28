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

/* --- External data arrays used by trap_runtime.c --- */
extern const unsigned char TrapXs[];
extern const unsigned char TrapYs[];
extern const unsigned char WhirlwindPrevRoomIdList[];
extern const unsigned char LinkToSquareOffsetsX[];
extern const unsigned char LinkToSquareOffsetsY[];
extern const unsigned char TrapAllowedDirs[];
extern const unsigned char LevelMasks[];
extern const unsigned char TeleportYs[];

/* --- Bank-forwarder functions used by trap_runtime.c --- */
extern void z05_reset_inv_obj_state(void);

/* --- ASM shim functions used by trap_runtime.c --- */
extern void c_draw_object_not_mirrored_with_frame(unsigned int frame, unsigned int slot);
extern void c_go_to_next_mode_from_play(void);
extern void c_draw_item_in_inventory(unsigned int d2, unsigned int d3);
extern void c_init_mode_enter_room(void);
extern void c_link_end_move_and_animate(void);
extern void c_run_cross_room_tasks_no_cellar(void);
extern void c_move_object(unsigned short slot);
extern void c_person_draw_and_check_collisions(unsigned int slot);

#endif
