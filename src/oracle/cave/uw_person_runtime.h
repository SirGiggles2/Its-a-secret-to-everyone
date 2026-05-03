#ifndef UW_PERSON_RUNTIME_H
#define UW_PERSON_RUNTIME_H

#include "platform_abi.h"

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

/* --- External data arrays used by uw_person_runtime.c --- */
extern const unsigned char UnderworldPersonTextSelectorsA[];
extern const unsigned char UnderworldPersonTextSelectorsC[];
extern const unsigned char TextboxLineAddrsLo[];
extern const unsigned char RupeeStashXs[];
extern const unsigned char RupeeStashYs[];
extern const unsigned char LifeOrMoneyItemXs[];
extern const unsigned char LifeOrMoneyItemTypes[];

/* --- ASM shim functions used by uw_person_runtime.c --- */
extern void c_check_monster_collisions(unsigned int slot);
extern void c_animate_item_object(unsigned char item_type, unsigned int slot);
extern void c_draw_object_mirrored(unsigned int slot);
extern void c_draw_object_not_mirrored(unsigned int slot);
extern void c_link_end_move_and_animate_bank1(void);
extern void c_update_person_state_textbox(void);

#endif
