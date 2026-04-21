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
