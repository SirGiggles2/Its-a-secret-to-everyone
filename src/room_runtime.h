#ifndef ROOM_RUNTIME_H
#define ROOM_RUNTIME_H

#include "room_state.h"

#ifdef __cplusplus
extern "C" {
#endif

unsigned char roomrt_has_compass(void);
unsigned char roomrt_has_map(void);
unsigned char roomrt_get_room_flags(void);
void roomrt_hide_all_sprites(void);
unsigned char roomrt_get_unique_room_id(void);
void roomrt_clear_room_history(void);
void roomrt_reset_player_state(void);
void roomrt_mark_room_visited(void);
void roomrt_calc_open_doorway_mask(unsigned int attr, unsigned int dir_idx);
void roomrt_add_door_flags(void);
unsigned int roomrt_split_room_id(void);
unsigned char roomrt_is_dark_room(unsigned int col);
void roomrt_set_door_flag(unsigned int dir_idx);
void roomrt_reset_door_flag(unsigned int dir_idx);
void roomrt_check_has_living_monsters(void);
void roomrt_silence_sound(void);
void roomrt_set_entering_doorway(void);
void roomrt_save_kill_count_ow(unsigned int slot);
void roomrt_trigger_open_door(unsigned int val);
void roomrt_touch_door_wall(void);
void roomrt_touch_door_open(void);
void roomrt_wield_nothing(void);
void roomrt_mask_cur_ppu_mask_grayscale(void);
void roomrt_block_at_wall(void);
unsigned int roomrt_check_secret_trigger_none(void);
unsigned int roomrt_trigger_shutters(void);
unsigned int roomrt_return_false(void);
unsigned int roomrt_check_secret_trigger_all_dead(void);
unsigned int roomrt_check_secret_trigger_last_boss(void);
unsigned int roomrt_check_secret_trigger_money_or_life(void);
unsigned int roomrt_check_secret_trigger_block_door(void);
unsigned int roomrt_check_secret_trigger_ringleader(void);
void roomrt_touch_door_bombable(void);
void roomrt_block_until_time(void);
unsigned int roomrt_touch_door_false(void);
void roomrt_touch_door_shutter(void);
void roomrt_check_screen_edge(void);

#ifdef __cplusplus
}
#endif

#endif
