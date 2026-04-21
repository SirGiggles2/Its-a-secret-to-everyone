/* z_04.c — C port of z_04 leaf functions.
 * Data tables and remaining code stay in z_04.asm.
 */

#include "../nes_abi.h"

void z04_hide_sprites_over_link(void) {
    RAM(0x0240) = 0xF8;
    RAM(0x0244) = 0xF8;
}

void z04_play_secret_found_tune(void) {
    RAM(0x0602) = 4;
}

void z04_play_boss_death_cry(void) {
    RAM(0x0601) = 2;
    RAM(0x0603) = 0x80;
}

void z04_dodongo_dec_bloated_timer(unsigned int slot) {
    RAM(0x045E + slot)--;
}

void z04_gleeok_dec_head_timer(void) {
    RAM(0x0418)--;
}

void z04_gleeok_set_segment_x(unsigned int val, unsigned int slot) {
    RAM(0x0072 + slot) = (unsigned char)val;
}

void z04_gohma_play_parry_tune(void) {
    RAM(0x0604) = 1;
}
