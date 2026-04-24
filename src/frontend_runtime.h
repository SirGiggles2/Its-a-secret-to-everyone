#ifndef FRONTEND_RUNTIME_H
#define FRONTEND_RUNTIME_H

#include "frontend_state.h"
#include "intro_common.h"

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
void frontdemo_init_demo_subphase_transfer_title_palette(void);
void frontdemo_init_demo_subphase_transfer_story_palette(void);
void frontdemo_animate_demo_phase1_subphase4(void);
void frontdemo_update_sprites_for_waterfall_crest(void);
void frontdemo_update_sprites_for_waterfall_wave(unsigned int wave_idx);
void frontdemo_update_waterfall_animation(void);
void frontdemo_init_mode13_sub3(void);
void frontdemo_init_mode13_sub4(void);

void frontdemo_init_demo_run_tasks(void);
void frontdemo_init_demo_phase_1(void);
void frontdemo_update_mode0_demo(void);
void frontdemo_update_mode0_demo_sub0(void);
void frontdemo_update_mode0_demo_sub2(void);
void frontdemo_animate_demo(void);
void frontdemo_animate_phase_1(void);

void frontname_reset_variables(unsigned int val);
void frontname_reset_button_repeat_state(unsigned int val);
void frontname_set_name_cursor_sprite_x(void);
void frontname_sync_char_board_cursor(void);

void frontutil_add_a_to_0f0e(unsigned int val);
void frontutil_add_a_to_cfce(unsigned int val);

#ifdef __cplusplus
}
#endif

/* --- ASM shim and bank-forwarder functions used by frontend_runtime.c --- */
extern void c_import_demo_animate_objects(void);
extern void z07_hide_all_sprites(void);
extern void z01_silence_all_sound(void);
extern void z01_begin_update_mode(void);
extern void c_turn_off_all_video(void);
extern void c_hide_all_sprites(void);
extern void z01_fetch_file_a_address_set(void);

/* --- c_import_* shims for demo/intro subphase dispatch --- */
extern void c_import_init_demo_subphase_clear_artifacts(void);
extern void c_import_init_demo_subphase_transfer_title_palette(void);
extern void c_import_init_demo_subphase_play_title_song(void);
extern void c_import_init_demo_subphase_transfer_story_palette(void);
extern void c_import_init_demo_subphase_transfer_story_tiles(void);
extern void c_import_animate_demo_phase0_subphase0(void);
extern void c_import_animate_demo_phase0_subphase1(void);
extern void c_import_animate_demo_phase1_subphase0(void);
extern void c_import_animate_demo_phase1_subphase1(void);
extern void c_import_animate_demo_phase1_subphase2(void);
extern void c_import_animate_demo_phase1_subphase3(void);
extern void c_import_animate_demo_phase1_subphase4(void);
extern void c_import_update_mode0_demo_sub1(void);
extern void c_import_format_file_a(void);

#endif
