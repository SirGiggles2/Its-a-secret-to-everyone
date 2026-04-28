/* src/intro_main.c
 *
 * Native intro boot entry. Pre-intro shell init in genesis_shell.asm
 * has already run. IPL is lowered. vblank_mode is 0 (native path
 * active), so VBlankISR is ticking music_tick and incrementing
 * s_intro_frame_counter.
 *
 * intro_main runs the phase machine and polls the controller for
 * Start press each frame. On press, calls intro_start_pressed which
 * jumps to the ASM trampoline and never returns.
 *
 * s_intro_frame_counter is accessed via address literal ($00FF0FF8)
 * rather than an extern linkage — the ASM symbol is an equ constant,
 * not a global label, so the linker cannot resolve it directly.
 */
#include "intro_main.h"
#include "platform_abi.h"
#include "intro_phase.h"
#include "intro_handoff.h"
#include "render_abi.h"

#define S_INTRO_FRAME_COUNTER (*(volatile unsigned long *)0x00FF0FF8)

#define CTRL1_DATA  (*(volatile unsigned char *)0x00A10003)

#define BTN_START   0x20

extern void music_play(unsigned char song_bitmap);

static void wait_vblank(void) {
    unsigned long start = S_INTRO_FRAME_COUNTER;
    while (S_INTRO_FRAME_COUNTER == start) {
        /* spin */
    }
}

static unsigned char read_controller_buttons(void) {
    /* TH=0 read latches Start/A at bits 5,4. Active low, so invert. */

    /* Phase 1: TH=1 idle assert (also reads C, B which we don't need) */
    CTRL1_DATA = 0x40;
    volatile int i;
    for (i = 0; i < 4; i++) { /* settle */ }

    /* Phase 2: TH=0 — Start at bit 5, A at bit 4. Active low. */
    CTRL1_DATA = 0x00;
    for (i = 0; i < 4; i++) { /* settle */ }
    unsigned char raw = ~CTRL1_DATA;

    /* Restore TH=1 idle state (matches _ctrl_strobe convention) */
    CTRL1_DATA = 0x40;
    return raw;
}

static unsigned char poll_start(unsigned short frame) {
    static unsigned char prev_start = 0;
    if (frame < 4u) {
        /* Ignore controller cold-read junk for the first few frames
         * after boot — port lines may not have settled. */
        prev_start = 0;
        return 0;
    }
    unsigned char raw = read_controller_buttons();
    unsigned char start_now = (raw & BTN_START) ? 1 : 0;
    unsigned char pressed = (start_now && !prev_start);
    prev_start = start_now;
    return pressed;
}

void intro_main(void) {
    /* Switch VDP plane to H32 x V32 ($9000). Lifted intro code (intro_title.c,
     * intro_story.c, intro_handoff.c clear_plane) uses row*64 byte stride which
     * is correct only for V32. Main ROM boot sets V64 ($9011) for transpiled
     * gameplay; trampoline restores V64 on Start press handoff. */
    render_mode_set_v32();
    /* Disable Window plane. genesis_shell.asm:261 enables Window covering
     * top 8 rows ($9208) for transpiled-gameplay HUD isolation, with the
     * Window plane filled by tile $05FF blank. That overlay HIDES the top
     * 8 rows of plane A in the intro (vines border + "THE LEGEND OF"
     * subtitle). Set reg 18 = $00 here so plane A's top is visible.
     * Trampoline restores $9208 before resuming transpiled gameplay. */
    *(volatile unsigned short *)0x00C00004 = 0x9200;  /* Reg 18 = 0: window V off */
    music_play(0x80);
    nes_ram[0x07FF] = 0xA1;  /* sentinel: intro_main entered (not phase byte at $07F0) */
    nes_ram[0x07F1] = 0;
    nes_ram[0x07F2] = 0;
    intro_phase_init();
    /* Run first phase step BEFORE any wait_vblank — title_setup enables
     * the display so vblank polling has stable state afterward. Mirrors
     * intro_demo's main.c pattern. */
    intro_phase_step();

    unsigned short frame = 0;
    for (;;) {
        wait_vblank();
        nes_ram[0x07F1] = (unsigned char)(frame & 0xFF);
        intro_phase_step();
        if (poll_start(frame)) {
            intro_start_pressed();
            /* unreachable — trampoline jmps, never returns */
        }
        frame++;
    }
}
