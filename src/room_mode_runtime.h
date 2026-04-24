#ifndef ROOM_MODE_RUNTIME_H
#define ROOM_MODE_RUNTIME_H

#include "room_state.h"
#include "link_state.h"
#include "save_state.h"
#include "item_state.h"

#ifdef __cplusplus
extern "C" {
#endif

void roommd_inc_submode(void);
void roommd_inc_2_submodes(void);
void roommd_init_mode_a_sub_a_go_to_mode4(void);
void roommd_init_mode4_go_to_sub0(void);
void roommd_update_mode11_death_sub_c(void);
void roommd_update_mode11_death_sub2(void);
void roommd_update_mode11_death_sub6(void);
void roommd_reset_vscroll_lo(void);
void roommd_select_transfer_buf(unsigned int val);
void roommd_select_transfer_buf_and_inc_state(unsigned int val);
unsigned int roommd_copy_next_row_to_transfer_buf(void);
unsigned int roommd_copy_next_row_advance_submode(void);
void roommd_set_fade_cycle_and_advance_submode(unsigned int val);
void roommd_update_mode7_scroll_sub2(void);
void roommd_update_mode7_scroll_sub7(void);
void roommd_update_mode7_scroll_sub6(void);
void roommd_cue_transfer_play_area_attrs_half_and_advance_submode(unsigned int ppu_hi, unsigned int ppu_lo, unsigned int end_off);
void roommd_update_menu_common2(void);
void roommd_update_menu_common3(void);
void roommd_update_menu_common4(void);
void roommd_update_menu5_ow(void);
void roommd_init_mode7_finish(void);
void roommd_switch_to_nt1(void);
void roommd_update_mode11_death_set_timer_inc_submode(unsigned int val);
void roommd_update_mode11_death_sub4(void);
void roommd_update_mode11_death_sub5(void);
void roommd_update_mode11_death_sub9(void);
void roommd_init_mode9_transfer_attrs(void);
void roommd_start_filling_hearts(void);
void roommd_init_mode_b_sub1(void);
void roommd_update_mode12_end_level_sub1(void);
void roommd_init_mode3_sub2(void);
void roommd_init_mode3_sub3(void);
void roommd_init_mode3_sub4(void);
void roommd_init_mode3_sub5(void);
void roommd_init_mode3_sub6(void);
void roommd_init_mode3_sub7(void);
void roommd_init_mode_a_sub1(void);
void roommd_end_game_mode12(void);
unsigned char roommd_end_game_mode(void);
void roommd_go_to_next_mode(void);
void roommd_go_to_next_mode_play_level_song(void);
void roommd_go_to_next_mode_reset_grid_offset(void);
void roommd_patch_and_cue_level_palettes_transfer(void);
void roommd_init_mode3_sub1(void);

#ifdef __cplusplus
}
#endif

/* --- External data arrays used by room_mode_runtime.c --- */
extern unsigned char LevelNumberTransferBuf[];
extern const unsigned char LevelSongIds[];
extern const unsigned char SaveSlotToPaletteRowOffset[];
extern unsigned char MenuPalettesTransferBuf[];

/* --- ASM shim / bank-forwarder functions used by room_mode_runtime.c --- */
extern void z05_copy_row_to_tilebuf(void);
extern void z05_copy_play_area_attrs_half(unsigned int ppu_hi, unsigned int ppu_lo, unsigned int end_off);
extern void z01_begin_update_mode(void);
extern void z07_patch_and_cue_level_palettes_transfer(void);
extern unsigned char z07_end_game_mode(void);

#endif
