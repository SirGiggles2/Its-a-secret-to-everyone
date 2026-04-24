#ifndef SAVE_MENU_RUNTIME_H
#define SAVE_MENU_RUNTIME_H

#include "frontend_state.h"

#ifdef __cplusplus
extern "C" {
#endif

void savert_update_mode_d_save_sub2(void);
void savert_fetch_profile_name_address(void);

/* Menu / Meters / Item-Scroll-Down dispatchers (drained from z_05). */
void savert_update_menu_and_meters(void);
void savert_update_menu(void);
void savert_update_menu_common_1(void);
void savert_update_menu_5_uw(void);
void savert_update_menu_scroll_down_ow(void);
void savert_update_menu_scroll_down_uw(void);

#ifdef __cplusplus
}
#endif

/* --- External data arrays used by save_menu_runtime.c --- */
extern const unsigned char ProfileNameAddrsLo[];
extern const unsigned char ProfileNameAddrsHi[];

/* --- ASM shim functions used by save_menu_runtime.c --- */
extern void c_import_sram_commit(void);
extern void c_hide_all_sprites(void);
extern void c_update_player_position_marker(void);
extern void c_move_position_markers(unsigned int vel);
extern void c_update_triforce_position_marker(void);
extern void c_update_hearts_and_rupees(void);
extern void c_submenu_cue_transfer_row_uw(void);
extern void c_submenu_cue_transfer_row_ow(void);
extern void c_update_menu_active(void);
extern void c_update_menu_scroll_up(void);
extern void c_update_menu_start_ow(void);

/* --- Bank-forwarder functions used by save_menu_runtime.c --- */
extern void z05_update_menu_common2(void);
extern void z05_update_menu_common3(void);
extern void z05_update_menu_common4(void);
extern void z05_update_menu5_ow(void);

#endif
