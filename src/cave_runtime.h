#ifndef CAVE_RUNTIME_H
#define CAVE_RUNTIME_H

#include "cave_state.h"

#ifdef __cplusplus
extern "C" {
#endif

void cavert_draw_cave_person(unsigned int slot);
void cavert_draw_cave_items(void);
void cavert_update_transfer_prices(void);
void cavert_update_talk_shop_or_door_charge(void);
void cavert_update_hint_or_money_game(void);
void cavert_update_cave_person(unsigned int slot);
void cavert_init_cave(unsigned int slot);
void cavert_try_take_item(unsigned int slot);
void cavert_try_take_room_item(void);
void cavert_clear_prices_cave_flag(void);
void cavert_update_person_state_delay_then_hide(void);
void cavert_format_decimal_byte(unsigned char val);
void cavert_write_prices_to_dynamic_transfer_buf(unsigned char price_char);
void cavert_write_prices_transfer_buf(void);
void cavert_update_person_state_textbox(void);

#ifdef __cplusplus
}
#endif

#endif
