#ifndef FRONTEND_RUNTIME_H
#define FRONTEND_RUNTIME_H

#include "frontend_state.h"

#ifdef __cplusplus
extern "C" {
#endif

void frontdemo_animate_phase1_sub0(void);
void frontdemo_animate_phase1_sub1(void);
void frontdemo_disable_fallen_objects(void);
void frontdemo_init_mode1_sub2(void);
void frontdemo_end_init_demo(unsigned int val);
void frontdemo_inc_subphase(void);
void frontdemo_animate_p1_sub3(void);
void frontdemo_animate_p1_end(void);
void frontdemo_init_demo_subphase_play_title_song(void);
void frontdemo_init_mode13_sub3(void);
void frontdemo_init_mode13_sub4(void);

void frontname_reset_variables(unsigned int val);
void frontname_reset_button_repeat_state(unsigned int val);
void frontname_set_name_cursor_sprite_x(void);
void frontname_sync_char_board_cursor(void);

void frontutil_add_a_to_0f0e(unsigned int val);
void frontutil_add_a_to_cfce(unsigned int val);

#ifdef __cplusplus
}
#endif

#endif
