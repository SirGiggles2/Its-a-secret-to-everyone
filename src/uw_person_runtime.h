#ifndef UW_PERSON_RUNTIME_H
#define UW_PERSON_RUNTIME_H

#include "nes_abi.h"

#ifdef __cplusplus
extern "C" {
#endif

void uwrt_init_underworld_person_a(unsigned int slot);
void uwrt_init_underworld_person_b(unsigned int slot);
void uwrt_init_underworld_person_c(unsigned int slot);
void uwrt_init_grumble_full(unsigned int slot);
void uwrt_init_rupee_stash_full(unsigned int slot);
void uwrt_init_life_or_money_full(unsigned int slot);
void uwrt_update_life_or_money_state_0(void);
void uwrt_underworld_person_destroy_if_taken(unsigned int slot);
void uwrt_person_flag_item_taken_and_advance_state(void);
void uwrt_check_person_blocking(void);
void uwrt_update_grumble1(void);
void uwrt_update_complex_state_sense_link(void);
void uwrt_update_life_or_money_state_2(void);
void uwrt_person_check_collisions(unsigned int slot);
void uwrt_person_draw_and_check_collisions(unsigned int slot);
void uwrt_draw_life_or_money_items(void);
void uwrt_update_grumble3(void);
void uwrt_update_person_complex(unsigned int slot);
void uwrt_update_person_full(unsigned int slot);
void uwrt_update_grumble_full(unsigned int slot);
void uwrt_update_life_or_money_full(unsigned int slot);

#ifdef __cplusplus
}
#endif

#endif
