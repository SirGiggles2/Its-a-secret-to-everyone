/* z_01.c — C port of z_01 leaf functions.
 * Data tables and remaining code stay in z_01.asm.
 */

#include "../nes_abi.h"

void z01_play_character_sfx(void) {
    RAM(0x0602) = 8;
}

void z01_reset_room_tile_obj_info(void) {
    RAM(0x052B) = 0;
    RAM(0x052C) = 0;
    RAM(0x052D) = 0;
}

void z01_play_key_taken_tune(void) {
    RAM(0x0602) = 0;
    RAM(0x0604) = 8;
}

void z01_take_power_triforce(void) {
    RAM(0x0509)++;
    RAM(0x0028) = 0xC0;
    RAM(0x00AC) = 64;
}

void z01_silence_all_sound(void) {
    RAM(0x0604) = 0x80;
    RAM(0x0603) = 0x80;
    RAM(0x0605) = 0;
    RAM(0x0607) = 0;
}

void z01_post_debit(unsigned int amount) {
    RAM(0x067E) = (unsigned char)(RAM(0x067E) + amount);
}

void z01_init_one_simple_object(unsigned int slot) {
    RAM(0x034F + slot) = RAM(0x00);
    RAM(0x0492 + slot) = 0;
    RAM(0x04BF + slot) = RAM(0x01);
}

void z01_destroy_object_wram(unsigned int val, unsigned int slot) {
    RAM(0x00C0 + slot) = val;
    RAM(0x00D3 + slot) = val;
    RAM(0x0028 + slot) = val;
    RAM(0x00AC + slot) = val;
    RAM(0x04F0 + slot) = val;
    RAM(0x0492 + slot) = 0xFF;
    RAM(0x0405 + slot) = 1;
}

void z01_destroy_whirlwind(unsigned int slot) {
    RAM(0x034F + slot) = 0;
    RAM(0x00C0 + slot) = 0;
    RAM(0x00D3 + slot) = 0;
    RAM(0x0028 + slot) = 0;
    RAM(0x00AC + slot) = 0;
    RAM(0x04F0 + slot) = 0;
    RAM(0x0492 + slot) = 0xFF;
    RAM(0x0405 + slot) = 1;
}

void z01_uw_person_complex_state_delay_and_quit(void) {
    unsigned char timer = RAM(0x0029);
    if (timer == 0)
        RAM(0x0350) = 0;
}

void z01_set_boomerang_speed(unsigned int val, unsigned int slot) {
    RAM(0x03BC + slot) = val;
    unsigned char state = RAM(0x00AC + slot) & 0xF0;
    if (state == 0x40) {
        unsigned char spd = RAM(0x03BC + slot);
        RAM(0x03BC + slot) = spd >> 1;
        RAM(0x0380 + slot)--;
        if (RAM(0x0380 + slot) == 0)
            RAM(0x00AC + slot) = 80;
    }
}

void z01_set_up_common_cave_objects(unsigned int x, unsigned int slot, unsigned int y) {
    RAM(0x0070 + slot) = x;
    RAM(0x0084 + slot) = y;
    RAM(0x0485 + slot) = 0;
    RAM(0x04BF + slot) = 0x81;
    RAM(0x00AC) = 64;
    RAM(0x0351) = 64;
    RAM(0x0352) = 64;
    RAM(0x0071 + slot) = 72;
    RAM(0x0072 + slot) = 0xA8;
    RAM(0x0085 + slot) = y;
    RAM(0x0086 + slot) = y;
}
