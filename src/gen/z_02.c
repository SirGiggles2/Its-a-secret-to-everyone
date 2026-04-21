/* z_02.c — C port of z_02 leaf functions.
 * Data tables and remaining code stay in z_02.asm.
 */

#include "../nes_abi.h"

void z02_animate_demo_phase1_sub0(void) {
    if (RAM(0x0015) & 0x01) {
        RAM(0x00FC)++;
        if (RAM(0x00FC) == 0xF0) {
            RAM(0x0415)++;
            RAM(0x00FC) = 0;
            RAM(0x005C)++;
        }
    }
    unsigned char vscroll = RAM(0x00FC);
    if (vscroll == 0x08 && RAM(0x0415) != 0) {
        RAM(0x0415) = 0;
        RAM(0x042D)++;
    }
}

void z02_animate_demo_phase1_sub1(void) {
    RAM(0x041A)++;
    if (RAM(0x041A) == 0)
        RAM(0x042D)++;
    RAM(0x041D) = 41;
    RAM(0x041C) = 0;
    RAM(0x0418) = 43;
    RAM(0x0417) = 0xE0;
}

void z02_disable_fallen_objects(void) {
    for (unsigned char x = 10; x >= 1; x--) {
        if (RAM(0x0084 + x) == 0xF0)
            RAM(0x00AC + x) = 0xFF;
    }
}

void z02_init_mode1_sub2(void) {
    RAM(0x0014) = 20;
    RAM(0x0013)++;
}

void z02_end_init_demo(unsigned int val) {
    RAM(0x0014) = (unsigned char)val;
    RAM(0x042D) = 0;
    RAM(0x0011)++;
}

void z02_mode_e_reset_variables(unsigned int val) {
    RAM(0x041F) = (unsigned char)val;
    RAM(0x0420) = (unsigned char)val;
    RAM(0x0421) = (unsigned char)val;
}

void z02_reset_button_repeat_state(unsigned int val) {
    RAM(0x0426) = (unsigned char)val;
    RAM(0x0428) = (unsigned char)val;
    RAM(0x0429) = (unsigned char)val;
}

void z02_mode_e_set_name_cursor_sprite_x(void) {
    RAM(0x0207) = RAM(0x0070);
}
