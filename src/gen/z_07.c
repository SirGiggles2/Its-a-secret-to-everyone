/* z_07.c — C port of z_07 leaf functions.
 * Data tables and remaining code stay in z_07.asm.
 */

#include "../nes_abi.h"

#define NES_SRAM_BASE  0x6000u

void z07_hide_all_sprites(void) {
    for (unsigned char i = 0; i < 64; i++)
        RAM(0x0200 + (unsigned short)i * 4) = 0xF8;
}

unsigned char z07_get_unique_room_id(void) {
    unsigned char room = RAM(0x00EB);
    return nes_ram[NES_SRAM_BASE + 0x09FE + room] & 0x3F;
}

void z07_clear_room_history(void) {
    RAM(0x0529) = 0;
    for (signed char i = 5; i >= 0; i--)
        RAM(0x0621 + (unsigned char)i) = 0;
}

void z07_reset_player_state(void) {
    RAM(0x00AC) = 0;
    RAM(0x066C) = 0;
}

void z07_reset_moving_dir(void) {
    RAM(0x000F) = 0;
}

void z07_ensure_object_aligned(unsigned int slot) {
    if (RAM(0x0394 + slot) != 0) return;
    RAM(0x0070 + slot) &= 0xF8;
    RAM(0x0084 + slot) = (RAM(0x0084 + slot) & 0xF8) | 0x05;
}
