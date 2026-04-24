#ifndef PROGRESS_RUNTIME_H
#define PROGRESS_RUNTIME_H

#include "progress_state.h"

#ifdef __cplusplus
extern "C" {
#endif

void progrt_update_bomb_flash_effect(unsigned int slot);
void progrt_update_position_marker(unsigned char room_id, unsigned int idx);
void progrt_update_player_position_marker(void);
void progrt_update_world_curtain_effect(void);
void progrt_update_world_curtain_effect_bank2(void);
void progrt_fetch_file_a_address_set(void);
void progrt_check_tile_objects_blocking(void);
void progrt_check_power_triforce_fanfare(void);
void progrt_replace_ganon_brown_palette_row(void);
void progrt_replace_ganon_blue_palette_row(void);
void progrt_replace_ashes_palette_row(void);
unsigned char progrt_reset_room_tile_obj_info(void);
void progrt_set_room_flag_uw_item_state(void);
unsigned char progrt_get_room_flag_uw_item_state(void);

#ifdef __cplusplus
}
#endif

/* --- External data arrays used by progress_runtime.c --- */
extern const unsigned char SaveFileAAddressSets[];
extern const unsigned char LevelMasks[];
extern const unsigned char PaletteRow7TransferRecord[];
extern const unsigned char GanonColorTriples[];

/* --- ASM shim / bank-forwarder functions used by progress_runtime.c --- */
extern void z05_copy_column_to_tilebuf(void);
extern unsigned char z07_get_room_flags(void);

#endif
