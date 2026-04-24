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

#endif
