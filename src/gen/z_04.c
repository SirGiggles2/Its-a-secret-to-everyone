/* z_04.c — C port of z_04 leaf functions.
 * Data tables and remaining code stay in z_04.asm.
 */

#include "../nes_abi.h"

extern void z04_reset_flyer_state(unsigned int slot);
extern void z04_init_digdogger1(unsigned int slot);
extern void z07_reset_obj_state(unsigned int slot);
extern void z07_reset_obj_metastate(unsigned int slot);
extern void z07_reset_obj_metastate_and_timer(unsigned int slot);

extern const unsigned char TektiteStartingDirs[];
extern const unsigned char GanonStartXs[];
extern const unsigned char Directions8[];

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

void z04_flyer_set_state_and_turns(unsigned int state, unsigned int slot) {
    RAM(0x0444 + slot) = (unsigned char)state;
    RAM(0x042C + slot) = 6;
}

void z04_init_aquamentus(unsigned int slot) {
    RAM(0x04B2 + slot) = 0xE2;
    RAM(0x0601) = 16;
    RAM(0x0070 + slot) = 0xB0;
    RAM(0x0084 + slot) = 0x80;
}

void z04_init_tektite(unsigned int slot) {
    unsigned char rnd = RAM(0x0019 + slot) & 0x03;
    unsigned char dir = TektiteStartingDirs[rnd];
    RAM(0x0098 + slot) = dir;
    unsigned char timer = dir << 2;
    RAM(0x0028 + slot) = timer;
}

void z04_ganon_randomize_location(unsigned int slot) {
    RAM(0x0084 + slot) = 0xA0;
    unsigned char idx = RAM(0x0015) & 0x01;
    RAM(0x0070 + slot) = GanonStartXs[idx];
}

void z04_init_digdogger1(unsigned int slot) {
    RAM(0x0601) = 64;
    unsigned char rnd = RAM(0x0018 + slot) & 0x07;
    unsigned char dir = Directions8[rnd];
    RAM(0x0098 + slot) = dir;
    RAM(0x041F + slot) = 63;
    RAM(0x0437 + slot) = 0x80;
    RAM(0x0507) = 3;
}

void z04_end_init_flyer(unsigned int slot) {
    z04_reset_flyer_state(slot);
    RAM(0x04D1) = 0xA0;
    RAM(0x041F + slot) = 31;
}

void z04_init_digdogger2(unsigned int slot) {
    z04_init_digdogger1(slot);
    RAM(0x034F + slot) = 56;
    RAM(0x0507) = 1;
}

void z04_update_dodongo_bloated_sub_end(unsigned int slot) {
    z07_reset_obj_state(slot);
    RAM(0x042C + slot) = 0;
}

void z04_set_up_fairy_object(unsigned int slot) {
    RAM(0x0602) = 8;
    z04_reset_flyer_state(slot);
    RAM(0x0098 + slot) = 8;
    RAM(0x041F + slot) = 127;
    RAM(0x04D1) = 0xA0;
}

void z04_jumper_point_boulder_downward(unsigned int slot) {
    if (RAM(0x034F + slot) != 0x20)
        return;
    unsigned char dir = RAM(0x0098 + slot) & 0x03;
    RAM(0x0098 + slot) = dir | 0x04;
}

void z04_flyer_delay(unsigned int slot) {
    if (RAM(0x0028 + slot) == 0)
        RAM(0x0444 + slot) = 0;
}

void z04_manhandla_set_all_segments_direction(unsigned int val) {
    for (signed char i = 4; i >= 0; i--)
        RAM(0x0099 + (unsigned char)i) = (unsigned char)val;
}

unsigned int z04_extract_hit_point_value(unsigned int val) {
    if (RAM(0x0000) & 1)
        return (val << 4) & 0xFF;
    else
        return val & 0xF0;
}

void z04_reset_flyer_state(unsigned int slot) {
    RAM(0x0412 + slot) = 0;
    RAM(0x042C + slot) = 0;
    RAM(0x0437 + slot) = 0;
    RAM(0x0444 + slot) = 0;
    RAM(0x04F0 + slot) = 0;
}

void z04_reset_push_timer(unsigned int slot) {
    RAM(0x0412 + slot) = 0;
}

void z04_set_dead_dummy_obj_type(unsigned int slot) {
    RAM(0x034F + slot) = 93;
}

void z04_jumper_reset_vspeed_frac(unsigned int slot) {
    RAM(0x041F + slot) = 0;
}

void z04_gleeok_set_segment_y(unsigned int val3, unsigned int slot) {
    RAM(0x0086 + slot) = (unsigned char)val3;
}

void z04_init_monster_shot(unsigned int slot) {
    RAM(0x03BC + slot) = 0xC0;
    z07_reset_obj_metastate(slot);
}

void z04_init_boulder(unsigned int slot) {
    z07_reset_obj_metastate_and_timer(slot);
    z04_init_tektite(slot);
}

void z04_init_boulder_set(unsigned int slot) {
    RAM(0x0515) = 0;
    z04_init_boulder(slot);
}
