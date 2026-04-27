/* intro_demo/main.c — boot entry: dispatch phase machine each vblank. */
#include "intro_phase.h"

#define VDP_DATA_WORD (*(volatile unsigned short *)0x00C00000)
#define VDP_CTRL_WORD (*(volatile unsigned short *)0x00C00004)
#define VDP_CTRL_LONG (*(volatile unsigned long  *)0x00C00004)

static void wait_vblank(void) {
    while ( (VDP_CTRL_WORD & 0x0008));
    while (!(VDP_CTRL_WORD & 0x0008));
}

int main(void) {
    intro_phase_init();
    /* Run first phase step before any wait_vblank — title load enables
     * the display so vblank polling can latch correctly afterward. */
    intro_phase_step();
    for (;;) {
        wait_vblank();
        intro_phase_step();
    }
    return 0;
}
