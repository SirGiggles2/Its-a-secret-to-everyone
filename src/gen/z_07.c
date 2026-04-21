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

unsigned char z07_get_room_flags(void) {
    unsigned char ptr_lo = nes_ram[NES_SRAM_BASE + 0x0BAF];
    unsigned char ptr_hi = nes_ram[NES_SRAM_BASE + 0x0BB0];
    RAM(0x00) = ptr_lo;
    RAM(0x01) = ptr_hi;
    unsigned short ptr = ((unsigned short)ptr_hi << 8) | ptr_lo;
    unsigned char room_id = RAM(0x00EB);
    return nes_ram[ptr + room_id];
}

void z07_mark_room_visited(void) {
    unsigned char flags = z07_get_room_flags();
    flags |= 0x20;
    unsigned short ptr = ((unsigned short)RAM(0x01) << 8) | RAM(0x00);
    unsigned char room_id = RAM(0x00EB);
    nes_ram[ptr + room_id] = flags;
}

void z07_reset_obj_state(unsigned int slot) {
    RAM(0x00AC + slot) = 0;
}

void z07_set_shot_spreading_state(unsigned int slot) {
    RAM(0x00AC + slot)++;
    RAM(0x0098 + slot) = 0xFE;
}

void z07_roll_over_anim_counter(unsigned int slot) {
    RAM(0x03D0 + slot) = RAM(0x00);
    RAM(0x03E4 + slot) ^= 0x01;
}

void z07_decrement_invincibility_timer(unsigned int slot) {
    if (RAM(0x04F0 + slot) == 0) return;
    if (RAM(0x0015) & 1) return;
    RAM(0x04F0 + slot)--;
}

void z07_update_dead_dummy(unsigned int slot) {
    RAM(0x0602) = 32;
    RAM(0x0405 + slot) = 16;
}

void z07_end_game_mode(void) {
    RAM(0x0011) = 0;
    RAM(0x0013) = 0;
}

void z07_set_shove_info_with0(unsigned int val, unsigned int slot) {
    RAM(0x00C0 + slot) = (unsigned char)val;
    RAM(0x00D3 + slot) = (unsigned char)val;
}

void z07_reset_obj_metastate(unsigned int slot) {
    RAM(0x0405 + slot) = 0;
}

void z07_anim_fetch_obj_pos(unsigned int slot) {
    RAM(0x0000) = RAM(0x0070 + slot);
    RAM(0x0001) = RAM(0x0084 + slot);
    RAM(0x000F) = 0;
}

