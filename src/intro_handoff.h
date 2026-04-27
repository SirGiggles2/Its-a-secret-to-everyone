/* src/intro_handoff.h
 *
 * Start press handoff from native intro to the transpiled file-select
 * path. C side handles VDP cleanup and probe markers, then calls the
 * ASM trampoline (intro_to_file_select_trampoline, defined in
 * genesis_shell.asm) which restores A4/A5/D7, seeds RAM contract,
 * re-enables NMI heartbeat, flips vblank_mode, and jumps to the
 * translated main loop.
 */
#ifndef INTRO_HANDOFF_H
#define INTRO_HANDOFF_H

void intro_start_pressed(void);   /* called by intro_main poll_start */

#endif
