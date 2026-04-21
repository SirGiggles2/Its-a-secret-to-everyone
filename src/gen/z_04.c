/* z_04.c — C port of z_04 leaf functions.
 * Data tables and remaining code stay in z_04.asm.
 */

#include "../nes_abi.h"

void z04_hide_sprites_over_link(void) {
    RAM(0x0240) = 0xF8;
    RAM(0x0244) = 0xF8;
}
