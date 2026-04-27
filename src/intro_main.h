/* src/intro_main.h
 *
 * Boot entry from src/genesis_shell.asm. Owns the main loop while the
 * native intro is running. Returns by jumping (not via stack) to the
 * Start handoff trampoline; never returns to the caller normally.
 */
#ifndef INTRO_MAIN_H
#define INTRO_MAIN_H

void intro_main(void);

#endif
