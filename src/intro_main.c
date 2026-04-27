/* src/intro_main.c
 *
 * Native intro boot entry. Pre-intro shell init in genesis_shell.asm
 * has already run (VDP regs, RAM zero, A4/A5/D7 seed, save-slot load).
 * IPL is lowered. vblank_mode is 0 (native path active), so VBlankISR
 * is ticking music_tick and incrementing s_intro_frame_counter.
 *
 * s_intro_frame_counter is accessed via address literal ($00FF0FF8)
 * rather than an extern linkage — the ASM symbol is an equ constant,
 * not a global label, so the linker cannot resolve it directly.
 *
 * For Task 2 this is a stub that:
 *   - Requests title music via music_play($80) (audio_driver.asm:691).
 *   - Writes a "we are alive" probe byte to nes_ram[$07F0].
 *   - Spins in wait_vblank() forever, bumping nes_ram[$07F1] each frame.
 *
 * Task 3+ wires the real phase machine in.
 */
#include "intro_main.h"
#include "nes_abi.h"   /* nes_ram[] base */

#define S_INTRO_FRAME_COUNTER (*(volatile unsigned long *)0x00FF0FF8)

extern void music_play(unsigned char song_bitmap);    /* in audio_driver.asm */

static void wait_vblank(void) {
    unsigned long start = S_INTRO_FRAME_COUNTER;
    while (S_INTRO_FRAME_COUNTER == start) {
        /* spin */
    }
}

void intro_main(void) {
    music_play(0x80);         /* SongIntro per audio_driver.asm:691 */
    nes_ram[0x07F0] = 0xA1;   /* probe: intro_main entered */
    nes_ram[0x07F1] = 0;      /* frame-tick probe (low byte) */

    for (;;) {
        wait_vblank();
        nes_ram[0x07F1]++;
    }
}
