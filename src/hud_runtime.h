#ifndef HUD_RUNTIME_H
#define HUD_RUNTIME_H

#include "nes_abi.h"

#ifdef __cplusplus
extern "C" {
#endif

void hudrt_format_hearts_in_text_buf(unsigned char start_off);
void hudrt_copy_triplet_to_text_buf(void);
void hudrt_format_decimal_count_byte(unsigned char val);
void hudrt_format_decimal_count_byte_in_text_buf(unsigned char val, unsigned char buf_offset);
void hudrt_format_status_bar_text(void);
void hudrt_world_change_rupees(void);

#ifdef __cplusplus
}
#endif

#endif
