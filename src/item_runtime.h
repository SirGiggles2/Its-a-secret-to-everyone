#ifndef ITEM_RUNTIME_H
#define ITEM_RUNTIME_H

#include "item_state.h"

#ifdef __cplusplus
extern "C" {
#endif

void itemrt_take_item(unsigned char item_id);

#ifdef __cplusplus
}
#endif

/* --- External data arrays used by item_runtime.c --- */
extern const unsigned char LevelMasks[];
extern const unsigned char LinkColors_CommonCode[];
extern const unsigned char SaveSlotToPaletteRowOffset[];
extern unsigned char MenuPalettesTransferBuf[];
extern const unsigned char ItemIdToSlot[];
extern const unsigned char ItemIdToDescriptor[];

/* --- ASM shim / bank-forwarder functions used by item_runtime.c --- */
extern unsigned char z07_end_game_mode(void);
extern void z07_patch_and_cue_level_palettes_transfer(void);
extern void z01_take_power_triforce(void);
extern void z01_take_5_rupees(void);
extern void z01_take_one_rupee(void);
extern void z01_take_hearts(void);
extern void z01_take_hearts_no_sound(void);
extern void z01_play_key_taken_tune(void);
extern void z01_set_item_value(unsigned int val, unsigned int slot3);

#endif
