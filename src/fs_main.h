/* src/fs_main.h
 *
 * Boot entry from boot.asm (proof ROM) or intro_handoff.c (main ROM v6).
 * Owns main loop while native File Select is active. Returns by jumping
 * to fs_to_transpiled_trampoline (v6); never returns normally.
 */
#ifndef FS_MAIN_H
#define FS_MAIN_H

void fs_main(void);

#endif
