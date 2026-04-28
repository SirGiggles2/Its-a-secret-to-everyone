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

#endif
